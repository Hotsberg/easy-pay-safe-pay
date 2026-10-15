// Easy Pay, Safe Pay: settings, the payment in progress, navigation and every user action.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audit.dart';
import 'engine.dart';
import 'i18n.dart';
import 'native.dart';

class Payee {
  String id, name, ico, mc, tn;
  int usual, count;
  bool saved, fromQr;

  Payee({required this.id, required this.name, this.usual = 0, this.ico = 'person', this.saved = false,
      this.fromQr = false, this.mc = '', this.tn = '', this.count = 1});

  Payee asSaved({String? mc}) =>
      Payee(id: id, name: name, usual: usual, ico: ico, saved: true, mc: mc ?? this.mc, tn: tn, count: count);

  Map<String, Object> toJson() => {'id': id, 'name': name, 'usual': usual, 'count': count, 'ico': ico};

  static Payee fromJson(Map<String, dynamic> j) => Payee(
      id: '${j['id']}', name: '${j['name'] ?? j['id']}', usual: (j['usual'] as num?)?.round() ?? 0,
      count: (j['count'] as num?)?.round() ?? 1, ico: '${j['ico'] ?? 'person'}');
}

// Practice data (no real UPI connection)
final demoSaved = [
  Payee(id: 'raju.kirana@okaxis', name: 'Raju Kirana Store', usual: 500, ico: 'shop'),
  Payee(id: 'meena.r@oksbi', name: 'Meena Rao (daughter)', usual: 2000, ico: 'person'),
  Payee(id: 'bescom.bill@ybl', name: 'BESCOM Electricity', usual: 1500, ico: 'bolt'),
];
const demoDir = {
  'sharma.tailor@okicici': 'Sharma Tailors',
  'sbi.kyc.help@ybl': 'Rahul Traders',
  'lottery.kbc@paytm': 'Prize Desk Services',
  // One letter off Raju's real ID (i -> l), with his shop name copied
  'raju.klrana@okaxis': 'Raju Kirana Store',
};
const demoQr = 'upi://pay?pa=raju.kirana@okaxis&pn=Raju%20Kirana%20Store&mc=5411';
// Practice story 3: a "scan to receive cashback" QR sent on WhatsApp
const scamQr = 'upi://pay?pa=cashback.offer7@ybl&pn=PhonePe%20Cashback%20Desk&am=4999&tn=Scan%20to%20RECEIVE%20Rs%204999%20cashback';
// Practice story 4: a sticker pasted over a shop's QR, leading to a fake bank website
const fakeQrSticker = 'http://sbi-kyc-update.in/verify?ref=8812';

/// Demo builds that mirror the phone to a projector pass --dart-define=ALLOW_SCREEN_MIRROR=true;
/// every other build keeps the screen hidden from screenshots, recording and screen sharing.
const allowMirror = bool.fromEnvironment('ALLOW_SCREEN_MIRROR');

/// How long a change that weakens protection waits before it starts. Short in practice mode so it can be shown live.
Duration coolingOff(bool real) => real ? const Duration(hours: 24) : const Duration(minutes: 2);

/// A payment left half-done in the background for longer than this is cancelled.
const sessionTimeout = Duration(seconds: 60);

/// Screens that are part of a payment in progress.
const flowScreens = {'payee', 'newPayee', 'nameCheck', 'amount', 'question', 'result', 'confirm', 'pin', 'request'};
const scamReq = (
  id: 'sbi.kyc.help@ybl',
  shown: 'SBI Refund Desk',
  name: 'Rahul Traders',
  amount: 15000,
  note: 'KYC refund approved. Enter UPI PIN to RECEIVE ₹15,000. Do it in 10 minutes or account will be blocked.',
);
const questions = ['caller', 'urgency', 'prize', 'remote'];
const upiMax = 100000;
const locales = {'en': 'en-IN', 'hi': 'hi-IN', 'kn': 'kn-IN'};

class Contact {
  String name, phone;
  int limit;
  Contact({this.name = 'Meena', this.phone = '9876543210', this.limit = 5000});
}

/// A change that weakens protection (a higher or no family limit, a different family number), waiting out its
/// cooling-off period. A scammer on the phone cannot make it happen today, and the family is told about it.
class Pending {
  int? limit;
  String? phone;
  int at; // epoch ms when it starts
  Pending({this.limit, this.phone, required this.at});

