// lib/pages/meditation.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:vibration/vibration.dart';
import 'package:new_rezonate/main.dart' as app;

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

/// Phase types for patterns
enum _PhaseKind { inhale, hold, exhale }

class _BreathPhase {
  final _PhaseKind kind;
  final int seconds;
  const _BreathPhase(this.kind, this.seconds);

  String get label {
    switch (kind) {
      case _PhaseKind.inhale:
        return 'Inhale';
      case _PhaseKind.hold:
        return 'Hold';
      case _PhaseKind.exhale:
        return 'Exhale';
    }
  }
}

class _BreathPattern {
  final String name;
  final List<_BreathPhase> phases;
  final int suggestedMinutes;
  const _BreathPattern(this.name, this.phases, this.suggestedMinutes);

  int get cycleSeconds => phases.fold(0, (a, p) => a + p.seconds);
}

/// Built-in patterns
const _patternDefault = _BreathPattern('Default (4–4)', [
  _BreathPhase(_PhaseKind.inhale, 4),
  _BreathPhase(_PhaseKind.exhale, 4),
], 5);

const _patternBox = _BreathPattern('Box (4–4–4–4)', [
  _BreathPhase(_PhaseKind.inhale, 4),
  _BreathPhase(_PhaseKind.hold, 4),
  _BreathPhase(_PhaseKind.exhale, 4),
  _BreathPhase(_PhaseKind.hold, 4),
], 5);

const _pattern478 = _BreathPattern('4–7–8', [
  _BreathPhase(_PhaseKind.inhale, 4),
  _BreathPhase(_PhaseKind.hold, 7),
  _BreathPhase(_PhaseKind.exhale, 8),
], 4);

const _patternResonant = _BreathPattern('Resonant (~6/min)', [
  _BreathPhase(_PhaseKind.inhale, 5),
  _BreathPhase(_PhaseKind.exhale, 5),
], 5);

const _patternSigh = _BreathPattern('Physiological Sigh', [
  _BreathPhase(_PhaseKind.inhale, 2),
  _BreathPhase(_PhaseKind.inhale, 1),
  _BreathPhase(_PhaseKind.exhale, 6),
], 2);

// ---- New longer & variety patterns (some 15 minutes) ----
const _patternBox15 = _BreathPattern('Box (4–4–4–4) · 15m', [
  _BreathPhase(_PhaseKind.inhale, 4),
  _BreathPhase(_PhaseKind.hold, 4),
  _BreathPhase(_PhaseKind.exhale, 4),
  _BreathPhase(_PhaseKind.hold, 4),
], 15);

const _patternResonant15 = _BreathPattern('Resonant (5–5) · 15m', [
  _BreathPhase(_PhaseKind.inhale, 5),
  _BreathPhase(_PhaseKind.exhale, 5),
], 15);

const _patternEqual66 = _BreathPattern('Equal (6–6)', [
  _BreathPhase(_PhaseKind.inhale, 6),
  _BreathPhase(_PhaseKind.exhale, 6),
], 10);

const _patternTriangle = _BreathPattern('Triangle (4–4–6)', [
  _BreathPhase(_PhaseKind.inhale, 4),
  _BreathPhase(_PhaseKind.hold, 4),
  _BreathPhase(_PhaseKind.exhale, 6),
], 10);

