// Screens: each returns what it says aloud and the widgets to show.

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'engine.dart';
import 'motion.dart';
import 'ui.dart';

class Scr {
  final String say;
  final List<Widget> children;
  const Scr(this.say, this.children);
}

Scr buildScreen(Ui u) {
  switch (u.s.current) {
    case 'payee':
      return _payee(u);
    case 'newPayee':
      return _newPayee(u);
    case 'nameCheck':
      return _nameCheck(u);
    case 'amount':
      return _amount(u);
    case 'question':
      return _question(u);
    case 'result':
      return _result(u);
    case 'alert':
      return _alert(u);
    case 'confirm':
      return _confirm(u);
    case 'pin':
      return _pin(u);
    case 'done':
      return _done(u);
    case 'stopped':
      return _stopped(u);
    case 'request':
      return _request(u);
    case 'reqDone':
      return _reqDone(u);
    case 'message':
      return _message(u);
    case 'report':
      return _report(u);
    case 'family':
      return _family(u);
    case 'settings':
      return _settings(u);
    case 'realConfirm':
      return _realConfirm(u);
    case 'qrBlocked':
      return _qrBlocked(u);
    case 'history':
      return _history(u);
    case 'wrongPerson':
      return _wrongPerson(u);
    case 'link':
      return _link(u);
    default:
      return _home(u);
  }
}

Scr _home(Ui u) {
  final s = u.s, t = u.t;
  final apps = s.remoteApps.join(', ');
  return Scr(
      '${s.remoteApps.isNotEmpty ? '${t('remoteWarnTitle', {
              'apps': apps
            })}. ' : ''}${t('hello')}. ${t('scanQr')}. ${t('sendMoney')}. ${t('gotRequest')}. ${t('checkMsg')}. ${t('checkLink')}. ${t('report')}.',
      [
        if (s.remoteApps.isNotEmpty)
          u.verdict('red', t('remoteWarnTitle', {'apps': apps}), [Text(t('remoteWarnMsg'), style: u.bold)]),
        u.card([
          u.title(t('hello')),
          u.flash(),
          u.stack([
            u.btn(t('scanQr'), s.scan, kind: BtnKind.hero, icon: 'qr', sub: t('scanQrSub')),
            u.btn(t('sendMoney'), s.startSend, icon: 'send', sub: t('sendMoneySub')),
            u.btn(t('gotRequest'), s.startRequest, icon: 'inbox', sub: t('gotRequestSub')),
            u.btn(t('checkMsg'), () => s.go('message'), icon: 'msg', sub: t('checkMsgSub')),
            u.btn(t('checkLink'), () => s.go('link'), icon: 'link', sub: t('checkLinkSub')),
            u.btn(t('report'), () => s.go('report'), icon: 'shield', badIcon: true, sub: t('reportSub')),
            u.btn('${t('family')}: ${s.contact.name}', () => s.go('family'), icon: 'people', sub: t('familySub')),
            u.btn(t('history'), () => s.go('history'), icon: 'history', sub: t('historySub')),
            u.btn(t('settings'), () => s.go('settings'), icon: 'gear', sub: t('settingsSub')),
          ]),
          if (!s.real) ...[
            u.label(t('stories')),
            u.stack([
              u.btn(t('story1'), s.story1, icon: 'play', sub: t('story1Sub')),
              u.btn(t('story2'), s.story2, icon: 'play', badIcon: true, sub: t('story2Sub')),
              u.btn(t('story3'), s.story3, icon: 'play', badIcon: true, sub: t('story3Sub')),
              u.btn(t('story4'), s.story4, icon: 'play', badIcon: true, sub: t('story4Sub')),
            ]),
          ],
        ]),
      ]);
}

Scr _payee(Ui u) {
  final s = u.s, t = u.t, list = s.savedList;
  return Scr(t('whoPay'), [
    u.card([
      u.progress(1),
      u.title(t('whoPay')),
      u.btn(t('scanQr'), s.scan, kind: BtnKind.hero, icon: 'qr'),
      u.label(t('savedPeople')),
      u.stack([
        if (list.isEmpty) Text(t('noSaved'), style: u.mutedStyle),
        for (var i = 0; i < list.length; i++) u.btn(list[i].name, () => s.pickSaved(i), icon: list[i].ico, sub: list[i].id),
        u.btn(t('someoneNew'), () => s.go('newPayee'), icon: 'plus', sub: t('someoneNewSub')),
      ]),
      u.flash(),
    ]),
    u.nav(),
  ]);
}