  Map<String, Object?> toJson() => {'limit': limit, 'phone': phone, 'at': at};
  static Pending? fromJson(Map<String, dynamic>? j) => j == null
      ? null
      : Pending(limit: (j['limit'] as num?)?.toInt(), phone: j['phone'] as String?, at: (j['at'] as num).toInt());
}

/// "••••3210": enough to recognise a number in the history without storing it in full.
String maskPhone(String p) => p.length <= 4 ? p : '••••${p.substring(p.length - 4)}';

/// The payment in progress.
class Flow {
  Map<String, bool> ans = {};
  Payee? payee;
  String amount = '';
  int qi = 0;
  bool collect = false, thinksReceive = false, nameMismatch = false;
  // Identity checks on the payee: the saved ID it imitates, a bank/government-sounding ID, a QR promising money
  String lookalike = '';
  bool official = false, qrReceive = false;
  Assessment? result;
  String pin = '', payStatus = 'success', txnId = '';
  Assessment? msgResult;
  List<LinkCheck> msgLinks = [];
  List<LinkCheck>? linkResults;
  ({String kind, String host, String url})? blockedQr;
}

class AppState extends ChangeNotifier {
  // ---- settings (persisted) ----
  String lang = 'en', mode = 'practice', size = 'normal';
  bool voice = false;
  Contact contact = Contact();
  List<Payee> payees = [];
  /// People paid in practice mode, kept apart from real ones so practice never makes a real payee look trusted.
  List<Payee> practicePayees = [];
  Pending? pending;

  // ---- safety history: one hash chain per mode, so practice runs never mix with real payments ----
  final logs = {'practice': AuditLog(), 'real': AuditLog()};
  AuditLog get log => logs[mode]!;

  // ---- security signals measured by the phone ----
  bool onCall = false, captured = false;
  List<String> remoteApps = [];
  DateTime Function() now = DateTime.now; // replaceable in tests
  DateTime? _pausedAt;
  bool _handoff = false; // we sent the user to another app on purpose (scanner, UPI app, WhatsApp, call)
  Timer? _pendingTimer;
  bool justScheduled = false;

  // ---- session ----
  Flow f = Flow();
  List<String> stack = ['home'];
  bool listening = false, canListen = false;
  String _micTarget = '';
  String lastSay = '';

  /// Bumped on every navigation, so each new screen starts scrolled to the top.
  int navId = 0;

  // A flash message shows for exactly one render, like the original app.
  String _flash = '';
  int _flashGen = -1, _gen = 0;
  String get flash => _flashGen == _gen ? _flash : '';

  /// Seconds left before "I am sure, continue" unlocks on a red result.
  int waitLeft = 0;
  Timer? _timer;

  bool copied = false;

  // Text fields
  final upiCtl = TextEditingController();
  final amtCtl = TextEditingController();
  final nickCtl = TextEditingController();
  final msgCtl = TextEditingController();
  final linkCtl = TextEditingController();
  final reqWhoCtl = TextEditingController();
  final reqAmtCtl = TextEditingController();
  final fNameCtl = TextEditingController();
  final fPhoneCtl = TextEditingController();
  final fLimitCtl = TextEditingController();

  SharedPreferences? _prefs;

  bool get real => mode == 'real';
  /// The people the user saved in the current mode (shown in Settings, where they can be removed).
  List<Payee> get myPayees => real ? payees : practicePayees;
  List<Payee> get savedList => real ? payees : [...practicePayees, ...demoSaved];
  String get current => stack.last;
  String get phoneDigits {
    final d = contact.phone.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  String t(String k, [Map<String, Object>? v]) {
    var s = strings[lang]?[k] ?? strings['en']![k] ?? k;
    v?.forEach((x, val) => s = s.split('{$x}').join('$val'));
    return s;
  }

  String wordsFor(String a) {
    final n = int.tryParse(a) ?? 0;
    if (n <= 0) return '';
    return lang == 'en' ? '${toWordsIN(n)} rupees' : '${rupee(n)} ${t('rupees')}';
  }

  // ---- persistence ----
  Future<void> load() async {
    Native.init();
    Native.onTtsMissing = () => _showFlash(t('noVoice'));
    Native.onCaptureChanged = (v) {
      captured = v;
      render();
    };
    if (allowMirror) await Native.setSecure(false);
    WidgetsBinding.instance.addObserver(_life);
    canListen = await Native.canListen();
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString('easypay');
      if (raw != null) {
        final v = jsonDecode(raw) as Map<String, dynamic>;
        lang = v['lang'] as String? ?? lang;
        voice = v['voice'] as bool? ?? voice;
        mode = v['mode'] as String? ?? mode;
        size = v['size'] as String? ?? size;
        final c = v['contact'] as Map<String, dynamic>?;
        if (c != null) {
          contact = Contact(name: '${c['name'] ?? ''}', phone: '${c['phone'] ?? ''}', limit: (c['limit'] as num?)?.round() ?? 0);
        }
        payees = ((v['payees'] as List?) ?? []).map((p) => Payee.fromJson(p as Map<String, dynamic>)).toList();
        practicePayees =
            ((v['practicePayees'] as List?) ?? []).map((p) => Payee.fromJson(p as Map<String, dynamic>)).toList();
        pending = Pending.fromJson(v['pending'] as Map<String, dynamic>?);
      }
      for (final m in logs.keys) {
        logs[m] = AuditLog.decode(_prefs!.getString('easypay_log_$m'));
      }
    } catch (_) {}
    _applyPending();
    await refreshSignals();
  }

