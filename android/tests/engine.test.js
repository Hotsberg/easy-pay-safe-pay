// Run: node --test tests/
const test = require('node:test');
const assert = require('node:assert');
const E = require('../app/src/main/assets/www/engine.js');

const base = { isCollect: false, thinksReceive: false, calledFirst: false, urgency: false, prizeRefund: false, remoteApp: false,
  nameMismatch: false, newPayee: false, amount: 200, usual: 500, familyLimit: 5000 };

test('known shop, small amount is green', () => {
  assert.strictEqual(E.assess(base).level, 'green');
});
test('new payee alone stays green, new payee + caller is amber', () => {
  assert.strictEqual(E.assess({ ...base, newPayee: true }).level, 'green');
  assert.strictEqual(E.assess({ ...base, newPayee: true, calledFirst: true }).level, 'amber');
});
test('bank-officer collect scam is red', () => {
  const r = E.assess({ ...base, isCollect: true, thinksReceive: true, calledFirst: true, urgency: true, newPayee: true, nameMismatch: true, amount: 15000, usual: 0 });
  assert.strictEqual(r.level, 'red');
  assert.strictEqual(r.reasons[0], 'collect');
});
test('remote-access app alone forces red', () => {
  assert.strictEqual(E.assess({ ...base, remoteApp: true }).level, 'red');
});
test('over family limit to a known payee needs a check', () => {
  assert.strictEqual(E.assess({ ...base, amount: 6000, usual: 5000 }).level, 'amber');
});
test('family limit 0 means no limit', () => {
  assert.strictEqual(E.assess({ ...base, amount: 6000, usual: 5000, familyLimit: 0 }).level, 'green');
});

test('scam SMS are flagged, normal SMS are not', () => {
  assert.strictEqual(E.checkMessage('Dear customer your SBI account will be blocked today. Update KYC now: http://bit.ly/x').level, 'red');
  assert.strictEqual(E.checkMessage('This is CBI. You are under digital arrest. Do not disconnect the call.').level, 'red');
  assert.strictEqual(E.checkMessage('Congratulations! You won KBC lottery 25 lakh. Pay processing fee to receive').level, 'red');
  assert.strictEqual(E.checkMessage('Your OTP for login is 482910. Do not share it with anyone.').level !== 'green', true);
  assert.strictEqual(E.checkMessage('Beta, I will reach home by 7. Keep dinner ready.').level, 'green');
  assert.strictEqual(E.checkMessage('आपका खाता बंद हो जाएगा, तुरंत KYC करें').level, 'red');
  assert.strictEqual(E.checkMessage('आपका बिजली कनेक्शन आज रात काट दिया जाएगा। तुरंत इस नंबर पर कॉल करें').level, 'red');
  assert.strictEqual(E.checkMessage('ನಿಮ್ಮ ವಿದ್ಯುತ್ ಸಂಪರ್ಕ ಇಂದು ರಾತ್ರಿ ಕಡಿತಗೊಳ್ಳುತ್ತದೆ').level, 'red');
});

test('number words, Indian system', () => {
  assert.strictEqual(E.toWordsIN(15000), 'fifteen thousand');
  assert.strictEqual(E.toWordsIN(125050), 'one lakh twenty-five thousand fifty');
  assert.strictEqual(E.toWordsIN(200), 'two hundred');
});

test('UPI QR parsing', () => {
  const q = E.parseUpiQr('upi://pay?pa=raju.kirana@okaxis&pn=Raju%20Kirana%20Store&am=150.00&mc=5411');
  assert.deepStrictEqual([q.pa, q.pn, q.am, q.mc], ['raju.kirana@okaxis', 'Raju Kirana Store', '150.00', '5411']);
  assert.strictEqual(E.parseUpiQr('UPI://pay?pa=Shop@YBL&pn=A+B').pa, 'shop@ybl');
  assert.strictEqual(E.parseUpiQr('https://example.com'), null);
  assert.strictEqual(E.parseUpiQr('upi://pay?pn=NoId'), null);
  assert.strictEqual(E.parseUpiQr('meena.r@oksbi').pa, 'meena.r@oksbi');
});

test('UPI link keeps @ literal and formats the amount', () => {
  const u = E.buildUpiUri({ pa: 'raju.kirana@okaxis', pn: 'Raju Kirana Store', am: '200' });
  assert.strictEqual(u, 'upi://pay?pa=raju.kirana@okaxis&pn=Raju%20Kirana%20Store&am=200.00&cu=INR&tn=Easy%20Pay');
});

test('UPI app responses', () => {
  assert.strictEqual(E.parseUpiResponse('txnId=AX1&responseCode=00&Status=SUCCESS&txnRef=9').status, 'success');
  assert.strictEqual(E.parseUpiResponse('txnId=AX1&Status=FAILURE').status, 'failure');
  assert.strictEqual(E.parseUpiResponse('status=submitted').status, 'pending');
  assert.strictEqual(E.parseUpiResponse('').status, 'unknown');
  assert.strictEqual(E.parseUpiResponse('txnId=AX1&responseCode=00&Status=SUCCESS').txnId, 'AX1');
});

test('spoken amounts and yes/no', () => {
  assert.strictEqual(E.parseSpokenAmount('two hundred'), 200);
  assert.strictEqual(E.parseSpokenAmount('₹1,500'), 1500);
  assert.strictEqual(E.parseSpokenAmount('5 हज़ार'), 5000);
  assert.strictEqual(E.parseSpokenAmount('fifteen thousand'), 15000);
  assert.strictEqual(E.parseYesNo('haan'), true);
  assert.strictEqual(E.parseYesNo('नहीं'), false);
  assert.strictEqual(E.parseYesNo('ಹೌದು'), true);
  assert.strictEqual(E.parseYesNo('hello'), null);
});
