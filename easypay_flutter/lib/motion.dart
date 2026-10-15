// Motion: small, calm animations in the spirit of Framer Motion, built on Flutter's own animation system.
// Every effect checks the phone's "remove animations" setting and shows the final state at once when it is on.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

bool motionOff(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

/// A gentle spring: overshoots a little, settles quickly.
const spring = Cubic(0.34, 1.36, 0.64, 1);

/// Fades and slides a child up into place, [index] steps after the screen appears (staggered lists).
class Entrance extends StatefulWidget {
  final Widget child;
  final int index;
  final double dy;
  const Entrance({super.key, required this.child, this.index = 0, this.dy = 18});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionOff(context)) {
      _c.value = 1;
    } else {
      _delay = Timer(Duration(milliseconds: math.min(widget.index, 8) * 55), _c.forward);
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.dy), child: child),
        ),
      );
}

/// Shrinks slightly while pressed and springs back: the tap feels physical.
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const Pressable({super.key, required this.child, this.enabled = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down && !motionOff(context) ? 0.965 : 1,
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: _down ? Curves.easeOut : spring,
          child: widget.child,
        ),
      );
}

/// Grows from 85% with a soft overshoot: for verdicts and result icons.
class PopIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    if (motionOff(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520) + delay,
      curve: Interval(delay.inMilliseconds / (520 + delay.inMilliseconds), 1, curve: spring),
      child: child,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
      ),
    );
  }
}

/// One short side-to-side shake, like a head saying "no": used once when a red verdict appears.
class Shake extends StatelessWidget {
  final Widget child;
  const Shake({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (motionOff(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      child: child,
      builder: (_, v, child) {
        // Starts after the pop-in, decays to rest
        final t = ((v - 0.35) / 0.65).clamp(0.0, 1.0);
        final dx = math.sin(t * math.pi * 6) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// A slow, endless glow that draws the eye without flashing (safe for older eyes; no strobing).
class Breathe extends StatefulWidget {
  final Widget child;
  final Color color;
  final BorderRadius radius;
  const Breathe({super.key, required this.child, required this.color, this.radius = const BorderRadius.all(Radius.circular(14))});

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionOff(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(_c.value);
          return DecoratedBox(
            decoration: BoxDecoration(borderRadius: widget.radius, boxShadow: [
              BoxShadow(color: widget.color.withValues(alpha: 0.18 + 0.22 * v), blurRadius: 10 + 14 * v, spreadRadius: 1 + 2 * v),
            ]),
            child: child,
          );
        },
      );
}

/// A ring that empties as the seconds run out (the 30-second "stop and think" lock).
class CountdownRing extends StatelessWidget {
  final int left, total;
  final Color color;
  const CountdownRing({super.key, required this.left, required this.total, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: left / total),
          duration: motionOff(context) ? Duration.zero : const Duration(milliseconds: 950),
          builder: (_, v, __) => CircularProgressIndicator(
            value: v,
            strokeWidth: 4,
            color: color,
            backgroundColor: color.withValues(alpha: 0.18),
          ),
        ),
      );
}