Scr _newPayee(Ui u) {
  final s = u.s, t = u.t;
  const examples = ['sharma.tailor@okicici', 'lottery.kbc@paytm', 'raju.klrana@okaxis'];
  return Scr('${t('enterUpi')}. ${t('upiHint')}', [
    u.card([
      u.progress(1),
      u.title(t('enterUpi')),
      u.field(t('upiLabel'), s.upiCtl, keyboard: TextInputType.emailAddress, hint: 'name@bank'),
      Text('${t('upiHint')} ${s.real ? '' : t('upiHintPractice')}', style: u.mutedStyle),
      if (!s.real) u.tools([for (final e in examples) u.chip(e, () => s.fillUpi(e))]),
      u.flash(),
      u.btn('${t('next')} →', s.submitUpi, kind: BtnKind.primary),
    ]),
    u.nav(),
  ]);
}

Scr _nameCheck(Ui u) {
  final s = u.s, t = u.t, p = s.f.payee!;
  final known = p.name.isNotEmpty && p.name != p.id;
  final label = p.fromQr ? t('qrName') : t('bankName');
  // Early warnings from the identity checks; the safety check counts them again
  final warns = [
    if (s.f.qrReceive) t('qrReceiveWarn'),
    if (s.f.lookalike.isNotEmpty) t('lookalikeWarn', {'known': s.f.lookalike}),
    if (s.f.official) t('officialWarn'),
  ];
  return Scr(
      '${warns.isNotEmpty ? '${warns.join(' ')} ' : ''}${t('nameCheck')}. ${known ? '$label ${p.name}' : t('noNameYet')}${s.real ? '. ${t('realNameNote')}' : ''}',
      [
        u.card([
          u.progress(1),
          if (warns.isNotEmpty) u.verdict('red', t('careful'), [u.bullets(warns)]),
          u.title(t('nameCheck')),
          if (known) ...[
            Text('$label:', style: u.mutedStyle),
            Text(p.name, style: TextStyle(fontSize: u.rem(1.8), height: 1.2, fontWeight: FontWeight.w700, color: u.p.ink)),
          ] else
            Text(t('noNameYet'), style: u.mutedStyle),
          Text(p.id, style: u.mutedStyle),
          if (s.real) u.box(Text(t('realNameNote'), style: u.body)),
          // Any name typed here is how they appear under "People you have paid before" next time
          u.field(t('nickLabel'), s.nickCtl, hint: known ? p.name : ''),
          u.stack([
            u.btn(t('yesRight'), () => s.nameOk(true), kind: BtnKind.primary),
            u.btn(t('noWrong'), () => s.nameOk(false), kind: BtnKind.center),
          ]),
        ]),
        u.nav(),
      ]);
}

Scr _amount(Ui u) {
  final s = u.s, t = u.t, name = s.f.payee!.name;
  return Scr('${t('howMuch')} ${t('to')} $name', [
    u.card([
      u.progress(2),
      u.title(t('howMuch'), [u.micBtn('amount')]),
      Text.rich(TextSpan(children: [
        TextSpan(text: '${t('to')}: ', style: u.mutedStyle),
        TextSpan(text: name, style: u.body.copyWith(fontWeight: FontWeight.w700)),
      ])),
      Semantics(
        label: 'Amount in rupees',
        child: u.field('', s.amtCtl,
            keyboard: TextInputType.number, hint: '₹ 0', amount: true, maxLength: 6, onChanged: s.onAmtTyped),
      ),
      ValueListenableBuilder(
        valueListenable: s.amtCtl,
        builder: (_, v, __) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: c)),
          child: Text(s.wordsFor(v.text),
              key: ValueKey(v.text), textAlign: TextAlign.center, style: u.bold.copyWith(color: u.p.muted)),
        ),
      ),
      Row(children: [
        for (final (i, v) in const [100, 200, 500, 1000].indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: u.chip('₹$v', () => s.quickAmt(v), minHeight: 52)),
        ],
      ]),
      u.flash(),
      u.btn('${t('next')} →', s.submitAmt, kind: BtnKind.primary),
    ]),
    u.nav(),
  ]);
}

Scr _question(Ui u) {
  final s = u.s, t = u.t, i = s.f.qi, key = questions[i];
  return Scr('${t('qTitle')}. ${t('q_$key')}', [
    u.card([
      u.progress(3),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          u.label('${t('qTitle')} · ${i + 1} / ${questions.length}'),
          u.tools([u.micBtn('yesno'), u.listenBtn()])
        ],
      ),
      if (i == 0) Text(t('qIntro'), style: u.mutedStyle),
      Text(t('q_$key'), style: u.h2),
      Row(children: [
        Expanded(child: _yesNo(u, t('yes'), () => s.answer(true))),
        const SizedBox(width: 12),
        Expanded(child: _yesNo(u, t('no'), () => s.answer(false))),
      ]),
      u.flash(),
    ]),
    u.nav(),
  ]);
}

