// Scam risk engine, SMS checker and small helpers. Pure functions, no Flutter imports, so they run in plain Dart tests.

/// The facts a payment check looks at. Some come from the user's answers, the rest are measured by the app
/// (the phone call, screen sharing and remote-control apps come from the phone itself, so a coached answer cannot hide them).
class PayContext {
  final bool isCollect, thinksReceive, calledFirst, urgency, prizeRefund, remoteApp, nameMismatch, newPayee;
  final bool onCall, screenShared, remoteInstalled, lookalike, impersonation, qrReceive;
  final num amount, usual, familyLimit, paidToday;
  final int recentPayments;

  const PayContext({
    this.isCollect = false,
    this.thinksReceive = false,
    this.calledFirst = false,
    this.urgency = false,
    this.prizeRefund = false,
    this.remoteApp = false,
    this.nameMismatch = false,
    this.newPayee = false,
    this.onCall = false,
    this.screenShared = false,
    this.remoteInstalled = false,
    this.lookalike = false,
    this.impersonation = false,
    this.qrReceive = false,
    this.amount = 0,
    this.usual = 0,
    this.familyLimit = 0,
    this.paidToday = 0,
    this.recentPayments = 0,
  });

  PayContext copyWith({
    bool? isCollect, bool? thinksReceive, bool? calledFirst, bool? urgency, bool? prizeRefund, bool? remoteApp,
    bool? nameMismatch, bool? newPayee, bool? onCall, bool? screenShared, bool? remoteInstalled, bool? lookalike,
    bool? impersonation, bool? qrReceive, num? amount, num? usual, num? familyLimit, num? paidToday, int? recentPayments,
  }) =>
      PayContext(
        isCollect: isCollect ?? this.isCollect,
        thinksReceive: thinksReceive ?? this.thinksReceive,
        calledFirst: calledFirst ?? this.calledFirst,
        urgency: urgency ?? this.urgency,
        prizeRefund: prizeRefund ?? this.prizeRefund,
        remoteApp: remoteApp ?? this.remoteApp,
        nameMismatch: nameMismatch ?? this.nameMismatch,
        newPayee: newPayee ?? this.newPayee,
        onCall: onCall ?? this.onCall,
        screenShared: screenShared ?? this.screenShared,
        remoteInstalled: remoteInstalled ?? this.remoteInstalled,
        lookalike: lookalike ?? this.lookalike,
        impersonation: impersonation ?? this.impersonation,
        qrReceive: qrReceive ?? this.qrReceive,
        amount: amount ?? this.amount,
        usual: usual ?? this.usual,
        familyLimit: familyLimit ?? this.familyLimit,
        paidToday: paidToday ?? this.paidToday,
        recentPayments: recentPayments ?? this.recentPayments,
      );
}

/// Result of a payment or message check: 'green', 'amber' or 'red', plus rule ids in order.
class Assessment {
  final int score;
  final String level;
  final List<String> reasons;
  const Assessment(this.score, this.level, this.reasons);
}

class Rule {
  final String id;
  final int pts;
  final bool critical;
  final bool Function(PayContext c) test;
  const Rule(this.id, this.pts, this.test, {this.critical = false});
}

// Payment rules: explainable points. 0-2 green, 3-5 amber, 6+ red.
// "critical" rules force red on their own: a collect request mistaken for receiving money, a remote-access app the user
// was told to install, a shared or recorded screen, and a QR code that promises money for scanning it.
final List<Rule> rules = [
  Rule('collect', 4, (c) => c.isCollect && c.thinksReceive, critical: true),
  Rule('qrReceive', 4, (c) => c.qrReceive, critical: true),
  Rule('remote', 4, (c) => c.remoteApp, critical: true),
  Rule('screenShared', 4, (c) => c.screenShared, critical: true),
  Rule('lookalike', 5, (c) => c.lookalike),
  Rule('onCall', 4, (c) => c.onCall),
  Rule('remoteInstalled', 4, (c) => c.remoteInstalled && !c.remoteApp),
  Rule('caller', 3, (c) => c.calledFirst),
  Rule('urgency', 3, (c) => c.urgency),
  Rule('prize', 3, (c) => c.prizeRefund),
  Rule('impersonation', 3, (c) => c.impersonation),
  Rule('mismatch', 3, (c) => c.nameMismatch),
  Rule('overLimit', 3, (c) => c.familyLimit > 0 && c.amount > c.familyLimit),
  // Splitting a big payment into small ones still adds up against the family limit
  Rule('dailyLimit', 3,
      (c) => c.familyLimit > 0 && c.amount <= c.familyLimit && c.paidToday + c.amount > c.familyLimit),
  // Drain scams repeat "the payment failed, pay again"
  Rule('velocity', 3, (c) => c.recentPayments >= 2),
  Rule('newPayee', 2, (c) => c.newPayee),
  Rule('bigAmount', 2, (c) => c.usual > 0 && c.amount > 3 * c.usual),
];

