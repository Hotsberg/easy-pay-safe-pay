# Easy Pay, Safe Pay: security demo guide for the judges

This guide is for the team presenting at Hackurity 2026, Track C, PS-8. It covers the security principles built into the app, how to show each one live in under 10 minutes, and how to answer the follow-up questions.

> **The pitch in one line:** most UPI fraud against older adults does not break any cryptography. It tricks the person. So every control here either **measures what a scammer cannot hide** (a live call, a shared screen, a lookalike ID, a fake QR) or **slows down what a scammer needs to rush** (red lock, cooling-off, re-check before paying).

All of this is in the Flutter app (`easypay_flutter/`). The old WebView app in `android/` does not have these controls.

---

## 1. The principles at a glance

| # | Control | Principle | Scam it stops | Where in code | Demo |
|---|---|---|---|---|---|
| 1 | **No internet permission, no runtime permissions** | Least privilege · Privacy by design | Data theft, spyware-style abuse | `android/app/src/main/AndroidManifest.xml` | Act 1 |
| 2 | **Screen shield** (screenshots, recording and screen sharing show black) | Defence in depth · Confidentiality | AnyDesk or WhatsApp screen-share "help" scams | `MainActivity.kt` (`FLAG_SECURE`), iOS `isCaptured` | Act 2 |
| 3 | **Phone-call detection, measured, not asked** | Zero trust: verify, don't ask | "Bank officer" or "digital arrest" calls while paying | `MainActivity.kt` `isOnCall`, `AppDelegate.swift` `CXCallObserver` | Act 3 |
| 4 | **Re-check at the moment of paying** | Complete mediation | A call or screen share that starts *after* the check | `app_state.dart` `payNow()` | Act 3 |
| 5 | **Lookalike and impersonation detection** | Input validation · Anti-spoofing | `raju.klrana@okaxis` posing as `raju.kirana@okaxis`; `sbi.kyc.help@ybl` | `engine.dart` `lookalikeOf`, `looksOfficial` | Act 4 |
| 6 | **QR attack blocking** (website QR, AutoPay QR, "scan to receive", malformed QR) | Secure parsing · Fail-safe defaults | QR sticker swaps, quishing, mandate traps | `engine.dart` `qrKind`, `qrPromisesMoney`, `parseUpiQr` | Act 5 |
| 7 | **Remote-control app detection** (AnyDesk, TeamViewer, RustDesk, AirDroid) | Defence in depth | Remote-access takeover | `MainActivity.kt` `remoteApps`, manifest `<queries>` | Act 6 (optional) |
| 8 | **Velocity and daily-total limits** | Rate limiting · Limit the blast radius | "Payment failed, pay again" drains; splitting under the limit | `engine.dart` rules `velocity`, `dailyLimit` | Act 7 |
| 9 | **Cooling-off on weakening settings** (higher limit, new family number) + family told | Separation of privilege · Time-delayed change | Scammer: "go to settings and raise your limit / change the number" | `app_state.dart` `saveFamily`, `Pending` | Act 8 |
| 10 | **Payment session timeout** | Session management | Victim leaves mid-payment to follow a caller's instructions | `app_state.dart` `onLifecycle` | Act 9 |
| 11 | **Tamper-evident safety history** (SHA-256 hash chain) | Accountability · Compromise recording | Hiding evidence; disputes; family oversight | `lib/audit.dart` | Act 10 |
| 12 | **30-second red lock, plain-language reasons, PIN never in this app** | Psychological acceptability · Fail-safe defaults | Panic decisions; PIN phishing | `screens.dart` `_result`, `_pin` | Act 3 / existing story 2 |

**Saltzer & Schroeder** (the classic 1975 design principles judges may name). The app covers:

- **Least privilege**: control 1.
- **Fail-safe defaults**: practice mode by default; screen shield on before the first frame; unknown or unreadable data is never green.
- **Complete mediation**: control 4.
- **Separation of privilege**: control 9, where the family must be told before a weakening change takes effect.
- **Open design**: the rules are public and explainable, and nothing depends on a secret.
- **Economy of mechanism**: about 20 point-scored rules, no server, no ML black box.
- **Psychological acceptability**: control 12, in three languages, read aloud.
- **Compromise recording**: control 11.

---

## 2. Before the demo (do this the day before)

### Build and install