Widget _yesNo(Ui u, String label, VoidCallback onTap) => Material(
      color: u.p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: u.p.line, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 80,
          child: Center(child: Text(label, style: TextStyle(fontSize: u.rem(1.3), fontWeight: FontWeight.w700, color: u.p.ink))),
        ),
      ),
    );

Scr _result(Ui u) {
  final s = u.s, t = u.t, f = s.f, r = f.result!, lv = r.level;
  final day = s.now();
  final vars = {
    'name': f.payee!.name,
    'limit': rupee(s.contact.limit),
    'known': f.lookalike,
    'apps': s.remoteApps.join(', '),
    'today': rupee(s.log.paidSince(DateTime(day.year, day.month, day.day), s.mode)),
    'n': s.log.paymentsSince(day.subtract(const Duration(hours: 1)), s.mode) + 1,
  };
  final reasons = r.reasons.take(3).map((id) => t('r_$id', vars)).toList();
  final fam = t('askFamily', {'name': s.contact.name});
  final List<Widget> actions;
  if (lv == 'green') {
    actions = [
      u.btn('${t('continuePay')} →', s.proceed, kind: BtnKind.primary),
      u.btn(t('cancel'), s.stop, kind: BtnKind.center),
    ];
  } else if (lv == 'amber') {
    actions = [
      u.btn(fam, () => s.go('alert'), kind: BtnKind.primary),
      u.btn(t('continuePay'), s.proceed, kind: BtnKind.center),
      u.btn(t('cancel'), s.stop, kind: BtnKind.center),
    ];
  } else {
    final locked = s.waitLeft > 0;
    actions = [
      u.btn(t('cancel'), s.stop, kind: BtnKind.danger),
      u.btn(fam, () => s.go('alert'), kind: BtnKind.center),
      u.btn(t('reportBtn'), () => s.go('report'), kind: BtnKind.center),
      u.btn(locked ? t('waitSec', {'s': s.waitLeft}) : t('payAnyway'), locked ? null : () => s.go('alert'),
          kind: BtnKind.center, leading: locked ? CountdownRing(left: s.waitLeft, total: 30, color: u.p.bad) : null),
    ];
  }
  return Scr('${t('lv_$lv')}. ${reasons.isNotEmpty ? reasons.join(' ') : t('greenMsg')}', [
    u.card([
      u.progress(3),
      u.flash(),
      u.verdict(lv, t('lv_$lv'), [
        reasons.isNotEmpty ? u.bullets(reasons) : Text(t('greenMsg'), style: u.bold),
        Align(alignment: Alignment.centerLeft, child: u.listenBtn()),
      ]),
      u.summary([(t('to'), f.payee!.name), (t('amountLabel'), rupee(int.parse(f.amount)))]),
      u.stack(actions),
    ]),
  ]);
}

Scr _alert(Ui u) {
  final s = u.s, t = u.t, f = s.f, c = s.contact;
  final msg = t('alertMsg',
      {'name': c.name, 'amt': rupee(int.parse(f.amount)), 'payee': f.payee!.name, 'level': t('lv_${f.result!.level}')});
  final wa = 'https://wa.me/91${s.phoneDigits}?text=${Uri.encodeComponent(msg)}';
  return Scr('${t('alertTitle', {'name': c.name})}. ${t('alertIntro', {'name': c.name})}', [
    u.card([
      u.title(t('alertTitle', {'name': c.name})),
      Text(t('alertIntro', {'name': c.name}), style: u.body),
      u.box(SelectableText(msg, style: u.body)),
      u.stack([
        u.btn('📞 ${t('callName', {'name': c.name})}', () => s.open('tel:${s.phoneDigits}'), kind: BtnKind.primary),
        u.btn(t('whatsapp'), () => s.open(wa), kind: BtnKind.center),
        u.btn(s.copied ? '✓ ${t('copied')}' : t('copyMsg'), () => s.copy(msg), kind: BtnKind.center),
        Text(t('whatsappNote'), style: u.mutedStyle),
        u.btn(t('talkedStop'), s.stop, kind: BtnKind.danger),
        u.btn(t('talkedOk'), s.proceed, kind: BtnKind.center),
      ]),
    ]),
    u.nav(),
  ]);
}