/// Levels in order of danger, for "did it get worse?" comparisons.
int levelRank(String level) => const {'green': 0, 'amber': 1, 'red': 2}[level] ?? 0;

Assessment assess(PayContext c) {
  final hits = rules.where((r) => r.test(c)).toList();
  final score = hits.fold<int>(0, (s, r) => s + r.pts);
  var level = score >= 6 ? 'red' : score >= 3 ? 'amber' : 'green';
  if (hits.any((h) => h.critical)) level = 'red';
  // Over the family limit (at once or across the day) always needs a check, even for a known payee
  if (level == 'green' && hits.any((h) => h.id == 'overLimit' || h.id == 'dailyLimit')) level = 'amber';
  return Assessment(score, level, hits.map((h) => h.id).toList());
}

// ---- payee identity checks ----

// Normalise the characters scammers swap to make an ID look like a familiar one (0/o, 1/l/i, 5/s, rn/m, vv/w).
String _skeleton(String id) => id
    .toLowerCase()
    .replaceAll('rn', 'm')
    .replaceAll('vv', 'w')
    .replaceAll(RegExp(r'[0]'), 'o')
    .replaceAll(RegExp(r'[1i|]'), 'l')
    .replaceAll('5', 's')
    .replaceAll('3', 'e')
    .replaceAll(RegExp(r'[._-]'), '');

