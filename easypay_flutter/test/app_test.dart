// Drives the two practice stories through the real screens.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safepay/app_state.dart';
import 'package:safepay/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the fake phone reports: e.g. {'isOnCall': true, 'remoteApps': ['AnyDesk']}. Anything else answers null.
final phone = <String, Object?>{};

Future<AppState> _start(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  phone.clear();
  // No real phone features in tests (no TTS, no mic, no UPI app); security signals come from [phone]
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.easypay.safepay/native'), (call) async => phone[call.method]);
  // Show every animation's end state at once, like a phone with "remove animations" on
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final state = AppState();
  await state.load();
  await tester.pumpWidget(EasyPayApp(state: state));
  return state;
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('story 1: a normal payment to Raju is green and completes', (tester) async {
    await _start(tester);
    expect(find.text('Namaste! What would you like to do?'), findsOneWidget);
    await _tap(tester, "Pay Raju's shop ₹200");
    expect(find.text('two hundred rupees'), findsOneWidget);
    await _tap(tester, 'Next →');
    for (var i = 0; i < 4; i++) {
      await _tap(tester, 'No');
    }
    expect(find.text('Looks safe'), findsOneWidget);
    await _tap(tester, 'Continue to pay →');
    expect(find.text('₹200'), findsOneWidget);
    await _tap(tester, 'Pay now →');
    for (final d in ['1', '2', '3', '4']) {
      await _tap(tester, d);
    }
    expect(find.text('Payment done'), findsOneWidget);
    expect(find.text('₹200 sent to Raju Kirana Store.'), findsOneWidget);
  });

  testWidgets('story 2: the "bank officer" collect request is red and locked for 30 seconds', (tester) async {
    final s = await _start(tester);
    await _tap(tester, "A 'bank officer' called me");
    await _tap(tester, 'I will RECEIVE money');
    for (final a in ['Yes', 'Yes', 'Yes', 'No']) {
      await _tap(tester, a);
    }
    expect(find.text('Stop. This looks like a scam.'), findsOneWidget);
    expect(find.textContaining('You are SENDING money'), findsOneWidget);
    expect(find.text('Wait 30 seconds and think'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('I am sure, continue'), findsOneWidget);
    await _tap(tester, 'Cancel payment');
    expect(find.text('Payment stopped. Your money is safe.'), findsOneWidget);
    expect(s.stack, ['home', 'stopped']);
  });

  testWidgets('back from the result returns to the last question', (tester) async {
    final s = await _start(tester);
    await _tap(tester, "Pay Raju's shop ₹200");
    await _tap(tester, 'Next →');
    for (var i = 0; i < 4; i++) {
      await _tap(tester, 'No');
    }
    s.onBack();
    await tester.pumpAndSettle();
    expect(find.text('Did anyone ask you to install an app or share your phone screen?'), findsOneWidget);
    s.onBack();
    await tester.pumpAndSettle();
    expect(find.text('Is this payment for a prize, refund, KYC update, loan or job?'), findsOneWidget);
  });

  testWidgets('language switch and message checker', (tester) async {
    await _start(tester);
    await _tap(tester, 'हिंदी');
    expect(find.text('नमस्ते! आप क्या करना चाहते हैं?'), findsOneWidget);
    await _tap(tester, 'English');
    await _tap(tester, 'Check a message');
    await tester.enterText(find.byType(TextField), 'This is CBI. You are under digital arrest. Do not disconnect the call.');
    await _tap(tester, 'Check this message');
    expect(find.text('This looks like a scam message'), findsOneWidget);
  });

  // ---- security controls, end to end ----

  Future<void> answerNo(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await _tap(tester, 'No');
    }
  }

  testWidgets('a phone call during the payment is noticed without asking', (tester) async {
    await _start(tester);
    phone['isOnCall'] = true;
    await _tap(tester, "Pay Raju's shop ₹200");
    await _tap(tester, 'Next →');
    await answerNo(tester);
    expect(find.text('Please check first'), findsOneWidget);
    expect(find.textContaining('You are on a phone call right now'), findsOneWidget);
  });

  testWidgets('a call that starts after the check is caught again at "Pay now"', (tester) async {
    final s = await _start(tester);
    await _tap(tester, "Pay Raju's shop ₹200");
    await _tap(tester, 'Next →');
    await answerNo(tester);
    expect(find.text('Looks safe'), findsOneWidget);
    await _tap(tester, 'Continue to pay →');
    phone['isOnCall'] = true; // the "bank officer" calls back now
    await _tap(tester, 'Pay now →');
    expect(s.current, 'result');
    expect(find.text('Something changed since the safety check. Please read this again.'), findsOneWidget);
    expect(find.textContaining('You are on a phone call right now'), findsOneWidget);
    expect(s.log.entries.last.data['recheck'], isTrue);
  });

  testWidgets('AnyDesk on the phone shows a warning on the home screen', (tester) async {
    final s = await _start(tester);
    phone['remoteApps'] = ['AnyDesk']; // installed while the app was in the background
    await s.onLifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('AnyDesk is installed'), findsOneWidget);
  });

  testWidgets('lookalike of a saved shop is red even though the name matches', (tester) async {
    await _start(tester);
    await _tap(tester, 'Send money');
    await _tap(tester, 'Someone new');
    await _tap(tester, 'raju.klrana@okaxis');
    await _tap(tester, 'Next →');
    expect(find.text('This looks like Raju Kirana Store, but the UPI ID is different.'), findsOneWidget);
    await _tap(tester, 'Yes, that is right');
    await tester.enterText(find.byType(TextField), '500');
    await _tap(tester, 'Next →');
    await answerNo(tester);
    expect(find.text('Stop. This looks like a scam.'), findsOneWidget);
    expect(find.textContaining("looks like Raju Kirana Store's"), findsOneWidget);
    await _tap(tester, 'Cancel payment');
  });

  testWidgets('story 3: a "scan to receive cashback" QR is red', (tester) async {
    await _start(tester);
    await _tap(tester, 'Scan to get ₹4,999 cashback');
    expect(find.text('This QR code says you will GET money. A QR code can only take money out.'), findsOneWidget);
    await _tap(tester, 'Yes, that is right');
    await _tap(tester, 'Next →');
    await answerNo(tester);
    expect(find.text('Stop. This looks like a scam.'), findsOneWidget);
    expect(find.textContaining('Scanning a QR code can only SEND money'), findsOneWidget);
    await _tap(tester, 'Cancel payment');
  });

  testWidgets('story 4: a website QR is blocked and never opened', (tester) async {
    final s = await _start(tester);
    await _tap(tester, "A new sticker on the shop's QR");
    expect(find.text('This QR code opens a website, not a payment'), findsOneWidget);
    expect(find.text('sbi-kyc-update.in'), findsOneWidget);
    expect(s.log.entries.last.kind, 'qrBlocked');
  });

  testWidgets('the third payment within an hour needs a check', (tester) async {
    await _start(tester);
    for (var round = 0; round < 3; round++) {
      await _tap(tester, "Pay Raju's shop ₹200");
      await _tap(tester, 'Next →');
      await answerNo(tester);
      if (round < 2) {
        expect(find.text('Looks safe'), findsOneWidget);
        await _tap(tester, 'Continue to pay →');
        await _tap(tester, 'Pay now →');
        for (final d in ['1', '2', '3', '4']) {
          await _tap(tester, d);
        }
        await _tap(tester, 'Back to home');
      }
    }
    expect(find.text('Please check first'), findsOneWidget);
    expect(find.textContaining('This is payment number 3 in the last hour'), findsOneWidget);
  });

  testWidgets('raising the family limit waits out the cooling-off period; lowering it is instant', (tester) async {
    final s = await _start(tester);
    var clock = DateTime(2026, 10, 14, 10);
    s.now = () => clock;
    await _tap(tester, 'Family helper: Meena');
    await tester.enterText(find.byType(TextField).at(2), '50000');
    await _tap(tester, 'Save');
    expect(s.contact.limit, 5000);
    expect(find.text('Waiting for safety'), findsOneWidget);
    expect(find.text('Tell Meena on WhatsApp'), findsOneWidget);
    clock = clock.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 6));
    expect(s.contact.limit, 50000);
    expect(s.pending, isNull);
    await tester.enterText(find.byType(TextField).at(2), '1000');
    await _tap(tester, 'Save');
    expect(s.contact.limit, 1000);
  });

  testWidgets('changing the family number waits too, and can be cancelled', (tester) async {
    final s = await _start(tester);
    await _tap(tester, 'Family helper: Meena');
    await tester.enterText(find.byType(TextField).at(1), '9000011111');
    await _tap(tester, 'Save');
    expect(s.contact.phone, '9876543210');
    expect(find.textContaining('New family number ••••1111 starts at'), findsOneWidget);
    await _tap(tester, 'Cancel this change');
    expect(s.pending, isNull);
    expect(s.contact.phone, '9876543210');
  });

  testWidgets('a payment left in the background for over a minute is cancelled', (tester) async {
    final s = await _start(tester);
    var clock = DateTime(2026, 10, 14, 10);
    s.now = () => clock;
    await _tap(tester, "Pay Raju's shop ₹200");
    s.onLifecycle(AppLifecycleState.paused);
    clock = clock.add(const Duration(minutes: 2));
    await s.onLifecycle(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(s.current, 'home');
    expect(find.textContaining('You left the app in the middle of a payment'), findsOneWidget);
  });

  testWidgets('history verifies, and shows when an entry was secretly edited', (tester) async {
    final s = await _start(tester);
    await _tap(tester, "A 'bank officer' called me");
    await _tap(tester, 'I will RECEIVE money');
    for (final a in ['Yes', 'Yes', 'Yes', 'No']) {
      await _tap(tester, a);
    }
    await _tap(tester, 'Cancel payment');
    await _tap(tester, 'Back to home');
    await _tap(tester, 'Safety history');
    expect(find.text('History is complete'), findsOneWidget);
    expect(find.text('Payment stopped'), findsOneWidget);
    await _tap(tester, 'Pretend someone secretly edited an entry');
    expect(find.text('Warning: this history was changed'), findsOneWidget);
    expect(s.log.intact, isFalse);
  });

  testWidgets('"No, I expected someone else" stops the payment instead of going on to the amount', (tester) async {
    final s = await _start(tester);
    await _tap(tester, 'Send money');
    await _tap(tester, 'Someone new');
    await tester.enterText(find.byType(TextField).first, 'sharma.tailor@okicici');
    await _tap(tester, 'Next →');
    expect(s.current, 'nameCheck');
    await _tap(tester, 'No, I expected someone else');
    expect(s.current, 'wrongPerson');
    expect(find.text('Good. We stopped the payment.'), findsOneWidget);
    expect(s.stack, ['home', 'wrongPerson']);
    await _tap(tester, 'Type the UPI ID again');
    expect(s.current, 'newPayee');
    expect(s.upiCtl.text, 'sharma.tailor@okicici');
  });

  testWidgets('a new person paid under a given name appears in "People you have paid before"', (tester) async {
    final s = await _start(tester);
    await _tap(tester, 'Send money');
    await _tap(tester, 'Someone new');
    await tester.enterText(find.byType(TextField).first, 'sharma.tailor@okicici');
    await _tap(tester, 'Next →');
    await tester.enterText(find.byType(TextField).first, 'Sharma ji tailor');
    await _tap(tester, 'Yes, that is right');
    await tester.enterText(find.byType(TextField).first, '300');
    await _tap(tester, 'Next →');
    for (var i = 0; i < 4; i++) {
      await _tap(tester, 'No');
    }
    await _tap(tester, 'Continue to pay →');
    await _tap(tester, 'Pay now →');
    for (final d in ['1', '2', '3', '4']) {
      await _tap(tester, d);
    }
    expect(find.text('Payment done'), findsOneWidget);
    expect(s.practicePayees.map((p) => p.name), ['Sharma ji tailor']);
    await _tap(tester, 'Back to home');
    await _tap(tester, 'Send money');
    expect(find.text('Sharma ji tailor'), findsOneWidget);
    // Kept after the app restarts
    final again = AppState();
    await again.load();
    expect(again.practicePayees.single.id, 'sharma.tailor@okicici');
    // Picked from the list, they count as known: no "new person" warning, straight to the amount
    await _tap(tester, 'Sharma ji tailor');
    expect(s.current, 'amount');
    expect(s.f.payee!.saved, isTrue);
  });

  testWidgets('real mode: a payment the UPI app did not confirm still saves the person', (tester) async {
    final s = await _start(tester);
    phone['payUpi'] = ''; // like iPhone UPI apps and some Android ones: no status comes back
    s.mode = 'real';
    s.render();
    await tester.pumpAndSettle();
    await _tap(tester, 'Send money');
    await _tap(tester, 'Someone new');
    await tester.enterText(find.byType(TextField).first, 'meena.r@oksbi');
    await _tap(tester, 'Next →');
    await tester.enterText(find.byType(TextField).first, 'Meena');
    await _tap(tester, 'Yes, that is right');
    await tester.enterText(find.byType(TextField).first, '500');
    await _tap(tester, 'Next →');
    for (var i = 0; i < 4; i++) {
      await _tap(tester, 'No');
    }
    await _tap(tester, 'Continue to pay →');
    await _tap(tester, 'Open my UPI app to pay →');
    expect(s.current, 'done');
    expect(s.payees.single.name, 'Meena');
  });

  testWidgets('check a link: a fake bank site is red and names the bank it copies', (tester) async {
    final s = await _start(tester);
    await _tap(tester, 'Check a link');
    await tester.enterText(find.byType(TextField).first, 'Your account is blocked, verify at http://sbi-kyc-update.in/verify now');
    await _tap(tester, 'Check this link');
    expect(find.text('Do not open this link. It looks like a trap.'), findsOneWidget);
    expect(find.text('sbi-kyc-update.in'), findsOneWidget);
    expect(find.textContaining("it is not SBI's real website"), findsOneWidget);
    expect(s.log.entries.last.kind, 'linkCheck');
  });

  testWidgets('a scam message with a link shows the link check too', (tester) async {
    await _start(tester);
    await _tap(tester, 'Check a message');
    await tester.enterText(find.byType(TextField).first, 'Dear customer, click hdfcbnak.com/login to stop your account closing');
    await _tap(tester, 'Check this message');
    expect(find.text('This looks like a scam message'), findsOneWidget);
    expect(find.text('LINKS IN THIS MESSAGE'), findsOneWidget);
    expect(find.text('hdfcbnak.com'), findsOneWidget);
  });
}