Scr _confirm(Ui u) {
  final s = u.s, t = u.t, f = s.f, amt = int.parse(f.amount);
  final w = s.lang == 'en' ? '${toWordsIN(amt)} rupees' : '${rupee(amt)} ${t('rupees')}';
  return Scr('${t('confirmTitle')}. ${t('youSend')} $w ${t('to')} ${f.payee!.name}${s.real ? '. ${t('payInAppNote')}' : ''}', [
    u.card([
      u.progress(4),
      u.title(t('confirmTitle')),
      Text(t('youSend'), style: u.mutedStyle),
      PopIn(child: u.bigAmt(rupee(amt))),
      Text(w, textAlign: TextAlign.center, style: u.bold.copyWith(color: u.p.muted)),
      u.summary([(t('to'), f.payee!.name), (t('upiLabel'), f.payee!.id)]),
      u.flash(),
      if (s.real) ...[
        u.box(Text(t('payInAppNote'), style: u.body)),
        u.btn('${t('payInApp')} →', s.payNow, kind: BtnKind.primary),
      ] else
        u.btn('${t('pay')} →', s.payNow, kind: BtnKind.primary),
      u.btn(t('cancel'), s.stop, kind: BtnKind.center),
    ]),
    u.nav(),
  ]);
}

Scr _pin(Ui u) {
  final s = u.s, t = u.t, n = s.f.pin.length, p = u.p;
  Widget key(String label, VoidCallback onTap, {double? size}) => Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 68,
            child: Center(
                child: Text(label, style: TextStyle(fontSize: size ?? u.rem(1.5), fontWeight: FontWeight.w700, color: p.ink))),
          ),
        ),
      );
  Widget row(List<Widget> keys) => Row(children: [
        for (final (i, k) in keys.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: k)],
      ]);
  return Scr('${t('pinPractice')} ${t('enterPin')}. ${t('pinNote')}', [
    u.card([
      u.progress(4),
      u.box(Text(t('pinPractice'), style: u.bold.copyWith(color: p.warn)), bg: p.warnBg),
      u.title(t('enterPin')),
      Text(t('pinNote'), style: u.mutedStyle),
      Semantics(
        label: '$n of 4',
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 22,
              height: 22,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: i < n ? p.ink : null, border: Border.all(color: p.ink, width: 3)),
            ),
        ]),
      ),
      Column(children: [
        for (final r in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ]) ...[
          row([for (final d in r) key('$d', () => s.pinKey(d))]),
          const SizedBox(height: 10),
        ],
        row([key(t('del'), s.pinDel, size: u.rem(1)), key('0', () => s.pinKey(0)), const SizedBox()]),
      ]),
    ]),
    u.nav(),
  ]);
}

Widget _bigIcon(String name, Color c) => PopIn(
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.12)),
        child: Icon(icons[name], size: 72, color: c),
      ),
    );

Scr _done(Ui u) {
  final s = u.s, t = u.t, f = s.f, p = u.p, name = f.payee!.name;
  final (ico, col, h, m) = switch (f.payStatus) {
    'failure' => ('stop', p.bad, t('res_failure'), t('res_failureMsg', {'name': s.contact.name})),
    'pending' => ('clock', p.warn, t('res_pending'), t('res_pendingMsg')),
    'unknown' => ('warn', p.warn, t('res_unknown'), t('res_unknownMsg')),
    _ => ('ok', p.good, t('paid'), t('paidMsg', {'amt': rupee(int.parse(f.amount)), 'name': name})),
  };
  return Scr('$h. $m', [
    u.card(centered: true, [
      _bigIcon(ico, col),
      Text(h, textAlign: TextAlign.center, style: u.h2.copyWith(color: col)),
      Text(m, textAlign: TextAlign.center, style: u.bold),
      if (f.txnId.isNotEmpty)
        SelectableText.rich(
            TextSpan(children: [
              TextSpan(text: '${t('txnId')}: ', style: u.mutedStyle),
              TextSpan(text: f.txnId, style: u.mutedStyle.copyWith(fontWeight: FontWeight.w700)),
            ]),
            textAlign: TextAlign.center),
      if (!s.real) Text(t('practiceNote'), textAlign: TextAlign.center, style: u.mutedStyle),
      SizedBox(width: double.infinity, child: u.btn(t('doneHome'), s.home, kind: BtnKind.primary)),
    ]),
  ]);
}

Scr _wrongPerson(Ui u) {
  final s = u.s, t = u.t, p = s.f.payee;
  return Scr('${t('wrongTitle')} ${t('wrongMsg')}', [
    u.card(centered: true, [
      _bigIcon('shield', u.p.good),
      Text(t('wrongTitle'), textAlign: TextAlign.center, style: u.h2.copyWith(color: u.p.good)),
      if (p != null) Text(p.id, textAlign: TextAlign.center, style: u.mutedStyle),
      Text(t('wrongMsg'), textAlign: TextAlign.center, style: u.body),
      SizedBox(
          width: double.infinity,
          child: u.btn((p?.fromQr ?? false) ? t('scanAgain') : t('tryAgainId'), s.retryPayee, kind: BtnKind.center)),
      SizedBox(width: double.infinity, child: u.btn(t('doneHome'), s.home, kind: BtnKind.primary)),
    ]),
  ]);
}

