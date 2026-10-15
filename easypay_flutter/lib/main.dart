// Easy Pay, Safe Pay: walks an older adult through a UPI payment one step at a time,
// and runs a scam check before any money moves.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'motion.dart';
import 'screens.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.load();
  runApp(EasyPayApp(state: state));
}

class EasyPayApp extends StatelessWidget {
  final AppState state;
  const EasyPayApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b, Pal p) => ThemeData(
          brightness: b,
          scaffoldBackgroundColor: p.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b, primary: p.accent, surface: p.surface),
          textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent),
        );
    return MaterialApp(
      title: 'Easy Pay Safe Pay',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light, Pal.light),
      darkTheme: theme(Brightness.dark, Pal.dark),
      // The app sets its own text sizes (Large / Extra large); cap the phone's font scale so buttons don't overflow.
      builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
      home: ListenableBuilder(listenable: state, builder: (context, _) => HomeShell(state: state)),
    );
  }
}

class HomeShell extends StatelessWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final u = Ui(s, dark ? Pal.dark : Pal.light);
    final p = u.p;
    final scr = buildScreen(u);
    WidgetsBinding.instance.addPostFrameCallback((_) => s.announce(scr.say));

    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Semantics(
            header: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Brand mark: a shield, with a soft gradient
              PopIn(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                        colors: [p.accent, Color.lerp(p.accent, p.good, 0.6)!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: Icon(Icons.verified_user_rounded, color: p.accentInk, size: 24),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text.rich(TextSpan(
                    style: TextStyle(fontSize: u.rem(1.4), height: 1.1, fontWeight: FontWeight.w700, color: p.ink),
                    children: [
                      TextSpan(text: '${u.t('app1')} '),
                      TextSpan(text: u.t('app2'), style: TextStyle(color: p.accent)),
                    ])),
              ),
            ]),
          ),
          u.chip('🔊 ${s.voice ? u.t('voiceOn') : u.t('voiceOff')}', s.toggleVoice, pressed: s.voice),
        ],
      ),
      const SizedBox(height: 10),
      Semantics(
        label: 'Language',
        child: u.tools([
          for (final (code, name) in const [('en', 'English'), ('hi', 'हिंदी'), ('kn', 'ಕನ್ನಡ')])
            u.chip(name, () => s.setLang(code), pressed: s.lang == code),
        ]),
      ),
      const SizedBox(height: 10),
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: s.real ? p.goodBg : null,
          border: Border.all(color: s.real ? p.good : p.line, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s.real ? u.t('bannerReal') : u.t('bannerPractice'),
            style: TextStyle(fontSize: u.rem(0.85), fontWeight: FontWeight.w600, color: s.real ? p.good : p.muted)),
      ),
      // iPhone: someone is recording, mirroring or sharing this screen. Shown on every screen until it stops.
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        child: !s.captured
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Breathe(
                  color: p.bad,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.bad, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.screen_share_outlined, color: p.surface, size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Text(u.t('capturedWarn'), style: u.bold.copyWith(color: p.surface))),
                    ]),
                  ),
                ),
              ),
      ),
    ]);

    // Each screen arrives as a whole (fade + rise), then its rows follow one after another (see Ui.card / Ui.stack)
    final Widget body = Column(
      key: ValueKey(s.navId),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, w) in scr.children.indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          Entrance(index: i, dy: 24, child: w)
        ],
      ],
    );

    return PopScope(
      canPop: !s.listening && s.stack.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) s.onBack();
      },
      child: Scaffold(
        body: DecoratedBox(
          // A soft wash of colour behind the cards
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(p.bg, p.accentSoft, 0.7)!, p.bg],
              stops: const [0, 0.45],
            ),
          ),
          child: SafeArea(
            child: DefaultTextStyle(
              style: u.body,
              child: SingleChildScrollView(
                key: ValueKey('scroll-${s.navId}'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, const SizedBox(height: 16), body],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