```bash
cd easypay_flutter
flutter test                                   # 44 tests, all must pass
JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk  (screen shield ON)
```

**Projector problem:** the screen shield also blacks out the phone when you mirror it (scrcpy, Vysor, Chromecast, Zoom share). That is the feature working. Make **two builds** on **two phones**, or reinstall between acts:

```bash
# Build A (for mirroring to the projector): shield off, everything else identical
flutter build apk --release --dart-define=ALLOW_SCREEN_MIRROR=true
# Build B (for Act 2, hand the phone to a judge): normal build, shield on
flutter build apk --release
```

Settings → Privacy and security in the app says which build is running ("Screen protection is on" or "OFF in this demo build").

### Phone setup checklist

- [ ] Android 8 or newer, Google Play services present (needed for the QR scanner).
- [ ] App in **Practice mode** (the default), language **English**.
- [ ] Family helper: Meena, `9876543210`, limit `₹5,000` (the defaults).
- [ ] **Clear practice history** (Safety history → bottom → "Clear practice history") so the velocity count starts at zero.
- [ ] A **second phone** ready to call the demo phone (Acts 3 and 9).
- [ ] [`demo/qr_codes.html`](demo/qr_codes.html) printed, or open on a laptop. It needs internet once to load the QR library.
- [ ] Optional, for Act 6: install **AnyDesk** from the Play Store on the demo phone. Uninstall it afterwards.
- [ ] Turn the phone's "Remove animations" setting **off**, so the motion is visible. With it on, the app shows every screen instantly, which is also worth mentioning as an accessibility feature.
- [ ] Rehearse Act 3 once: some phones need the call **answered** (not just ringing) before the call state changes.

---

## 3. The demo script (about 10 minutes)

Each act has **Say** (what to tell the judges), **Do** (taps), **They see** (the visible result) and **Principle**. If time is short, do Acts **3, 4, 5, 8 and 10**. Those are the most memorable.

### Act 0: opening (30 s)

**Say:** "UPI fraud is one of the most reported cybercrimes in India, and older adults are a favourite target. Almost none of these attacks break encryption. They break *people*: a fake bank officer on the phone, a QR sticker swapped at a shop, a screen-sharing app. So we built controls that measure what a scammer can't hide, and slow down what a scammer needs to rush."

### Act 1: least privilege (45 s)

**Do:** Phone Settings → Apps → Easy Pay Safe Pay → **Permissions**.
**They see:** "No permissions requested." The `aapt2` output below also shows there is **no INTERNET permission**.
**Say:** "A payment-safety app that can't connect to the internet can't leak your data, can't be remotely updated by an attacker, and can't phone home. QR scanning and voice input run inside Google's own apps, and the actual payment runs inside your UPI app. We never see the PIN."
**Proof for technical judges:**

```bash
aapt2 dump permissions app-release.apk
# package: com.easypay.safepay
# uses-permission: ...DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION  (AndroidX's internal signature-level guard)
# uses-permission: android.permission.ACCESS_NETWORK_STATE      (only "is there a network?"; Google's QR scanner
#                                                                fails on Android 14+ without it; cannot send data)
# uses-permission: android.permission.CAMERA                    (only for the built-in fallback QR scanner; asked
#                                                                only if Google's scanner is missing on the phone)
# no INTERNET
```

Also say: backups are switched off (`allowBackup=false`, `data_extraction_rules.xml`), so the history and saved payees cannot be pulled off the phone by `adb backup` or restored onto another phone.
**Principle:** least privilege, data minimisation (Settings → *Privacy and security* lists exactly what is and is never stored).

### Act 2: screen shield (45 s, use build B, hand the phone over)

**Do:** Ask a judge to take a screenshot. Then open Recent Apps. Optionally start Google Meet or WhatsApp screen sharing.
**They see:** "Can't take screenshot due to security policy" (wording varies by phone). The app's card in Recent Apps is blank, and a screen share shows black.
**Say:** "The number one tool in 'helpful bank officer' scams is AnyDesk or WhatsApp screen sharing. The scammer watches the OTP and the PIN screen. Here they see a black rectangle. It's on before the first frame is drawn, so the default is safe. On iPhone, where apps can't block capture, we detect it instead: a red banner appears on every screen and every payment check turns red."
**Principle:** defence in depth, fail-safe defaults.

### Act 3: the phone call it can hear (2 min, the headline act)

**Part A, measured:**

