package com.easypay.safepay;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.speech.tts.TextToSpeech;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.codescanner.GmsBarcodeScanner;
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions;
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Locale;

/**
 * Hosts the web UI (assets/www) and gives it the phone features it needs:
 * UPI payment via the user's own UPI app, QR scanning, text-to-speech, voice input, calls and links.
 * The app never sees or handles a UPI PIN.
 */
public class MainActivity extends Activity {
    private static final int REQ_UPI = 101;
    private static final int REQ_VOICE = 102;

    private WebView web;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private String pendingSpeech = null;
    private String pendingLocale = null;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setTextZoom(100);
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return openExternal(request.getUrl());
            }
        });
        web.addJavascriptInterface(new Bridge(), "AndroidBridge");
        web.loadUrl("file:///android_asset/www/index.html");

        tts = new TextToSpeech(this, status -> {
            ttsReady = status == TextToSpeech.SUCCESS;
            if (ttsReady && pendingSpeech != null) {
                doSpeak(pendingSpeech, pendingLocale);
                pendingSpeech = null;
            }
        });
    }

    /** Links (tel:, https:, WhatsApp) leave the app; only our own asset pages stay in the WebView. */
    private boolean openExternal(Uri uri) {
        String scheme = uri.getScheme() == null ? "" : uri.getScheme();
        if (scheme.equals("file")) return false;
        try {
            Intent i = scheme.equals("tel") ? new Intent(Intent.ACTION_DIAL, uri) : new Intent(Intent.ACTION_VIEW, uri);
            startActivity(i);
        } catch (ActivityNotFoundException ignored) {
        }
        return true;
    }

    private void js(String code) {
        runOnUiThread(() -> web.evaluateJavascript(code, null));
    }

    private static String quote(String s) {
        return JSONObject.quote(s == null ? "" : s);
    }

    private void doSpeak(String text, String localeTag) {
        Locale loc = Locale.forLanguageTag(localeTag == null ? "en-IN" : localeTag);
        int res = tts.setLanguage(loc);
        if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
            js("EP.onTtsMissing()");
            tts.setLanguage(new Locale("en", "IN"));
        }
        tts.setSpeechRate(0.85f);
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ep");
    }

    private class Bridge {
        @JavascriptInterface
        public void speak(String text, String localeTag) {
            if (!ttsReady) {
                pendingSpeech = text;
                pendingLocale = localeTag;
                return;
            }
            doSpeak(text, localeTag);
        }

        @JavascriptInterface
        public void stopSpeaking() {
            if (tts != null) tts.stop();
        }

        @JavascriptInterface
        public boolean canListen() {
            Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            return i.resolveActivity(getPackageManager()) != null;
        }

        @JavascriptInterface
        public void listen(String localeTag) {
            runOnUiThread(() -> {
                if (tts != null) tts.stop();
                Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag);
                i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag);
                i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
                try {
                    startActivityForResult(i, REQ_VOICE);
                } catch (ActivityNotFoundException e) {
                    js("EP.onVoice('')");
                }
            });
        }

        @JavascriptInterface
        public void scanQr() {
            runOnUiThread(() -> {
                GmsBarcodeScannerOptions opts = new GmsBarcodeScannerOptions.Builder()
                        .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                        .build();
                GmsBarcodeScanner scanner = GmsBarcodeScanning.getClient(MainActivity.this, opts);
                scanner.startScan()
                        .addOnSuccessListener(b -> js("EP.onQr(" + quote(b.getRawValue()) + ")"))
                        .addOnCanceledListener(() -> js("EP.onQr('')"))
                        .addOnFailureListener(e -> js("EP.onQr('__unavailable__')"));
            });
        }

        /** Hands the payment to the user's UPI app. Returns false when no UPI app is installed. */
        @JavascriptInterface
        public boolean payUpi(String uri) {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));
            PackageManager pm = getPackageManager();
            if (pm.queryIntentActivities(i, 0).isEmpty()) return false;
            Intent chooser = Intent.createChooser(i, "Pay with");
            runOnUiThread(() -> {
                try {
                    startActivityForResult(chooser, REQ_UPI);
                } catch (ActivityNotFoundException e) {
                    js("EP.onUpi('')");
                }
            });
            return true;
        }

        @JavascriptInterface
        public void copy(String text) {
            ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            cm.setPrimaryClip(ClipData.newPlainText("Easy Pay", text));
        }

        @JavascriptInterface
        public String paste() {
            ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (!cm.hasPrimaryClip() || cm.getPrimaryClip() == null || cm.getPrimaryClip().getItemCount() == 0) return "";
            CharSequence cs = cm.getPrimaryClip().getItemAt(0).coerceToText(MainActivity.this);
            return cs == null ? "" : cs.toString();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_UPI) {
            // UPI apps return "txnId=..&responseCode=..&Status=SUCCESS&txnRef=.." (key name varies by app)
            String resp = "";
            if (data != null) {
                resp = data.getStringExtra("response");
                if (resp == null) resp = data.getStringExtra("Status") != null ? "Status=" + data.getStringExtra("Status") : "";
            }
            js("EP.onUpi(" + quote(resp) + ")");
        } else if (requestCode == REQ_VOICE) {
            String joined = "";
            if (resultCode == RESULT_OK && data != null) {
                ArrayList<String> res = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
                if (res != null) joined = String.join("|", res);
            }
            js("EP.onVoice(" + quote(joined) + ")");
        }
    }

    @SuppressWarnings("deprecation")
    @Override
    public void onBackPressed() {
        web.evaluateJavascript("(window.EP && EP.onBack()) ? 'y' : 'n'", v -> {
            if (v == null || !v.contains("y")) MainActivity.super.onBackPressed();
        });
    }

    @Override
    protected void onDestroy() {
        if (tts != null) tts.shutdown();
        web.destroy();
        super.onDestroy();
    }
}