int _editDistance(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// The saved UPI ID that [id] imitates (one or two characters off, or the same after swapping lookalike characters),
/// or null. An exact match is the real payee, not a lookalike.
String? lookalikeOf(String id, Iterable<String> known) {
  final a = id.toLowerCase();
  final sa = _skeleton(a);
  for (final k in known) {
    final b = k.toLowerCase();
    if (a == b) return null;
  }
  for (final k in known) {
    final b = k.toLowerCase();
    final sb = _skeleton(b);
    if (sa == sb || (sb.length >= 8 && _editDistance(sa, sb) <= 2)) return k;
  }
  return null;
}

// Words that make a personal UPI ID or name pose as a bank, the government or a prize desk
final _officialSeg = RegExp(
    r'^(sbi|hdfc|icici|axis|kotak|pnb|bob|canara|rbi|npci|uidai|bank|kyc|refund|helpdesk|help|support|care|official|govt|gov|police|cbi|customs|lottery|kbc|prize|reward|cashback|incometax|aadhar|aadhaar)$');
final _officialAny = RegExp(r'kyc|refund|helpdesk|customercare|lottery|cashback|incometax|reward');
final _officialName = RegExp(
    r'\b(sbi|hdfc|icici|axis|kotak|rbi|npci|bank|kyc|refund|help ?desk|customer care|support|government|govt|police|cbi|customs|lottery|kbc|prize|cashback)\b',
    caseSensitive: false);

/// True when the UPI ID (before the @) or the shown name pretends to be a bank, government office or prize desk.
bool looksOfficial(String id, [String name = '']) {
  final local = id.toLowerCase().split('@').first;
  if (local.split(RegExp(r'[._\-0-9]+')).any(_officialSeg.hasMatch) || _officialAny.hasMatch(local)) return true;
  return _officialName.hasMatch(name);
}

// A payment QR only ever sends money. A note promising money for scanning it is the "scan to receive" scam.
final _receiveNote = RegExp(
    r'receive|refund|cashback|prize|reward|winner|lottery|claim|kyc|get ₹|get rs|प्राप्त|पाएं|इनाम|रिफंड|ಪಡೆಯಿರಿ|ರೀಫಂಡ್|ಬಹುಮಾನ',
    caseSensitive: false);
bool qrPromisesMoney(String note) => _receiveNote.hasMatch(note);

/// What a scanned code is: 'upi' (a payment), 'mandate' (UPI AutoPay), 'web' (a website link) or 'other'.
String qrKind(String? text) {
  final s = (text ?? '').trim().toLowerCase();
  if (s.startsWith('upi://mandate')) return 'mandate';
  if (s.startsWith('upi://') || isUpiId(s)) return 'upi';
  if (RegExp(r'^(https?://|www\.)').hasMatch(s)) return 'web';
  return 'other';
}

/// The website a 'web' QR code would open, for showing the user ("bit.ly", "sbi-kyc-update.in").
String qrHost(String text) {
  final s = text.trim();
  final u = Uri.tryParse(s.toLowerCase().startsWith('www.') ? 'https://$s' : s);
  return (u?.host.isNotEmpty ?? false) ? u!.host : s;
}

// ---- phishing link check (offline: we read the address, never open it) ----

/// The result of checking one link: its level, the reason ids, the website shown to the user, the brand it imitates
/// (for 'brand'), the organisation it really belongs to (for a clean official site) and its ending (for 'tld').
class LinkCheck {
  final String url, host, level, brand, official, tld;
  final int score;
  final List<String> reasons;
  const LinkCheck(this.url, this.host, this.level, this.score, this.reasons, {this.brand = '', this.official = '', this.tld = ''});
}

// Real websites of banks, payment apps and offices that scammers copy, by registrable domain
const officialSites = {
  'sbi.co.in': 'SBI', 'onlinesbi.sbi': 'SBI', 'sbi.bank.in': 'SBI', 'hdfcbank.com': 'HDFC Bank', 'hdfc.bank.in': 'HDFC Bank',
  'icicibank.com': 'ICICI Bank', 'icici.bank.in': 'ICICI Bank', 'axisbank.com': 'Axis Bank', 'axis.bank.in': 'Axis Bank',
  'kotak.com': 'Kotak Bank', 'pnbindia.in': 'Punjab National Bank', 'bankofbaroda.in': 'Bank of Baroda',
  'canarabank.com': 'Canara Bank', 'unionbankofindia.co.in': 'Union Bank', 'paytm.com': 'Paytm', 'phonepe.com': 'PhonePe',
  'google.com': 'Google', 'npci.org.in': 'NPCI', 'bhimupi.org.in': 'BHIM', 'rbi.org.in': 'RBI', 'amazon.in': 'Amazon',
  'amazon.com': 'Amazon', 'flipkart.com': 'Flipkart', 'whatsapp.com': 'WhatsApp', 'airtel.in': 'Airtel', 'jio.com': 'Jio',
  'bsnl.co.in': 'BSNL', 'bescom.co.in': 'BESCOM', 'indiapost.gov.in': 'India Post', 'uidai.gov.in': 'Aadhaar (UIDAI)',
  'incometax.gov.in': 'Income Tax Department', 'epfindia.gov.in': 'EPFO', 'cybercrime.gov.in': 'Cyber Crime Portal',
  'sancharsaathi.gov.in': 'Sanchar Saathi',
};

// Names scammers put in fake website addresses, and the brand to show the user
const _brandWords = {
  'sbi': 'SBI', 'onlinesbi': 'SBI', 'yono': 'SBI', 'hdfc': 'HDFC Bank', 'hdfcbank': 'HDFC Bank', 'icici': 'ICICI Bank',
  'icicibank': 'ICICI Bank', 'axisbank': 'Axis Bank', 'kotak': 'Kotak Bank', 'pnb': 'Punjab National Bank',
  'canara': 'Canara Bank', 'barodabank': 'Bank of Baroda', 'paytm': 'Paytm', 'phonepe': 'PhonePe', 'gpay': 'Google Pay',
  'googlepay': 'Google Pay', 'bhim': 'BHIM', 'npci': 'NPCI', 'rbi': 'RBI', 'reservebank': 'RBI', 'uidai': 'Aadhaar (UIDAI)',
  'aadhaar': 'Aadhaar (UIDAI)', 'aadhar': 'Aadhaar (UIDAI)', 'incometax': 'Income Tax Department', 'epfo': 'EPFO',
  'indiapost': 'India Post', 'amazon': 'Amazon', 'flipkart': 'Flipkart', 'whatsapp': 'WhatsApp', 'airtel': 'Airtel',
  'jio': 'Jio', 'bsnl': 'BSNL', 'bescom': 'BESCOM', 'fastag': 'FASTag', 'echallan': 'e-Challan', 'parivahan': 'Parivahan',
};

const _shorteners = {
  'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'cutt.ly', 'rb.gy', 'shorturl.at', 'tiny.cc', 'ow.ly', 'rebrand.ly',
  's.id', 't.ly', 'v.gd', 'bitly.com', 'shorte.st', 'adf.ly', 'tinu.be', 'u.to', 'qr.ae', 'surl.li', 'clck.ru', 'wa.link',
};
const _riskyTlds = {
  'xyz', 'top', 'club', 'online', 'site', 'live', 'buzz', 'icu', 'tk', 'ml', 'ga', 'cf', 'gq', 'work', 'click', 'link',
  'loan', 'win', 'vip', 'monster', 'rest', 'cyou', 'sbs', 'bond', 'shop', 'store', 'support', 'help', 'info', 'cc', 'ru', 'cn',
};
// Endings where the name people register sits one label further left (x.co.in, x.gov.in)
const _twoLevel = {'co.in', 'gov.in', 'org.in', 'net.in', 'ac.in', 'nic.in', 'res.in', 'edu.in', 'firm.in', 'gen.in', 'ind.in', 'bank.in', 'co.uk'};
final _bait = RegExp(
    r'kyc|verif|update|login|signin|secure|reward|refund|claim|prize|lottery|cashback|bonus|gift|free|otp|pan-?card|block|suspend|unlock|redeem|wallet|challan|penalty');

String _registrable(String host) {
  final parts = host.split('.');
  if (parts.length <= 2) return host;
  final n = _twoLevel.contains(parts.sublist(parts.length - 2).join('.')) ? 3 : 2;
  return parts.length <= n ? host : parts.sublist(parts.length - n).join('.');
}

/// The organisation a website really belongs to, or '' when it is not one of the sites scammers copy.
String officialOwner(String host) {
  final h = host.toLowerCase();
  final owner = officialSites[_registrable(h)];
  if (owner != null) return owner;
  if (h.endsWith('.gov.in') || h.endsWith('.nic.in')) return 'Government of India';
  if (h.endsWith('.sbi')) return 'SBI';
  return '';
}

// Links in a message: with http(s):// or www., or a bare address with a known ending (sbi-kyc.in/verify)
final _urlRe = RegExp(
    r"(?:https?://|www\.)[^\s<>\x22']+|(?<![@\w.-])[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:com|in|net|org|info|xyz|top|club|online|site|live|buzz|icu|tk|ml|ga|cf|gq|work|click|link|shop|store|loan|win|vip|cc|co|io|me|ly|gl|gd|sbi|app|ru|cn|support|help|bond|sbs|cyou|monster|rest)(?![\w-])(?:/[^\s<>\x22']*)?",
    caseSensitive: false);

/// Every link written in [text], in order, without trailing punctuation.
List<String> findLinks(String? text) => _urlRe
    .allMatches(text ?? '')
    .map((m) => m.group(0)!.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), ''))
    .where((u) => u.isNotEmpty)
    .toSet()
    .toList();

