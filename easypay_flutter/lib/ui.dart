// Layout: one phone-width column, one question per screen, safety colours carry meaning.
// Shared colours and building blocks (cards, big buttons, chips, verdict boxes).

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'motion.dart';

class Pal {
  final Color bg, surface, ink, muted, line, accent, accentInk, accentSoft, good, goodBg, warn, warnBg, bad, badBg;
  const Pal(
      {required this.bg,
      required this.surface,
      required this.ink,
      required this.muted,
      required this.line,
      required this.accent,
      required this.accentInk,
      required this.accentSoft,
      required this.good,
      required this.goodBg,
      required this.warn,
      required this.warnBg,
      required this.bad,
      required this.badBg});

  static const light = Pal(
      bg: Color(0xFFE9EFF2),
      surface: Color(0xFFFFFFFF),
      ink: Color(0xFF13243A),
      muted: Color(0xFF46586B),
      line: Color(0xFFC4D0DA),
      accent: Color(0xFF0B5E6B),
      accentInk: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFD7ECEE),
      good: Color(0xFF1A6E39),
      goodBg: Color(0xFFE0F2E6),
      warn: Color(0xFF7A4F00),
      warnBg: Color(0xFFFFF0CC),
      bad: Color(0xFFA8231B),
      badBg: Color(0xFFFBE2DF));

  static const dark = Pal(
      bg: Color(0xFF0E161E),
      surface: Color(0xFF16222D),
      ink: Color(0xFFE7EEF3),
      muted: Color(0xFFA7B6C3),
      line: Color(0xFF2D3D4C),
      accent: Color(0xFF5BBAC5),
      accentInk: Color(0xFF062228),
      accentSoft: Color(0xFF163A40),
      good: Color(0xFF73D49C),
      goodBg: Color(0xFF123020),
      warn: Color(0xFFF2C35B),
      warnBg: Color(0xFF33270C),
      bad: Color(0xFFFF8F85),
      badBg: Color(0xFF3B1714));

  Color level(String lv) => lv == 'green'
      ? good
      : lv == 'amber'
          ? warn
          : bad;
  Color levelBg(String lv) => lv == 'green'
      ? goodBg
      : lv == 'amber'
          ? warnBg
          : badBg;
}

const icons = <String, IconData>{
  'qr': Icons.qr_code_scanner,
  'send': Icons.arrow_forward,
  'inbox': Icons.move_to_inbox,
  'msg': Icons.sms_failed_outlined,
  'shield': Icons.shield_outlined,
  'people': Icons.people_outline,
  'gear': Icons.settings_outlined,
  'shop': Icons.storefront_outlined,
  'person': Icons.person_outline,
  'bolt': Icons.bolt_outlined,
  'plus': Icons.add,
  'play': Icons.play_arrow_outlined,
  'ok': Icons.check_circle_outline,
  'warn': Icons.warning_amber_rounded,
  'stop': Icons.dangerous_outlined,
  'clock': Icons.schedule,
  'history': Icons.receipt_long_outlined,
  'link': Icons.link,
};

IconData levelIcon(String lv) => icons[lv == 'green'
    ? 'ok'
    : lv == 'amber'
        ? 'warn'
        : 'stop']!;

enum BtnKind { plain, primary, danger, center, hero }

/// Everything a screen needs to draw itself: state, colours and the base font size.
class Ui {
  final AppState s;
  final Pal p;
  final double base; // 1rem in the original CSS

  Ui(this.s, this.p) : base = s.size == 'big' ? 23 : 20;

  double rem(double x) => x * base;
  String t(String k, [Map<String, Object>? v]) => s.t(k, v);

  TextStyle get body => TextStyle(fontSize: rem(1), height: 1.5, color: p.ink);
  TextStyle get mutedStyle => TextStyle(fontSize: rem(0.95), height: 1.5, color: p.muted);
  TextStyle get h2 => TextStyle(fontSize: rem(1.6), height: 1.25, fontWeight: FontWeight.w700, color: p.ink);
  TextStyle get bold => body.copyWith(fontWeight: FontWeight.w600);

  Widget gap([double h = 16]) => SizedBox(height: h);

  /// A screen's main panel. Its children slide in one after another.
  Widget card(List<Widget> children, {bool centered = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line, width: 2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: p.ink.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
          children: _spaced([for (final (i, c) in children.indexed) Entrance(index: i + 1, child: c)], 16),
        ),
      );

