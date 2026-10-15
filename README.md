# Easy Pay, Safe Pay

An Android app that walks an older adult through a UPI payment one step at a time, and runs a scam check before any money moves. Built for Hackurity 2026, Track C, Problem Statement 8.

**Install:** copy `EasyPaySafePay.apk` to an Android 8+ phone and tap it (allow "Install unknown apps" when asked).

## What it does

- **Pay by QR or UPI ID:** scan a shop's QR code, pick someone you paid before, or type a UPI ID. Big buttons, one question per screen, "Step X of 4", amount also shown in words.
- **Safety check before paying:** four yes/no questions plus automatic signals (new payee, amount above the family limit or usual amount, name mismatch). Green, amber or red, with up to three plain-language reasons. On red the "continue" button stays locked for 30 seconds.
- **Money request check:** catches the "enter your PIN to RECEIVE money" collect-request scam.
- **Check a message:** paste an SMS or WhatsApp message to look for KYC, OTP, "digital arrest", lottery, link, screen-sharing and job scams.
- **Family helper:** one tap to call them, or send a ready-made WhatsApp message, when a payment looks risky.
- **Report fraud:** one tap to call 1930, plus links to cybercrime.gov.in and Sanchar Saathi (Chakshu).
- **English, Hindi, Kannada,** with read-aloud on every screen and voice answers for the amount and the yes/no questions.
- **Practice mode (default):** fake money and two demo stories ("Pay Raju's shop ₹200", "A 'bank officer' called me"). **Real mode** (Settings) hands the payment to the phone's own UPI app (GPay, PhonePe, BHIM, Paytm). The PIN is typed only there, never in this app.

## Project layout

| Path | What it is |
| --- | --- |
| `android/app/src/main/assets/www/` | The UI: `app.js` (screens), `engine.js` (scam rules, QR/UPI parsing), `i18n.js` (text), `style.css` |
| `android/app/src/main/java/.../MainActivity.java` | WebView host and the native bridge: UPI intent, ML Kit QR scanner, text-to-speech, speech input, clipboard |
| `android/tests/engine.test.js` | Unit tests for the rules and parsers: `node --test android/tests/` |

## Build

Requires JDK 17 and the Android SDK (platform 34).

```bash
cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew assembleRelease
```

Output: `android/app/build/outputs/apk/release/app-release.apk`. It is signed with the debug key so it installs directly; use your own keystore before publishing to the Play Store.

To try the UI in a browser, serve `android/app/src/main/assets/www/` (for example `python3 -m http.server`). Without the Android bridge, "Scan QR" pretends to scan Raju's shop in practice mode.

## Known limits

- Some UPI apps refuse payments started from another app, especially to personal UPI IDs; shop QR codes are the most reliable. The app reports "could not confirm" rather than claiming success.
- The app cannot look up the bank name for a typed UPI ID; it tells the user to check the name their UPI app shows before entering the PIN.
- QR scanning needs Google Play services. Kannada read-aloud needs a Kannada voice installed on the phone.
- Hindi and Kannada text should be checked by a native speaker.