class _MeditationPageState extends State<MeditationPage>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  int? _preCountdown; // null = not counting down

  // Session duration presets (minutes)
  final List<int> _presets = const [3, 5, 10, 15];
  int _selectedMinutes = 5;

  // Countdown
  int _remainingSeconds = 5 * 60;
  Timer? _timer;
  bool _running = false;

  // Breathing pattern + animation
  _BreathPattern _pattern = _patternDefault;

  // NOTE: no auto-repeat; we only animate when the timer is running
  late final AnimationController _breathCtrl = AnimationController(
    vsync: this,
    duration: Duration(seconds: _pattern.cycleSeconds),
  );

  // Track phase changes for haptics
  int _lastPhaseIndex = -1;

  // smooth scale for inhale/exhale
  static const double _minScale = 0.85;
  static const double _maxScale = 1.12;

  @override
  void initState() {
    super.initState();
    _breathCtrl.addListener(_onBreathTick); // haptics
    _resetToMinutes(_selectedMinutes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  BoxDecoration _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors:
            dark
                ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
                : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFD7C3F1),
                  Color(0xFF41B3A2),
                ],
      ),
    );
  }

  void _resetToMinutes(int minutes) {
    _timer?.cancel();
    _breathCtrl.stop(); // stop animation when not running
    _breathCtrl.value = 0.0; // reset to start (static)
    _lastPhaseIndex = -1;
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _running = false;
    });
  }

  void _toggle() => _running ? _pause() : _start();

  void _start() {
    if (_remainingSeconds <= 0) _resetToMinutes(_selectedMinutes);
    _timer?.cancel();
    setState(() => _running = true);
    _lastPhaseIndex = -1; // ensure first phase buzzes
    _breathCtrl.repeat(); // animate only while running
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
        _breathCtrl.stop(); // stop animation when finished
        _showDone();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _breathCtrl.stop(); // freeze animation on pause
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    _breathCtrl.stop();
    _breathCtrl.value = 0.0;
    _lastPhaseIndex = -1;
    setState(() {
      _remainingSeconds = _selectedMinutes * 60;
      _running = false;
    });
  }

  Future<void> _showDone() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Session complete'),
            content: const Text('Nice work. Ready for another round?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  String _mmss(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    final ss = s < 10 ? '0$s' : '$s';
    return '$m:$ss';
  }

  /// Switch to a breathing pattern and (optionally) auto-start
  Future<void> _applyPattern(_BreathPattern p, {bool start = true}) async {
    _pattern = p;
    _breathCtrl.stop();
    _breathCtrl.duration = Duration(seconds: _pattern.cycleSeconds);
    _breathCtrl.reset();
    _resetToMinutes(p.suggestedMinutes);
    setState(() {});

    // 1️⃣ Scroll to top (so timer is visible)
    await _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );

    if (!start) return;

    // 2️⃣ Show a 5-second pre-countdown
    setState(() => _preCountdown = 5);

    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _preCountdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    // 3️⃣ Clear countdown & start session
    setState(() => _preCountdown = null);
    _start();
  }

  /// Determine current phase and subprogress within that phase (0..1)
  ({
    _BreathPhase phase,
    double subProgress,
    _PhaseKind lastNonHold,
    int phaseIndex,
  })
  _phaseAt(double cycleSecondsElapsed) {
    final total = _pattern.cycleSeconds;
    double t = cycleSecondsElapsed % total;
    _PhaseKind lastNonHold = _PhaseKind.exhale; // default start size small
    int idx = 0;
    for (final ph in _pattern.phases) {
      if (t < ph.seconds) {
        final sub = ph.seconds == 0 ? 0.0 : t / ph.seconds;
        return (
          phase: ph,
          subProgress: sub,
          lastNonHold: lastNonHold,
          phaseIndex: idx,
        );
      }
      if (ph.kind != _PhaseKind.hold) lastNonHold = ph.kind;
      t -= ph.seconds;
      idx++;
    }
    final ph = _pattern.phases.last;
    return (
      phase: ph,
      subProgress: 1.0,
      lastNonHold: lastNonHold,
      phaseIndex: _pattern.phases.length - 1,
    );
  }

  String _cueText() {
    if (!_running) return 'Inhale'; // static while stopped/paused
    final secs = _breathCtrl.value * _pattern.cycleSeconds;
    final info = _phaseAt(secs);
    return info.phase.label;
  }

  double _scaleForAnimation() {
    if (!_running) return 1.0; // static size while stopped/paused
    final secs = _breathCtrl.value * _pattern.cycleSeconds;
    final info = _phaseAt(secs);
    final k = (_maxScale - _minScale);
    switch (info.phase.kind) {
      case _PhaseKind.inhale:
        return _minScale + k * info.subProgress;
      case _PhaseKind.exhale:
        return _maxScale - k * info.subProgress;
      case _PhaseKind.hold:
        return (info.lastNonHold == _PhaseKind.inhale) ? _maxScale : _minScale;
    }
  }

  // --- Haptics ---
  Future<void> _buzzForPhase(_PhaseKind k) async {
    // Safely handle nullable return from hasVibrator / hasAmplitudeControl
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    final hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;

    if (!hasVibrator) {
      // No vibrator available — fallback to light haptics so iOS devices / non-vibrate devices still get a cue
      switch (k) {
        case _PhaseKind.inhale:
          HapticFeedback.lightImpact();
          break;
        case _PhaseKind.hold:
          HapticFeedback.selectionClick();
          break;
        case _PhaseKind.exhale:
          HapticFeedback.mediumImpact();
          break;
      }
      return;
    }

    // Device has vibrator — use vibration (with amplitude if supported)
    switch (k) {
      case _PhaseKind.inhale:
        if (hasAmplitude) {
          Vibration.vibrate(duration: 80, amplitude: 128);
        } else {
          Vibration.vibrate(duration: 80);
        }
        break;
      case _PhaseKind.hold:
        if (hasAmplitude) {
          Vibration.vibrate(duration: 50, amplitude: 70);
        } else {
          Vibration.vibrate(duration: 50);
        }
        break;
      case _PhaseKind.exhale:
        if (hasAmplitude) {
          Vibration.vibrate(duration: 130, amplitude: 200);
        } else {
          Vibration.vibrate(duration: 130);
        }
        break;
    }
  }

  void _onBreathTick() {
    if (!_running) return;
    final secs = _breathCtrl.value * _pattern.cycleSeconds;
    final info = _phaseAt(secs);
    if (info.phaseIndex != _lastPhaseIndex) {
      _lastPhaseIndex = info.phaseIndex;
      _buzzForPhase(info.phase.kind);
    }
  }

  double _topPadding(BuildContext context) {
    // Push content below the title: status bar + app bar height + extra spacing.
    final status = MediaQuery.of(context).padding.top;
    const appBar = kToolbarHeight;
    const extra = 36.0;
    return status + appBar + extra;
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0D7C66);

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light, // ← pretend it’s always light mode
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Meditation',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
              color: Colors.black,
            ),
          ),
        ),
        body: Container(
          decoration: _bg(context),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: _scrollCtrl,
              padding: EdgeInsets.fromLTRB(16, _topPadding(context), 16, 24),
              children: [
                // Breathing visual + timer (FIRST)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 0.7),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // --- Main timer/visual content ---
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _breathCtrl,
                            builder: (context, _) {
                              final scale = _scaleForAnimation();
                              return Column(
                                children: [
                                  Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const RadialGradient(
                                          colors: [
                                            Colors.white,
                                            Color(0xFFBDE5DC),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withOpacity(.25),
                                            blurRadius: 24,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          _cueText(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _mmss(_remainingSeconds),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _running
                                ? 'Tap pause anytime'
                                : 'Choose a duration or start an exercise',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _toggle,
                                icon: Icon(
                                  _running
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                label: Text(_running ? 'Pause' : 'Start'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _reset,
                                icon: Icon(
                                  Icons.replay_rounded,
                                  color:
                                      app.ThemeControllerScope.of(
                                            context,
                                          ).isDark
                                          ? const Color.fromARGB(255, 0, 0, 0)
                                          : Colors.black87, // icon color
                                ),
                                label: Text(
                                  'Reset',
                                  style: TextStyle(
                                    color:
                                        app.ThemeControllerScope.of(
                                              context,
                                            ).isDark
                                            ? const Color.fromARGB(255, 0, 0, 0)
                                            : Colors.black87, // text color
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  side: BorderSide(
                                    color:
                                        app.ThemeControllerScope.of(
                                              context,
                                            ).isDark
                                            ? const Color.fromARGB(
                                              255,
                                              0,
                                              0,
                                              0,
                                            ).withOpacity(.6)
                                            : Colors.black.withOpacity(.2),
                                  ),
                                  shape: const StadiumBorder(),
                                  backgroundColor:
                                      app.ThemeControllerScope.of(
                                            context,
                                          ).isDark
                                          ? Colors.white.withOpacity(.15)
                                          : Colors.white.withOpacity(.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // --- Countdown overlay (if active) ---
                      /*if (_preCountdown != null)
                      Container(
                        child: Center(
                          child: Text(
                            '$_preCountdown',
                            style: const TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),*/
                      // --- Countdown overlay (animated) ---
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 1000),
                        transitionBuilder: (child, animation) {
                          // Fade + gentle scale transition
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.4,
                                end: 1.0,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child:
                            _preCountdown != null
                                ? Container(
                                  key: ValueKey(
                                    _preCountdown,
                                  ), // Important for AnimatedSwitcher
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 12),
                                        Text(
                                          '$_preCountdown',
                                          style: const TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Duration presets (BELOW the timer)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.78),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          app.ThemeControllerScope.of(context).isDark
                              ? Colors.white.withOpacity(.3)
                              : Colors.black.withOpacity(.2),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _presets.map((m) {
                          final selected = _selectedMinutes == m && !_running;
                          final dark =
                              app.ThemeControllerScope.of(context).isDark;
                          return ChoiceChip(
                            label: Text(
                              '${m}m',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color:
                                    dark
                                        ? (selected
                                            ? Colors.black
                                            : Colors.white)
                                        : (selected
                                            ? Colors.black
                                            : Colors.black87),
                              ),
                            ),
                            selected: selected,
                            onSelected:
                                _running ? null : (_) => _resetToMinutes(m),
                            selectedColor: dark ? const Color.fromARGB(255, 156, 156, 156) : Colors.white,
                            side: BorderSide(
                              color:
                                  dark
                                      ? Colors.white.withOpacity(.3)
                                      : Colors.black.withOpacity(.12),
                            ),
                          );
                        }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Quick tips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.72),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 0.7),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick tips',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Inhale through the nose for ~4s, exhale for ~4s.',
                      ),
                      Text('• Keep shoulders relaxed and jaw unclenched.'),
                      Text('• Breathe from the diaphragm, not the chest.'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Guided breathing exercises with Play buttons (sets pattern & starts timer)
                const Text(
                  'Guided breathing exercises',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),

                _ExerciseCard(
                  title: 'Box Breathing (4-4-4-4)',
                  tag: 'Focus · 3–5 min',
                  bullets: const [
                    'Inhale 4s',
                    'Hold 4s',
                    'Exhale 4s',
                    'Hold 4s, repeat',
                  ],
                  onPlay: () => _applyPattern(_patternBox, start: true),
                ),
                const SizedBox(height: 10),

                _ExerciseCard(
                  title: '4–7–8 Relaxation',
                  tag: 'Wind-down · 2–4 min',
                  bullets: const [
                    'Inhale 4s',
                    'Hold 7s',
                    'Exhale 8s (slow)',
                    'Repeat 4–6 cycles',
                  ],
                  onPlay: () => _applyPattern(_pattern478, start: true),
                ),
                const SizedBox(height: 10),

                _ExerciseCard(
                  title: 'Resonant Breathing (~6/min)',
                  tag: 'Calm · 5–10 min',
                  bullets: const [
                    'Inhale 5s',
                    'Exhale 5s',
                    'Keep breaths smooth and even',
                  ],
                  onPlay: () => _applyPattern(_patternResonant, start: true),
                ),
                const SizedBox(height: 10),

                _ExerciseCard(
                  title: 'Physiological Sigh',
                  tag: 'De-stress · 1–2 min',
                  bullets: const [
                    'Short inhale through nose',
                    'Add a second quick inhale',
                    'Long, slow exhale through mouth',
                    'Repeat 5–10 times',
                  ],
                  onPlay: () => _applyPattern(_patternSigh, start: true),
                ),
                const SizedBox(height: 10),

                // --- New longer cards (15 minutes) ---
                _ExerciseCard(
                  title: 'Box Breathing (4-4-4-4) · 15 minutes',
                  tag: 'Deep focus · 15 min',
                  bullets: const [
                    'Inhale 4s',
                    'Hold 4s',
                    'Exhale 4s',
                    'Hold 4s · repeat for full session',
                  ],
                  onPlay: () => _applyPattern(_patternBox15, start: true),
                ),
                const SizedBox(height: 10),

                _ExerciseCard(
                  title: 'Resonant (5-5) · 15 minutes',
                  tag: 'Heart-rate coherence · 15 min',
                  bullets: const [
                    'Inhale 5s',
                    'Exhale 5s',
                    'Relax shoulders, steady rhythm',
                  ],
                  onPlay: () => _applyPattern(_patternResonant15, start: true),
                ),
                const SizedBox(height: 10),

                // Extra variety
                _ExerciseCard(
                  title: 'Equal Breathing (6-6)',
                  tag: 'Grounding · 8–10 min',
                  bullets: const [
                    'Inhale 6s',
                    'Exhale 6s',
                    'Aim for smooth transitions',
                  ],
                  onPlay: () => _applyPattern(_patternEqual66, start: true),
                ),
                const SizedBox(height: 10),

                _ExerciseCard(
                  title: 'Triangle (4-4-6)',
                  tag: 'Relax & lengthen exhale · 8–10 min',
                  bullets: const [
                    'Inhale 4s',
                    'Hold 4s',
                    'Exhale 6s',
                    'Repeat',
                  ],
                  onPlay: () => _applyPattern(_patternTriangle, start: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.title,
    required this.tag,
    required this.bullets,
    required this.onPlay,
  });

  final String title;
  final String tag;
  final List<String> bullets;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 0.7),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF7F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0D7C66).withOpacity(.25),
              ),
            ),
            child: Text(
              tag,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0D7C66)),
            ),
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(height: 1.4)),
                  Expanded(child: Text(b)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
