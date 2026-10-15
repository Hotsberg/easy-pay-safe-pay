import AVFoundation
import CallKit
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EasyPayNative") {
      EasyPayNative.register(with: registrar)
    }
  }
}

/// Gives the Flutter UI the phone features it needs (channel "com.easypay.safepay/native"), matching MainActivity.kt:
/// UPI payment via the user's own UPI app, QR scanning, text-to-speech, voice input, calls and links.
/// The app never sees or handles a UPI PIN.
final class EasyPayNative: NSObject, FlutterPlugin {
  private static var instance: EasyPayNative?

  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?
  private let synth = AVSpeechSynthesizer()
  private var listener: VoiceListener?
  private var upiResult: FlutterResult?
  private var leftApp = false
  // Sees phone, FaceTime and WhatsApp calls (anything using CallKit) without any permission
  private let callObserver = CXCallObserver()

  // iOS UPI apps register their own URL schemes; "upi://" is claimed by BHIM and some others.
  // Each scheme must also be listed under LSApplicationQueriesSchemes in Info.plist.
  private static let upiApps: [(name: String, prefix: String)] = [
    ("Google Pay", "gpay://upi/pay?"),
    ("PhonePe", "phonepe://pay?"),
    ("Paytm", "paytmmp://pay?"),
    ("BHIM", "upi://pay?"),
  ]

  init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
    super.init()
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    nc.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(captureChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
  }

  /// Screen recording, AirPlay mirroring or screen sharing started or stopped: tell the app straight away.
  @objc private func captureChanged() {
    channel.invokeMethod("onCaptureChanged", arguments: UIScreen.main.isCaptured)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.easypay.safepay/native", binaryMessenger: registrar.messenger())
    let plugin = EasyPayNative(channel: channel, registrar: registrar)
    instance = plugin
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "speak":
      speak(args["text"] as? String ?? "", locale: args["locale"] as? String ?? "en-IN")
      result(nil)
    case "stopSpeaking":
      synth.stopSpeaking(at: .immediate)
      result(nil)
    case "canListen":
      result(SFSpeechRecognizer(locale: Locale(identifier: "en-IN")) != nil
        && SFSpeechRecognizer.authorizationStatus() != .denied
        && SFSpeechRecognizer.authorizationStatus() != .restricted)
    case "listen":
      synth.stopSpeaking(at: .immediate)
      listener?.finish()
      let l = VoiceListener()
      listener = l
      l.start(locale: args["locale"] as? String ?? "en-IN") { [weak self] text in
        self?.listener = nil
        result(text)
      }
    case "scanQr":
      scanQr(cancelLabel: args["cancel"] as? String ?? "Cancel", result: result)
    case "payUpi":
      payUpi(args["uri"] as? String ?? "", cancelLabel: args["cancel"] as? String ?? "Cancel", result: result)
    case "setSecure":
      result(nil) // iOS cannot block screenshots; screenCaptured / onCaptureChanged warn instead
    case "isOnCall":
      result(callObserver.calls.contains { !$0.hasEnded })
    case "screenCaptured":
      result(UIScreen.main.isCaptured)
    case "remoteApps":
      result([String]()) // iOS apps cannot control another app; screen sharing shows up as screenCaptured
    case "openUrl":
      if let url = URL(string: args["url"] as? String ?? "") { UIApplication.shared.open(url) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // ---- text-to-speech ----
  private func speak(_ text: String, locale: String) {
    var voice = AVSpeechSynthesisVoice(language: locale)
    if voice == nil {
      channel.invokeMethod("onTtsMissing", arguments: nil)
      voice = AVSpeechSynthesisVoice(language: "en-IN")
    }
    // Playback category: speech is heard even with the silent switch on
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    synth.stopSpeaking(at: .immediate)
    let u = AVSpeechUtterance(string: text)
    u.voice = voice
    u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
    synth.speak(u)
  }

  // ---- QR scanner ----
  private func scanQr(cancelLabel: String, result: @escaping FlutterResult) {
    guard AVCaptureDevice.default(for: .video) != nil else { return result("__unavailable__") }
    let present = { [weak self] in
      guard let host = self?.topViewController() else { return result("__unavailable__") }
      let vc = QrScannerViewController(cancelLabel: cancelLabel) { text in result(text) }
      vc.modalPresentationStyle = .fullScreen
      host.present(vc, animated: true)
    }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      present()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { ok in
        DispatchQueue.main.async { ok ? present() : result("__unavailable__") }
      }
    default:
      result("__unavailable__")
    }
  }

  // ---- UPI payment ----
  /// Hands the payment to the user's UPI app. Answers nil when no UPI app is installed.
  /// iOS UPI apps do not report back, so the answer is always "" (the app then says "could not confirm").
  private func payUpi(_ uri: String, cancelLabel: String, result: @escaping FlutterResult) {
    let query = uri.components(separatedBy: "?").dropFirst().joined(separator: "?")
    let installed = Self.upiApps.compactMap { app -> (String, URL)? in
      guard let url = URL(string: app.prefix + query), UIApplication.shared.canOpenURL(url) else { return nil }
      return (app.name, url)
    }
    if installed.isEmpty { return result(nil) }
    if installed.count == 1 { return open(installed[0].1, result: result) }
    guard let host = topViewController() else { return open(installed[0].1, result: result) }
    let sheet = UIAlertController(title: "Pay with", message: nil, preferredStyle: .actionSheet)
    for (name, url) in installed {
      sheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in self?.open(url, result: result) })
    }
    sheet.addAction(UIAlertAction(title: cancelLabel, style: .cancel) { _ in result("") })
    sheet.popoverPresentationController?.sourceView = host.view
    sheet.popoverPresentationController?.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.maxY, width: 0, height: 0)
    host.present(sheet, animated: true)
  }

  private func open(_ url: URL, result: @escaping FlutterResult) {
    upiResult?("")
    upiResult = result
    leftApp = false
    UIApplication.shared.open(url) { [weak self] ok in
      if !ok, let r = self?.upiResult {
        self?.upiResult = nil
        r("")
      }
    }
  }

  @objc private func didEnterBackground() {
    if upiResult != nil { leftApp = true }
  }

  /// Back from the UPI app: report "" so the app asks the user to check the UPI app's history.
  @objc private func didBecomeActive() {
    guard leftApp, let r = upiResult else { return }
    leftApp = false
    upiResult = nil
    r("")
  }

  private func topViewController() -> UIViewController? {
    var vc = registrar?.viewController
      ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
  }
}