1. **Do:** Call the demo phone from the second phone and **answer it**. Put it on speaker.
2. **Do:** Tap **"Pay Raju's shop ₹200"** → Next → answer **No** to all four questions. This is what a coached victim does.
3. **They see:** **"Please check first"**, with the reason: *"You are on a phone call right now. Scammers stay on the line while you pay. Hang up first, then decide."*
4. **Say:** "The victim said No to 'did someone call you?' because the scammer told them to. The app didn't believe the answer. It asked the phone. No permission is needed: we read the audio mode, not the call log."

**Part B, complete mediation:**

1. **Do:** Hang up. Start "Pay Raju's shop ₹200" again → No ×4 → green **Looks safe** → **Continue to pay**.
2. **Do:** On the confirm screen, call the phone again and answer. Now tap **Pay now**.
3. **They see:** The app does not pay. It jumps back to the safety result: *"Something changed since the safety check. Please read this again."* The on-call reason is now listed.
4. **Say:** "Checking once is not enough. A check at minute one says nothing about minute three. We re-check at the instant money would move. That's *complete mediation*."

**Bonus, the existing story 2:** "A 'bank officer' called me" → "I will RECEIVE money" → Yes, Yes, Yes, No. The result is **red**: *"You are SENDING money, not receiving it"*. The "I am sure" button is **locked for 30 seconds** with a countdown ring. **Say:** "Scammers manufacture urgency. We manufacture calm."

### Act 4: lookalike and impersonation (1 min)

**Do:** Send money → Someone new → tap the example **`raju.klrana@okaxis`** → Next.
**They see:** On the name screen, before any money question, a red **"Careful"** box: *"This looks like Raju Kirana Store, but the UPI ID is different."* Continue with Yes → ₹500 → No ×4 and the result is **red**.
**Say:** "The name is perfect, copied from the real shop. The ID differs by one letter: *i* became *l*. We compare against everyone you've paid before, after normalising the characters scammers swap (0/o, 1/l/i, rn/m, 5/s), plus an edit distance of up to 2. We also flag IDs that pose as banks, KYC desks or prize offices, like `sbi.kyc.help@ybl`, but not normal bank handles like `@oksbi`."
**Printed version:** scan the **"Swapped sticker: lookalike ID"** QR. It reproduces the real-world sticker-swap attack.
**Principle:** never trust displayed names; validate identity.

### Act 5: QR attacks (1.5 min)

1. **Do:** Practice story **"Scan to get ₹4,999 cashback"** (or scan the printed QR).
   **They see:** an immediate warning: *"This QR code says you will GET money. A QR code can only take money out."* After the check, **red** even with every answer No.
2. **Do:** Practice story **"A new sticker on the shop's QR"** (or scan the printed **website** QR).
   **They see:** A full red screen: *"This QR code opens a website, not a payment"*, with the domain shown. The link is **never opened**, and with no internet permission it physically can't be.
3. **Do:** Scan the printed **AutoPay mandate** QR.
   **They see:** *"This QR code sets up AutoPay"*, blocked.
4. **Do:** Scan the printed **malformed amount** QR (`am=1e9&cu=USD`).
   **They see:** *"This is not a UPI payment QR code."* Strict parsing: amounts must be a plain rupee figure ≤ 6 digits, and the currency must be INR.

**Say:** "QR codes are untrusted input. We parse them like a security engineer would: allow-list the format, reject anything else, never follow links."
**Principle:** secure input handling, fail-safe defaults.

### Act 6: remote-control app detection (30 s, optional, needs AnyDesk installed)

**Do:** Open the app (or come back to it after installing AnyDesk).
**They see:** A red card at the top of Home: **"AnyDesk is installed"**, *"This app lets someone else see and control your phone…"* Every payment check also counts it.
**Say:** "We look for seven specific package names: AnyDesk, TeamViewer and others. Android's package-visibility rules make us declare each one in the manifest. We do *not* request the 'see all apps' permission. That's least privilege again."

### Act 7: velocity and split payments (45 s)

**Do:** Run **"Pay Raju's shop ₹200"** to completion twice (No ×4 → Continue → Pay now → any 4 digits). On the **third** time, stop at the result.
**They see:** **"Please check first"**: *"This is payment number 3 in the last hour. Scammers ask you to pay again and again."*
**Say:** "Drain scams say 'the payment failed, try again'. We count. Separately, small payments that add up past the family's daily limit are flagged too, so you can't dodge a ₹5,000 limit with three ₹2,000 payments."
**Principle:** rate limiting, limiting the blast radius.