/// One checked link: the website it really opens, what is wrong with it, and what to do.
Widget _linkVerdict(Ui u, LinkCheck l) {
  final t = u.t;
  final reasons = [for (final r in l.reasons) t('l_$r', {'brand': l.brand, 'tld': '.${l.tld}'})];
  return u.verdict(l.level, t('lk_${l.level}'), [
    u.box(Text(l.host, style: u.bold)),
    if (l.official.isNotEmpty) Text(t('lk_official', {'name': l.official}), style: u.bold),
    if (reasons.isNotEmpty) ...[u.bullets(reasons), Text(t('lk_advice'), style: u.body)] else
      Text(t('lk_greenMsg'), style: u.body),
  ]);
}

String _linkSay(Ui u, LinkCheck l) {
  final t = u.t;
  final reasons = [for (final r in l.reasons) t('l_$r', {'brand': l.brand, 'tld': '.${l.tld}'})];
  return '${t('lk_${l.level}')}. ${l.host}. ${l.official.isNotEmpty ? '${t('lk_official', {'name': l.official})} ' : ''}'
      '${reasons.isNotEmpty ? '${reasons.join(' ')} ${t('lk_advice')}' : t('lk_greenMsg')}';
}

Scr _link(Ui u) {
  final s = u.s, t = u.t, r = s.f.linkResults;
  const examples = ['http://sbi-kyc-update.in/verify', 'https://bit.ly/3kYcUpd', 'https://www.onlinesbi.sbi'];
  final say = r != null ? r.map((l) => _linkSay(u, l)).join(' ') : '${t('linkTitle')}. ${t('linkIntro')}';
  return Scr(say, [
    u.card([
      u.title(t('linkTitle')),
      Text(t('linkIntro'), style: u.mutedStyle),
      u.btn('📋 ${t('linkPaste')}', s.pasteLink, kind: BtnKind.center),
      u.field('', s.linkCtl, keyboard: TextInputType.url, hint: t('linkPlaceholder'), maxLines: 4),
      if (!s.real) u.tools([for (final e in examples) u.chip(e, () => s.fillLink(e))]),
      u.flash(),
      u.btn(t('linkCheck'), s.checkLinks, kind: BtnKind.primary),
      if (r != null) ...[
        for (final l in r) _linkVerdict(u, l),
        Align(alignment: Alignment.centerLeft, child: u.listenBtn()),
        if (r.any((l) => l.level == 'red')) u.btn(t('reportBtn'), () => s.go('report'), kind: BtnKind.danger),
      ],
    ]),
    u.nav(showBack: false),
  ]);
}

Scr _stopped(Ui u) {
  final s = u.s, t = u.t;
  return Scr('${t('stopped')} ${t('stoppedMsg')}', [
    u.card(centered: true, [
      _bigIcon('shield', u.p.good),
      Text(t('stopped'), textAlign: TextAlign.center, style: u.h2.copyWith(color: u.p.good)),
      Text(t('stoppedMsg'), textAlign: TextAlign.center, style: u.body),
      SizedBox(width: double.infinity, child: u.btn(t('reportBtn'), () => s.go('report'), kind: BtnKind.danger)),
      SizedBox(width: double.infinity, child: u.btn(t('doneHome'), s.home, kind: BtnKind.primary)),
    ]),
  ]);
}

Scr _request(Ui u) {
  final s = u.s, t = u.t;
  final answers = u.stack([
    u.btn(t('reqReceive'), () => s.reqAnswer(true), kind: BtnKind.center),
    u.btn(t('reqPay'), () => s.reqAnswer(false), kind: BtnKind.center),
  ]);
  final question = Text(t('reqQ'), style: u.h2.copyWith(fontSize: u.rem(1.3)));
  if (s.real) {
    return Scr('${t('reqTitle')}. ${t('reqWho')}', [
      u.card([
        u.progress(2),
        u.title(t('reqTitle')),
        u.field(t('reqWho'), s.reqWhoCtl),
        u.field(t('reqAmt'), s.reqAmtCtl, keyboard: TextInputType.number, amount: true, maxLength: 6, onChanged: (v) {
          final d = v.replaceAll(RegExp(r'\D'), '');
          if (d != v) s.reqAmtCtl.text = d;
        }),
        u.flash(),
        question,
        answers,
      ]),
      u.nav(),
    ]);
  }
  return Scr('${t('reqTitle')}. ${t('reqFrom', {'name': scamReq.shown})} ${rupee(scamReq.amount)}. ${t('reqQ')}', [
    u.card([
      u.progress(2),
      u.title(t('reqTitle')),
      u.box(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('reqFrom', {'name': scamReq.shown}), style: u.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          u.bigAmt(rupee(scamReq.amount)),
          const SizedBox(height: 8),
          Text(scamReq.id, style: u.mutedStyle),
          const SizedBox(height: 8),
          Text('${t('reqNoteLabel')}:', style: u.mutedStyle),
          const SizedBox(height: 8),
          Text('“${scamReq.note}”', style: u.body.copyWith(fontStyle: FontStyle.italic)),
        ]),
      ),
      question,
      answers,
    ]),
    u.nav(),
  ]);
}

