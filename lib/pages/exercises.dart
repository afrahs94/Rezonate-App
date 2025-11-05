// lib/pages/exercises.dart
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:new_rezonate/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart'; 

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  String _filter = 'All';
  String _query = '';

  // persistent "recently used" list (most recent first)
  final List<_Exercise> _recent = [];
  static const int _recentMax = 8;
  static const String _recentKey = 'recent_exercises_v1';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final titles = prefs.getStringList(_recentKey) ?? const [];
    // Map saved titles back to exercise objects, preserving order and skipping missing
    final mapped = <_Exercise>[];
    for (final t in titles) {
      final match = _exercises.where((e) => e.title == t);
      if (match.isNotEmpty) mapped.add(match.first);
    }
    if (mounted) {
      setState(() {
        _recent
          ..clear()
          ..addAll(mapped.take(_recentMax));
      });
    }
  }

  Future<void> _persistRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recent.map((e) => e.title).toList());
  }

  void _markRecent(_Exercise e) {
    _recent.removeWhere((x) => x.title == e.title);
    _recent.insert(0, e);
    if (_recent.length > _recentMax) {
      _recent.removeRange(_recentMax, _recent.length);
    }
    setState(() {}); // reflect UI immediately
    _persistRecent(); // persist in the background
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

  List<_Exercise> get _filtered {
    final lower = _query.trim().toLowerCase();
    return _exercises.where((e) {
      final matchesFilter = _filter == 'All' || e.tags.contains(_filter);
      final matchesText =
          lower.isEmpty ||
          e.title.toLowerCase().contains(lower) ||
          e.description.toLowerCase().contains(lower) ||
          e.tags.any((t) => t.toLowerCase().contains(lower));
      return matchesFilter && matchesText;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Exercises',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Search
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
                    hintText: 'Search exercises or conditions',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),

              const SizedBox(height: 10),

              // Professional filter bar (horizontal chips) — NO ICONS
              _FilterChipsBar(
                tags: _tags,
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
              ),

              const SizedBox(height: 12),

              // Recently used quick access (persists across visits)
              if (_recent.isNotEmpty) ...[
                const Text(
                  'Recently used',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final ex = _recent[i];
                      return _RecentPill(
                        title: ex.title,
                        minutes: ex.minutes,
                        onTap: () => _openFromRecent(ex),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Count
              Text(
                '${_filtered.length} exercise${_filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              // Cards
              ..._filtered.map(
                (e) => _ExerciseCard(
                  exercise: e,
                  onPlay: () {
                    _markRecent(e);
                    _openPlayer(e);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFromRecent(_Exercise e) {
    _markRecent(e); // keep at front
    _openPlayer(e);
  }

  Future<void> _openPlayer(_Exercise e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PlayerSheet(exercise: e);
      },
    );
  }
}

/* ---------- filter chips without icons ---------- */
class _FilterChipsBar extends StatelessWidget {
  const _FilterChipsBar({
    required this.tags,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tags;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final t in tags) ...[
            _ChipButton(
              label: t,
              selected: t == selected,
              onTap: () => onSelected(t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? const Color(0xFF0D7C66) : Colors.white.withOpacity(.78);
    final fg = selected ? Colors.white : Colors.black87;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ),
    );
  }
}

/* ---------- recent pills ---------- */
class _RecentPill extends StatelessWidget {
  const _RecentPill({
    required this.title,
    required this.minutes,
    required this.onTap,
  });

  final String title;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('${minutes}m'),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onPlay});

  final _Exercise exercise;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + play
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play'),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF7F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0D7C66).withOpacity(.25),
                    ),
                  ),
                  child: Text(
                    '${exercise.minutes}–${exercise.minutes + 2} min',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0D7C66),
                    ),
                  ),
                ),
                ...exercise.tags.map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(t, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(exercise.description),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet player — step-by-step timed tutorial
class _PlayerSheet extends StatefulWidget {
  const _PlayerSheet({required this.exercise});

  final _Exercise exercise;

  @override
  State<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<_PlayerSheet> {
  int _i = 0;
  int _remaining = 0;
  bool _running = false;
  Timer? _t;

  int get _totalSeconds =>
      widget.exercise.steps.fold(0, (a, s) => a + s.seconds);

  int get _elapsedSeconds {
    int sum = 0;
    for (int j = 0; j < _i; j++) {
      sum += widget.exercise.steps[j].seconds;
    }
    return sum + (widget.exercise.steps[_i].seconds - _remaining);
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _reset() {
    _t?.cancel();
    _running = false;
    _i = 0;
    _remaining = widget.exercise.steps[0].seconds;
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_running) {
      _t?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _t = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remaining <= 1) {
          Vibration.hasVibrator().then((hasVibrator) {
            if (hasVibrator ?? false) {
              Vibration.vibrate(duration: 300);
            } else {
              HapticFeedback.mediumImpact();
            }
          });

          if (_i >= widget.exercise.steps.length - 1) {
            timer.cancel();
            setState(() {
              _running = false;
              _remaining = 0;
            });
          } else {
            setState(() {
              _i += 1;
              _remaining = widget.exercise.steps[_i].seconds;
            });
          }
        } else {
          setState(() => _remaining -= 1);
        }
      });
    }
  }

  void _next() {
    if (_i < widget.exercise.steps.length - 1) {
      setState(() {
        _i += 1;
        _remaining = widget.exercise.steps[_i].seconds;
      });
    }
  }

  void _prev() {
    if (_i > 0) {
      setState(() {
        _i -= 1;
        _remaining = widget.exercise.steps[_i].seconds;
      });
    }
  }

  String _mmss(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '$m:${ss.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.exercise.steps[_i];
    final progress = _totalSeconds == 0 ? 0.0 : _elapsedSeconds / _totalSeconds;
    const green = Color(0xFF0D7C66);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.exercise.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.black12,
                color: green,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 16),
              // Step bubble
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF7F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: green.withOpacity(.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Step ${_i + 1} of ${widget.exercise.steps.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(step.instruction, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    Text(
                      _mmss(_remaining),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Wrap controls so they never overflow
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _prev,
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: const Text('Prev'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(_running ? 'Pause' : 'Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Next'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'All steps',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ...widget.exercise.steps.asMap().entries.map((e) {
                final k = e.key;
                final s = e.value;
                final isCurrent = k == _i;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFE1F4EF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${k + 1}. ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Expanded(child: Text(s.title)),
                      Text(
                        '${s.seconds}s',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _Exercise {
  final String title;
  final String description;
  final List<String> tags; // condition categories
  final int minutes; // suggested minutes
  final List<_ExStep> steps;

  const _Exercise({
    required this.title,
    required this.description,
    required this.tags,
    required this.minutes,
    required this.steps,
  });
}

class _ExStep {
  final String title;
  final String instruction;
  final int seconds;

  const _ExStep(this.title, this.instruction, this.seconds);
}

/* ------------------------------- Library -------------------------------- */

// Common tags/filters (first item must be 'All')
const List<String> _tags = [
  'All',
  'Anxiety',
  'Depression',
  'Stress',
  'PTSD',
  'Panic',
  'OCD',
  'ADHD',
  'Sleep',
  'Anger',
  'Grief',
  'Social',
  'Bipolar',
  'Eating',
  'Addiction',
  'Mindfulness',
  'Grounding',
];

List<_ExStep> _breathBox() => const [
  _ExStep('Inhale', 'Breathe in steadily through your nose.', 4),
  _ExStep('Hold', 'Gently hold the breath—soft shoulders, loose jaw.', 4),
  _ExStep('Exhale', 'Exhale slowly through the mouth.', 4),
  _ExStep('Hold', 'Rest before the next inhale.', 4),
];

List<_ExStep> _pmrShort() => const [
  _ExStep('Hands', 'Clench fists for 5s, then release.', 10),
  _ExStep('Arms', 'Tense biceps for 5s, release.', 10),
  _ExStep('Shoulders', 'Shrug up for 5s, release.', 10),
  _ExStep('Face', 'Scrunch gently 5s, release.', 10),
  _ExStep('Core', 'Tighten stomach 5s, release.', 10),
  _ExStep('Legs', 'Press feet into floor 5s, release.', 10),
];

List<_ExStep> _fiveFourThreeTwoOne() => const [
  _ExStep('Look', 'Name 5 things you can see.', 20),
  _ExStep('Touch', 'Notice 4 things you can feel.', 20),
  _ExStep('Hear', 'Identify 3 sounds around you.', 20),
  _ExStep('Smell', 'Notice 2 smells (or remember pleasant ones).', 20),
  _ExStep('Taste', 'Name 1 taste or sip water mindfully.', 20),
];

List<_ExStep> _worryContainment() => const [
  _ExStep('Capture', 'Write brief bullet worries; no solving yet.', 45),
  _ExStep('Schedule', 'Pick a 10–15min “worry window” later today.', 30),
  _ExStep('Redirect', 'Return to present task; breathe 4–6 pattern.', 45),
];

List<_ExStep> _thoughtRecord() => const [
  _ExStep('Situation', 'Note what happened + where/when.', 45),
  _ExStep('Thought', 'Write the automatic thought.', 45),
  _ExStep('Evidence', 'List evidence for and against.', 60),
  _ExStep('Reframe', 'Create a balanced alternative thought.', 60),
];

List<_ExStep> _behavioralActivation() => const [
  _ExStep('Pick', 'Choose 1 small enjoyable/meaningful activity.', 30),
  _ExStep('Plan', 'Plan when/where; set a 5–10m timer.', 45),
  _ExStep('Do', 'Start—focus only on the first minute.', 60),
  _ExStep('Reward', 'Check it off; note how you feel now.', 30),
];

List<_ExStep> _urgeSurfing() => const [
  _ExStep('Notice', 'Label the urge and its intensity (0–10).', 30),
  _ExStep('Breathe', 'Slow exhales; watch the urge like a wave.', 60),
  _ExStep('Ride', 'Tell yourself: “This will peak and pass.”', 60),
  _ExStep('Choose', 'Pick a values-aligned action.', 30),
];

List<_ExStep> _sleepWindDown() => const [
  _ExStep('Lights', 'Dim lights, reduce screens and noise.', 60),
  _ExStep('Body', 'Gentle stretches or warm shower.', 60),
  _ExStep('Mind', 'Journaling or gratitude list (3 items).', 60),
  _ExStep('Breathe', '4–7–8 breathing for 4 cycles.', 60),
];

List<_ExStep> _stopSkill() => const [
  _ExStep('Stop', 'Freeze the impulse—don’t act yet.', 10),
  _ExStep('Take a breath', 'One slow breath to create space.', 10),
  _ExStep('Observe', 'What do you feel/think? What are the facts?', 30),
  _ExStep('Proceed', 'Act wisely toward your values.', 30),
];

List<_ExStep> _tipDbs() => const [
  _ExStep('Temp', 'Cool down: splash cold water or hold an ice pack.', 30),
  _ExStep('Intense exercise', '1–2 min vigorous movement.', 60),
  _ExStep('Paced breathing', 'Exhale longer than inhale (~4/6).', 60),
  _ExStep('Paired muscle relax', 'Brief tense–release cycles.', 30),
];

List<_ExStep> _socialWarmup() => const [
  _ExStep('Micro-smile', 'Relax jaw; soft eye contact practice.', 20),
  _ExStep('Opener', 'Prepare one friendly question.', 30),
  _ExStep('Approach', 'Say hello to someone nearby (or text).', 40),
  _ExStep('Reflect', 'Note something that went okay.', 30),
];

List<_ExStep> _exposurePlanning() => const [
  _ExStep('List', 'Write 5 feared situations (1–10 scale).', 45),
  _ExStep('Pick', 'Choose one medium challenge (4–6).', 30),
  _ExStep('Plan', 'Define a 10–15m exposure; no safety behaviors.', 60),
  _ExStep('Review', 'Log anxiety peak and drop afterward.', 45),
];

List<_ExStep> _compassionBreak() => const [
  _ExStep('Mindful moment', 'Acknowledge: “This is hard.”', 20),
  _ExStep('Common humanity', '“Others struggle too; I’m not alone.”', 20),
  _ExStep('Kindness', 'Place hand on chest; say something kind.', 30),
];

List<_ExStep> _valuesClarify() => const [
  _ExStep('Domains', 'Choose one domain (health, family, work…).', 30),
  _ExStep('Qualities', 'List 3 qualities of the person you want to be.', 45),
  _ExStep('Action', 'Write 1 tiny action that reflects those.', 45),
];

List<_ExStep> _breath478() => const [
  _ExStep('Inhale', 'Inhale through nose (4s).', 4),
  _ExStep('Hold', 'Hold gently (7s).', 7),
  _ExStep('Exhale', 'Exhale slowly through mouth (8s).', 8),
];

List<_ExStep> _miniGround() => const [
  _ExStep('Feet', 'Press feet into floor; notice support.', 20),
  _ExStep('Name', 'Say your full name and today’s date.', 15),
  _ExStep('Look', 'Name three colors you can see.', 20),
];

List<_ExStep> _gratitude3() => const [
  _ExStep('One', 'Write one thing you’re grateful for.', 30),
  _ExStep('Two', 'Write a second (different domain).', 30),
  _ExStep('Three', 'Write a third + why it matters.', 45),
];

List<_ExStep> _safePlace() => const [
  _ExStep('Visualize', 'Imagine a safe, calm place in detail.', 60),
  _ExStep('Sense', 'What can you see, hear, smell, feel there?', 60),
  _ExStep('Anchor', 'Choose a word/picture as an anchor.', 30),
];

List<_ExStep> _bodyScanShort() => const [
  _ExStep('Head', 'Notice sensations in face and head.', 30),
  _ExStep('Chest', 'Notice breath in chest and ribs.', 30),
  _ExStep('Belly', 'Let abdomen soften as you breathe.', 30),
  _ExStep('Legs', 'Scan down to toes, relaxing as you go.', 30),
];

List<_ExStep> _oppositeAction() => const [
  _ExStep('Name emotion', 'Identify emotion + urge (e.g., avoid).', 30),
  _ExStep('Check facts', 'Is the threat realistic/probable?', 45),
  _ExStep('Act opposite', 'Choose a small opposite action.', 45),
];

final List<_Exercise> _baseExercises = [
  _Exercise(
    title: '5-4-3-2-1 Grounding',
    description: 'Orient to the present using your senses.',
    tags: ['Anxiety', 'Panic', 'PTSD', 'Grounding'],
    minutes: 3,
    steps: _fiveFourThreeTwoOne(),
  ),
  _Exercise(
    title: 'Box Breathing',
    description: 'Stabilize the nervous system with 4-4-4-4 breaths.',
    tags: ['Anxiety', 'Stress', 'Panic', 'Mindfulness'],
    minutes: 4,
    steps: _breathBox(),
  ),
  _Exercise(
    title: '4-7-8 Breathing',
    description: 'Wind down with extended exhales.',
    tags: ['Anxiety', 'Sleep', 'Stress', 'Mindfulness'],
    minutes: 3,
    steps: _breath478(),
  ),
  _Exercise(
    title: 'Mini Grounding',
    description: 'Quick reset for sudden spikes of anxiety.',
    tags: ['Anxiety', 'Panic', 'PTSD', 'Grounding'],
    minutes: 2,
    steps: _miniGround(),
  ),
  _Exercise(
    title: 'Interoceptive Practice (Panic)',
    description: 'Reduce fear of body sensations by practicing safely.',
    tags: ['Panic', 'Anxiety'],
    minutes: 5,
    steps: const [
      _ExStep(
        'Spin gently',
        'Stand and spin slowly for 10–15s, then stop and notice sensations.',
        30,
      ),
      _ExStep(
        'Stairs/step-ups',
        'Walk faster or step-up to raise heart rate briefly.',
        60,
      ),
      _ExStep('Recovery', 'Breathe slowly and label sensations as safe.', 60),
    ],
  ),
  _Exercise(
    title: 'TIP Skill (DBT)',
    description: 'Fast physiology downshift for high distress.',
    tags: ['Anxiety', 'Panic', 'Anger', 'Stress'],
    minutes: 4,
    steps: _tipDbs(),
  ),
  _Exercise(
    title: 'Safe Place Visualization',
    description: 'Imagine and anchor a personally safe scene.',
    tags: ['PTSD', 'Anxiety', 'Sleep', 'Mindfulness'],
    minutes: 4,
    steps: _safePlace(),
  ),
  _Exercise(
    title: 'Body Scan (Short)',
    description: 'Tune into the body with curiosity.',
    tags: ['Mindfulness', 'Anxiety', 'Sleep', 'Stress'],
    minutes: 4,
    steps: _bodyScanShort(),
  ),
  _Exercise(
    title: 'Progressive Muscle Relaxation',
    description: 'Release tension with tense–release cycles.',
    tags: ['Anxiety', 'Stress', 'Sleep'],
    minutes: 5,
    steps: _pmrShort(),
  ),
  _Exercise(
    title: 'Breath Counting',
    description: 'Count breaths 1–10; start over when distracted.',
    tags: ['Mindfulness', 'Anxiety', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Settle', 'Sit tall; soften shoulders and jaw.', 30),
      _ExStep('Count', 'Count “in-1, out-2 … up to 10”, repeat.', 120),
      _ExStep('Finish', 'Noting how you feel, open your eyes.', 30),
    ],
  ),
  _Exercise(
    title: 'Behavioral Activation – Tiny Task',
    description: 'Do one small, rewarding activity to nudge mood.',
    tags: ['Depression', 'Stress'],
    minutes: 5,
    steps: _behavioralActivation(),
  ),
  _Exercise(
    title: 'Gratitude x 3',
    description: 'Write three specific things and why they matter.',
    tags: ['Depression', 'Stress', 'Mindfulness'],
    minutes: 4,
    steps: _gratitude3(),
  ),
  _Exercise(
    title: 'Self-Compassion Break',
    description: 'Respond to pain with kindness, not criticism.',
    tags: ['Depression', 'Anxiety', 'Grief', 'Mindfulness'],
    minutes: 3,
    steps: _compassionBreak(),
  ),
  _Exercise(
    title: 'Values Clarification (ACT)',
    description: 'Reconnect to what matters and pick one action.',
    tags: ['Depression', 'Stress', 'Bipolar'],
    minutes: 4,
    steps: _valuesClarify(),
  ),
  _Exercise(
    title: 'Thought Record (CBT)',
    description: 'Balance unhelpful thoughts with evidence.',
    tags: ['Depression', 'Anxiety', 'OCD'],
    minutes: 6,
    steps: _thoughtRecord(),
  ),
  _Exercise(
    title: 'Worry Window',
    description: 'Contain worry and protect the present moment.',
    tags: ['Anxiety'],
    minutes: 4,
    steps: _worryContainment(),
  ),
  _Exercise(
    title: 'Label & Let Be',
    description: 'Note thoughts as “thinking” and refocus.',
    tags: ['Mindfulness', 'Anxiety', 'OCD'],
    minutes: 4,
    steps: const [
      _ExStep('Note', 'When a thought appears, label it: “thinking”.', 60),
      _ExStep('Refocus', 'Return attention to breath or task.', 60),
      _ExStep('Repeat', 'Practice for a few minutes.', 60),
    ],
  ),
  _Exercise(
    title: 'Social Warm-Up',
    description: 'Prep a safe opener and practice one approach.',
    tags: ['Social', 'Anxiety'],
    minutes: 4,
    steps: _socialWarmup(),
  ),
  _Exercise(
    title: 'Exposure Planning',
    description: 'Design a small step toward feared situations.',
    tags: ['Anxiety', 'OCD', 'PTSD', 'Social'],
    minutes: 5,
    steps: _exposurePlanning(),
  ),
  _Exercise(
    title: 'Opposite Action',
    description: 'Gently act against unhelpful emotion urges.',
    tags: ['Depression', 'Anxiety', 'Anger', 'Bipolar'],
    minutes: 4,
    steps: _oppositeAction(),
  ),
  _Exercise(
    title: 'STOP Skill',
    description: 'Pause before reacting; choose a wise action.',
    tags: ['Anger', 'Anxiety', 'Stress'],
    minutes: 2,
    steps: _stopSkill(),
  ),
  _Exercise(
    title: 'Wind-Down Routine',
    description: 'Create a calm 10–15m runway into sleep.',
    tags: ['Sleep', 'Anxiety', 'Stress'],
    minutes: 5,
    steps: _sleepWindDown(),
  ),
  _Exercise(
    title: 'Stimulus Control (CBT-I)',
    description: 'Strengthen the bed–sleep connection.',
    tags: ['Sleep'],
    minutes: 5,
    steps: const [
      _ExStep('Out of bed', 'If awake >20m, get up under dim light.', 60),
      _ExStep('Calm activity', 'Read paper book or breathe slowly.', 60),
      _ExStep('Return', 'Return to bed when sleepy. Repeat if needed.', 60),
    ],
  ),
  _Exercise(
    title: 'Cold Water Reset',
    description: 'Use cold stimulus to drop arousal fast.',
    tags: ['Anger', 'Panic', 'Stress'],
    minutes: 2,
    steps: const [
      _ExStep('Cool', 'Splash cold water on face 10–20s.', 30),
      _ExStep('Breathe', 'Exhale longer than inhale.', 45),
    ],
  ),
  _Exercise(
    title: 'Count to 20 + Reframe',
    description: 'Create space before responding.',
    tags: ['Anger', 'Stress'],
    minutes: 2,
    steps: const [
      _ExStep('Pause', 'Count slowly to 20.', 40),
      _ExStep('Phrase', 'Choose one respectful sentence to start.', 40),
    ],
  ),
  _Exercise(
    title: 'Ground & Name (Trauma)',
    description: 'Reduce flashback intensity with orientation.',
    tags: ['PTSD', 'Anxiety', 'Grounding'],
    minutes: 3,
    steps: const [
      _ExStep('Orient', 'Say your full name, place, and date.', 30),
      _ExStep('Sense', 'Press feet and back into support; breathe.', 60),
      _ExStep('Look', 'Describe 3 neutral objects around you.', 45),
    ],
  ),
  _Exercise(
    title: 'Nightmare Rehearsal',
    description: 'Rewrite one nightmare with a safer ending.',
    tags: ['PTSD', 'Sleep', 'Anxiety'],
    minutes: 6,
    steps: const [
      _ExStep('Write', 'Briefly describe the dream (no gore).', 90),
      _ExStep('Change', 'Alter ending to safe/neutral.', 90),
      _ExStep('Rehearse', 'Visualize new version twice calmly.', 120),
    ],
  ),
  _Exercise(
    title: 'ERP Mini – Ritual Delay',
    description: 'Delay a compulsion briefly and watch anxiety fall.',
    tags: ['OCD', 'Anxiety'],
    minutes: 4,
    steps: const [
      _ExStep('Choose', 'Pick one ritual to delay 5 minutes.', 30),
      _ExStep('Delay', 'Set timer; focus on slow exhales.', 180),
      _ExStep('Log', 'Record anxiety drop (0–10).', 30),
    ],
  ),
  _Exercise(
    title: 'Body-Double Sprint',
    description: 'Work alongside a buddy (or timer) for 10 min.',
    tags: ['ADHD', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Set up', 'Pick a tiny task; clear desk.', 60),
      _ExStep('Sprint', 'Work with a 5–10m timer; no switching.', 180),
      _ExStep('Check-off', 'Mark done; take 1m break.', 60),
    ],
  ),
  _Exercise(
    title: 'Visual To-Do (3 items)',
    description: 'Reduce overwhelm by limiting to the vital three.',
    tags: ['ADHD', 'Depression', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('Dump', 'Write all tasks fast (2 min).', 120),
      _ExStep('Pick 3', 'Circle the most important three.', 30),
      _ExStep('Order', 'Choose the first tiny action.', 30),
    ],
  ),
  _Exercise(
    title: 'Urge Surfing',
    description: 'Ride cravings like waves without acting on them.',
    tags: ['Addiction', 'Anxiety', 'Stress'],
    minutes: 4,
    steps: _urgeSurfing(),
  ),
  _Exercise(
    title: 'Delay & Distract',
    description: 'Delay the urge and switch contexts.',
    tags: ['Addiction', 'OCD', 'Eating'],
    minutes: 3,
    steps: const [
      _ExStep('Delay', 'Set a 10m timer; wait before acting.', 60),
      _ExStep('Move', 'Change rooms; step outside or walk.', 60),
      _ExStep('Distract', 'Do a 3–5m absorbing task.', 60),
    ],
  ),
  _Exercise(
    title: 'Regular Eating Cue',
    description: 'Plan the next meal/snack at a steady time.',
    tags: ['Eating', 'Anxiety'],
    minutes: 3,
    steps: const [
      _ExStep('Time', 'Schedule the next meal/snack.', 45),
      _ExStep('Prep', 'Choose a balanced, safe option.', 60),
      _ExStep('Commit', 'Put reminder & tell a supporter.', 45),
    ],
  ),
  _Exercise(
    title: 'Grief Wave',
    description: 'Make space for emotion, then re-engage.',
    tags: ['Grief', 'Depression'],
    minutes: 5,
    steps: const [
      _ExStep('Allow', 'Sit with feelings; name them kindly.', 90),
      _ExStep('Remember', 'Recall a story or photo briefly.', 90),
      _ExStep('Re-engage', 'Do a small grounding act (walk, tea).', 120),
    ],
  ),
  _Exercise(
    title: 'Leaf on a Stream',
    description: 'Place thoughts on leaves floating by.',
    tags: ['Mindfulness', 'Anxiety', 'Depression'],
    minutes: 4,
    steps: const [
      _ExStep('Imagine', 'See a gentle stream with leaves.', 60),
      _ExStep('Place', 'Put each thought onto a leaf; watch float by.', 90),
      _ExStep('Return', 'Return attention to breath/body.', 60),
    ],
  ),
  _Exercise(
    title: 'Counting Backwards by 7s',
    description: 'Cognitive grounding to disrupt spirals.',
    tags: ['Anxiety', 'Panic', 'Grounding'],
    minutes: 3,
    steps: const [
      _ExStep('Start', 'Pick a number (e.g., 300).', 20),
      _ExStep('Count', 'Subtract 7 repeatedly; speak aloud if you can.', 80),
      _ExStep('Breathe', 'Finish with 3 slow breaths.', 40),
    ],
  ),
  _Exercise(
    title: 'Name the Colors',
    description: 'Label colors you see; keep eyes moving.',
    tags: ['Panic', 'Grounding', 'PTSD'],
    minutes: 2,
    steps: const [
      _ExStep('Scan', 'Name 10 different colors around you.', 60),
      _ExStep('Settle', 'Notice your seat and feet supporting you.', 30),
    ],
  ),
  _Exercise(
    title: 'Walking Mindfulness',
    description: 'Notice steps, contact, and surroundings.',
    tags: ['Mindfulness', 'Depression', 'Anxiety'],
    minutes: 5,
    steps: const [
      _ExStep('Feet', 'Feel heel–toe; count 10 quiet steps.', 60),
      _ExStep('Senses', 'Look for details, listen for distant sounds.', 120),
      _ExStep('Gratitude', 'Name one thing you appreciate here.', 60),
    ],
  ),
  _Exercise(
    title: 'Sunlight Boost',
    description: 'Morning light to lift mood and anchor the day.',
    tags: ['Depression', 'Sleep', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Step outside', 'Get 5–10 minutes of daylight if safe.', 180),
      _ExStep('Breathe', 'Slow, easy breathing as you stand/walk.', 120),
    ],
  ),
  _Exercise(
    title: 'Journaling – 5 Lines',
    description: 'Reduce pressure: just five honest lines.',
    tags: ['Depression', 'Anxiety', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Prompt', '“Right now I notice…” Write 5 lines.', 180),
      _ExStep('Close', 'Circle one small next step.', 60),
    ],
  ),
  _Exercise(
    title: 'Plan the First Minute',
    description: 'Beat avoidance by planning just the first 60s.',
    tags: ['Depression', 'ADHD', 'Anxiety'],
    minutes: 3,
    steps: const [
      _ExStep('Target', 'Choose the task you avoid.', 45),
      _ExStep('Minute 1', 'Plan exactly what 60s looks like.', 45),
      _ExStep('Go', 'Start now; stop after 1m if needed.', 60),
    ],
  ),
  _Exercise(
    title: 'Kind Reappraisal',
    description: 'Reframe with compassion and accuracy.',
    tags: ['Depression', 'Anxiety', 'Social'],
    minutes: 4,
    steps: const [
      _ExStep('Event', 'Note what happened briefly.', 45),
      _ExStep('Alternative', 'Draft one kinder, realistic view.', 60),
      _ExStep('Action', 'Pick a small next behavior from that view.', 45),
    ],
  ),
  _Exercise(
    title: 'Breathing with a Phrase',
    description: 'Anchor breath with words like “In… Out…”.',
    tags: ['Mindfulness', 'Anxiety'],
    minutes: 4,
    steps: const [
      _ExStep('Choose', 'Pick a simple phrase to pair with breath.', 30),
      _ExStep('Breathe', 'Repeat phrase silently with inhales/exhales.', 120),
      _ExStep('Finish', 'Soften shoulders; notice any shift.', 30),
    ],
  ),
  _Exercise(
    title: 'Chair Stretch Reset',
    description: 'Loosen tension in 3 minutes.',
    tags: ['Stress', 'Anxiety'],
    minutes: 3,
    steps: const [
      _ExStep('Neck', 'Slow side stretches, gentle half-circles.', 60),
      _ExStep('Back', 'Seated twists left/right; easy range.', 60),
      _ExStep('Hips', 'Ankle on knee stretch; switch sides.', 60),
    ],
  ),
  _Exercise(
    title: 'Savoring Snapshot',
    description: 'Take a deliberate mental picture of a good moment.',
    tags: ['Depression', 'Stress', 'Mindfulness'],
    minutes: 3,
    steps: const [
      _ExStep('Notice', 'Find one small pleasant detail now.', 45),
      _ExStep('Savor', 'Hold attention on it for 30–60s.', 60),
      _ExStep('Store', 'Breathe in; say “thank you” internally.', 30),
    ],
  ),
  _Exercise(
    title: 'Urge Log (2-Minute)',
    description: 'Track urges quickly to spot patterns.',
    tags: ['Addiction', 'Eating', 'OCD'],
    minutes: 2,
    steps: const [
      _ExStep('Note', 'Write time, trigger, intensity (0–10).', 60),
      _ExStep('Alternate', 'Pick a healthy alternative (walk, text).', 60),
    ],
  ),
  _Exercise(
    title: 'Social Smile + Hello',
    description: 'Micro-exposure for social anxiety.',
    tags: ['Social', 'Anxiety'],
    minutes: 2,
    steps: const [
      _ExStep('Practice', 'Relax face; soft smile; breathe.', 30),
      _ExStep('Say hello', 'Greet one person or send a friendly text.', 60),
      _ExStep('Reflect', 'What went OK? One learning.', 30),
    ],
  ),
  _Exercise(
    title: 'Plan a Pleasant Event',
    description: 'Schedule one small joy this week.',
    tags: ['Depression', 'Stress'],
    minutes: 4,
    steps: const [
      _ExStep('Choose', 'Pick something truly enjoyable.', 60),
      _ExStep('Schedule', 'Pick day/time; invite a friend if helpful.', 60),
      _ExStep('Prepare', 'Note any supplies or reminders.', 60),
    ],
  ),
  _Exercise(
    title: 'Morning Check-In',
    description: 'Set tone with intention + one action.',
    tags: ['Depression', 'ADHD', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('Intention', '“Today I want to be more …”', 45),
      _ExStep('Action', 'One 5-minute action toward that.', 60),
      _ExStep('Plan', 'Put it on calendar or set a timer.', 45),
    ],
  ),
  _Exercise(
    title: 'Evening Shutdown',
    description: 'Close loops to reduce next-day anxiety.',
    tags: ['Anxiety', 'Sleep', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Capture', 'List open loops; 2-minute brain dump.', 120),
      _ExStep('Pick 3', 'Star the 3 most important for tomorrow.', 60),
      _ExStep('Wind-down', 'Begin your bedtime routine.', 60),
    ],
  ),
  _Exercise(
    title: 'Anger Cool-Down Walk',
    description: 'Walk briskly; exhale longer to discharge energy.',
    tags: ['Anger', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Walk', '3–5 minutes brisk walk, safe area.', 180),
      _ExStep('Exhale', 'Focus on long, slow exhales.', 90),
    ],
  ),
  _Exercise(
    title: 'Compassion Letter (Short)',
    description: 'Write to yourself as you would to a friend.',
    tags: ['Depression', 'Grief', 'Anxiety'],
    minutes: 5,
    steps: const [
      _ExStep('Dear me', 'One paragraph validating the struggle.', 120),
      _ExStep('Kind wish', 'One paragraph of encouragement.', 120),
    ],
  ),
  _Exercise(
    title: 'Micro-Exposure: Perfectionism',
    description: 'Publish a “good-enough” draft now.',
    tags: ['Anxiety', 'OCD', 'Depression'],
    minutes: 3,
    steps: const [
      _ExStep('Set limit', '5–10m timebox; no polishing.', 60),
      _ExStep('Ship it', 'Send or post to the intended place.', 60),
      _ExStep('Note', 'What happened? What was okay?', 60),
    ],
  ),
  _Exercise(
    title: 'If-Then Plan',
    description: 'Prepare one coping action for a trigger.',
    tags: ['Anxiety', 'Addiction', 'ADHD'],
    minutes: 3,
    steps: const [
      _ExStep('If', 'Identify a trigger (time/place/situation).', 45),
      _ExStep('Then', 'Pick one concrete response you will do.', 45),
      _ExStep('Practice', 'Rehearse the sentence out loud.', 45),
    ],
  ),
  _Exercise(
    title: 'Breath + Count Down',
    description: 'Inhale 4, exhale 6, count down 5→1 with each exhale.',
    tags: ['Panic', 'Anxiety'],
    minutes: 3,
    steps: const [
      _ExStep('Start', 'Inhale 4, exhale 6 – say 5 on exhale.', 60),
      _ExStep('Continue', 'Repeat to 4,3,2,1…', 60),
      _ExStep('Finish', 'Notice any change in body tension.', 30),
    ],
  ),
  _Exercise(
    title: 'Finger Tapping Focus',
    description: 'Gently tap thumb to each finger while breathing.',
    tags: ['Anxiety', 'ADHD', 'Mindfulness'],
    minutes: 2,
    steps: const [
      _ExStep('Tap', 'Index, middle, ring, pinky… and back.', 60),
      _ExStep('Breathe', 'Match taps to slow breaths.', 30),
    ],
  ),
  _Exercise(
    title: 'S.T.O.P. for Social Fear',
    description: 'Mini-pause before speaking in groups.',
    tags: ['Social', 'Anxiety'],
    minutes: 2,
    steps: _stopSkill(),
  ),
  _Exercise(
    title: 'Morning Light Stretch',
    description: 'Wake the body gently with 3 poses.',
    tags: ['Depression', 'Sleep', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('Reach', 'Arms overhead stretch + yawn.', 40),
      _ExStep('Fold', 'Forward fold; bend knees as needed.', 40),
      _ExStep('Open', 'Chest opener with hands behind back.', 40),
    ],
  ),
  _Exercise(
    title: 'Three Good Things',
    description: 'End the day by recalling three positives.',
    tags: ['Depression', 'Stress'],
    minutes: 4,
    steps: _gratitude3(),
  ),
  _Exercise(
    title: 'Calm Counting Breath',
    description: 'In 4, out 6 – simple and steady.',
    tags: ['Anxiety', 'Stress', 'Sleep'],
    minutes: 3,
    steps: const [
      _ExStep('Posture', 'Sit tall; relax shoulders.', 20),
      _ExStep('Breath', 'In 4, out 6 for ~8–10 cycles.', 120),
    ],
  ),
  _Exercise(
    title: 'Ground with Objects',
    description: 'Hold a cool or textured object; describe it.',
    tags: ['PTSD', 'Panic', 'Grounding'],
    minutes: 2,
    steps: const [
      _ExStep('Hold', 'Notice weight, texture, temperature.', 60),
      _ExStep('Describe', 'Use 5 adjectives out loud.', 40),
    ],
  ),
  _Exercise(
    title: 'Reality Check (Catastrophizing)',
    description: 'Estimate probabilities; plan if/then.',
    tags: ['Anxiety', 'OCD'],
    minutes: 4,
    steps: const [
      _ExStep('List fear', 'Write feared outcome.', 45),
      _ExStep('Percent', 'Estimate realistic probability.', 45),
      _ExStep('Plan', 'If it happened, what would you do?', 60),
    ],
  ),
  _Exercise(
    title: 'Emotion Labeling',
    description: 'Name the emotion to tame the reaction.',
    tags: ['Anger', 'Anxiety', 'Depression'],
    minutes: 2,
    steps: const [
      _ExStep('Scan', 'Ask: What emotion? Where do I feel it?', 45),
      _ExStep('Say', '“I am noticing … and that’s understandable.”', 45),
    ],
  ),
  _Exercise(
    title: '10-Minute Tidy',
    description: 'Clear visual clutter to calm the mind.',
    tags: ['ADHD', 'Depression', 'Stress'],
    minutes: 5,
    steps: const [
      _ExStep('Pick zone', 'Choose one surface or corner.', 60),
      _ExStep('Timer', '2–5 min tidy; trash/recycle first.', 120),
      _ExStep('Reward', 'Enjoy a small pleasant activity.', 60),
    ],
  ),
  _Exercise(
    title: 'Soothe with Senses',
    description: 'Use one pleasant stimulus for each sense.',
    tags: ['Anxiety', 'Depression', 'Stress'],
    minutes: 4,
    steps: const [
      _ExStep('See', 'Look at a favorite photo or nature.', 45),
      _ExStep('Hear', 'Play one calming song.', 60),
      _ExStep('Smell/Taste/Touch', 'Tea, lotion, or soft blanket.', 60),
    ],
  ),
  _Exercise(
    title: 'Tiny Exposure – Contamination',
    description: 'Touch a “medium-scary” object; delay washing.',
    tags: ['OCD', 'Anxiety'],
    minutes: 5,
    steps: const [
      _ExStep('Choose', 'Pick an item (e.g., doorknob).', 45),
      _ExStep('Touch', 'Touch without washing for 5 minutes.', 180),
      _ExStep('Log', 'Record anxiety from start to end.', 45),
    ],
  ),
  _Exercise(
    title: 'Bipolar Sleep Anchor',
    description: 'Protect routine with a fixed wake time.',
    tags: ['Bipolar', 'Sleep'],
    minutes: 3,
    steps: const [
      _ExStep('Choose', 'Pick a realistic daily wake time.', 45),
      _ExStep('Plan', 'Adjust bedtime and evening habits.', 60),
      _ExStep('Commit', 'Set alarm + backup plan.', 45),
    ],
  ),
  _Exercise(
    title: 'Energy Check (Depression)',
    description: 'Match task size to today’s fuel.',
    tags: ['Depression'],
    minutes: 3,
    steps: const [
      _ExStep('Rate', '0–10 energy today?', 20),
      _ExStep('Choose', 'Pick a task scaled to energy.', 50),
      _ExStep('Do', '1–5 minutes toward it.', 60),
    ],
  ),
  _Exercise(
    title: 'ADHD Timer Chain',
    description: 'Chain 3 x 10-minute sprints with 2-minute breaks.',
    tags: ['ADHD'],
    minutes: 6,
    steps: const [
      _ExStep('Sprint 1', '10m on task; mute notifications.', 60),
      _ExStep('Break', '2m stand/water/breathe.', 30),
      _ExStep('Sprint 2', '10m more; keep momentum.', 60),
    ],
  ),
  _Exercise(
    title: 'Coping Cards',
    description: 'Write 3 balanced statements for your triggers.',
    tags: ['Anxiety', 'OCD', 'Depression'],
    minutes: 4,
    steps: const [
      _ExStep('Trigger', 'Pick one common trigger.', 40),
      _ExStep('Write', 'Draft a balanced statement.', 60),
      _ExStep('Practice', 'Read aloud 3 times; carry with you.', 45),
    ],
  ),
  _Exercise(
    title: 'Small Talk Ladder',
    description: 'Gradual steps to build confidence.',
    tags: ['Social', 'Anxiety'],
    minutes: 4,
    steps: const [
      _ExStep('Step 1', 'Eye contact + smile.', 40),
      _ExStep('Step 2', 'Say hello to a neighbor/coworker.', 50),
      _ExStep('Step 3', 'Ask one open question.', 50),
    ],
  ),
  _Exercise(
    title: 'Morning Sun + Water',
    description: 'Hydrate and light = simple mood support.',
    tags: ['Depression', 'Sleep'],
    minutes: 3,
    steps: const [
      _ExStep('Water', 'Drink a glass of water.', 30),
      _ExStep('Light', 'Stand near daylight for a few minutes.', 60),
      _ExStep('Breathe', '3 slow breaths before screen time.', 30),
    ],
  ),
  _Exercise(
    title: 'Micro-Meditation 2m',
    description: 'Two minutes of pure attention.',
    tags: ['Mindfulness', 'Anxiety', 'Stress'],
    minutes: 2,
    steps: const [
      _ExStep('Focus', 'Attend to breath or sound.', 60),
      _ExStep('Return', 'When distracted, gently return.', 60),
    ],
  ),
  _Exercise(
    title: 'Sensory Reset (Cold–Warm–Soft)',
    description: 'Quick sensory grounding using temperature and texture.',
    tags: ['Anxiety', 'Panic', 'Grounding', 'PTSD'],
    minutes: 3,
    steps: const [
      _ExStep('Cold', 'Hold something cool for 10–20s.', 30),
      _ExStep('Warm', 'Wrap in blanket or hold mug for warmth.', 45),
      _ExStep('Soft', 'Touch something comforting like fabric.', 45),
    ],
  ),
  _Exercise(
    title: 'Micro-Meditation (1 Minute)',
    description: 'Train focus with a single minute of mindful breathing.',
    tags: ['Mindfulness', 'Anxiety', 'Stress'],
    minutes: 1,
    steps: const [
      _ExStep('Set timer', 'One minute only.', 10),
      _ExStep('Breathe', 'Focus entirely on breath sensations.', 40),
      _ExStep('Finish', 'Notice one word that describes how you feel.', 10),
    ],
  ),
  _Exercise(
    title: 'Affirmation Practice',
    description: 'Replace self-criticism with balanced statements.',
    tags: ['Depression', 'Anxiety', 'Grief'],
    minutes: 3,
    steps: const [
      _ExStep(
        'Identify',
        'Write one harsh thought you often say to yourself.',
        45,
      ),
      _ExStep(
        'Reframe',
        'Write a balanced truth (e.g., “I’m trying my best”).',
        60,
      ),
      _ExStep('Repeat', 'Say the new phrase 3 times aloud.', 45),
    ],
  ),
  _Exercise(
    title: 'Mood Rating & Note',
    description: 'Quick awareness tool for emotion tracking.',
    tags: ['Bipolar', 'Depression', 'Stress'],
    minutes: 2,
    steps: const [
      _ExStep('Rate', 'Rate mood 0–10 right now.', 20),
      _ExStep('Note', 'Write 1–2 triggers or events today.', 45),
      _ExStep('Plan', 'Pick one stabilizing action (e.g., walk, water).', 45),
    ],
  ),
  _Exercise(
    title: 'Anchoring Phrase',
    description: 'Create a calm phrase to repeat during distress.',
    tags: ['Anxiety', 'PTSD', 'Panic'],
    minutes: 2,
    steps: const [
      _ExStep('Choose', 'Pick phrase (e.g., “I’m safe right now”).', 30),
      _ExStep('Repeat', 'Say aloud or in mind with slow breaths.', 60),
    ],
  ),
  _Exercise(
    title: 'Guided Imagery: Calm Morning',
    description: 'Visualize a peaceful morning scene to reset mood.',
    tags: ['Anxiety', 'Depression', 'Stress'],
    minutes: 4,
    steps: const [
      _ExStep('Imagine', 'Picture a soft morning light, safe place.', 60),
      _ExStep('Engage', 'Notice 3 senses: sound, smell, texture.', 60),
      _ExStep('Breathe', 'Stay with the image for a few breaths.', 60),
    ],
  ),
  _Exercise(
    title: 'Mini Gratitude Text',
    description: 'Send one short appreciation message.',
    tags: ['Social', 'Depression', 'Mindfulness'],
    minutes: 2,
    steps: const [
      _ExStep('Pick', 'Choose one person who helped or matters.', 30),
      _ExStep('Write', 'Send a short thank-you or kind check-in.', 60),
    ],
  ),
  _Exercise(
    title: 'Distraction Plan (Crisis)',
    description: 'Prepare safe distractions for intense urges.',
    tags: ['Addiction', 'Self-Harm', 'Anxiety'],
    minutes: 4,
    steps: const [
      _ExStep('List', 'Write 3 safe distractions (music, walk, call).', 60),
      _ExStep('Prep', 'Keep items or contacts easy to reach.', 60),
      _ExStep('Use', 'Use list at first sign of high urge.', 60),
    ],
  ),
  _Exercise(
    title: 'Gentle Movement Reset',
    description: 'Loosen body tension to regulate emotion.',
    tags: ['Stress', 'Anxiety', 'Depression'],
    minutes: 3,
    steps: const [
      _ExStep('Roll', 'Roll shoulders and neck slowly.', 45),
      _ExStep('Stretch', 'Reach arms overhead; exhale slowly.', 45),
      _ExStep('Shake', 'Gently shake arms/legs for release.', 45),
    ],
  ),
  _Exercise(
    title: 'Tiny Goal Tracker',
    description: 'Celebrate micro-progress for motivation.',
    tags: ['ADHD', 'Depression', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('Pick', 'Choose one goal you worked on today.', 45),
      _ExStep('Note', 'Write one thing you did toward it.', 45),
      _ExStep('Reward', 'Acknowledge progress (smile, mark done).', 45),
    ],
  ),
  _Exercise(
    title: 'Coping Card',
    description: 'Write reminders for hard moments.',
    tags: ['Anxiety', 'Depression', 'PTSD'],
    minutes: 3,
    steps: const [
      _ExStep('Write', 'One sentence you want to remember when upset.', 60),
      _ExStep('Keep', 'Save on phone lock screen or paper.', 45),
    ],
  ),
  _Exercise(
    title: 'Eating Check-In',
    description: 'Pause before meals to connect with body cues.',
    tags: ['Eating', 'Anxiety', 'Mindfulness'],
    minutes: 3,
    steps: const [
      _ExStep('Pause', 'Take 3 slow breaths before eating.', 30),
      _ExStep('Notice', 'Ask: Am I hungry, bored, or stressed?', 60),
      _ExStep('Begin', 'Eat first bites slowly, noticing texture.', 60),
    ],
  ),
  _Exercise(
    title: 'Urge Wave Visualization',
    description: 'Imagine cravings like waves that crest and fall.',
    tags: ['Addiction', 'Anxiety', 'OCD'],
    minutes: 3,
    steps: const [
      _ExStep('Notice', 'Visualize the craving as a rising wave.', 45),
      _ExStep('Ride', 'Breathe and picture it cresting + fading.', 60),
      _ExStep('Reflect', 'See that it passed without acting.', 45),
    ],
  ),
  _Exercise(
    title: 'Reconnecting Memory',
    description: 'Recall a time you felt supported or strong.',
    tags: ['Grief', 'Depression', 'PTSD'],
    minutes: 4,
    steps: const [
      _ExStep('Recall', 'Think of one caring moment or ally.', 60),
      _ExStep('Feel', 'Notice sensations or emotions that arise.', 60),
      _ExStep('Anchor', 'Hold that feeling for 2 breaths.', 60),
    ],
  ),
  _Exercise(
    title: 'One-Minute Nature Pause',
    description: 'Reset attention with something living.',
    tags: ['Mindfulness', 'Depression', 'Stress'],
    minutes: 1,
    steps: const [
      _ExStep('Look', 'Find one plant, sky, or animal nearby.', 20),
      _ExStep('Observe', 'Watch movement, color, or sound.', 40),
    ],
  ),
  _Exercise(
    title: 'Sleep Thought Dump',
    description: 'Write thoughts to clear the mind before bed.',
    tags: ['Sleep', 'Anxiety', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('Write', 'List any lingering thoughts or worries.', 90),
      _ExStep('Close', 'Say “I’ll handle this tomorrow.”', 45),
    ],
  ),
  _Exercise(
    title: 'Mindful Sip',
    description: 'Ground yourself with a single mindful drink.',
    tags: ['Mindfulness', 'Anxiety', 'Stress'],
    minutes: 2,
    steps: const [
      _ExStep('Observe', 'Notice smell, warmth, color.', 30),
      _ExStep('Sip', 'Feel the liquid; swallow slowly.', 45),
      _ExStep('Breathe', 'Take one slow exhale after each sip.', 30),
    ],
  ),
  _Exercise(
    title: 'Social Mini-Goal',
    description: 'Create one achievable social step for today.',
    tags: ['Social', 'Anxiety', 'Depression'],
    minutes: 3,
    steps: const [
      _ExStep('Plan', 'Pick one safe person to connect with.', 45),
      _ExStep('Act', 'Send message or wave hello.', 45),
      _ExStep('Reflect', 'Note what felt okay afterward.', 45),
    ],
  ),
  _Exercise(
    title: 'Hope List',
    description: 'List small things you still look forward to.',
    tags: ['Depression', 'Grief', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('List', 'Write 3 things that bring a spark of interest.', 60),
      _ExStep('Choose', 'Circle one you can do this week.', 45),
    ],
  ),
  _Exercise(
    title: 'Breath + Posture Reset',
    description: 'Quick alignment to signal calm to the nervous system.',
    tags: ['Anxiety', 'Stress', 'Mindfulness'],
    minutes: 2,
    steps: const [
      _ExStep('Straighten', 'Lift chest slightly; relax shoulders.', 30),
      _ExStep('Inhale', 'Deep breath through nose, feel ribs expand.', 30),
      _ExStep('Exhale', 'Slowly through mouth; drop tension.', 30),
      _ExStep('Repeat', 'Two more cycles, softer each time.', 30),
    ],
  ),
  _Exercise(
    title: 'Urge Wave Sketch',
    description: 'Draw your craving like a wave to visualize rise and fall.',
    tags: ['Addiction', 'Anxiety', 'Stress'],
    minutes: 3,
    steps: const [
      _ExStep('Draw', 'Sketch a wave—label “urge intensity”.', 45),
      _ExStep('Track', 'Mark where you are right now on the curve.', 60),
      _ExStep('Wait', 'Breathe and let time move you down the wave.', 60),
    ],
  ),
  _Exercise(
    title: 'Self-Talk Audit',
    description: 'Catch and reword unhelpful inner dialogue.',
    tags: ['Depression', 'Anxiety', 'OCD'],
    minutes: 4,
    steps: const [
      _ExStep('Notice', 'Write one recent harsh thought.', 45),
      _ExStep('Ask', 'Would I say this to a friend?', 45),
      _ExStep('Reword', 'Rewrite it with accuracy and kindness.', 60),
    ],
  ),
  _Exercise(
    title: 'Ground by Counting Shapes',
    description: 'Cognitive grounding using geometry.',
    tags: ['Anxiety', 'Panic', 'PTSD', 'Grounding'],
    minutes: 2,
    steps: const [
      _ExStep('Look', 'Find 5 circles, 5 squares, 5 triangles.', 60),
      _ExStep('Breathe', 'Slow exhale while scanning next shape.', 45),
    ],
  ),
  _Exercise(
    title: 'The 10-Second Kind Act',
    description: 'Fast boost of meaning and connection.',
    tags: ['Depression', 'Social', 'Stress'],
    minutes: 2,
    steps: const [
      _ExStep('Pick', 'Think of one tiny kindness (message, smile).', 30),
      _ExStep('Do', 'Complete it now—keep it simple.', 45),
      _ExStep('Note', 'Notice how that felt, even if small.', 30),
    ],
  ),
  _Exercise(
    title: 'ADHD Momentum Loop',
    description: 'Build inertia with micro-commitments.',
    tags: ['ADHD', 'Depression', 'Stress'],
    minutes: 4,
    steps: const [
      _ExStep('Choose', 'Pick a 2-min doable task.', 45),
      _ExStep('Do', 'Start timer; work until it dings.', 120),
      _ExStep('Decide', 'Continue 2 more mins or stop with pride.', 60),
    ],
  ),
  _Exercise(
    title: 'Emotional Weather Check',
    description: 'Label and rate the day’s “weather” to track patterns.',
    tags: ['Depression', 'Bipolar', 'Anxiety'],
    minutes: 3,
    steps: const [
      _ExStep('Forecast', 'Pick a weather word for mood (sunny, foggy…).', 45),
      _ExStep('Rate', '0–10 intensity; note any triggers.', 60),
      _ExStep('Adjust', 'Choose one gentle act of care.', 45),
    ],
  ),
  _Exercise(
    title: 'Five-Breath Reset',
    description: 'Portable grounding to fit any context.',
    tags: ['Anxiety', 'Stress', 'Panic', 'Mindfulness'],
    minutes: 2,
    steps: const [
      _ExStep('One', 'Notice the first inhale and exhale fully.', 20),
      _ExStep('Two–Four', 'Relax one body part each breath.', 60),
      _ExStep('Five', 'Smile softly; open eyes wider.', 20),
    ],
  ),
];

/// === Final exercises list (includes all base items, no artificial limit) ===
final List<_Exercise> _exercises = [..._baseExercises];