### Act 8: cooling-off and family notification (1.5 min)

**Do:** Home → Family helper → change the limit from `5000` to `50000` → Save.
**They see:**

- *"Saved. For safety, this starts at 7:42 PM, 14/10."* The limit is **still ₹5,000**.
- An amber **"Waiting for safety"** card: *"If someone on the phone told you to change this, cancel it now. It is a scam."*
- A button **"Tell Meena on WhatsApp"**. The message goes to the **current** number.

**Say:** "Every 'digital arrest' script includes 'go to settings and remove the limit'. Weakening a protection now waits **24 hours** in real mode. We use 2 minutes in practice mode so you can watch it happen. Tightening is instant. The family is messaged on the **old** number, so a scammer who types in their own number can't hide the change. That's separation of privilege: one person under pressure can't remove the safety net alone."
**Do:** Change the family number too → see it wait. Tap **"Cancel this change"**. Then wait out the 2 minutes on another change to show it applying by itself. Both events appear in the Safety history.

### Act 9: session timeout (45 s)

**Do:** Start "Pay Raju's shop ₹200". Press the phone's Home button, wait **over 60 seconds** (take a judge question meanwhile), then reopen the app.
**They see:** Back on Home: *"You left the app in the middle of a payment, so we cancelled it to keep you safe."*
**Say:** "Victims leave the app to read the scammer's WhatsApp instructions, then come back to finish. A stale payment session is cancelled, and the check runs again from scratch. Deliberate hand-offs, like the QR scanner, the UPI app or calling family, don't count."

### Act 10: tamper-evident safety history (1 min)

**Do:** Home → **Safety history**.
**They see:** A green **"History is complete"** banner, then every check, warning overridden, payment, blocked QR and settings change, with times. Phone numbers are masked (`••••3210`).
**Say:** "Each entry stores the SHA-256 of the previous entry, like a tiny blockchain without the hype. Change or delete one entry and every later link breaks."
**Do:** Tap **"Pretend someone secretly edited an entry"** (practice only).
**They see:** The banner turns **red**, *"Warning: this history was changed"*, and the edited entry is highlighted.
**Say:** "This matters for the family, who can see that Amma continued after a red warning, and for the police: the 1930 / cybercrime.gov.in complaint needs evidence. The Report screen links straight here. We deliberately did **not** add a one-tap 'delete history', because a scammer would ask for exactly that."

### Act 11: proof (30 s)

**Do:** On the laptop, run `cd easypay_flutter && flutter test`.
**They see:** `All tests passed!`: 44 tests, including end-to-end tests that fake a phone call, fake an AnyDesk install, swap a QR, tamper with the history and fast-forward the cooling-off clock.

---

## 4. Likely judge questions

| Question | Answer |
|---|---|
| **Can a scammer just tell the victim to switch the app off?** | They can, and then the victim simply has no extra protection. Nothing in this app can move money by itself: the UPI app still asks for the PIN. What a scammer *cannot* do is make the app say "safe" while a call is live, a screen is shared or the ID is a lookalike. |
| **Why rules instead of AI/ML?** | Explainability: every red has up to three plain-language reasons a 70-year-old can understand, and a judge can audit. It works offline with no data leaving the phone. And there's no model for an attacker to probe. (Saltzer & Schroeder: economy of mechanism, open design.) |
| **How do you read the phone call without a permission?** | Android: `AudioManager.getMode()` is `MODE_IN_CALL` (phone) or `MODE_IN_COMMUNICATION` (WhatsApp/VoIP); no `READ_PHONE_STATE` needed. iPhone: `CXCallObserver` from CallKit, also permission-free. We never see *who* is calling. |
| **Your hash chain has no secret key. Can't an attacker rewrite the whole chain?** | Yes, an attacker with root access who rewrites *every* hash could. The chain is **tamper-evident against casual edits and deletions**, not tamper-proof. The next step is signing each entry with a key held in the Android Keystore / iOS Secure Enclave, which can't be extracted even on a rooted phone. Say this upfront; judges respect it. |
| **Why 24 hours of cooling-off? Isn't that annoying?** | It only applies to *loosening* protection, which is rare and never urgent for a genuine user. Tightening is instant. Banks use the same idea for new beneficiaries. |
| **What about false positives?** | Most signals are amber ("Please check first"), not red, and still allow paying. Red needs a critical sign (collect request believed to be "receive", a screen share, a remote app the user was told to install, a "scan to receive" QR) or several signs together. The lock is 30 seconds, not a block. |
| **Does this comply with privacy law (DPDP Act 2023)?** | Purpose limitation and data minimisation by design: no network, no PII sent anywhere, nothing collected beyond what the user typed, phone numbers masked in the history, no backups. Users can remove saved payees, and uninstalling erases everything. |
| **Why not read SMS to auto-check messages?** | `READ_SMS` is one of the most abused permissions and Google Play restricts it. We use paste-to-check instead: same protection, zero standing access. |
| **What's different on iPhone?** | iOS can't block screenshots, so we *detect* recording, mirroring and sharing (`UIScreen.isCaptured`) and warn live. iOS apps can't remote-control other apps, so the remote-app check isn't needed there. Call detection works the same. |