Scr _reqDone(Ui u) {
  final s = u.s, t = u.t, f = s.f;
  return Scr(t('reqSafe'), [
    u.card(centered: true, [
      _bigIcon('warn', u.p.warn),
      Text(t('reqSafe'), textAlign: TextAlign.center, style: u.bold),
      u.summary([(t('to'), f.payee!.name), (t('amountLabel'), rupee(int.parse(f.amount)))]),
      SizedBox(width: double.infinity, child: u.btn(t('doneHome'), s.home, kind: BtnKind.primary)),
    ]),
  ]);
}

Scr _message(Ui u) {
  final s = u.s, t = u.t, r = s.f.msgResult;
  final reasons = r == null ? <String>[] : r.reasons.take(4).map((id) => t('s_$id')).toList();
  final say = r != null
      ? '${t('m_${r.level}')}. ${reasons.isNotEmpty ? '${reasons.join(' ')} ${t('m_advice')}' : t('m_greenMsg')}'
          '${s.f.msgLinks.isNotEmpty ? ' ${t('msgLinks')}. ${s.f.msgLinks.map((l) => _linkSay(u, l)).join(' ')}' : ''}'
      : '${t('msgTitle')}. ${t('msgIntro')}';
  return Scr(say, [
    u.card([
      u.title(t('msgTitle')),
      Text(t('msgIntro'), style: u.mutedStyle),
      u.btn('📋 ${t('msgPaste')}', s.pasteMsg, kind: BtnKind.center),
      u.field('', s.msgCtl, keyboard: TextInputType.multiline, hint: t('msgPlaceholder'), maxLines: 12),
      u.flash(),
      u.btn(t('msgCheck'), s.checkMsg, kind: BtnKind.primary),
      if (r != null) ...[
        u.verdict(r.level, t('m_${r.level}'), [
          if (reasons.isNotEmpty) ...[u.bullets(reasons), Text(t('m_advice'), style: u.body)] else
            Text(t('m_greenMsg'), style: u.bold),
          Align(alignment: Alignment.centerLeft, child: u.listenBtn()),
        ]),
        if (s.f.msgLinks.isNotEmpty) ...[
          u.label(t('msgLinks')),
          for (final l in s.f.msgLinks) _linkVerdict(u, l),
        ],
        if (r.level == 'red') u.btn(t('reportBtn'), () => s.go('report'), kind: BtnKind.danger),
      ],
    ]),
    u.nav(showBack: false),
  ]);
}

Scr _report(Ui u) {
  final s = u.s, t = u.t, p = u.p;
  const links = {
    'rp3': ('cybercrime.gov.in', 'https://cybercrime.gov.in'),
    'rp4': ('Sanchar Saathi (Chakshu)', 'https://sancharsaathi.gov.in/sfc/'),
  };
  final keys = ['rp1', 'rp2', 'rp3', 'rp4', 'rp5'];
  final plain = keys.map((k) => links[k] == null ? t(k) : t(k).replaceAll('{link}', links[k]!.$1)).toList();
  Widget item(String k) {
    final link = links[k];
    if (link == null) return Text(t(k), style: u.body);
    final parts = t(k).split('{link}');
    return Text.rich(TextSpan(style: u.body, children: [
      TextSpan(text: parts.first),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Semantics(
          link: true,
          child: GestureDetector(
            onTap: () => s.open(link.$2),
            child: Text(link.$1,
                style: u.body.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: p.accent)),
          ),
        ),
      ),
      if (parts.length > 1) TextSpan(text: parts.sublist(1).join()),
    ]));
  }

  return Scr('${t('reportTitle')}. ${t('reportIntro')} ${plain.join('. ')}', [
    u.card([
      u.title(t('reportTitle')),
      Text('1930',
          style: TextStyle(
              fontSize: u.rem(3), height: 1, fontWeight: FontWeight.w700, color: p.bad, letterSpacing: u.rem(3) * 0.04)),
      u.btn('📞 ${t('call1930')}', () => s.open('tel:1930'), kind: BtnKind.danger),
      Text(t('reportIntro'), style: u.bold),
      u.bullets(const [], numbered: true, custom: keys.map(item).toList()),
      if (s.phoneDigits.isNotEmpty)
        u.btn('📞 ${t('callName', {'name': s.contact.name})}', () => s.open('tel:${s.phoneDigits}'), kind: BtnKind.center),
      u.btn(t('historyForPolice'), () => s.go('history'), kind: BtnKind.center),
    ]),
    u.nav(),
  ]);
}

