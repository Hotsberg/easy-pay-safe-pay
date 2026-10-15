// Port of the original android/tests/engine.test.js.
import 'package:flutter_test/flutter_test.dart';
import 'package:safepay/engine.dart';

void main() {
  const base = PayContext(amount: 200, usual: 500, familyLimit: 5000);

  test('known shop, small amount is green', () {
    expect(assess(base).level, 'green');
  });
  test('new payee alone stays green, new payee + caller is amber', () {
    expect(assess(base.copyWith(newPayee: true)).level, 'green');
    expect(assess(base.copyWith(newPayee: true, calledFirst: true)).level, 'amber');
  });
  test('bank-officer collect scam is red', () {
    final r = assess(base.copyWith(isCollect: true, thinksReceive: true, calledFirst: true, urgency: true, newPayee: true,
        nameMismatch: true, amount: 15000, usual: 0));
    expect(r.level, 'red');
    expect(r.reasons.first, 'collect');
  });
  test('remote-access app alone forces red', () {
    expect(assess(base.copyWith(remoteApp: true)).level, 'red');
  });
  test('over family limit to a known payee needs a check', () {
    expect(assess(base.copyWith(amount: 6000, usual: 5000)).level, 'amber');
  });
  test('family limit 0 means no limit', () {
    expect(assess(base.copyWith(amount: 6000, usual: 5000, familyLimit: 0)).level, 'green');
  });

  test('scam SMS are flagged, normal SMS are not', () {
    expect(checkMessage('Dear customer your SBI account will be blocked today. Update KYC now: http://bit.ly/x').level, 'red');
    expect(checkMessage('This is CBI. You are under digital arrest. Do not disconnect the call.').level, 'red');
    expect(checkMessage('Congratulations! You won KBC lottery 25 lakh. Pay processing fee to receive').level, 'red');
    expect(checkMessage('Your OTP for login is 482910. Do not share it with anyone.').level, isNot('green'));
    expect(checkMessage('Beta, I will reach home by 7. Keep dinner ready.').level, 'green');
    expect(checkMessage('आपका खाता बंद हो जाएगा, तुरंत KYC करें').level, 'red');
    expect(checkMessage('आपका बिजली कनेक्शन आज रात काट दिया जाएगा। तुरंत इस नंबर पर कॉल करें').level, 'red');
    expect(checkMessage('ನಿಮ್ಮ ವಿದ್ಯುತ್ ಸಂಪರ್ಕ ಇಂದು ರಾತ್ರಿ ಕಡಿತಗೊಳ್ಳುತ್ತದೆ').level, 'red');
  });
  test('message reasons are ordered by weight, ties keep rule order', () {
    expect(checkMessage('Update KYC now: http://bit.ly/x, your OTP').reasons, ['otp', 'kyc', 'link']);
  });

  test('number words, Indian system', () {
    expect(toWordsIN(15000), 'fifteen thousand');
    expect(toWordsIN(125050), 'one lakh twenty-five thousand fifty');
    expect(toWordsIN(200), 'two hundred');
  });
  test('rupee amounts use Indian grouping', () {
    expect(rupee(200), '₹200');
    expect(rupee(15000), '₹15,000');
    expect(rupee(100000), '₹1,00,000');
    expect(rupee(12345678), '₹1,23,45,678');
  });

  test('UPI QR parsing', () {
    final q = parseUpiQr('upi://pay?pa=raju.kirana@okaxis&pn=Raju%20Kirana%20Store&am=150.00&mc=5411')!;
    expect([q.pa, q.pn, q.am, q.mc], ['raju.kirana@okaxis', 'Raju Kirana Store', '150.00', '5411']);
    expect(parseUpiQr('UPI://pay?pa=Shop@YBL&pn=A+B')!.pa, 'shop@ybl');
    expect(parseUpiQr('https://example.com'), isNull);
    expect(parseUpiQr('upi://pay?pn=NoId'), isNull);
    expect(parseUpiQr('meena.r@oksbi')!.pa, 'meena.r@oksbi');
  });

  test('UPI link keeps @ literal and formats the amount', () {
    final u = buildUpiUri(pa: 'raju.kirana@okaxis', pn: 'Raju Kirana Store', am: 200);
    expect(u, 'upi://pay?pa=raju.kirana@okaxis&pn=Raju%20Kirana%20Store&am=200.00&cu=INR&tn=Easy%20Pay');
  });

  test('UPI app responses', () {
    expect(parseUpiResponse('txnId=AX1&responseCode=00&Status=SUCCESS&txnRef=9').status, 'success');
    expect(parseUpiResponse('txnId=AX1&Status=FAILURE').status, 'failure');
    expect(parseUpiResponse('status=submitted').status, 'pending');
    expect(parseUpiResponse('').status, 'unknown');
    expect(parseUpiResponse('txnId=AX1&responseCode=00&Status=SUCCESS').txnId, 'AX1');
  });

  test('spoken amounts and yes/no', () {
    expect(parseSpokenAmount('two hundred'), 200);
    expect(parseSpokenAmount('₹1,500'), 1500);
    expect(parseSpokenAmount('5 हज़ार'), 5000);
    expect(parseSpokenAmount('fifteen thousand'), 15000);
    expect(parseYesNo('haan'), isTrue);
    expect(parseYesNo('नहीं'), isFalse);
    expect(parseYesNo('ಹೌದು'), isTrue);
    expect(parseYesNo('hello'), isNull);
  });

  // ---- security controls ----

  test('being on a call while paying a new person is red; a known shop is amber', () {
    expect(assess(base.copyWith(onCall: true, newPayee: true)).level, 'red');
    expect(assess(base.copyWith(onCall: true)).level, 'amber');
  });

  test('screen sharing and a "scan to receive" QR force red on their own', () {
    expect(assess(base.copyWith(screenShared: true)).level, 'red');
    expect(assess(base.copyWith(qrReceive: true)).level, 'red');
  });

  test('a remote-control app on the phone plus a new payee is red', () {
    expect(assess(base.copyWith(remoteInstalled: true, newPayee: true)).level, 'red');
    // Not counted twice when the user also said yes to the remote-app question
    expect(assess(base.copyWith(remoteInstalled: true, remoteApp: true)).reasons, ['remote']);
  });

  test('lookalike UPI IDs are caught; the real one and unrelated ones are not', () {
    const known = ['raju.kirana@okaxis', 'meena.r@oksbi'];
    expect(lookalikeOf('raju.klrana@okaxis', known), 'raju.kirana@okaxis'); // i -> l
    expect(lookalikeOf('rajukirana@okaxis', known), 'raju.kirana@okaxis'); // dot removed
    expect(lookalikeOf('raju.kirana@okaxls', known), 'raju.kirana@okaxis'); // handle changed
    expect(lookalikeOf('raju.klrana0@okaxis', known), 'raju.kirana@okaxis'); // one extra character
    expect(lookalikeOf('raju.kirana@okaxis', known), isNull);
    expect(lookalikeOf('sharma.tailor@okicici', known), isNull);
    expect(assess(base.copyWith(lookalike: true, newPayee: true)).level, 'red');
  });

  test('IDs and names posing as banks, government or prize desks', () {
    expect(looksOfficial('sbi.kyc.help@ybl'), isTrue);
    expect(looksOfficial('hdfcrefund2024@paytm'), isTrue);
    expect(looksOfficial('rahul.t@ybl', 'SBI Refund Desk'), isTrue);
    expect(looksOfficial('raju.kirana@okaxis', 'Raju Kirana Store'), isFalse);
    expect(looksOfficial('meena.r@oksbi', 'Meena Rao'), isFalse); // the bank handle after @ is normal
  });

  test('what a scanned code is', () {
    expect(qrKind('upi://pay?pa=a@ybl'), 'upi');
    expect(qrKind('UPI://mandate?pa=a@ybl&am=999'), 'mandate');
    expect(qrKind('http://sbi-kyc-update.in/verify'), 'web');
    expect(qrKind('www.bit.ly/x'), 'web');
    expect(qrKind('hello'), 'other');
    expect(qrHost('http://sbi-kyc-update.in/verify?ref=1'), 'sbi-kyc-update.in');
    expect(qrPromisesMoney('Scan to RECEIVE Rs 4999 cashback'), isTrue);
    expect(qrPromisesMoney('Groceries'), isFalse);
  });

  test('malformed payment QR codes are rejected', () {
    expect(parseUpiQr('upi://pay?pa=a.b@ybl&am=1e9'), isNull);
    expect(parseUpiQr('upi://pay?pa=a.b@ybl&am=-50'), isNull);
    expect(parseUpiQr('upi://pay?pa=a.b@ybl&am=10&cu=USD'), isNull);
    expect(parseUpiQr('upi://pay?pa=a.b@ybl&am=99.50&cu=INR'), isNotNull);
  });

  test('many payments in an hour, and small payments adding up past the family limit', () {
    expect(assess(base.copyWith(recentPayments: 2)).reasons, contains('velocity'));
    expect(assess(base.copyWith(recentPayments: 1)).level, 'green');
    final split = assess(base.copyWith(amount: 2000, usual: 2000, paidToday: 4000));
    expect(split.reasons, ['dailyLimit']);
    expect(split.level, 'amber');
  });

  test('phishing links: fake bank sites, short links, tricks; real sites pass', () {
    final fake = checkLink('http://sbi-kyc-update.in/verify?ref=8812');
    expect(fake.level, 'red');
    expect(fake.reasons, contains('brand'));
    expect(fake.brand, 'SBI');
    expect(checkLink('hdfcbnak.com/login').brand, 'HDFC Bank'); // two letters swapped
    expect(checkLink('https://paytrn.com').brand, 'Paytm'); // rn looks like m
    expect(checkLink('https://bit.ly/3abc').reasons, contains('shortener'));
    expect(checkLink('https://sbi.co.in@evil.xyz/a').host, 'evil.xyz');
    expect(checkLink('https://sbi.co.in@evil.xyz/a').level, 'red');
    expect(checkLink('http://192.168.4.20/pay').reasons, contains('ip'));
    expect(checkLink('https://drive.google.com/x/app.apk').reasons, contains('apk'));
    expect(checkLink('https://bescom-bill-pay.online').level, 'red');
    for (final ok in ['https://www.onlinesbi.sbi', 'https://www.hdfcbank.com/personal', 'incometax.gov.in', 'https://wikipedia.org']) {
      expect(checkLink(ok).level, 'green', reason: ok);
    }
    expect(checkLink('https://www.onlinesbi.sbi').official, 'SBI');
  });

  test('links are found inside a message, but not UPI IDs, amounts or names', () {
    expect(findLinks('KYC blocked. Update at sbi-kyc.in/verify or http://bit.ly/x1. Mr.Sharma, Rs.500, pay raju@okaxis.'),
        ['sbi-kyc.in/verify', 'http://bit.ly/x1']);
    expect(findLinks('Your bill is due. Thank you.'), isEmpty);
  });
}

