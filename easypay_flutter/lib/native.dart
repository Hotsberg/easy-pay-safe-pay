// Bridge to the phone (MainActivity.kt on Android, AppDelegate.swift on iOS): UPI payment via the user's own
// UPI app, QR scanning, text-to-speech, voice input, calls and links. The app never sees or handles a UPI PIN.
// On other platforms every call degrades to a safe no-op, so the UI can be tried with `flutter run -d chrome`/desktop.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Native {
  static const _ch = MethodChannel('com.easypay.safepay/native');

  static bool get available =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Called when the phone has no voice for the chosen language.
  static void Function()? onTtsMissing;

  /// Called on iPhone when screen recording, mirroring or screen sharing starts or stops.
  static void Function(bool captured)? onCaptureChanged;

  static void init() {
    if (!available) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onTtsMissing') onTtsMissing?.call();
      if (call.method == 'onCaptureChanged') onCaptureChanged?.call(call.arguments == true);
    });
  }

  // ---- security signals, measured by the phone (no permission prompts) ----

  /// Hide the app from screenshots, screen recording, screen sharing and the recent-apps preview (Android FLAG_SECURE).
  /// On by default in MainActivity before any screen is drawn; only a demo build that mirrors to a projector turns it off.
  static Future<void> setSecure(bool on) => _call<void>('setSecure', {'on': on});

  /// True during a phone call or a WhatsApp / internet call.
  static Future<bool> isOnCall() async => await _call<bool>('isOnCall') ?? false;

  /// True while the screen is recorded, mirrored or shared (iPhone; Android blocks capture instead).
  static Future<bool> screenCaptured() async => await _call<bool>('screenCaptured') ?? false;

  /// Names of installed remote-control apps scammers use (AnyDesk, TeamViewer, RustDesk, AirDroid).
  static Future<List<String>> remoteApps() async =>
      (await _call<List<Object?>>('remoteApps') ?? const []).map((e) => '$e').toList();

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    if (!available) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> speak(String text, String locale) => _call<void>('speak', {'text': text, 'locale': locale});

  static Future<void> stopSpeaking() => _call<void>('stopSpeaking');

  static Future<bool> canListen() async => await _call<bool>('canListen') ?? false;

  /// Up to three recognised alternatives joined with "|", or '' when nothing was heard.
  static Future<String> listen(String locale) async => await _call<String>('listen', {'locale': locale}) ?? '';

  /// The scanned text, '' when the scanner was closed, or '__unavailable__' when there is no scanner
  /// (no Google Play services on Android, no camera or camera permission refused on iOS).
  /// [cancel] labels the iOS scanner's close button.
  /// [prompt] is shown on Android's built-in fallback scanner.
  static Future<String> scanQr(String cancel, [String prompt = '']) async =>
      await _call<String>('scanQr', {'cancel': cancel, 'prompt': prompt}) ?? '__unavailable__';

  /// Hands the payment to the user's UPI app and returns its response string,
  /// or null when no UPI app is installed. iOS UPI apps never report back, so iOS always answers ''
  /// and the app shows "could not confirm, check your UPI app's history".
  /// [cancel] labels the iOS "Pay with" chooser's cancel button.
  static Future<String?> payUpi(String uri, String cancel) => _call<String>('payUpi', {'uri': uri, 'cancel': cancel});

  /// tel:, https: and WhatsApp links leave the app.
  static Future<void> openUrl(String url) => _call<void>('openUrl', {'url': url});
}
