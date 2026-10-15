# Easy Pay, Safe Pay

A Flutter app for Android and iPhone that walks an older adult through a UPI payment one step at a time, and runs a scam check before any money moves. Built for Hackurity 2026, Track C, Problem Statement 8.

**Install:** Android: build the APK (below), copy it to an Android 8+ phone and tap it (allow "Install unknown apps" when asked). iPhone (iOS 15+): build from Xcode (below).

## What it does

- **Pay by QR or UPI ID:** scan a shop's QR code, pick someone you paid before, or type a UPI ID. Big buttons, one question per screen, "Step X of 4", amount also shown in words.
- **Safety check before paying:** four yes/no questions plus automatic signals (new payee, amount above the family limit or usual amount, name mismatch). Green, amber or red, with up to three plain-language reasons. On red the "continue" button stays locked for 30 seconds.
- **Money request check:** catches the "enter your PIN to RECEIVE money" collect-request scam.
- **Check a message:** paste an SMS or WhatsApp message to look for KYC, OTP, "digital arrest", lottery, link, screen-sharing and job scams.
- **Check a link:** paste a link (or a whole message) to spot phishing websites without opening them: fake bank or app sites (sbi-kyc-update.in, hdfcbnak.com), short links, number-only addresses, hidden "@" tricks, look-alike letters, scam-prone endings and .apk downloads. Links inside "Check a message" are checked the same way.
- **Saved people:** anyone you pay (under the name you give them) appears under "People you have paid before" next time. Not after a red warning, so a risky payee is always checked again.
- **Wrong person stops the payment:** answering "No, I expected someone else" on the name check stops the payment, with a button to type the ID or scan again.
- **Family helper:** one tap to call them, or send a ready-made WhatsApp message, when a payment looks risky.
- **Report fraud:** one tap to call 1930, plus links to cybercrime.gov.in and Sanchar Saathi (Chakshu).
- **English, Hindi, Kannada,** with read-aloud on every screen and voice answers for the amount and the yes/no questions.
- **Security controls you can see:** phone-call and screen-sharing detection, a screen shield against screenshots and screen sharing, lookalike and fake-bank UPI ID detection, website / AutoPay / "scan to receive" QR blocking, AnyDesk-style app detection, payment velocity limits, a cooling-off period before loosening the family limit or number, payment session timeout, and a tamper-evident (SHA-256 hash-chained) safety history. No internet permission. See [`../SECURITY_DEMO.md`](../SECURITY_DEMO.md) for how to demonstrate each one.
- **Practice mode (default):** fake money and two demo stories ("Pay Raju's shop ₹200", "A 'bank officer' called me"). **Real mode** (Settings) hands the payment to the phone's own UPI app (GPay, PhonePe, BHIM, Paytm). The PIN is typed only there, never in this app.

## Project layout

| Path | What it is |
| --- | --- |
| `lib/main.dart` | App shell: header, language and voice chips, practice/real banner, back button |
| `lib/screens.dart` | Every screen (home, payee, amount, safety questions, result, family alert, confirm, PIN, request, message check, report, settings) |
| `lib/app_state.dart` | Settings (saved with `shared_preferences`), the payment in progress, navigation and all actions |
| `lib/engine.dart` | Scam rules, lookalike / impersonation / QR checks, SMS checker, QR/UPI parsing, number words. Pure Dart |
| `lib/audit.dart` | Safety history: SHA-256 hash chain that shows when an entry was edited or deleted. Pure Dart |
| `lib/motion.dart` | Animations (staggered entrances, press spring, pop-in verdicts); all respect the phone's "remove animations" setting |
| `lib/i18n.dart` | English, Hindi and Kannada text |
| `lib/ui.dart` | Colours (light and dark) and shared widgets |
| `lib/native.dart` | Dart side of the platform channel |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Android native side: UPI intent, ML Kit QR scanner, text-to-speech, speech input, links |
| `ios/Runner/AppDelegate.swift` | iOS native side: UPI app hand-off, camera QR scanner, text-to-speech, speech input, links |
| `test/` | `engine_test.dart` (rules and parsers), `audit_test.dart` (hash chain) and `app_test.dart` (practice stories and security controls, end to end) |

## Build and test

Requires Flutter (stable), JDK 17 and the Android SDK.

```bash
flutter test
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. It is signed with the debug key so it installs directly; use your own keystore before publishing to the Play Store.

### iPhone

Requires a Mac with Xcode and an Apple developer account (a free Apple ID can install on your own iPhone for 7 days).

```bash
open ios/Runner.xcworkspace        # once: Runner target → Signing & Capabilities → pick your Team
flutter run --release              # install on a connected iPhone
flutter build ipa                  # App Store / TestFlight build, in build/ios/ipa/
```

Off a phone (for example `flutter run -d macos`), the phone features are no-ops and "Scan QR" pretends to scan Raju's shop in practice mode.

## Known limits

**iPhone only:**
- iOS UPI apps do not tell the app whether a payment went through, so after paying the app always says "could not confirm, check your UPI app's history", and real-mode payees are not saved to "People you have paid before".
- The app opens Google Pay, PhonePe, Paytm or BHIM through their own links (`gpay://`, `phonepe://`, `paytmmp://`, `upi://`). Test each on a real iPhone; app makers sometimes change these.
- QR scanning and voice answers ask for camera, microphone and speech-recognition permission (Android normally needs none, because Google's scanner and recogniser run outside the app; if Google's scanner is missing, the built-in fallback scanner asks for the camera once).

**Both:**

- Some UPI apps refuse payments started from another app, especially to personal UPI IDs; shop QR codes are the most reliable. The app reports "could not confirm" rather than claiming success.
- The app cannot look up the bank name for a typed UPI ID; it tells the user to check the name their UPI app shows before entering the PIN.
- QR scanning uses Google's code scanner when Play services has it, and otherwise the built-in ZXing scanner. Kannada read-aloud needs a Kannada voice installed on the phone.
- Hindi and Kannada text should be checked by a native speaker.