/// Look for the signs of a phishing link. Works offline: the link is never opened.
LinkCheck checkLink(String raw) {
  final url = raw.trim();
  final hasScheme = RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(url);
  final full = hasScheme ? url : 'https://$url';
  final afterScheme = full.substring(full.indexOf('://') + 3);
  final authority = afterScheme.split(RegExp(r'[/?#]')).first;
  final rest = afterScheme.substring(authority.length).toLowerCase();
  // The real website is what comes after any "@": https://sbi.co.in@evil.xyz opens evil.xyz
  var host = authority.split('@').last.toLowerCase();
  host = (host.startsWith('[') ? host : host.split(':').first).replaceAll(RegExp(r'\.$'), '');
  final reasons = <String>[];
  var score = 0;
  void add(String id, int pts) {
    reasons.add(id);
    score += pts;
  }

  final owner = officialOwner(host);
  final tld = host.contains('.') ? host.split('.').last : '';
  var brand = '';

  if (authority.contains('@')) add('at', 4);
  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) || host.startsWith('[')) add('ip', 4);
  if (host.contains('xn--') || RegExp(r'[^\x00-\x7f]').hasMatch(host)) add('puny', 4);
  if (owner.isEmpty) {
    // A brand name in the address, or one or two letters off it (hdfcbnak, paytrn), on a website that is not theirs
    for (final tok in host.split(RegExp(r'[.-]')).where((x) => x.isNotEmpty)) {
      final sk = _skeleton(tok);
      for (final e in _brandWords.entries) {
        final w = e.key, sw = _skeleton(w);
        final hit = w.length <= 4
            ? (tok == w || sk == sw || (tok.length <= w.length + 6 && (sk.startsWith(sw) || sk.endsWith(sw))))
            : (sk.contains(sw) || (w.length >= 6 && sk.length >= 6 && _editDistance(sk, sw) <= 2));
        if (hit) {
          brand = e.value;
          break;
        }
      }
      if (brand.isNotEmpty) break;
    }
    if (brand.isNotEmpty) add('brand', 5);
    if (_shorteners.contains(host) || _shorteners.contains(_registrable(host))) add('shortener', 3);
    if (_riskyTlds.contains(tld)) add('tld', 2);
    final label = _registrable(host).split('.').first;
    if (host.split('.').length > 4 || '-'.allMatches(label).length >= 2 || label.length > 24) add('messy', 2);
    if (_bait.hasMatch(host) || _bait.hasMatch(rest)) add('bait', 2);
    if (url.toLowerCase().startsWith('http://')) add('http', 1);
  }
  if (RegExp(r'\.apk($|[?#])').hasMatch(rest)) add('apk', 5);

  final level = score >= 4 ? 'red' : score >= 2 ? 'amber' : 'green';
  return LinkCheck(url, host, level, score, reasons,
      brand: brand, official: owner.isNotEmpty && score == 0 ? owner : '', tld: tld);
}