Scr _family(Ui u) {
  final s = u.s, t = u.t, c = s.contact;
  return Scr('${t('familyTitle')}. ${t('familyIntro')}', [
    u.card([
      u.title(t('familyTitle')),
      Text(t('familyIntro'), style: u.mutedStyle),
      u.field(t('fName'), s.fNameCtl),
      u.field(t('fPhone'), s.fPhoneCtl, keyboard: TextInputType.phone),
      u.field(t('fLimit'), s.fLimitCtl, keyboard: TextInputType.number),
      Text(t('coolingNote', {'wait': s.real ? t('wait24h') : t('wait2m')}), style: u.mutedStyle),
      u.flash(ok: true),
      u.btn(t('save'), s.saveFamily, kind: BtnKind.primary),
      if (s.pending != null) _pendingCard(u),
      if (s.phoneDigits.isNotEmpty)
        u.btn('📞 ${t('callName', {'name': c.name})}', () => s.open('tel:${s.phoneDigits}'), kind: BtnKind.center),
    ]),
    u.nav(),
  ]);
}

Widget _pendingCard(Ui u) {
  final s = u.s, t = u.t, p = s.pending!;
  final at = fmtTime(DateTime.fromMillisecondsSinceEpoch(p.at));
  final wa = 'https://wa.me/91${s.phoneDigits}?text=${Uri.encodeComponent(s.pendingMsg)}';
  return u.verdict('amber', t('pendingTitle'), [
    if (p.limit != null) Text(t('pendingLimit', {'amt': p.limit == 0 ? t('noLimit') : rupee(p.limit!), 'at': at}), style: u.bold),
    if (p.phone != null) Text(t('pendingPhone', {'phone': maskPhone(p.phone!), 'at': at}), style: u.bold),
    Text(t('pendingWhy'), style: u.body),
    u.btn(t('pendingTell', {'name': s.contact.name}), () => s.open(wa), kind: BtnKind.primary),
    u.btn(t('pendingCancel'), s.cancelPending, kind: BtnKind.center),
  ]);
}