  void _persistLog() {
    try {
      for (final m in logs.keys) {
        _prefs?.setString('easypay_log_$m', logs[m]!.encode());
      }
    } catch (_) {}
  }

  /// Append to the safety history of the current mode.
  void record(String kind, Map<String, Object?> data) {
    log.add(kind, {...data, 'mode': mode}, at: now());
    _persistLog();
  }

  /// Ask the phone, right now, whether a call is on, the screen is being shared and which remote-control apps exist.
  Future<void> refreshSignals() async {
    onCall = await Native.isOnCall();
    captured = await Native.screenCaptured();
    remoteApps = await Native.remoteApps();
  }

  // ---- session expiry: a payment left in the background is cancelled ----
  late final _life = _Lifecycle(this);

  Future<void> onLifecycle(AppLifecycleState st) async {
    if (st == AppLifecycleState.paused) {
      if (!_handoff && flowScreens.contains(current)) _pausedAt = now();
    } else if (st == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : now().difference(_pausedAt!);
      _pausedAt = null;
      _handoff = false;
      _applyPending();
      // Back from another app: a remote-control app may have been installed meanwhile
      await refreshSignals();
      if (away > sessionTimeout && flowScreens.contains(current)) {
        record('expired', {'screen': current});
        _newFlow();
        _reset(['home']);
        _flashNext(t('sessionExpired'));
        _enter();
      } else {
        render();
      }
    }
  }

  void _persist() {
    try {
      _prefs?.setString('easypay', jsonEncode({
        'lang': lang, 'voice': voice, 'mode': mode, 'size': size,
        'contact': {'name': contact.name, 'phone': contact.phone, 'limit': contact.limit},
        'payees': payees.map((p) => p.toJson()).toList(),
        'practicePayees': practicePayees.map((p) => p.toJson()).toList(),
        'pending': pending?.toJson(),
      }));
    } catch (_) {}
  }

  // ---- render / navigation ----
  void render() {
    _gen++;
    notifyListeners();
  }

  void _showFlash(String m) {
    _flash = m;
    _flashGen = _gen + 1;
    render();
  }

  void go(String name) {
    stack.add(name);
    _enter();
  }