class SmsRule {
  final String id;
  final int pts;
  final RegExp re;
  SmsRule(this.id, this.pts, String pattern) : re = RegExp(pattern, caseSensitive: false);
}

// Message checker: keyword groups found in scam SMS / WhatsApp messages (English, Hinglish, Hindi, Kannada).
final List<SmsRule> smsRules = [
  SmsRule('kyc', 3, r'\bkyc\b|pan\s*card.*(update|link)|aadhaa?r.*(update|link)|re-?verify|केवाईसी|ಕೆವೈಸಿ'),
  SmsRule('blocked', 3, r'block|suspend|deactivat|freez|disconnect|band ho|kat jayega|बंद|ब्लॉक|काट|कट जाएगा|ಬ್ಲಾಕ್|ಸ್ಥಗಿತ|ಕಡಿತ'),
  SmsRule('arrest', 4, r'digital arrest|arrest|warrant|\bcbi\b|\bed\b officer|narcotic|customs|police case|money laundering|गिरफ्तार|ಬಂಧನ'),
  SmsRule('otp', 4, r'\botp\b|one time password|upi pin|share.*pin|pin.*share|ओटीपी|ಒಟಿಪಿ'),
  SmsRule('prize', 3, r'lottery|lucky draw|winner|won|prize|kbc|jackpot|reward|cashback|इनाम|लॉटरी|ಬಹುಮಾನ|ಲಾಟರಿ'),
  SmsRule('refund', 2, r'refund|tax return|income tax|रिफंड|ರೀಫಂಡ್'),
  SmsRule('urgent', 2, r'urgent|immediately|within \d+\s*(min|hour|hr)|today only|last chance|tonight|turant|aaj raat|जल्दी|तुरंत|आज रात|ತಕ್ಷಣ|ಬೇಗ|ಇಂದು ರಾತ್ರಿ'),
  SmsRule('link', 3, r'https?://|www\.|bit\.ly|tinyurl|\.apk\b|click (here|the link)|लिंक|ಲಿಂಕ್'),
  SmsRule('remote', 4, r'anydesk|teamviewer|quick ?support|rustdesk|screen ?shar|install (this|the) app|स्क्रीन शेयर|ಸ್ಕ್ರೀನ್'),
  SmsRule('job', 2, r'part[- ]time|work from home|daily income|earn ₹?\s?\d|like (and|&) earn|task.*(earn|pay)|नौकरी|ಕೆಲಸ'),
  SmsRule('courier', 2, r'courier|parcel|fedex|dhl|blue ?dart|package (held|seized)|पार्सल|ಪಾರ್ಸೆಲ್'),
  SmsRule('payToGet', 3, r'pay.*(to receive|to get|processing fee|registration fee)|fee.*(release|claim)|शुल्क|ಶುಲ್ಕ'),
];