  /// A column of rows; each row arrives a beat after the one above.
  Widget stack(List<Widget> children, [double spacing = 12]) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([for (final (i, c) in children.indexed) Entrance(index: i + 2, dy: 12, child: c)], spacing));

  List<Widget> _spaced(List<Widget> c, double g) {
    final out = <Widget>[];
    for (final w in c) {
      if (out.isNotEmpty) out.add(SizedBox(height: g));
      out.add(w);
    }
    return out;
  }

  Widget ico(String name, {bool bad = false, bool onHero = false}) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onHero
              ? Colors.white.withValues(alpha: 0.18)
              : bad
                  ? p.badBg
                  : p.accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icons[name] ?? Icons.person_outline,
            size: 26,
            color: onHero
                ? p.accentInk
                : bad
                    ? p.bad
                    : p.accent),
      );

  /// The big tappable rows and buttons (min 64px tall).
  Widget btn(String label, VoidCallback? onTap,
      {BtnKind kind = BtnKind.plain, String? icon, bool badIcon = false, String? sub, Widget? leading}) {
    final filled = kind == BtnKind.primary || kind == BtnKind.hero || kind == BtnKind.danger;
    final bg = kind == BtnKind.danger
        ? p.bad
        : filled
            ? p.accent
            : p.surface;
    final fg = kind == BtnKind.danger
        ? p.surface
        : filled
            ? p.accentInk
            : p.ink;
    final centered = kind == BtnKind.primary || kind == BtnKind.danger || kind == BtnKind.center;
    final text = Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: rem(1.05), fontWeight: FontWeight.w700, color: fg, height: 1.3)),
        if (sub != null)
          Text(sub, style: TextStyle(fontSize: rem(0.85), color: filled ? fg.withValues(alpha: 0.9) : p.muted, height: 1.35)),
      ],
    );
    final lead = leading ?? (icon != null ? ico(icon, bad: badIcon, onHero: kind == BtnKind.hero) : null);
    final hero = kind == BtnKind.hero;
    Widget b = AnimatedOpacity(
      opacity: onTap == null ? 0.5 : 1,
      duration: const Duration(milliseconds: 250),
      child: Material(
        color: hero ? Colors.transparent : bg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: BorderSide(color: filled ? bg : p.line, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: hero
              ? BoxDecoration(
                  gradient: LinearGradient(
                      colors: [p.accent, Color.lerp(p.accent, p.good, 0.55)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight))
              : null,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: kind == BtnKind.hero ? 84 : 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    if (lead != null) ...[lead, const SizedBox(width: 14)],
                    centered ? Flexible(child: text) : Expanded(child: text),
                    if (!centered && onTap != null) Icon(Icons.chevron_right_rounded, color: filled ? fg : p.muted, size: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (hero) b = Breathe(color: p.accent, child: b);
    return Pressable(enabled: onTap != null, child: b);
  }

  Widget chip(String label, VoidCallback? onTap, {bool pressed = false, bool alert = false, double minHeight = 44}) {
    final border = alert
        ? p.bad
        : pressed
            ? p.accent
            : p.line;
    final bg = alert
        ? p.badBg
        : pressed
            ? p.accentSoft
            : p.surface;
    return Semantics(
      button: true,
      selected: pressed,
      child: Pressable(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: ShapeDecoration(color: bg, shape: StadiumBorder(side: BorderSide(color: border, width: 2))),
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Center(
                    widthFactor: 1,
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: rem(0.85), fontWeight: FontWeight.w600, color: p.ink)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget tools(List<Widget> children) => Wrap(spacing: 8, runSpacing: 8, children: children);

  Widget listenBtn() => chip('🔊 ${t('listen')}', () => s.speak(s.lastSay));

  Widget micBtn(String target) => s.canListen
      ? chip('🎤 ${s.listening ? t('listening') : t('speakBtn')}', () => s.startListening(target), alert: s.listening)
      : const SizedBox.shrink();

  Widget title(String text, [List<Widget> extra = const []]) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Semantics(header: true, child: Text(text, style: h2)),
          tools([...extra, listenBtn()])
        ],
      );

  Widget label(String text) => Text(text.toUpperCase(),
      style: TextStyle(fontSize: rem(0.85), fontWeight: FontWeight.w700, letterSpacing: rem(0.85) * 0.06, color: p.muted));

  Widget progress(int n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(t('step', {'n': n, 't': 4})),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Row(children: [
              for (var i = 1; i <= 4; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4)),
                    alignment: Alignment.centerLeft,
                    // Earlier steps are full; the step just reached fills from the left
                    child: i > n
                        ? null
                        : TweenAnimationBuilder<double>(
                            tween: Tween(begin: i == n ? 0 : 1, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => FractionallySizedBox(
                              widthFactor: v,
                              child:
                                  Container(decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(4))),
                            ),
                          ),
                  ),
                ),
              ],
            ]),
          ),
        ],
      );

  Widget flash({bool ok = false}) {
    final f = s.flash;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: f.isEmpty
          ? const SizedBox(width: double.infinity)
          : Shake(
              child: Semantics(
                liveRegion: true,
                child: Text(f, style: TextStyle(fontSize: rem(1), fontWeight: FontWeight.w700, color: ok ? p.good : p.bad)),
              ),
            ),
    );
  }

  Widget nav({bool showBack = true}) => Row(children: [
        if (showBack) ...[Expanded(child: btn('← ${t('back')}', s.back, kind: BtnKind.center)), const SizedBox(width: 10)],
        Expanded(child: btn(t('home'), s.home, kind: BtnKind.center)),
      ]);

  Widget field(String labelText, TextEditingController ctl,
      {TextInputType? keyboard,
      ValueChanged<String>? onChanged,
      String? hint,
      bool amount = false,
      int? maxLength,
      int maxLines = 1}) {
    final input = TextField(
      controller: ctl,
      keyboardType: keyboard,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      maxLines: maxLines,
      minLines: maxLines.clamp(1, 5),
      maxLength: maxLength,
      textAlign: amount ? TextAlign.center : TextAlign.start,
      style: TextStyle(
          fontSize: amount ? rem(2.2) : rem(1.1),
          fontWeight: maxLines > 1 ? FontWeight.w400 : FontWeight.w600,
          color: p.ink,
          fontFeatures: amount ? const [FontFeature.tabularFigures()] : null),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: TextStyle(color: p.muted),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line, width: 2)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.accent, width: 3)),
      ),
    );
    if (labelText.isEmpty) return input;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(labelText, style: body.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      input,
    ]);
  }

  Widget verdict(String lv, String heading, List<Widget> children) {
    Widget v = Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: p.levelBg(lv), border: Border.all(color: p.level(lv), width: 3), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _spaced([
            Row(children: [
              PopIn(delay: const Duration(milliseconds: 160), child: Icon(levelIcon(lv), size: 36, color: p.level(lv))),
              const SizedBox(width: 12),
              Expanded(child: Text(heading, style: h2.copyWith(color: p.level(lv)))),
            ]),
            ...children,
          ], 12),
        ),
      ),
    );
    if (lv == 'red') v = Shake(child: v);
    return PopIn(child: v);
  }

  Widget bullets(List<String> items, {bool numbered = false, List<Widget>? custom}) {
    final rows = custom ?? items.map((x) => Text(x, style: bold) as Widget).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        for (var i = 0; i < rows.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: rem(1.3), child: Text(numbered ? '${i + 1}.' : '•', style: bold)),
            Expanded(child: rows[i]),
          ]),
      ], numbered ? 10 : 8),
    );
  }

  Widget summary(List<(String, String)> rows) => Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final (k, v) in rows)
            TableRow(children: [
              Padding(padding: const EdgeInsets.only(right: 16, bottom: 6), child: Text(k, style: mutedStyle)),
              Padding(
                  padding: const EdgeInsets.only(bottom: 6), child: Text(v, style: body.copyWith(fontWeight: FontWeight.w700))),
            ]),
        ],
      );

  Widget box(Widget child, {Color? bg}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg ?? p.bg, border: Border.all(color: p.line, width: 2), borderRadius: BorderRadius.circular(12)),
        child: child,
      );

  Widget bigAmt(String text) => Text(text,
      style: TextStyle(
          fontSize: rem(2.4),
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: p.ink,
          fontFeatures: const [FontFeature.tabularFigures()]));

  /// A selectable option row with a round dot (Settings).
  Widget radio(String label, bool on, VoidCallback onTap) => Semantics(
        selected: on,
        child: Pressable(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
                color: on ? p.accentSoft : p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? p.accent : p.line, width: 2)),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration:
                            BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? p.accent : p.muted, width: 3)),
                        alignment: Alignment.center,
                        child: AnimatedScale(
                          scale: on ? 1 : 0,
                          duration: const Duration(milliseconds: 260),
                          curve: spring,
                          child: Container(
                              width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(label, style: TextStyle(fontSize: rem(1.05), fontWeight: FontWeight.w700, color: p.ink))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