---

## 5. Honest limits (say them before the judges find them)

- **Hash chain without a hardware key:** tamper-evident, not tamper-proof (see above).
- **Call detection** reads the audio mode. A few phones report the mode only once a call is answered, not while it's ringing.
- **Remote-app list** covers 7 well-known apps. A renamed or unknown remote-control app won't be named, though the screen shield still blacks it out on Android.
- **Lookalike check** compares only against people you've paid before. A first-ever payment to a fake "Raju" with no real Raju saved can't be compared, but the new-payee and name-check steps still apply.
- **Release APK** is signed with the debug key (fine for the demo; use a real keystore for the Play Store).
- The **Hindi and Kannada** text for the new screens should be checked by a native speaker.
- **Debug builds** declare INTERNET in `src/debug/AndroidManifest.xml` (Flutter needs it for hot reload). The release build was verified to have none. Always demo with a release build.

---

## 6. On-stage troubleshooting

| Problem | Fix |
|---|---|
| Projector shows black | You're on build B (shield on). Switch to build A (`ALLOW_SCREEN_MIRROR=true`), or present this as Act 2. |
| Call not detected | Answer the call (don't leave it ringing) and wait a second. Try a WhatsApp call: `MODE_IN_COMMUNICATION` is very reliable. |
| Velocity reason doesn't appear | Practice history wasn't cleared, or the earlier payments weren't completed (the PIN step counts as paid). Count must reach 3 within an hour. |
| Cooling-off didn't apply | It checks every 5 seconds while open and again on resume. Practice mode waits 2 minutes, real mode 24 hours. |
| "QR scanner not available" | Google Play services missing or outdated. Use the practice stories instead of printed QRs. |
| Everything appears instantly, no animation | The phone's "Remove animations" accessibility setting is on. That's intended behaviour. |

---

## 7. Files changed for these controls

| File | What it adds |
|---|---|
| `easypay_flutter/lib/engine.dart` | New rules (`onCall`, `screenShared`, `remoteInstalled`, `lookalike`, `impersonation`, `qrReceive`, `velocity`, `dailyLimit`), lookalike and impersonation checks, QR classification, strict QR parsing |
| `easypay_flutter/lib/audit.dart` | SHA-256 hash-chained safety history (new) |
| `easypay_flutter/lib/app_state.dart` | Live signals, re-check before paying, cooling-off, session timeout, history logging, practice stories 3 and 4 |
| `easypay_flutter/lib/screens.dart` | Warnings, Safety history, Blocked-QR screen, cooling-off card, privacy section |
| `easypay_flutter/lib/motion.dart` | Animation layer: staggered entrances, spring press, pop-in verdicts, shake on red, countdown ring. All of it respects "Remove animations" |
| `easypay_flutter/lib/native.dart`, `MainActivity.kt`, `AppDelegate.swift` | `setSecure`, `isOnCall`, `screenCaptured`, `remoteApps`, live capture events |
| `easypay_flutter/android/app/src/main/AndroidManifest.xml` | INTERNET removed, backups off, remote-app `<queries>` |
| `easypay_flutter/test/` | `audit_test.dart` (new), plus security tests in `engine_test.dart` and `app_test.dart` (44 total) |
| `demo/qr_codes.html` | Printable genuine and attack QR codes for the live demo |