/// Speech input with Apple's recogniser. Stops after 1.5 s of silence or 8 s in total, and answers
/// up to three alternatives joined with "|" ("" when nothing was heard or permission was refused).
final class VoiceListener {
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var silenceTimer: Timer?
  private var maxTimer: Timer?
  private var tapped = false
  private var heard: [String] = []
  private var done: ((String) -> Void)?

  func start(locale: String, done: @escaping (String) -> Void) {
    self.done = done
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else { return self.finish() }
        let granted: (Bool) -> Void = { ok in DispatchQueue.main.async { ok ? self.begin(locale) : self.finish() } }
        if #available(iOS 17.0, *) {
          AVAudioApplication.requestRecordPermission(completionHandler: granted)
        } else {
          AVAudioSession.sharedInstance().requestRecordPermission(granted)
        }
      }
    }
  }

  private func begin(_ locale: String) {
    guard done != nil else { return }
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else { return finish() }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let req = SFSpeechAudioBufferRecognitionRequest()
      req.shouldReportPartialResults = true
      request = req
      let input = engine.inputNode
      input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in req.append(buffer) }
      tapped = true
      engine.prepare()
      try engine.start()
      task = recognizer.recognitionTask(with: req) { [weak self] res, err in
        DispatchQueue.main.async {
          guard let self else { return }
          if let res {
            self.heard = res.transcriptions.prefix(3).map { $0.formattedString }
            if res.isFinal { return self.finish() }
            self.silenceTimer?.invalidate()
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in self?.finish() }
          }
          if err != nil { self.finish() }
        }
      }
      maxTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in self?.finish() }
    } catch {
      finish()
    }
  }

  func finish() {
    guard let done else { return }
    self.done = nil
    silenceTimer?.invalidate()
    maxTimer?.invalidate()
    if engine.isRunning { engine.stop() }
    if tapped {
      engine.inputNode.removeTap(onBus: 0)
      tapped = false
    }
    request?.endAudio()
    task?.cancel()
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    done(heard.joined(separator: "|"))
  }
}

/// Full-screen camera view that reads one UPI QR code. Answers the text, or "" when cancelled.
final class QrScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let session = AVCaptureSession()
  private let cancelLabel: String
  private var onDone: ((String) -> Void)?

  init(cancelLabel: String, onDone: @escaping (String) -> Void) {
    self.cancelLabel = cancelLabel
    self.onDone = onDone
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    let output = AVCaptureMetadataOutput()
    if let device = AVCaptureDevice.default(for: .video),
       let input = try? AVCaptureDeviceInput(device: device),
       session.canAddInput(input), session.canAddOutput(output) {
      session.addInput(input)
      session.addOutput(output)
      output.setMetadataObjectsDelegate(self, queue: .main)
      output.metadataObjectTypes = [.qr]
      let preview = AVCaptureVideoPreviewLayer(session: session)
      preview.videoGravity = .resizeAspectFill
      preview.frame = view.bounds
      view.layer.addSublayer(preview)
    }

    // A square guide in the middle
    let frame = UIView()
    frame.translatesAutoresizingMaskIntoConstraints = false
    frame.layer.borderColor = UIColor.white.cgColor
    frame.layer.borderWidth = 4
    frame.layer.cornerRadius = 16
    view.addSubview(frame)

    // Big, high-contrast cancel button
    let cancel = UIButton(type: .system)
    cancel.translatesAutoresizingMaskIntoConstraints = false
    cancel.setTitle("✕  \(cancelLabel)", for: .normal)
    cancel.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
    cancel.setTitleColor(.black, for: .normal)
    cancel.backgroundColor = .white
    cancel.layer.cornerRadius = 14
    cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    view.addSubview(cancel)

    NSLayoutConstraint.activate([
      frame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      frame.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
      frame.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
      frame.heightAnchor.constraint(equalTo: frame.widthAnchor),
      cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      cancel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
      cancel.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
    ])
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view.layer.sublayers?.compactMap { $0 as? AVCaptureVideoPreviewLayer }.forEach { $0.frame = view.bounds }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let s = session
    DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let s = session
    DispatchQueue.global(qos: .userInitiated).async { s.stopRunning() }
  }

  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
    guard let code = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    finish(code)
  }

  @objc private func cancelTapped() { finish("") }

  private func finish(_ text: String) {
    guard let done = onDone else { return }
    onDone = nil
    dismiss(animated: true) { done(text) }
  }
}
