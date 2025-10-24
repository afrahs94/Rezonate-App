// lib/pages/meditation.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// A definition for a meditation card (used for search + recent)
class _MeditationDef {
  final String title;
  final String tag;
  final List<String> bullets;
  final _BreathPattern pattern;
  const _MeditationDef({
    required this.title,
    required this.tag,
    required this.bullets,
    required this.pattern,
  });
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

  // --------- Search & Recents -----------
  static const _kRecentsKey = 'meditation_recent_titles';
  static const int _maxRecents = 8;
  String _query = '';
  final List<_MeditationDef> _all = []; // populated in initState
  final Map<String, _MeditationDef> _byTitle = {};
  List<String> _recentTitles = [];

  @override
  void initState() {
    super.initState();
    _breathCtrl.addListener(_onBreathTick); // haptics
    _seedMeditations(); // build the catalog (includes the 50 you asked for)
    _loadRecents();
    _resetToMinutes(_selectedMinutes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _seedMeditations() {
    // --- Guided breathing cards (original + 50 added) ---
    final items = <_MeditationDef>[
      // Originals from the page
      _MeditationDef(
        title: 'Box Breathing (4-4-4-4)',
        tag: 'Focus · 3–5 min',
        bullets: const ['Inhale 4s', 'Hold 4s', 'Exhale 4s', 'Hold 4s, repeat'],
        pattern: _patternBox,
      ),
      _MeditationDef(
        title: '4–7–8 Relaxation',
        tag: 'Wind-down · 2–4 min',
        bullets: const [
          'Inhale 4s',
          'Hold 7s',
          'Exhale 8s (slow)',
          'Repeat 4–6 cycles'
        ],
        pattern: _pattern478,
      ),
      _MeditationDef(
        title: 'Resonant Breathing (~6/min)',
        tag: 'Calm · 5–10 min',
        bullets: const [
          'Inhale 5s',
          'Exhale 5s',
          'Keep breaths smooth and even'
        ],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Physiological Sigh',
        tag: 'De-stress · 1–2 min',
        bullets: const [
          'Short inhale through nose',
          'Add a second quick inhale',
          'Long, slow exhale through mouth',
          'Repeat 5–10 times'
        ],
        pattern: _patternSigh,
      ),
      _MeditationDef(
        title: 'Box Breathing (4-4-4-4) · 15 minutes',
        tag: 'Deep focus · 15 min',
        bullets: const [
          'Inhale 4s',
          'Hold 4s',
          'Exhale 4s',
          'Hold 4s · repeat for full session'
        ],
        pattern: _patternBox15,
      ),
      _MeditationDef(
        title: 'Resonant (5-5) · 15 minutes',
        tag: 'Heart-rate coherence · 15 min',
        bullets: const ['Inhale 5s', 'Exhale 5s', 'Relax shoulders, steady rhythm'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Equal Breathing (6-6)',
        tag: 'Grounding · 8–10 min',
        bullets: const ['Inhale 6s', 'Exhale 6s', 'Aim for smooth transitions'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Triangle (4-4-6)',
        tag: 'Relax & lengthen exhale · 8–10 min',
        bullets: const ['Inhale 4s', 'Hold 4s', 'Exhale 6s', 'Repeat'],
        pattern: _patternTriangle,
      ),

      // ---- +50 Meditations ----
      _MeditationDef(
        title: 'Mindful Body Scan (Short)',
        tag: 'Presence · 5–8 min',
        bullets: const [
          'Attention from head to toes',
          'Notice sensations without judging',
          'Return to breath when distracted'
        ],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Loving-Kindness (Metta) Starter',
        tag: 'Warmth · 5–10 min',
        bullets: const ['Breathe evenly', 'Repeat kind phrases silently', 'Expand to others'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Gratitude Breath',
        tag: 'Uplift · 4–6 min',
        bullets: const ['Inhale and name one thing', 'Exhale and say “thank you”', 'Repeat gently'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Calm Counting',
        tag: 'Settle · 3–5 min',
        bullets: const ['In 4 · Out 4', 'Count 1–10 and restart', 'Soft focus on breath'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Ocean Wave Breath',
        tag: 'Soothing · 5–8 min',
        bullets: const ['Slow, wave-like rhythm', 'Imagine tide in and out', 'Loosen jaw and shoulders'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Mountain Visualization',
        tag: 'Steadiness · 6–10 min',
        bullets: const [
          'Picture a strong mountain',
          'Breathe with its stability',
          'Return when mind wanders'
        ],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Focus on Sound',
        tag: 'Awareness · 5–8 min',
        bullets: const ['In 5 · Out 5', 'Notice near & far sounds', 'Let them pass like clouds'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Box Focus Sprint',
        tag: 'Sharpen · 3–5 min',
        bullets: const [
          '4–4–4–4 cycle',
          'Eyes soft, spine tall',
          'Re-center attention quickly'
        ],
        pattern: _patternBox,
      ),
      _MeditationDef(
        title: 'Triangle Calm',
        tag: 'Unwind · 6–8 min',
        bullets: const ['In 4 · Hold 4 · Out 6', 'Lengthen exhale gently', 'Release tension on out-breath'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Equal Breathing Ground',
        tag: 'Balance · 8–10 min',
        bullets: const ['In 6 · Out 6', 'Even, smooth flow', 'Steady attention on diaphragm'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Morning Centering',
        tag: 'Start fresh · 5 min',
        bullets: const ['In 4 · Out 4', 'Set a gentle intention', 'Smile softly'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Evening Wind-Down',
        tag: 'Ease into rest · 6–8 min',
        bullets: const ['In 4 · Hold 7 · Out 8', 'Dim lights, slow everything', 'Let thoughts pass'],
        pattern: _pattern478,
      ),
      _MeditationDef(
        title: 'Stress Reset',
        tag: 'Quick relief · 3–4 min',
        bullets: const ['Physiological sigh x 8–10', 'Relax shoulders', 'Return to normal breathing'],
        pattern: _patternSigh,
      ),
      _MeditationDef(
        title: 'Pre-Meeting Focus',
        tag: 'Composure · 3–5 min',
        bullets: const ['Box rhythm 4–4–4–4', 'Visualize calm presence', 'Enter with clarity'],
        pattern: _patternBox,
      ),
      _MeditationDef(
        title: 'Post-Work Unwind',
        tag: 'Transition · 6–8 min',
        bullets: const ['In 5 · Out 5', 'Let the day go', 'Arrive where you are'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Commute Calm',
        tag: 'On-the-go · 5 min',
        bullets: const ['In 4 · Out 4 (eyes open)', 'Notice contact points', 'Keep attention wide'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Study Focus',
        tag: 'Mental clarity · 5–10 min',
        bullets: const ['Box rhythm 4–4–4–4', 'Single-task intention', 'Begin immediately after'],
        pattern: _patternBox15,
      ),
      _MeditationDef(
        title: 'Sleep Prep',
        tag: 'Drowsy drift · 6–8 min',
        bullets: const ['4–7–8 pattern', 'Soften gaze or eyes closed', 'Dark, quiet space'],
        pattern: _pattern478,
      ),
      _MeditationDef(
        title: 'Midday Reset',
        tag: 'Refresh · 3–5 min',
        bullets: const ['In 5 · Out 5', 'Stretch neck/shoulders', 'Return with energy'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Anxiety Soother',
        tag: 'Downshift · 5–8 min',
        bullets: const ['In 4 · Hold 4 · Out 6', 'Name 3 colors you see', 'Exhale longer each cycle'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Energy Balance',
        tag: 'Even keel · 8–10 min',
        bullets: const ['Equal 6–6', 'Steady posture', 'Gentle attention at nostrils'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Gentle Presence',
        tag: 'Kind awareness · 5–7 min',
        bullets: const ['In 4 · Out 4', 'Notice, name, nurture', 'Soft half-smile'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Compassion Pause',
        tag: 'Heart-soften · 6–8 min',
        bullets: const ['In 5 · Out 5', 'Hand on chest', 'One kind phrase repeated'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Patience Builder',
        tag: 'Steadying · 5–7 min',
        bullets: const ['Box 4–4–4–4', 'Count five full cycles', 'Return if mind wanders'],
        pattern: _patternBox,
      ),
      _MeditationDef(
        title: 'Social Ease',
        tag: 'Soften nerves · 4–6 min',
        bullets: const ['In 4 · Hold 4 · Out 6', 'Release shoulder tension', 'Picture a friendly face'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Clarity Minute',
        tag: 'Quick tune · 3–4 min',
        bullets: const ['Physiological sighs', 'One clear next step', 'Begin calmly'],
        pattern: _patternSigh,
      ),
      _MeditationDef(
        title: 'Creativity Prime',
        tag: 'Open mind · 5–8 min',
        bullets: const ['In 5 · Out 5', 'Widen attention after 3 min', 'Note any ideas lightly'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Mood Lift',
        tag: 'Brighten · 4–6 min',
        bullets: const ['In 4 · Out 4', 'Recall a small joy', 'Savor for three breaths'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Tension Release',
        tag: 'Let go · 5–7 min',
        bullets: const ['In 4 · Hold 4 · Out 6', 'Relax jaw, brow, belly', 'Exhale through mouth softly'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Calm Check-In',
        tag: 'Regroup · 3–5 min',
        bullets: const ['Equal 6–6 or 4–4', 'Name how you feel', 'Choose one gentle action'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Focus Ladder',
        tag: 'Build attention · 6–8 min',
        bullets: const [
          'Box 4–4–4–4',
          'Climb 5 cycles without distraction',
          'Restart if mind wanders'
        ],
        pattern: _patternBox15,
      ),
      _MeditationDef(
        title: 'Resilience Breath',
        tag: 'Inner strength · 6–8 min',
        bullets: const ['In 5 · Out 5', 'Recall a challenge overcome', 'Breathe with that strength'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Acceptance Moment',
        tag: 'Allowing · 5–7 min',
        bullets: const ['In 4 · Out 4', 'Whisper “this too” on exhale', 'Notice space around sensations'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Let-Go Exhale',
        tag: 'Release · 4–6 min',
        bullets: const ['In 4 · Hold 4 · Out 6–8', 'Imagine tension leaving', 'Soften hands/feet'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Balance Breath',
        tag: 'Equanimity · 8–10 min',
        bullets: const ['Equal 6–6', 'Even cadence, even mind', 'Anchor at the navel'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Ground & Grow',
        tag: 'Steady growth · 6–8 min',
        bullets: const ['In 5 · Out 5', 'Imagine roots to ground', 'Grow taller with breath'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Quiet Confidence',
        tag: 'Self-trust · 5–7 min',
        bullets: const ['Box rhythm', 'Repeat: “I can handle this”', 'Relaxed posture'],
        pattern: _patternBox,
      ),
      _MeditationDef(
        title: 'Steady Rhythm',
        tag: 'Consistency · 8–10 min',
        bullets: const ['In 5 · Out 5', 'Minimal effort, maximum ease', 'Stay with sensation'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Soft Gaze Meditation',
        tag: 'Open awareness · 5–8 min',
        bullets: const ['Equal 6–6 (eyes open)', 'Gentle unfocused gaze', 'Let sights come to you'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Heart Coherence',
        tag: 'Warm balance · 6–10 min',
        bullets: const ['Resonant 5–5', 'Breathe through heart area', 'Recall a pleasant moment'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Pause Before Sleep',
        tag: 'Quiet mind · 6–8 min',
        bullets: const ['4–7–8 pattern', 'Dim light; no screens', 'Let body feel heavy'],
        pattern: _pattern478,
      ),
      _MeditationDef(
        title: 'Wake-Up Align',
        tag: 'Gentle start · 4–6 min',
        bullets: const ['In 4 · Out 4', 'Set one kind intention', 'Stretch lightly'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Digital Detox',
        tag: 'Unplug · 5–8 min',
        bullets: const ['In 5 · Out 5', 'Device out of reach', 'Notice cravings & let pass'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Nature Imagine',
        tag: 'Restore · 6–8 min',
        bullets: const ['Equal 6–6', 'Visualize a calm scene', 'Engage all senses'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Slow Flow',
        tag: 'Ease · 6–10 min',
        bullets: const ['In 5 · Out 5', 'Smooth, wave-like motion', 'Relax shoulders on exhale'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Centered Leadership',
        tag: 'Poise · 6–8 min',
        bullets: const ['Box 4–4–4–4', 'Stand/sit tall', 'Lead with calm presence'],
        pattern: _patternBox15,
      ),
      _MeditationDef(
        title: 'Gentle Reset',
        tag: 'Recenter · 4–6 min',
        bullets: const ['In 4 · Out 4', 'Count 1–10 softly', 'Start anew'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Calm Before Call',
        tag: 'Prepare · 3–5 min',
        bullets: const ['Physiological sighs x 6–8', 'One intention for the call', 'Begin with ease'],
        pattern: _patternSigh,
      ),
      _MeditationDef(
        title: 'Clutter Clear Head',
        tag: 'Declutter · 5–7 min',
        bullets: const ['In 5 · Out 5', 'Note 3 priorities', 'Return to single task'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Reflect & Breathe',
        tag: 'Insight · 6–8 min',
        bullets: const ['Equal 6–6', 'One question in mind', 'Let answer emerge naturally'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Gracious Pause',
        tag: 'Kind reset · 4–6 min',
        bullets: const [
          'In 4 · Hold 4 · Out 6',
          'Whisper “thank you” on out-breath',
          'Relax tongue from palate'
        ],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Steady Focus Anchor',
        tag: 'Attention · 6–8 min',
        bullets: const ['Box 4–4–4–4', 'Anchor at nostrils', 'Notice/return kindly'],
        pattern: _patternBox15,
      ),
      _MeditationDef(
        title: 'Ease the Edges',
        tag: 'Soften · 5–7 min',
        bullets: const ['In 5 · Out 5', 'Soften eyes and jaw', 'Let edges blur'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Simple Stillness',
        tag: 'Quiet · 4–6 min',
        bullets: const ['In 4 · Out 4', 'Sit tall, be still', 'Notice the pauses'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Exhale Lengthen',
        tag: 'Downshift · 5–7 min',
        bullets: const ['In 4 · Hold 4 · Out 6–8', 'Longer out-breaths', 'Drop shoulders each time'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Open & Curious',
        tag: 'Beginner’s mind · 6–8 min',
        bullets: const ['Equal 6–6', 'Notice labels drop', 'Stay curious'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Calm Confidence Prime',
        tag: 'Compose · 6–8 min',
        bullets: const ['Resonant 5–5', 'Visualize succeeding', 'Act with ease'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Body Awareness Mini',
        tag: 'Embodied · 5–7 min',
        bullets: const ['In 4 · Out 4', 'Scan contact points', 'Relax hands, feet'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Pre-Workout Breath',
        tag: 'Prime · 3–5 min',
        bullets: const ['Box 4–4–4–4', 'Steady nerves', 'Focus form & intent'],
        pattern: _patternBox,
      ),
      _MeditationDef(
        title: 'Post-Workout Cool',
        tag: 'Recover · 4–6 min',
        bullets: const ['Physiological sigh x 10', 'Return to nasal breathing', 'Lower arousal gently'],
        pattern: _patternSigh,
      ),
      _MeditationDef(
        title: 'Between Tasks Reset',
        tag: 'Context switch · 3–5 min',
        bullets: const ['In 5 · Out 5', 'Name next single step', 'Begin now'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Before Eating',
        tag: 'Savor · 3–5 min',
        bullets: const ['Equal 6–6', 'Notice aromas', 'Eat with awareness'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'After Eating',
        tag: 'Settle · 4–6 min',
        bullets: const ['In 4 · Hold 4 · Out 6', 'Sit tall, relax belly', 'Gentle gratitude'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Kind Self-Talk',
        tag: 'Support · 5–7 min',
        bullets: const ['Resonant flow', 'One caring sentence', 'Repeat for 5 breaths'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Quiet Morning Readiness',
        tag: 'Ready · 5–7 min',
        bullets: const ['In 4 · Out 4', 'Picture your first move', 'Start gently'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Steady Before Speech',
        tag: 'Poised · 6–8 min',
        bullets: const ['Box 4–4–4–4', 'Slow first sentence rehearsal', 'Enter with calm'],
        pattern: _patternBox15,
      ),
      _MeditationDef(
        title: 'Ease Neck & Jaw',
        tag: 'Soften · 4–6 min',
        bullets: const ['In 5 · Out 5', 'Release jaw on exhale', 'Drop shoulders'],
        pattern: _patternResonant,
      ),
      _MeditationDef(
        title: 'Patience in Queue',
        tag: 'Wait well · 3–5 min',
        bullets: const ['Equal 6–6 (standing)', 'Feel feet grounded', 'Smile inwardly'],
        pattern: _patternEqual66,
      ),
      _MeditationDef(
        title: 'Kind Closure',
        tag: 'End day · 5–7 min',
        bullets: const ['4–7–8 wind-down', 'Name 1 thing done', 'Release the rest'],
        pattern: _pattern478,
      ),
      _MeditationDef(
        title: 'Head-Clear Notes',
        tag: 'Refocus · 4–6 min',
        bullets: const ['In 5 · Out 5', 'Note key thought on paper', 'Return to breath'],
        pattern: _patternResonant15,
      ),
      _MeditationDef(
        title: 'Brief Renewal',
        tag: 'Micro break · 3–5 min',
        bullets: const ['In 4 · Out 4', 'Look far away briefly', 'Back to task refreshed'],
        pattern: _patternDefault,
      ),
      _MeditationDef(
        title: 'Softer Shoulders',
        tag: 'Unknot · 4–6 min',
        bullets: const ['In 4 · Hold 4 · Out 6', 'Roll shoulders gently', 'Exhale the weight down'],
        pattern: _patternTriangle,
      ),
      _MeditationDef(
        title: 'Grateful Close',
        tag: 'Appreciate · 4–6 min',
        bullets: const ['Equal 6–6', 'Three thanks, one breath each', 'Rest in contentment'],
        pattern: _patternEqual66,
      ),
    ];

    _all.clear();
    _all.addAll(items);
    _byTitle.clear();
    for (final d in _all) {
      _byTitle[d.title] = d;
    }
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    _recentTitles = prefs.getStringList(_kRecentsKey) ?? [];
    // Only keep recents that still exist in catalog
    _recentTitles = _recentTitles.where(_byTitle.containsKey).toList();
    setState(() {});
  }

  Future<void> _recordRecent(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentsKey) ?? [];
    // Move-to-front unique
    list.remove(title);
    list.insert(0, title);
    while (list.length > _maxRecents) {
      list.removeLast();
    }
    await prefs.setStringList(_kRecentsKey, list);
    _recentTitles = list;
    if (mounted) setState(() {});
  }

  List<_MeditationDef> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((d) {
      if (d.title.toLowerCase().contains(q)) return true;
      if (d.tag.toLowerCase().contains(q)) return true;
      if (d.pattern.name.toLowerCase().contains(q)) return true;
      for (final b in d.bullets) {
        if (b.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  BoxDecoration _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
            : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
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
      builder: (ctx) => AlertDialog(
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
  }) _phaseAt(double cycleSecondsElapsed) {
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
    // Title row sits in scroll; add safe padding.
    final status = MediaQuery.of(context).padding.top;
    const extra = 8.0;
    return status + extra;
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
        // No AppBar so the header (back + title) scrolls — matches screenshot style
        extendBodyBehindAppBar: false,
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: _bg(context),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: _scrollCtrl,
              padding: EdgeInsets.fromLTRB(16, _topPadding(context), 16, 24),
              children: [
                // --- Screenshot-style header row: subtle back chevron + bold centered title ---
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      // Back button (to Tools / previous page)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: Colors.black),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black,
                        ),
                        tooltip: 'Back',
                      ),
                      // Centered title — keep perfectly centered by balancing trailing space
                      Expanded(
                        child: Center(
                          child: Text(
                            'Meditation',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: .2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Trailing spacer matching IconButton width to keep the title centered
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // --- Search ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.78),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      icon: Icon(Icons.search_rounded),
                      hintText: 'Search meditations, patterns, or tags',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),

                // --- Recently used (persistent) ---
                if (_recentTitles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Recently used',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _recentTitles.map((t) {
                        final def = _byTitle[t]!;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              def.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () async {
                              await _applyPattern(def.pattern, start: true);
                              // keep it at top of recents
                              _recordRecent(def.title);
                            },
                            backgroundColor: Colors.white.withOpacity(.86),
                            side: BorderSide(color: Colors.black.withOpacity(.15)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Breathing visual + timer (FIRST)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.78),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 0.7),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
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
                                          colors: [Colors.white, Color(0xFFBDE5DC)],
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
                            _running ? 'Tap pause anytime' : 'Choose a duration or start an exercise',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _toggle,
                                icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                label: Text(_running ? 'Pause' : 'Start'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _reset,
                                icon: Icon(
                                  Icons.replay_rounded,
                                  color: app.ThemeControllerScope.of(context).isDark
                                      ? const Color.fromARGB(255, 0, 0, 0)
                                      : Colors.black87,
                                ),
                                label: Text(
                                  'Reset',
                                  style: TextStyle(
                                    color: app.ThemeControllerScope.of(context).isDark
                                        ? const Color.fromARGB(255, 0, 0, 0)
                                        : Colors.black87,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  side: BorderSide(
                                    color: app.ThemeControllerScope.of(context).isDark
                                        ? const Color.fromARGB(255, 0, 0, 0).withOpacity(.6)
                                        : Colors.black.withOpacity(.2),
                                  ),
                                  shape: const StadiumBorder(),
                                  backgroundColor: app.ThemeControllerScope.of(context).isDark
                                      ? Colors.white.withOpacity(.15)
                                      : Colors.white.withOpacity(.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // --- Countdown overlay (animated) ---
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 1000),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.4, end: 1.0).animate(
                                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: _preCountdown != null
                            ? Container(
                                key: ValueKey(_preCountdown),
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
                      color: app.ThemeControllerScope.of(context).isDark
                          ? Colors.white.withOpacity(.3)
                          : Colors.black.withOpacity(.2),
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets.map((m) {
                      final selected = _selectedMinutes == m && !_running;
                      final dark = app.ThemeControllerScope.of(context).isDark;
                      return ChoiceChip(
                        label: Text(
                          '${m}m',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: dark
                                ? (selected ? Colors.black : Colors.white)
                                : (selected ? Colors.black : Colors.black87),
                          ),
                        ),
                        selected: selected,
                        onSelected: _running ? null : (_) => _resetToMinutes(m),
                        selectedColor: dark ? const Color.fromARGB(255, 156, 156, 156) : Colors.white,
                        side: BorderSide(
                          color: dark ? Colors.white.withOpacity(.3) : Colors.black.withOpacity(.12),
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
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick tips', style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 8),
                      Text('• Inhale through the nose for ~4s, exhale for ~4s.'),
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

                // Render filtered list
                ..._filtered.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExerciseCard(
                        title: d.title,
                        tag: d.tag,
                        bullets: d.bullets,
                        onPlay: () async {
                          await _applyPattern(d.pattern, start: true);
                          _recordRecent(d.title);
                        },
                      ),
                    )),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              border: Border.all(color: const Color(0xFF0D7C66).withOpacity(.25)),
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