  /// Called whenever the visible screen changes.
  void _enter() {
    navId++;
    copied = false;
    _timer?.cancel();
    _timer = null;
    switch (current) {
      case 'nameCheck':
        nickCtl.text = '';
      case 'amount':
        amtCtl.text = f.amount;
      case 'family':
        fNameCtl.text = contact.name;
        fPhoneCtl.text = contact.phone;
        fLimitCtl.text = '${contact.limit}';
      case 'result':
        if (f.result?.level == 'red') {
          waitLeft = 30;
          _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
            waitLeft--;
            if (waitLeft <= 0) tm.cancel();
            notifyListeners();
          });
        }
    }
    render();
  }

  void _reset(List<String> s) {
    stack = s;
  }

  /// Start a fresh payment: drop the flow and its typed drafts.
  void _newFlow() {
    f = Flow();
    for (final c in [upiCtl, amtCtl, msgCtl, linkCtl, reqWhoCtl, reqAmtCtl]) {
      c.clear();
    }
  }

  /// Speak the screen text when voice is on and the screen changed. Called by the UI after each build.
  void announce(String say) {
    if (say == lastSay) return;
    lastSay = say;
    if (voice && !listening) speak(say);
  }

  // ---- voice ----
  void speak(String text) => Native.speak(text, locales[lang]!);

  Future<void> startListening(String target) async {
    if (listening) return;
    _micTarget = target;
    listening = true;
    _handoff = true;
    Native.stopSpeaking();
    render();
    onVoice(await Native.listen(locales[lang]!));
  }

  void onVoice(String text) {
    if (!listening) return; // cancelled with the back button
    listening = false;
    final alts = text.split('|').where((s) => s.isNotEmpty);
    if (_micTarget == 'amount') {
      final n = alts.map(parseSpokenAmount).firstWhere((x) => x > 0, orElse: () => 0);
      if (n > 0) {
        f.amount = '$n';
        amtCtl.text = f.amount;
        render();
        return;
      }
    } else if (_micTarget == 'yesno') {
      final yn = alts.map(parseYesNo).firstWhere((x) => x != null, orElse: () => null);
      if (yn != null) {
        answer(yn);
        return;
      }
    }
    _showFlash(t('notHeard'));
    if (voice) speak(t('notHeard'));
  }

  // ---- QR / UPI results ----
  void onQr(String text) {
    if (text == '__unavailable__') {
      _newFlow();
      _reset(['home', 'payee']);
      _flashNext(t('qrUnavailable'));
      go('newPayee');
      return;
    }
    if (text.isEmpty) return; // scanner closed
    // A website link or an AutoPay mandate is never a shop payment: block it and never open it
    final kind = qrKind(text);
    if (kind == 'web' || kind == 'mandate') {
      _newFlow();
      f.blockedQr = (kind: kind, host: kind == 'web' ? qrHost(text) : '', url: kind == 'web' ? text.trim() : '');
      record('qrBlocked', {'kind': kind, 'host': f.blockedQr!.host});
      _reset(['home']);
      go('qrBlocked');
      return;
    }
    final q = parseUpiQr(text);
    if (q == null) {
      if (current != 'payee') {
        _newFlow();
        _reset(['home']);
        _flashNext(t('qrFail'));
        go('payee');
      } else {
        _showFlash(t('qrFail'));
      }
      return;
    }
    _newFlow();
    _reset(['home', 'payee']);
    final am = num.tryParse(q.am) ?? 0;
    if (am > 0) f.amount = '${am.round()}';
    final saved = savedList.where((p) => p.id == q.pa).firstOrNull;
    if (saved != null) {
      f.payee = saved.asSaved(mc: q.mc);
      go('amount');
      return;
    }
    final demoName = real ? '' : (demoDir[q.pa] ?? '');
    f.payee = Payee(
        id: q.pa, name: q.pn.isNotEmpty ? q.pn : (demoName.isNotEmpty ? demoName : q.pa),
        fromQr: q.pn.isNotEmpty, mc: q.mc, tn: q.tn);
    f.qrReceive = qrPromisesMoney(q.tn);
    _checkIdentity();
    go('nameCheck');
  }

  /// Show a flash on the screen we are about to navigate to.
  void _flashNext(String m) {
    _flash = m;
    _flashGen = _gen + 1;
  }

  void onUpi(String resp) {
    if (f.payee == null) {
      home();
      return;
    }
    final r = parseUpiResponse(resp);
    f.payStatus = r.status;
    f.txnId = r.txnId;
    record('paid', {..._payInfo, 'status': r.status});
    // Many UPI apps (and every iPhone UPI app) do not report back, so 'unknown' still counts: the user sent it on
    if (r.status != 'failure') _rememberPayee(f.payee!, int.tryParse(f.amount) ?? 0);
    _reset(['home']);
    go('done');
  }

  /// System back button. Returns true when handled inside the app.
  bool onBack() {
    if (listening) {
      listening = false;
      render();
      return true;
    }
    if (stack.length > 1 && !const ['done', 'stopped', 'reqDone', 'wrongPerson'].contains(current)) {
      back();
      return true;
    }
    if (stack.length > 1) {
      home();
      return true;
    }
    return false;
  }

  /// Add the payee to "People you have paid before" (or update their usual amount), under the name the user gave.
  /// Not after a red check: a payee the user was warned about must stay "new" so the next payment is checked again.
  void _rememberPayee(Payee p, int amount) {
    if (p.id.isEmpty || f.collect || f.result?.level == 'red') return;
    if (!real && demoSaved.any((x) => x.id == p.id)) return;
    var list = myPayees;
    final ex = list.where((x) => x.id == p.id).firstOrNull;
    if (ex != null) {
      ex.count = ex.count + 1;
      ex.usual = ((ex.usual == 0 ? amount : ex.usual) * (ex.count - 1) + amount) ~/ ex.count;
      if (p.name.isNotEmpty && p.name != p.id) ex.name = p.name;
    } else {
      list.insert(0, Payee(id: p.id, name: p.name.isNotEmpty ? p.name : p.id, usual: amount, ico: p.mc.isNotEmpty ? 'shop' : 'person'));
    }
    if (list.length > 12) list = list.sublist(0, 12);
    if (real) {
      payees = list;
    } else {
      practicePayees = list;
    }
    _persist();
  }

  /// The user's answers plus what the app measures itself. Signals must be fresh (refreshSignals) before this runs.
  Assessment _assess() {
    final t0 = now();
    return assess(PayContext(
      isCollect: f.collect, thinksReceive: f.thinksReceive,
      calledFirst: f.ans['caller'] ?? false, urgency: f.ans['urgency'] ?? false,
      prizeRefund: f.ans['prize'] ?? false, remoteApp: f.ans['remote'] ?? false,
      nameMismatch: f.nameMismatch, newPayee: !f.payee!.saved,
      onCall: onCall, screenShared: captured, remoteInstalled: remoteApps.isNotEmpty,
      lookalike: f.lookalike.isNotEmpty, impersonation: f.official, qrReceive: f.qrReceive,
      amount: int.tryParse(f.amount) ?? 0, usual: f.payee!.usual, familyLimit: contact.limit,
      paidToday: log.paidSince(DateTime(t0.year, t0.month, t0.day), mode),
      recentPayments: log.paymentsSince(t0.subtract(const Duration(hours: 1)), mode),
    ));
  }

  Map<String, Object?> get _payInfo => {'payee': f.payee?.name ?? '', 'id': f.payee?.id ?? '', 'amt': int.tryParse(f.amount) ?? 0};

  Future<void> _runCheck() async {
    _applyPending();
    await refreshSignals();
    f.result = _assess();
    record('check', {..._payInfo, 'level': f.result!.level, 'reasons': f.result!.reasons});
  }

  /// After the safety check (and after talking to family), where "continue" leads.
  String get nextAfterCheck => f.collect && real ? 'reqDone' : 'confirm';

  /// "Continue" on the result or family screen. Going ahead after amber or red is written to the history.
  void proceed() {
    final lv = f.result?.level ?? 'green';
    if (lv != 'green') record('override', {..._payInfo, 'level': lv});
    go(nextAfterCheck);
  }

  /// "Pay" on the confirm screen. Check again at the last moment: a call may have started or a screen share begun
  /// since the safety check. If anything new turned up, show the result again instead of paying.
  Future<void> payNow() async {
    final before = f.result!;
    await refreshSignals();
    final again = _assess();
    final added = again.reasons.where((r) => !before.reasons.contains(r));
    if (added.isNotEmpty) {
      f.result = again;
      record('check', {..._payInfo, 'level': again.level, 'reasons': again.reasons, 'recheck': true});
      _reset(['home']);
      _flashNext(t('changedSinceCheck'));
      go('result');
      return;
    }
    if (real) {
      await payReal();
    } else {
      go('pin');
    }
  }

  // ---- actions ----
  void home() {
    _newFlow();
    _reset(['home']);
    _enter();
  }

  void back() {
    final popped = stack.length > 1 ? stack.removeLast() : '';
    if (popped == 'question' && current == 'question' && f.qi > 0) f.qi--;
    _enter();
  }

  void setLang(String v) {
    lang = v;
    _persist();
    render();
  }

  void toggleVoice() {
    voice = !voice;
    _persist();
    if (!voice) {
      Native.stopSpeaking();
    } else {
      speak(lastSay);
    }
    render();
  }

  void startSend() {
    _newFlow();
    go('payee');
  }

  void startRequest() {
    _newFlow();
    go('request');
  }

  Future<void> scan() async {
    if (!Native.available) {
      // No camera scanner off the phone; in practice mode pretend we scanned Raju's shop
      onQr(real ? '__unavailable__' : demoQr);
      return;
    }
    _handoff = true;
    onQr(await Native.scanQr(t('back'), t('scanQrSub')));
  }

  void story1() {
    _newFlow();
    f
      ..payee = demoSaved[0].asSaved()
      ..amount = '200';
    _reset(['home', 'payee']);
    go('amount');
  }

  void story2() {
    _newFlow();
    _reset(['home']);
    go('request');
  }

  void story3() => onQr(scamQr);

  void story4() => onQr(fakeQrSticker);

  void pickSaved(int i) {
    f.payee = savedList[i].asSaved();
    f.nameMismatch = false;
    go('amount');
  }

  void fillUpi(String v) {
    upiCtl.text = v;
    render();
  }

  void submitUpi() {
    final id = upiCtl.text.trim().toLowerCase();
    if (!isUpiId(id)) {
      _showFlash(t('upiInvalid'));
      return;
    }
    final saved = savedList.where((p) => p.id == id).firstOrNull;
    if (saved != null) {
      f.payee = saved.asSaved();
      f.nameMismatch = false;
      go('amount');
      return;
    }
    final guess = id.split('@')[0].split(RegExp(r'[._-]')).where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    final name = real ? '' : (demoDir[id] ?? guess);
    f.payee = Payee(id: id, name: name.isNotEmpty ? name : id);
    _checkIdentity();
    go('nameCheck');
  }

  /// Compare a new payee with the people already saved, and with the words scammers use to look official.
  void _checkIdentity() {
    final p = f.payee!;
    final known = savedList.map((x) => x.id);
    final like = lookalikeOf(p.id, known);
    f.lookalike = like == null ? '' : savedList.firstWhere((x) => x.id == like).name;
    f.official = looksOfficial(p.id, p.name);
  }

  /// "Is this who you want to pay?" Yes goes on to the amount. No stops the payment: paying a name you did not
  /// expect is exactly how wrong-ID and impostor payments happen.
  void nameOk(bool ok) {
    if (!ok) {
      record('stopped', {..._payInfo, 'level': '', 'why': 'wrongPerson'});
      _reset(['home']);
      go('wrongPerson');
      return;
    }
    final nick = nickCtl.text.trim();
    if (nick.isNotEmpty) f.payee!.name = nick;
    f.nameMismatch = false;
    go('amount');
  }

  /// From the "wrong person" screen: scan again if the ID came from a QR code, otherwise type it again.
  void retryPayee() {
    final fromQr = f.payee?.fromQr ?? false;
    final id = f.payee?.id ?? '';
    _newFlow();
    _reset(['home', 'payee']);
    if (fromQr) {
      _enter();
      scan();
    } else {
      upiCtl.text = id;
      go('newPayee');
    }
  }

  void quickAmt(int v) {
    f.amount = '$v';
    amtCtl.text = f.amount;
    render();
  }

  void onAmtTyped(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits != v) amtCtl.text = digits;
    f.amount = digits;
  }

  void submitAmt() {
    final n = int.tryParse(amtCtl.text) ?? 0;
    if (n <= 0) {
      _showFlash(t('amountZero'));
      return;
    }
    if (n > upiMax) {
      _showFlash(t('amountMax'));
      return;
    }
    f
      ..amount = '$n'
      ..qi = 0
      ..ans = {};
    go('question');
  }

  Future<void> answer(bool yes) async {
    f.ans[questions[f.qi]] = yes;
    if (f.qi < questions.length - 1) {
      f.qi++;
      go('question');
    } else {
      await _runCheck();
      go('result');
    }
  }

  void reqAnswer(bool receive) {
    if (real) {
      final who = reqWhoCtl.text.trim();
      final n = int.tryParse(reqAmtCtl.text) ?? 0;
      if (n <= 0) {
        _showFlash(t('amountZero'));
        return;
      }
      final known = who.isNotEmpty && savedList.any((p) => p.name.toLowerCase() == who.toLowerCase());
      f.payee = Payee(id: who.isNotEmpty ? who : '?', name: who.isNotEmpty ? who : '?', saved: known);
      f.amount = '$n';
      f.nameMismatch = false;
    } else {
      f.payee = Payee(id: scamReq.id, name: scamReq.name);
      f.amount = '${scamReq.amount}';
      f.nameMismatch = true;
      f.official = looksOfficial(scamReq.id, scamReq.shown);
    }
    f
      ..collect = true
      ..thinksReceive = receive
      ..qi = 0
      ..ans = {};
    go('question');
  }

  void stop() {
    if (f.payee != null) record('stopped', {..._payInfo, 'level': f.result?.level ?? ''});
    _reset(['home']);
    go('stopped');
  }

  void pinKey(int d) {
    f.pin += '$d';
    if (f.pin.length >= 4) {
      f
        ..pin = ''
        ..payStatus = 'success';
      record('paid', {..._payInfo, 'status': 'success'});
      _rememberPayee(f.payee!, int.tryParse(f.amount) ?? 0);
      _reset(['home']);
      go('done');
    } else {
      render();
    }
  }

  void pinDel() {
    if (f.pin.isNotEmpty) f.pin = f.pin.substring(0, f.pin.length - 1);
    render();
  }

  Future<void> payReal() async {
    final p = f.payee!;
    final uri = buildUpiUri(pa: p.id, pn: p.name, am: int.tryParse(f.amount) ?? 0, mc: p.mc, tn: p.tn.isNotEmpty ? p.tn : 'Easy Pay');
    _handoff = true;
    final resp = await Native.payUpi(uri, t('back'));
    if (resp == null) {
      _showFlash(t('noUpiApp'));
    } else {
      onUpi(resp);
    }
  }

  Future<void> copy(String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    copied = true;
    render();
  }

  Future<void> pasteMsg() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final s = d?.text ?? '';
    if (s.isNotEmpty) {
      msgCtl.text = s;
      f.msgResult = null;
      render();
    }
  }

  void checkMsg() {
    final s = msgCtl.text.trim();
    if (s.isEmpty) {
      f.msgResult = null;
      _showFlash(t('msgEmpty'));
      return;
    }
    f.msgResult = checkMessage(s);
    f.msgLinks = findLinks(s).take(5).map(checkLink).toList();
    // A fake bank or app link makes the whole message a scam, even without other scam words
    if (f.msgLinks.any((l) => l.level == 'red') && f.msgResult!.level != 'red') {
      f.msgResult = Assessment(f.msgResult!.score, 'red', f.msgResult!.reasons);
    }
    render();
  }

  // ---- phishing link check ----
  Future<void> pasteLink() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final v = d?.text ?? '';
    if (v.isNotEmpty) {
      linkCtl.text = v;
      f.linkResults = null;
      render();
    }
  }

  void fillLink(String v) {
    linkCtl.text = v;
    f.linkResults = null;
    render();
  }

  /// Check every link in what the user pasted (a bare link or a whole message). Nothing is opened.
  void checkLinks() {
    final v = linkCtl.text.trim();
    final found = findLinks(v);
    // A single word with a dot that the pattern did not catch (an unusual ending) is still checked as a link
    final links = found.isNotEmpty ? found : (RegExp(r'^\S+\.\S+$').hasMatch(v) ? [v] : <String>[]);
    if (links.isEmpty) {
      f.linkResults = null;
      _showFlash(v.isEmpty ? t('linkEmpty') : t('linkNone'));
      return;
    }
    f.linkResults = links.take(5).map(checkLink).toList();
    final worst = f.linkResults!.map((l) => l.level).fold('green', (a, b) => a == 'red' || b == 'red' ? 'red' : (a == 'amber' || b == 'amber' ? 'amber' : 'green'));
    record('linkCheck', {'level': worst, 'host': f.linkResults!.first.host});
    render();
  }

  /// Save the family helper. Changes that make the app stricter (a lower limit, a first number) start now.
  /// Changes that weaken it (a higher or no limit, a different number) wait out the cooling-off period.
  void saveFamily() {
    final name = fNameCtl.text.trim();
    final phone = fPhoneCtl.text.replaceAll(RegExp(r'\D'), '');
    final limit = int.tryParse(fLimitCtl.text.trim()) ?? 0;
    contact.name = name.isNotEmpty ? name : 'Family';
    final at = now().add(coolingOff(real)).millisecondsSinceEpoch;
    final weakerLimit = contact.limit > 0 && (limit == 0 || limit > contact.limit);
    final newPhone = contact.phone.isNotEmpty && phone != contact.phone;
    var p = pending;
    if (weakerLimit) {
      p = (p ?? Pending(at: at))..limit = limit;
      p.at = at;
      record('setting', {'what': 'limit', 'from': contact.limit, 'to': limit, 'state': 'scheduled', 'at': at});
    } else if (limit != contact.limit) {
      record('setting', {'what': 'limit', 'from': contact.limit, 'to': limit, 'state': 'applied'});
      contact.limit = limit;
      p?.limit = null; // a stricter limit also cancels a looser one that was waiting
    }
    if (newPhone) {
      p = (p ?? Pending(at: at))..phone = phone;
      p.at = at;
      record('setting', {'what': 'phone', 'from': maskPhone(contact.phone), 'to': maskPhone(phone), 'state': 'scheduled', 'at': at});
    } else if (contact.phone.isEmpty) {
      contact.phone = phone;
    }
    pending = (p == null || (p.limit == null && p.phone == null)) ? null : p;
    justScheduled = weakerLimit || newPhone;
    _persist();
    _watchPending();
    fLimitCtl.text = '${contact.limit}';
    fPhoneCtl.text = contact.phone;
    _showFlash(justScheduled ? t('pendingSaved', {'at': fmtTime(DateTime.fromMillisecondsSinceEpoch(pending!.at))}) : t('saved'));
  }

  void cancelPending() {
    if (pending == null) return;
    record('setting', {'what': pending!.limit != null ? 'limit' : 'phone', 'state': 'cancelled'});
    pending = null;
    justScheduled = false;
    _persist();
    _watchPending();
    render();
  }

  /// Start any waiting change whose cooling-off period is over.
  void _applyPending() {
    final p = pending;
    if (p == null || now().millisecondsSinceEpoch < p.at) {
      _watchPending();
      return;
    }
    if (p.limit != null) {
      record('setting', {'what': 'limit', 'from': contact.limit, 'to': p.limit, 'state': 'applied'});
      contact.limit = p.limit!;
    }
    if (p.phone != null) {
      record('setting', {'what': 'phone', 'from': maskPhone(contact.phone), 'to': maskPhone(p.phone!), 'state': 'applied'});
      contact.phone = p.phone!;
    }
    pending = null;
    justScheduled = false;
    _persist();
    _watchPending();
    if (current == 'family') {
      fLimitCtl.text = '${contact.limit}';
      fPhoneCtl.text = contact.phone;
    }
    render();
  }

  /// While a change waits, look every few seconds so it starts on time even if the app stays open.
  void _watchPending() {
    if (pending == null) {
      _pendingTimer?.cancel();
      _pendingTimer = null;
    } else {
      _pendingTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => _applyPending());
    }
  }

  /// Message for the family about a waiting change. Sent to the CURRENT number, so a scammer who typed in
  /// their own number cannot hide the change from the real family.
  String get pendingMsg {
    final p = pending!;
    final at = fmtTime(DateTime.fromMillisecondsSinceEpoch(p.at));
    final what = [
      if (p.limit != null) t('pendingLimit', {'amt': p.limit == 0 ? t('noLimit') : rupee(p.limit!), 'at': at}),
      if (p.phone != null) t('pendingPhone', {'phone': maskPhone(p.phone!), 'at': at}),
    ].join(' ');
    return t('pendingMsg', {'name': contact.name, 'what': what});
  }

  /// Practice only: change an old history entry without fixing its hash, to show that the history notices.
  void tamperPractice() {
    final l = logs['practice']!;
    final i = l.entries.lastIndexWhere((e) => e.kind == 'paid' || e.kind == 'check');
    if (real || i < 0) return;
    final e = l.entries[i];
    l.entries[i] = LogEntry(e.t, e.kind, {...e.data, 'amt': 1}, e.prev, e.hash);
    _persistLog();
    render();
  }

  void clearPractice() {
    if (real) return;
    logs['practice'] = AuditLog();
    _persistLog();
    render();
  }

  void setMode(String v) {
    if (v == mode) return;
    if (v == 'real') {
      go('realConfirm');
      return;
    }
    mode = 'practice';
    _persist();
    render();
  }

  void confirmReal() {
    mode = 'real';
    record('setting', {'what': 'mode', 'to': 'real', 'state': 'applied'});
    _persist();
    stack.removeLast();
    _enter();
  }

  void setSize(String v) {
    size = v;
    _persist();
    render();
  }

  void removePayee(int i) {
    myPayees.removeAt(i);
    _persist();
    render();
  }

  void open(String url) {
    _handoff = true;
    Native.openUrl(url);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pendingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_life);
    for (final c in [upiCtl, amtCtl, nickCtl, msgCtl, linkCtl, reqWhoCtl, reqAmtCtl, fNameCtl, fPhoneCtl, fLimitCtl]) {
      c.dispose();
    }
    super.dispose();
  }
}

class _Lifecycle with WidgetsBindingObserver {
  final AppState s;
  _Lifecycle(this.s);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => s.onLifecycle(state);
}

/// "10:30 AM, 14/10"
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}, ${d.day}/${d.month}';
}
