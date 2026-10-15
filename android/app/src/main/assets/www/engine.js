// Scam risk engine, SMS checker and small helpers. Pure functions, no DOM, so they run in Node tests too.

// Payment rules: explainable points. 0-2 green, 3-5 amber, 6+ red.
// "critical" rules force red on their own (a collect request mistaken for receiving money, a remote-access app).
const RULES = [
  { id: 'collect',   pts: 4, critical: true, test: c => c.isCollect && c.thinksReceive },
  { id: 'remote',    pts: 4, critical: true, test: c => c.remoteApp },
  { id: 'caller',    pts: 3, test: c => c.calledFirst },
  { id: 'urgency',   pts: 3, test: c => c.urgency },
  { id: 'prize',     pts: 3, test: c => c.prizeRefund },
  { id: 'mismatch',  pts: 3, test: c => c.nameMismatch },
  { id: 'overLimit', pts: 3, test: c => c.familyLimit > 0 && c.amount > c.familyLimit },
  { id: 'newPayee',  pts: 2, test: c => c.newPayee },
  { id: 'bigAmount', pts: 2, test: c => c.usual > 0 && c.amount > 3 * c.usual }
];

function assess(c) {
  const hits = RULES.filter(r => r.test(c));
  const score = hits.reduce((s, r) => s + r.pts, 0);
  let level = score >= 6 ? 'red' : score >= 3 ? 'amber' : 'green';
  if (hits.some(h => h.critical)) level = 'red';
  // Over the family limit always needs a check, even for a known payee
  if (level === 'green' && hits.some(h => h.id === 'overLimit')) level = 'amber';
  return { score, level, reasons: hits.map(h => h.id) };
}

// Message checker: keyword groups found in scam SMS / WhatsApp messages (English, Hinglish, Hindi, Kannada).
const SMS_RULES = [
  { id: 'kyc',      pts: 3, re: /\bkyc\b|pan\s*card.*(update|link)|aadhaa?r.*(update|link)|re-?verify|केवाईसी|ಕೆವೈಸಿ/i },
  { id: 'blocked',  pts: 3, re: /block|suspend|deactivat|freez|disconnect|band ho|kat jayega|बंद|ब्लॉक|काट|कट जाएगा|ಬ್ಲಾಕ್|ಸ್ಥಗಿತ|ಕಡಿತ/i },
  { id: 'arrest',   pts: 4, re: /digital arrest|arrest|warrant|\bcbi\b|\bed\b officer|narcotic|customs|police case|money laundering|गिरफ्तार|ಬಂಧನ/i },
  { id: 'otp',      pts: 4, re: /\botp\b|one time password|upi pin|share.*pin|pin.*share|ओटीपी|ಒಟಿಪಿ/i },
  { id: 'prize',    pts: 3, re: /lottery|lucky draw|winner|won|prize|kbc|jackpot|reward|cashback|इनाम|लॉटरी|ಬಹುಮಾನ|ಲಾಟರಿ/i },
  { id: 'refund',   pts: 2, re: /refund|tax return|income tax|रिफंड|ರೀಫಂಡ್/i },
  { id: 'urgent',   pts: 2, re: /urgent|immediately|within \d+\s*(min|hour|hr)|today only|last chance|tonight|turant|aaj raat|जल्दी|तुरंत|आज रात|ತಕ್ಷಣ|ಬೇಗ|ಇಂದು ರಾತ್ರಿ/i },
  { id: 'link',     pts: 3, re: /https?:\/\/|www\.|bit\.ly|tinyurl|\.apk\b|click (here|the link)|लिंक|ಲಿಂಕ್/i },
  { id: 'remote',   pts: 4, re: /anydesk|teamviewer|quick ?support|rustdesk|screen ?shar|install (this|the) app|स्क्रीन शेयर|ಸ್ಕ್ರೀನ್/i },
  { id: 'job',      pts: 2, re: /part[- ]time|work from home|daily income|earn ₹?\s?\d|like (and|&) earn|task.*(earn|pay)|नौकरी|ಕೆಲಸ/i },
  { id: 'courier',  pts: 2, re: /courier|parcel|fedex|dhl|blue ?dart|package (held|seized)|पार्सल|ಪಾರ್ಸೆಲ್/i },
  { id: 'payToGet', pts: 3, re: /pay.*(to receive|to get|processing fee|registration fee)|fee.*(release|claim)|शुल्क|ಶುಲ್ಕ/i }
];

function checkMessage(text) {
  const s = String(text || '');
  if (!s.trim()) return { score: 0, level: 'green', reasons: [] };
  const hits = SMS_RULES.filter(r => r.re.test(s));
  const score = hits.reduce((a, r) => a + r.pts, 0);
  const level = score >= 5 ? 'red' : score >= 2 ? 'amber' : 'green';
  return { score, level, reasons: hits.sort((a, b) => b.pts - a.pts).map(h => h.id) };
}