Assessment checkMessage(String? text) {
  final s = text ?? '';
  if (s.trim().isEmpty) return const Assessment(0, 'green', []);
  final hits = smsRules.where((r) => r.re.hasMatch(s)).toList();
  final score = hits.fold<int>(0, (a, r) => a + r.pts);
  final level = score >= 5 ? 'red' : score >= 2 ? 'amber' : 'green';
  // Stable sort by points, highest first (List.sort is not stable, so break ties on the original order)
  final order = {for (var i = 0; i < hits.length; i++) hits[i]: i};
  hits.sort((a, b) => b.pts != a.pts ? b.pts - a.pts : order[a]! - order[b]!);
  return Assessment(score, level, hits.map((h) => h.id).toList());
}

// Indian-system number to words (English), e.g. 15000 -> "fifteen thousand"
String toWordsIN(num value) {
  var n = value.floor();
  if (n <= 0) return '';
  const ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
    'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
  String two(int x) => x < 20 ? ones[x] : tens[x ~/ 10] + (x % 10 != 0 ? '-${ones[x % 10]}' : '');
  String three(int x) =>
      (x >= 100 ? '${ones[x ~/ 100]} hundred${x % 100 != 0 ? ' ' : ''}' : '') + (x % 100 != 0 ? two(x % 100) : '');
  final parts = <String>[];
  final crore = n ~/ 10000000; n %= 10000000;
  final lakh = n ~/ 100000; n %= 100000;
  final thousand = n ~/ 1000; n %= 1000;
  if (crore > 0) parts.add('${three(crore)} crore');
  if (lakh > 0) parts.add('${two(lakh)} lakh');
  if (thousand > 0) parts.add('${two(thousand)} thousand');
  if (n > 0) parts.add(three(n));
  return parts.join(' ');
}

/// "₹1,00,000": rupee sign with Indian digit grouping.
String rupee(num n) {
  final whole = n.round().abs().toString();
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final pairs = <String>[];
    while (rest.length > 2) {
      pairs.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) pairs.insert(0, rest);
    grouped = '${pairs.join(',')},$last3';
  }
  return '₹${n < 0 ? '-' : ''}$grouped';
}

final _upiIdRe = RegExp(r'^[a-z0-9._-]{2,}@[a-z0-9]{2,}$', caseSensitive: false);
bool isUpiId(String s) => _upiIdRe.hasMatch(s.trim());

class UpiQr {
  final String pa, pn, am, tn, mc;
  const UpiQr({required this.pa, this.pn = '', this.am = '', this.tn = '', this.mc = ''});
}

String _decode(String v) {
  try {
    return Uri.decodeComponent(v);
  } catch (_) {
    return v;
  }
}

// Parse a UPI QR / deep link: upi://pay?pa=..&pn=..&am=..&tn=..
UpiQr? parseUpiQr(String? text) {
  final s = (text ?? '').trim();
  if (isUpiId(s)) return UpiQr(pa: s.toLowerCase());
  final m = RegExp(r'^upi://pay\?(.*)$', caseSensitive: false).firstMatch(s);
  if (m == null) return null;
  final out = <String, String>{};
  for (final kv in m.group(1)!.split('&')) {
    final i = kv.indexOf('=');
    if (i < 0) continue;
    out[kv.substring(0, i).toLowerCase()] = _decode(kv.substring(i + 1).replaceAll('+', ' '));
  }
  final pa = out['pa'];
  if (pa == null || !isUpiId(pa)) return null;
  // Reject what a genuine payment QR never carries: a foreign currency, or an amount that is not a plain rupee figure
  final cu = out['cu'];
  if (cu != null && cu.isNotEmpty && cu.toUpperCase() != 'INR') return null;
  final am = out['am'] ?? '';
  if (am.isNotEmpty && !RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(am)) return null;
  return UpiQr(pa: pa.toLowerCase(), pn: out['pn'] ?? '', am: out['am'] ?? '', tn: out['tn'] ?? '', mc: out['mc'] ?? '');
}

