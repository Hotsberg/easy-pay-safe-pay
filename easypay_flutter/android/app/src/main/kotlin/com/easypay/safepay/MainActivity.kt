package com.easypay.safepay

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import java.util.Locale

/**
 * Hosts the Flutter UI and gives it the phone features it needs (channel "com.easypay.safepay/native"):
 * UPI payment via the user's own UPI app, QR scanning, text-to-speech, voice input, calls and links.
 * The app never sees or handles a UPI PIN.
 */
class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeech: Pair<String, String>? = null
    private var upiResult: MethodChannel.Result? = null
    private var voiceResult: MethodChannel.Result? = null
    private var qrResult: MethodChannel.Result? = null

    /** Secure by default: block screenshots, screen recording, screen sharing and the recent-apps preview
     *  before the first frame is drawn. Only a demo build for a projector turns it off (setSecure false). */
    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.easypay.safepay/native")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    speak(call.argument<String>("text") ?: "", call.argument<String>("locale") ?: "en-IN")
                    result.success(null)
                }
                "stopSpeaking" -> {
                    tts?.stop()
                    result.success(null)
                }
                "canListen" -> result.success(
                    Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).resolveActivity(packageManager) != null
                )
                "listen" -> listen(call.argument<String>("locale") ?: "en-IN", result)
                "scanQr" -> scanQr(call.argument<String>("prompt") ?: "", result)
                "payUpi" -> payUpi(call.argument<String>("uri") ?: "", result)
                "setSecure" -> {
                    if (call.argument<Boolean>("on") != false) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "isOnCall" -> result.success(isOnCall())
                "screenCaptured" -> result.success(false) // FLAG_SECURE already blanks any capture
                "remoteApps" -> result.success(remoteApps())
                "openUrl" -> {
                    openExternal(Uri.parse(call.argument<String>("url") ?: ""))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            val p = pendingSpeech
            if (ttsReady && p != null) {
                doSpeak(p.first, p.second)
                pendingSpeech = null
            }
        }
    }

    /** A phone call or a WhatsApp / internet call is active. AudioManager needs no permission, unlike the phone state. */
    private fun isOnCall(): Boolean {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        return am.mode == AudioManager.MODE_IN_CALL || am.mode == AudioManager.MODE_IN_COMMUNICATION
    }

    /** Remote-control apps used in screen-sharing scams. Each package is listed under <queries> in the manifest,
     *  so no QUERY_ALL_PACKAGES permission is needed. */
    private fun remoteApps(): List<String> = REMOTE_APPS.filter { (pkg, _) ->
        try {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }.map { it.second }.distinct()

    /** Links (tel:, https:, WhatsApp) leave the app. */
    private fun openExternal(uri: Uri) {
        val intent = if (uri.scheme == "tel") Intent(Intent.ACTION_DIAL, uri) else Intent(Intent.ACTION_VIEW, uri)
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
        }
    }

    private fun speak(text: String, localeTag: String) {
        if (!ttsReady) {
            pendingSpeech = text to localeTag
            return
        }
        doSpeak(text, localeTag)
    }

    private fun doSpeak(text: String, localeTag: String) {
        val engine = tts ?: return
        val res = engine.setLanguage(Locale.forLanguageTag(localeTag))
        if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
            channel.invokeMethod("onTtsMissing", null)
            engine.setLanguage(Locale("en", "IN"))
        }
        engine.setSpeechRate(0.85f)
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ep")
    }

    /** Speech input through the phone's own recogniser, so the app needs no microphone permission. */
    private fun listen(localeTag: String, result: MethodChannel.Result) {
        tts?.stop()
        voiceResult?.success("")
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        try {
            voiceResult = result
            startActivityForResult(i, REQ_VOICE)
        } catch (_: ActivityNotFoundException) {
            voiceResult = null
            result.success("")
        }
    }

    /**
     * QR scanning. First choice is Google's code scanner (no camera permission, runs in Play services). Sideloaded
     * APKs often don't have its module downloaded yet, and some phones have old or no Play services, so whenever it
     * is missing or fails we ask Play services to fetch it for next time and scan with the built-in ZXing scanner
     * instead (offline; asks for the camera permission the first time).
     */
    private fun scanQr(prompt: String, result: MethodChannel.Result) {
        val opts = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .enableAutoZoom()
            .build()
        val gms = try {
            GmsBarcodeScanning.getClient(this, opts)
        } catch (e: Exception) {
            android.util.Log.w("EasyPay", "Google code scanner not available", e)
            scanWithZxing(prompt, result)
            return
        }
        val modules = ModuleInstall.getClient(this)
        modules.areModulesAvailable(gms)
            .addOnSuccessListener { r ->
                if (r.areModulesAvailable()) {
                    scanWithGms(gms, prompt, result)
                } else {
                    android.util.Log.i("EasyPay", "Google code scanner module not downloaded yet; using built-in scanner")
                    modules.deferredInstall(gms)
                    scanWithZxing(prompt, result)
                }
            }
            .addOnFailureListener { e ->
                android.util.Log.w("EasyPay", "Could not ask Play services about the code scanner", e)
                scanWithZxing(prompt, result)
            }
    }

    private fun scanWithGms(gms: com.google.mlkit.vision.codescanner.GmsBarcodeScanner, prompt: String, result: MethodChannel.Result) {
        var answered = false
        try {
            gms.startScan()
                .addOnSuccessListener { b ->
                    if (!answered) { answered = true; result.success(b.rawValue ?: "") }
                }
                .addOnCanceledListener {
                    if (!answered) { answered = true; result.success("") }
                }
                .addOnFailureListener { e ->
                    android.util.Log.w("EasyPay", "Google code scanner failed; using built-in scanner", e)
                    if (!answered) { answered = true; scanWithZxing(prompt, result) }
                }
        } catch (e: Exception) {
            android.util.Log.w("EasyPay", "Google code scanner failed to start; using built-in scanner", e)
            if (!answered) { answered = true; scanWithZxing(prompt, result) }
        }
    }

    /** The built-in scanner (ZXing). Its screen asks for the camera permission itself. */
    private fun scanWithZxing(prompt: String, result: MethodChannel.Result) {
        qrResult?.success("")
        val opts = ScanOptions()
            .setDesiredBarcodeFormats(ScanOptions.QR_CODE)
            .setPrompt(prompt)
            .setBeepEnabled(false)
            .setOrientationLocked(true)
            // Look harder, and also read light-on-dark codes: UPI stickers are often small, glossy or have a logo
            .addExtra(com.google.zxing.client.android.Intents.Scan.SCAN_TYPE, com.google.zxing.client.android.Intents.Scan.MIXED_SCAN)
            .addExtra(com.google.zxing.DecodeHintType.TRY_HARDER.name, true)
        try {
            qrResult = result
            startActivityForResult(ScanContract().createIntent(this, opts), REQ_QR)
        } catch (e: Exception) {
            android.util.Log.w("EasyPay", "Built-in scanner failed to start", e)
            qrResult = null
            result.success("__unavailable__")
        }
    }

    /** Hands the payment to the user's UPI app. Answers null when no UPI app is installed. */
    private fun payUpi(uri: String, result: MethodChannel.Result) {
        val i = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        if (packageManager.queryIntentActivities(i, 0).isEmpty()) {
            result.success(null)
            return
        }
        upiResult?.success("")
        try {
            upiResult = result
            startActivityForResult(Intent.createChooser(i, "Pay with"), REQ_UPI)
        } catch (_: ActivityNotFoundException) {
            upiResult = null
            result.success("")
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQ_UPI -> {
                // UPI apps return "txnId=..&responseCode=..&Status=SUCCESS&txnRef=.." (key name varies by app)
                val resp = data?.getStringExtra("response")
                    ?: data?.getStringExtra("Status")?.let { "Status=$it" }
                    ?: ""
                upiResult?.success(resp)
                upiResult = null
            }
            REQ_QR -> {
                val r = ScanContract().parseResult(resultCode, data)
                val noCamera = r.originalIntent?.hasExtra(com.google.zxing.client.android.Intents.Scan.MISSING_CAMERA_PERMISSION) == true
                qrResult?.success(r.contents ?: if (noCamera) "__unavailable__" else "")
                qrResult = null
            }
            REQ_VOICE -> {
                val joined = if (resultCode == RESULT_OK) {
                    data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.joinToString("|") ?: ""
                } else ""
                voiceResult?.success(joined)
                voiceResult = null
            }
        }
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }

    private companion object {
        const val REQ_UPI = 101
        const val REQ_VOICE = 102
        const val REQ_QR = 103
        val REMOTE_APPS = listOf(
            "com.anydesk.anydeskandroid" to "AnyDesk",
            "com.teamviewer.quicksupport.market" to "TeamViewer QuickSupport",
            "com.teamviewer.teamviewer.market.mobile" to "TeamViewer",
            "com.teamviewer.host.market" to "TeamViewer Host",
            "com.carriez.flutter_hbb" to "RustDesk",
            "com.sand.airdroid" to "AirDroid",
            "com.sand.airmirror" to "AirMirror",
        )
    }
}