// Indian-system number to words (English), e.g. 15000 -> "fifteen thousand"
function toWordsIN(n) {
  n = Math.floor(n);
  if (!(n > 0)) return '';
  const ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
  const two = x => x < 20 ? ones[x] : tens[Math.floor(x / 10)] + (x % 10 ? '-' + ones[x % 10] : '');
  const three = x => (x >= 100 ? ones[Math.floor(x / 100)] + ' hundred' + (x % 100 ? ' ' : '') : '') + (x % 100 ? two(x % 100) : '');
  const parts = [];
  const crore = Math.floor(n / 1e7); n %= 1e7;
  const lakh = Math.floor(n / 1e5); n %= 1e5;
  const thousand = Math.floor(n / 1e3); n %= 1e3;
  if (crore) parts.push(three(crore) + ' crore');
  if (lakh) parts.push(two(lakh) + ' lakh');
  if (thousand) parts.push(two(thousand) + ' thousand');
  if (n) parts.push(three(n));
  return parts.join(' ');
}

function isUpiId(s) { return /^[a-z0-9._-]{2,}@[a-z0-9]{2,}$/i.test(String(s).trim()); }

// Parse a UPI QR / deep link: upi://pay?pa=..&pn=..&am=..&tn=..
function parseUpiQr(text) {
  const s = String(text || '').trim();
  if (isUpiId(s)) return { pa: s.toLowerCase(), pn: '', am: '', tn: '' };
  const m = s.match(/^upi:\/\/pay\?(.*)$/i);
  if (!m) return null;
  const out = {};
  m[1].split('&').forEach(kv => {
    const i = kv.indexOf('=');
    if (i < 0) return;
    const k = kv.slice(0, i).toLowerCase();
    let v = kv.slice(i + 1);
    try { v = decodeURIComponent(v.replace(/\+/g, ' ')); } catch (e) {}
    out[k] = v;
  });
  if (!out.pa || !isUpiId(out.pa)) return null;
  return { pa: out.pa.toLowerCase(), pn: out.pn || '', am: out.am || '', tn: out.tn || '', mc: out.mc || '' };
}

// Build the upi://pay link handed to GPay / PhonePe / BHIM / Paytm. "@" stays literal: some apps reject %40.
function buildUpiUri(p) {
  const enc = v => encodeURIComponent(v).replace(/%40/g, '@');
  const q = ['pa=' + enc(p.pa), 'pn=' + enc(p.pn || p.pa), 'am=' + Number(p.am).toFixed(2), 'cu=INR', 'tn=' + enc(p.tn || 'Easy Pay')];
  if (p.mc) q.push('mc=' + enc(p.mc));
  if (p.tr) q.push('tr=' + enc(p.tr));
  return 'upi://pay?' + q.join('&');
}

// Read the response string UPI apps return: "txnId=..&responseCode=..&Status=SUCCESS&txnRef=.."
function parseUpiResponse(resp) {
  if (resp == null || resp === '' || resp === 'null') return { status: 'unknown' };
  const o = {};
  String(resp).split('&').forEach(kv => {
    const i = kv.indexOf('=');
    if (i > 0) o[kv.slice(0, i).trim().toLowerCase()] = decodeURIComponent(kv.slice(i + 1).trim());
  });
  const st = (o.status || '').toUpperCase();
  const status = st === 'SUCCESS' ? 'success' : (st === 'FAILURE' || st === 'FAILED') ? 'failure' : st === 'SUBMITTED' || st === 'PENDING' ? 'pending' : 'unknown';
  return { status, txnId: o.txnid || o.txnref || '', code: o.responsecode || '' };
}

// Spoken amount: "two hundred", "1500", "पाँच सौ" (digits only for non-English; recognisers usually return digits)
function parseSpokenAmount(text) {
  const s = String(text || '').toLowerCase().replace(/,/g, '');
  const d = s.match(/\d+/);
  if (d) {
    let n = parseInt(d[0], 10);
    if (/\b(thousand|hazaar|hazar)\b|हज़ार|हजार|ಸಾವಿರ/.test(s) && n < 1000) n *= 1000;
    if (/\b(lakh|lac)\b|लाख|ಲಕ್ಷ/.test(s) && n < 100000) n *= 100000;
    return n;
  }
  const W = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12,
    fifteen: 15, twenty: 20, thirty: 30, forty: 40, fifty: 50, sixty: 60, seventy: 70, eighty: 80, ninety: 90 };
  let total = 0, cur = 0, any = false;
  s.split(/[\s-]+/).forEach(w => {
    if (W[w] != null) { cur += W[w]; any = true; }
    else if (w === 'hundred') { cur = (cur || 1) * 100; any = true; }
    else if (w === 'thousand') { total += (cur || 1) * 1000; cur = 0; any = true; }
    else if (w === 'lakh') { total += (cur || 1) * 100000; cur = 0; any = true; }
  });
  return any ? total + cur : 0;
}

// Spoken yes / no in English, Hindi, Kannada
function parseYesNo(text) {
  const s = String(text || '').toLowerCase();
  if (/\b(no|nope|nahi|nahin|illa)\b|नहीं|नही|ಇಲ್ಲ/.test(s)) return false;
  if (/\b(yes|yeah|haan|ha|han|haudu)\b|हाँ|हां|ಹೌದು/.test(s)) return true;
  return null;
}

if (typeof module !== 'undefined') module.exports = { RULES, assess, SMS_RULES, checkMessage, toWordsIN, isUpiId, parseUpiQr, buildUpiUri, parseUpiResponse, parseSpokenAmount, parseYesNo };