// Build the upi://pay link handed to GPay / PhonePe / BHIM / Paytm. "@" stays literal: some apps reject %40.
String buildUpiUri({required String pa, String pn = '', required num am, String tn = '', String mc = '', String tr = ''}) {
  String enc(String v) => Uri.encodeComponent(v).replaceAll('%40', '@');
  final q = [
    'pa=${enc(pa)}',
    'pn=${enc(pn.isNotEmpty ? pn : pa)}',
    'am=${am.toStringAsFixed(2)}',
    'cu=INR',
    'tn=${enc(tn.isNotEmpty ? tn : 'Easy Pay')}',
  ];
  if (mc.isNotEmpty) q.add('mc=${enc(mc)}');
  if (tr.isNotEmpty) q.add('tr=${enc(tr)}');
  return 'upi://pay?${q.join('&')}';
}

class UpiResponse {
  final String status, txnId, code;
  const UpiResponse(this.status, {this.txnId = '', this.code = ''});
}

// Read the response string UPI apps return: "txnId=..&responseCode=..&Status=SUCCESS&txnRef=.."
UpiResponse parseUpiResponse(String? resp) {
  if (resp == null || resp.isEmpty || resp == 'null') return const UpiResponse('unknown');
  final o = <String, String>{};
  for (final kv in resp.split('&')) {
    final i = kv.indexOf('=');
    if (i > 0) o[kv.substring(0, i).trim().toLowerCase()] = _decode(kv.substring(i + 1).trim());
  }
  final st = (o['status'] ?? '').toUpperCase();
  final status = st == 'SUCCESS'
      ? 'success'
      : (st == 'FAILURE' || st == 'FAILED')
          ? 'failure'
          : (st == 'SUBMITTED' || st == 'PENDING')
              ? 'pending'
              : 'unknown';
  final txn = (o['txnid'] ?? '').isNotEmpty ? o['txnid']! : (o['txnref'] ?? '');
  return UpiResponse(status, txnId: txn, code: o['responsecode'] ?? '');
}

// Spoken amount: "two hundred", "1500", "पाँच सौ" (digits only for non-English; recognisers usually return digits)
int parseSpokenAmount(String? text) {
  final s = (text ?? '').toLowerCase().replaceAll(',', '');
  final d = RegExp(r'\d+').firstMatch(s);
  if (d != null) {
    var n = int.parse(d.group(0)!);
    if (RegExp(r'\b(thousand|hazaar|hazar)\b|हज़ार|हजार|ಸಾವಿರ').hasMatch(s) && n < 1000) n *= 1000;
    if (RegExp(r'\b(lakh|lac)\b|लाख|ಲಕ್ಷ').hasMatch(s) && n < 100000) n *= 100000;
    return n;
  }
  const w = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'fifteen': 15, 'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
    'seventy': 70, 'eighty': 80, 'ninety': 90};
  var total = 0, cur = 0;
  var any = false;
  for (final word in s.split(RegExp(r'[\s-]+'))) {
    if (w[word] != null) {
      cur += w[word]!;
      any = true;
    } else if (word == 'hundred') {
      cur = (cur == 0 ? 1 : cur) * 100;
      any = true;
    } else if (word == 'thousand') {
      total += (cur == 0 ? 1 : cur) * 1000;
      cur = 0;
      any = true;
    } else if (word == 'lakh') {
      total += (cur == 0 ? 1 : cur) * 100000;
      cur = 0;
      any = true;
    }
  }
  return any ? total + cur : 0;
}

// Spoken yes / no in English, Hindi, Kannada
bool? parseYesNo(String? text) {
  final s = (text ?? '').toLowerCase();
  if (RegExp(r'\b(no|nope|nahi|nahin|illa)\b|नहीं|नही|ಇಲ್ಲ').hasMatch(s)) return false;
  if (RegExp(r'\b(yes|yeah|haan|ha|han|haudu)\b|हाँ|हां|ಹೌದು').hasMatch(s)) return true;
  return null;
}