Scr _qrBlocked(Ui u) {
  final s = u.s, t = u.t, b = s.f.blockedQr!;
  final web = b.kind == 'web';
  // What else is wrong with the website, from the same check as "Check a link"
  final lc = web && b.url.isNotEmpty ? checkLink(b.url) : null;
  final head = web ? t('qrWebTitle') : t('qrMandateTitle');
  final msg = web ? t('qrWebMsg', {'host': b.host}) : t('qrMandateMsg');
  return Scr('$head. $msg', [
    u.card([
      u.verdict('red', head, [
        if (web) u.box(Text(b.host, style: u.bold.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
        Text(msg, style: u.bold),
        if (lc != null && lc.reasons.isNotEmpty)
          u.bullets([for (final r in lc.reasons) t('l_$r', {'brand': lc.brand, 'tld': '.${lc.tld}'})]),
        Align(alignment: Alignment.centerLeft, child: u.listenBtn()),
      ]),
      u.btn(t('reportBtn'), () => s.go('report'), kind: BtnKind.danger),
      u.btn(t('doneHome'), s.home, kind: BtnKind.primary),
    ]),
  ]);
}

Scr _history(Ui u) {
  final s = u.s, t = u.t, p = u.p, log = s.log;
  final broken = log.firstBroken();
  final items = log.entries.reversed.take(60).toList();
  final brokenAt = broken < 0 ? null : log.entries[broken];
  final head = broken < 0 ? t('historyIntact') : t('historyBroken');
  Widget row(e) {
    final d = e.data as Map<String, Object?>;
    final lv = '${d['level'] ?? ''}';
    final (ico, col) = switch (e.kind as String) {
      'check' => (
          lv == 'green'
              ? 'ok'
              : lv == 'amber'
                  ? 'warn'
                  : 'stop',
          p.level(lv.isEmpty ? 'green' : lv)
        ),
      'override' => ('warn', p.bad),
      'stopped' => ('shield', p.good),
      'paid' => ('send', d['status'] == 'failure' ? p.bad : p.ink),
      'qrBlocked' => ('stop', p.bad),
      'linkCheck' => ('link', p.level(lv.isEmpty ? 'green' : lv)),
      'setting' => ('gear', p.warn),
      _ => ('clock', p.muted),
    };
    final amt = (d['amt'] as num?)?.toInt() ?? 0;
    final title = switch (e.kind as String) {
      'check' => '${t('h_check')}: ${t('lv_$lv')}${d['recheck'] == true ? ' (${t('h_recheck')})' : ''}',
      'linkCheck' => '${t('h_linkCheck')}: ${t('lv_$lv')}',
      'stopped' when d['why'] == 'wrongPerson' => t('h_wrongPerson'),
      'setting' => t('h_setting_${d['state']}', {'what': t('h_what_${d['what']}')}),
      _ => t('h_${e.kind}'),
    };
    final detail = switch (e.kind as String) {
      'setting' => d['what'] == 'limit'
          ? '${d['from'] != null ? '${rupee(d['from'] as num)} → ' : ''}${d['to'] == null ? '' : (d['to'] == 0 ? t('noLimit') : rupee(d['to'] as num))}'
          : d['what'] == 'phone'
              ? '${d['from'] ?? ''} → ${d['to'] ?? ''}'
              : '',
      'qrBlocked' || 'linkCheck' => '${d['host'] ?? ''}',
      'expired' => '',
      _ => '${d['payee'] ?? ''}${amt > 0 ? ' · ${rupee(amt)}' : ''}',
    };
    final isBroken = brokenAt != null && identical(e, brokenAt);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBroken ? p.badBg : p.surface,
        border: Border.all(color: isBroken ? p.bad : p.line, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icons[ico], color: col, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: u.bold),
            if (detail.isNotEmpty) Text(detail, style: u.body),
            Text(fmtTime(e.time), style: u.mutedStyle),
          ]),
        ),
      ]),
    );
  }

  return Scr('${t('historyTitle')}. $head', [
    u.card([
      u.title(t('historyTitle')),
      u.verdict(
          broken < 0 ? 'green' : 'red', head, [Text(broken < 0 ? t('historyIntactMsg') : t('historyBrokenMsg'), style: u.body)]),
      Text(t('historyNote'), style: u.mutedStyle),
      if (items.isEmpty) Text(t('historyEmpty'), style: u.mutedStyle),
      u.stack([for (final e in items) row(e)], 10),
      if (!s.real && items.isNotEmpty) ...[
        u.label(t('practiceOnly')),
        u.btn(t('historyTamper'), s.tamperPractice, kind: BtnKind.center),
        u.btn(t('historyClear'), s.clearPractice, kind: BtnKind.center),
      ],
    ]),
    u.nav(),
  ]);
}

Scr _settings(Ui u) {
  final s = u.s, t = u.t;
  return Scr(t('setTitle'), [
    u.card([
      u.title(t('setTitle')),
      u.label(t('setMode')),
      u.stack([
        u.radio(t('modePractice'), !s.real, () => s.setMode('practice')),
        u.radio(t('modeReal'), s.real, () => s.setMode('real')),
      ], 10),
      u.label(t('setText')),
      u.stack([
        u.radio(t('textNormal'), s.size != 'big', () => s.setSize('normal')),
        u.radio(t('textBig'), s.size == 'big', () => s.setSize('big')),
      ], 10),
      if (s.myPayees.isNotEmpty) ...[
        u.label(t('setPayees')),
        u.stack([
          for (var i = 0; i < s.myPayees.length; i++)
            Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${s.myPayees[i].name}\n', style: u.bold),
                  TextSpan(text: s.myPayees[i].id, style: u.mutedStyle),
                ])),
              ),
              const SizedBox(width: 10),
              u.chip(t('remove'), () => s.removePayee(i)),
            ]),
        ]),
      ],
      u.label(t('privTitle')),
      u.bullets([t('priv1'), t('priv2'), t('priv3'), t('priv4'), allowMirror ? t('screenProtOff') : t('screenProtOn')]),
      u.btn(t('history'), () => s.go('history'), icon: 'history', sub: t('historySub')),
      Text(t('setAbout'), style: u.mutedStyle),
    ]),
    u.nav(),
  ]);
}

Scr _realConfirm(Ui u) {
  final s = u.s, t = u.t;
  return Scr(t('realWarn'), [
    u.card([
      u.verdict('amber', t('modeReal'), [Text(t('realWarn'), style: u.bold)]),
      u.btn(t('turnOn'), s.confirmReal, kind: BtnKind.primary),
      u.btn(t('keepPractice'), s.back, kind: BtnKind.center),
    ]),
  ]);
}
