// lib/pages/tips.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _showBack = false;
  final _rng = Random();

  // Search (single button -> bottom sheet)
  String _query = '';

  List<_Tip> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _allTips;
    return _allTips.where((t) {
      final hay = '${t.condition} ${t.short} ${t.details} ${t.tips.join(" ")} ${t.keywords.join(" ")}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _applyNext() {
    final list = _filtered;
    if (list.isEmpty) return;
    setState(() {
      _showBack = false;
      _index = (_index + 1) % list.length;
    });
  }

  void _applyPrev() {
    final list = _filtered;
    if (list.isEmpty) return;
    setState(() {
      _showBack = false;
      _index = (_index - 1) < 0 ? list.length - 1 : _index - 1;
    });
  }

  void _applyShuffle() {
    final list = _filtered;
    if (list.isEmpty) return;
    setState(() {
      _showBack = false;
      _index = _rng.nextInt(list.length);
    });
  }

  Future<void> _openSearchSheet() async {
    final controller = TextEditingController(text: _query);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Search Flashcards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g., “panic”, “sleep”, “OCD”, “trauma”, “ADHD focus”, …',
                  prefixIcon: const Icon(Icons.search_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
                onSubmitted: (v) {
                  Navigator.pop(ctx);
                  setState(() {
                    _query = v;
                    _index = 0;
                    _showBack = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _query = controller.text;
                          _index = 0;
                          _showBack = false;
                        });
                      },
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _query = '';
                          _index = 0;
                          _showBack = false;
                        });
                      },
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final tip = list.isEmpty ? null : list[_index.clamp(0, list.length - 1)];
    const green = Color(0xFF0D7C66);

    // Choose a fixed card height to prevent page jumping
    final screenH = MediaQuery.of(context).size.height;
    final double cardHeight = screenH <= 700 ? 260 : 300;

    Widget flashcardDeck() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inline search chip
          InkWell(
            onTap: _openSearchSheet,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _query.isEmpty ? 'Search flashcards' : 'Search: “$_query” (tap to change)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton.filledTonal(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _query = '';
                        _index = 0;
                        _showBack = false;
                      }),
                      icon: const Icon(Icons.clear_rounded),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Fixed-height flashcard (front/back) to stop layout shifts
          SizedBox(
            height: cardHeight,
            child: tip == null
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 1),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: const Center(
                      child: Text(
                        'No results. Try changing your search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _showBack = !_showBack),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: Tween<double>(begin: .98, end: 1).animate(anim), child: child),
                      child: _showBack
                          ? _BackCard(key: const ValueKey('back'), tip: tip)
                          : _FrontCard(key: const ValueKey('front'), tip: tip),
                    ),
                  ),
          ),

          // Combined centered controls with NO backgrounds
          const SizedBox(height: 12),
          if (list.isNotEmpty)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Previous',
                    visualDensity: VisualDensity.compact,
                    onPressed: _applyPrev,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: _applyShuffle,
                    style: TextButton.styleFrom(
                      foregroundColor: green,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Next',
                    visualDensity: VisualDensity.compact,
                    onPressed: _applyNext,
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_index + 1}/${list.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final contentChildren = <Widget>[
      flashcardDeck(),
      const SizedBox(height: 20),
      // Interactive Crash Courses (launch as pop-ups)
      const _CrashCourses(),
      const SizedBox(height: 20),
      // Disclaimer
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          'These cards are educational only and not medical advice. '
          'If you’re in crisis, call your local emergency number or a crisis hotline.',
          style: TextStyle(fontSize: 12.5, color: Colors.black87),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              // Scrollable header
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                floating: false,
                pinned: false,
                snap: false,
                title: const Text(
                  'Tips',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: .2),
                ),
              ),

              // Page content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(contentChildren),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({super.key, required this.tip});
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tip.condition,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              tip.short,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.touch_app_rounded, color: Colors.black45),
            const SizedBox(height: 4),
            const Text('Tap to flip', style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({super.key, required this.tip});
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.condition, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(tip.details),
                const SizedBox(height: 10),
                const Text('Try:', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ...tip.tips.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(t)),
                        ],
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

// ---------------- INTERACTIVE CRASH COURSES (POP-UPS) ----------------

class _CrashCourses extends StatelessWidget {
  const _CrashCourses();

  @override
  Widget build(BuildContext context) {
    // Titles only (no grey subtitles).
    Widget box({required String title, required _CourseData data}) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: ListTile(
            title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            trailing: const Icon(Icons.play_circle_fill_rounded),
            onTap: () => _openCourse(context, data),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        box(title: 'Crash Course: Depression', data: _depressionCourse),
        box(title: 'Crash Course: Anxiety', data: _anxietyCourse),
        box(title: 'Crash Course: ADHD', data: _adhdCourse),
        box(title: 'Crash Course: PTSD', data: _ptsdCourse),
        box(title: 'Crash Course: Sleep', data: _sleepCourse),
        box(title: 'Crash Course: OCD / ERP', data: _ocdErpCourse),
        box(title: 'Crash Course: Stress Management', data: _stressCourse),
        box(title: 'Crash Course: Mindfulness', data: _mindfulnessCourse),
        box(title: 'Crash Course: Eating Regularity', data: _eatingCourse),
        box(title: 'Crash Course: Grief & Loss', data: _griefCourse),
      ],
    );
  }

  Future<void> _openCourse(BuildContext context, _CourseData data) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
        child: _CourseModal(data: data),
      ),
    );
  }
}

class _CourseModal extends StatefulWidget {
  final _CourseData data;
  const _CourseModal({required this.data});

  @override
  State<_CourseModal> createState() => _CourseModalState();
}

class _CourseModalState extends State<_CourseModal> {
  late final List<_Slide> _slides;
  int _i = 0;
  int? _selected;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _slides = widget.data.mergedSlides;
  }

  void _next() {
    setState(() {
      if (_i < _slides.length - 1) {
        _i++;
        _selected = null;
        _checked = false;
      }
    });
  }

  void _prev() {
    setState(() {
      if (_i > 0) {
        _i--;
        _selected = null;
        _checked = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_i];
    final pct = (_i + 1) / _slides.length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, minHeight: 420),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.data.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 10,
                              backgroundColor: Colors.black12,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF0D7C66)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Slide ${_i + 1}/${_slides.length}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 1),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: slide.map(
                      content: (c) => _ContentSlideView(content: c),
                      quiz: (q) => _QuizSlideView(
                        quiz: q,
                        selected: _selected,
                        checked: _checked,
                        onSelect: (v) => setState(() => _selected = v),
                        onCheck: () => setState(() => _checked = true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _i > 0 ? _prev : null,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      label: const Text('Back'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: (_i < _slides.length - 1)
                          ? () {
                              final isQuiz = slide.when(quiz: (_) => true, content: (_) => false);
                              if (isQuiz && !_checked) return;
                              _next();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      label: const Text('Next'),
                    ),
                    const Spacer(),
                    if (_i == _slides.length - 1)
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Slide Views

class _ContentSlideView extends StatelessWidget {
  final _ContentSlide content;
  const _ContentSlideView({required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content.heading, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...content.bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(b)),
                  ],
                ),
              )),
          if (content.tip != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D7C66).withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0D7C66).withOpacity(.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.tip!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizSlideView extends StatelessWidget {
  final _QuizData quiz;
  final int? selected;
  final bool checked;
  final ValueChanged<int> onSelect;
  final VoidCallback onCheck;

  const _QuizSlideView({
    required this.quiz,
    required this.selected,
    required this.checked,
    required this.onSelect,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = (selected != null && selected == quiz.correctIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pop Quiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(quiz.question),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: quiz.options.length,
            itemBuilder: (_, i) => RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: Text(quiz.options[i]),
              value: i,
              groupValue: selected,
              onChanged: (v) {
                if (v != null) onSelect(v);
              },
            ),
          ),
        ),
        Row(
          children: [
            FilledButton(
              onPressed: selected == null ? null : onCheck,
              child: const Text('Check Answer'),
            ),
            const SizedBox(width: 8),
            if (checked)
              Row(
                children: [
                  Icon(isCorrect ? Icons.check_circle : Icons.cancel),
                  const SizedBox(width: 6),
                  Text(isCorrect ? 'Correct!' : 'Not quite'),
                ],
              ),
          ],
        ),
        if (checked) ...[
          const SizedBox(height: 8),
          Text(quiz.rationale),
        ],
      ],
    );
  }
}

// ---------- Course Data Model

class _CourseData {
  final String title;
  final List<_ContentSlide> contentSlides; // usually 10
  final List<_QuizData> quizzes; // usually 5

  const _CourseData({
    required this.title,
    required this.contentSlides,
    required this.quizzes,
  });

  // Interleave as: C1, C2, Q1, C3, C4, Q2, C5, C6, Q3, C7, C8, Q4, C9, C10, Q5
  List<_Slide> get mergedSlides {
    final List<_Slide> out = [];
    int c = 0, q = 0;
    while (c < contentSlides.length) {
      out.add(_Slide.content(contentSlides[c++]));
      if (c % 2 == 0 && q < quizzes.length) {
        out.add(_Slide.quiz(quizzes[q++]));
      }
    }
    while (q < quizzes.length) {
      out.add(_Slide.quiz(quizzes[q++]));
    }
    return out;
  }
}

/// Base slide type (content or quiz)
abstract class _Slide {
  const _Slide();
  static _Slide content(_ContentSlide contentSlide) => contentSlide;
  static _Slide quiz(_QuizData quiz) => _QuizSlide(quiz);

  T map<T>({
    required T Function(_ContentSlide) content,
    required T Function(_QuizData) quiz,
  }) {
    if (this is _ContentSlide) return content(this as _ContentSlide);
    return quiz((this as _QuizSlide).data);
  }

  T when<T>({
    required T Function(_QuizData) quiz,
    required T Function(_ContentSlide) content,
  }) {
    return map(content: content, quiz: quiz);
  }
}

class _ContentSlide extends _Slide {
  final String heading;
  final List<String> bullets;
  final String? tip;
  const _ContentSlide({required this.heading, required this.bullets, this.tip});
}

class _QuizSlide extends _Slide {
  final _QuizData data;
  const _QuizSlide(this.data);
}

// ---------------- QUIZ DATA TYPE ----------------

class _QuizData {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String rationale;
  const _QuizData({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.rationale,
  });
}

// ---------------- COURSE CONTENT (same as previous turn, with +6 added) ----------------

// Depression
final _CourseData _depressionCourse = _CourseData(
  title: 'Crash Course: Depression',
  contentSlides: const [
    _ContentSlide(
      heading: 'What is Depression?',
      bullets: [
        'A mood disorder with persistent low mood and loss of interest (anhedonia).',
        'Often includes sleep/appetite changes, fatigue, concentration problems.',
        'It is common and treatable; support and care help recovery.',
      ],
      tip: 'Depression is not a personal failure—symptoms are real and valid.',
    ),
    _ContentSlide(
      heading: 'How It Works (Brain & Behavior)',
      bullets: [
        'Negative thinking patterns can narrow attention to losses and threats.',
        'Reduced activity lowers opportunities for pleasure/mastery → vicious cycle.',
        'Sleep and light exposure strongly affect energy and mood.',
      ],
      tip: 'Small, reliable routines begin restoring energy and motivation.',
    ),
    _ContentSlide(
      heading: 'Behavioral Activation Basics',
      bullets: [
        'Action often precedes motivation (not the other way around).',
        'Schedule tiny, specific, doable activities daily.',
        'Track what improves mood/energy a little (mastery/pleasure).',
      ],
      tip: 'Use a 5-minute rule: start for 5 minutes, then reassess.',
    ),
    _ContentSlide(
      heading: 'Routines & Anchors',
      bullets: [
        'Keep a consistent wake time; get light within an hour of waking.',
        'Anchor meals and short movement to stabilize circadian rhythm.',
        'Batch difficult tasks when energy is best.',
      ],
      tip: 'A 10–20 minute daylight walk can lift energy and regulate the clock.',
    ),
    _ContentSlide(
      heading: 'Thought Skills (CBT)',
      bullets: [
        'Notice thinking traps: all-or-nothing, catastrophizing, mind-reading.',
        'Check the evidence and consider alternative explanations.',
        'Experiment: test predictions with small real-world actions.',
      ],
      tip: 'Write “What would I tell a friend?” to de-personalize self-criticism.',
    ),
    _ContentSlide(
      heading: 'Social Connection',
      bullets: [
        'Isolation maintains low mood; gentle reach-outs matter.',
        'Plan low-pressure contact (text, walk, 15-minute call).',
        'Support groups or therapy can add accountability and skills.',
      ],
      tip: 'If reaching out feels hard, send a simple emoji or short check-in.',
    ),
    _ContentSlide(
      heading: 'Sleep Hygiene for Mood',
      bullets: [
        'Fixed wake time; avoid long naps and late caffeine.',
        'Bed reserved for sleep/intimacy; if awake >20 min, get up briefly.',
        'Wind-down with low light and relaxing cues.',
      ],
      tip: 'Treat bedtime like a landing: dim lights, reduce stimulation, repeat nightly.',
    ),
    _ContentSlide(
      heading: 'Movement & Body',
      bullets: [
        'Gentle activity (walk, stretch) is enough to start.',
        'Aim for consistency over intensity; pair with music or nature.',
        'Fuel with regular meals; dehydration worsens fatigue.',
      ],
    ),
    _ContentSlide(
      heading: 'Values & Meaning',
      bullets: [
        'Identify what matters (kindness, learning, family, creativity).',
        'Schedule tiny actions aligned with values to rebuild meaning.',
        'Progress, not perfection—celebrate small steps.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek More Help',
      bullets: [
        'If symptoms persist or worsen despite self-help steps.',
        'If there are thoughts of self-harm or suicide—seek urgent help.',
        'Therapies (e.g., CBT) and medications can be effective together.',
      ],
      tip: 'Crisis resources and local emergency numbers are available 24/7.',
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'Behavioral activation primarily emphasizes…',
      options: [
        'Waiting for motivation before acting.',
        'Starting tiny, scheduled actions to rebuild motivation.',
        'Eliminating all negative thoughts first.',
        'Avoiding routines to stay flexible.',
      ],
      correctIndex: 1,
      rationale: 'Small, scheduled actions create mastery/pleasure loops that lift mood.',
    ),
    _QuizData(
      question: 'Which is most likely a thinking trap?',
      options: [
        'Considering multiple explanations.',
        'All-or-nothing conclusions after a single setback.',
        'Tracking mastery and pleasure.',
        'Scheduling a 10-minute walk.',
      ],
      correctIndex: 1,
      rationale: 'All-or-nothing thinking is a classic cognitive distortion.',
    ),
    _QuizData(
      question: 'A practical sleep step is to…',
      options: [
        'Vary wake time daily to “catch up.”',
        'Use bed for work to associate it with productivity.',
        'Keep a fixed wake time and dim lights before bed.',
        'Drink strong coffee late to ensure focus.',
      ],
      correctIndex: 2,
      rationale: 'Stable wake times and low light cues support circadian regulation.',
    ),
    _QuizData(
      question: 'Which social step best breaks isolation?',
      options: [
        'Waiting until you feel fully better to reach out.',
        'Scheduling a low-pressure 15-minute call or walk.',
        'Avoiding people to prevent rejection.',
        'Only messaging when you have “big news.”',
      ],
      correctIndex: 1,
      rationale: 'Gentle, predictable contact rebuilds connection without overwhelm.',
    ),
    _QuizData(
      question: 'Values work focuses on…',
      options: [
        'Doing what others expect.',
        'Perfect outcomes every time.',
        'Identifying what matters and taking small aligned actions.',
        'Avoiding all uncomfortable feelings.',
      ],
      correctIndex: 2,
      rationale: 'Values-aligned micro-steps restore meaning and momentum.',
    ),
  ],
);

// Anxiety
final _CourseData _anxietyCourse = _CourseData(
  title: 'Crash Course: Anxiety',
  contentSlides: const [
    _ContentSlide(
      heading: 'Anxiety Basics',
      bullets: [
        'Anxiety is a body alarm tuned to detect possible threats.',
        'It often fires “false positives” in modern life.',
        'Short-term relief behaviors can reinforce long-term anxiety.',
      ],
      tip: 'Label sensations: “My alarm is loud, not necessarily accurate.”',
    ),
    _ContentSlide(
      heading: 'Avoidance & Reassurance',
      bullets: [
        'Avoidance reduces anxiety now but teaches “danger” later.',
        'Excess reassurance keeps the cycle alive.',
        'Opposite action: approach in small, doable steps.',
      ],
    ),
    _ContentSlide(
      heading: 'Exposure Ladders',
      bullets: [
        'List feared situations from easier → harder.',
        'Approach gradually and repeat until anxiety dips.',
        'Track SUDS (0–100) during practices.',
      ],
    ),
    _ContentSlide(
      heading: 'Interoceptive Exposure',
      bullets: [
        'Practice body sensations (e.g., spinning, running in place) safely.',
        'Learn that sensations are tolerable and pass on their own.',
        'Reduces fear-of-fear for panic.',
      ],
      tip: 'Always practice in safe settings and stop if medically risky.',
    ),
    _ContentSlide(
      heading: 'Breathing & Grounding',
      bullets: [
        '4-in / 6-out breathing calms arousal.',
        '5–4–3–2–1 senses to reorient to the present.',
        'Relax shoulders/jaw; lengthen exhale.',
      ],
    ),
    _ContentSlide(
      heading: 'Worry Windows',
      bullets: [
        'Schedule a daily 10-minute “worry time.”',
        'Postpone worries to that window; jot down cues.',
        'Train the brain that worries can wait.',
      ],
    ),
    _ContentSlide(
      heading: 'Thinking Skills',
      bullets: [
        'Catch catastrophizing and probability inflation.',
        'Ask: “What evidence supports/contradicts my fear?”',
        'Make “likely/best/worst” plans.',
      ],
    ),
    _ContentSlide(
      heading: 'Behavioral Experiments',
      bullets: [
        'Test feared predictions with small experiments.',
        'Collect disconfirming data.',
        'Confidence grows as experiments succeed.',
      ],
    ),
    _ContentSlide(
      heading: 'Lifestyle Supports',
      bullets: [
        'Sleep regularity and movement lower baseline arousal.',
        'Limit caffeine/alcohol when sensitive.',
        'Plan tiny, daily wins for mastery.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek More Help',
      bullets: [
        'If anxiety severely impairs daily life.',
        'CBT/exposure therapies are effective; meds can help.',
        'Seek urgent help for crisis or safety concerns.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'What maintains anxiety long-term?',
      options: [
        'Gradual exposure and repetition.',
        'Avoidance and constant reassurance.',
        'Labeling sensations as temporary.',
        'Scheduling a worry window.',
      ],
      correctIndex: 1,
      rationale: 'Avoidance/reassurance give short relief but reinforce threat beliefs.',
    ),
    _QuizData(
      question: 'Interoceptive exposure targets…',
      options: [
        'Only thoughts.',
        'Body sensations feared in panic.',
        'Time management.',
        'Sleep timing.',
      ],
      correctIndex: 1,
      rationale: 'Practicing feared sensations reduces fear-of-fear.',
    ),
    _QuizData(
      question: 'Effective breathing pattern here is…',
      options: [
        '6-in / 4-out (short exhale).',
        '4-in / 6-out (long exhale).',
        'Hold breath for 30 seconds.',
        'Very rapid breaths.',
      ],
      correctIndex: 1,
      rationale: 'Longer exhale activates parasympathetic calming.',
    ),
    _QuizData(
      question: 'A worry window helps by…',
      options: [
        'Eliminating all worries permanently.',
        'Postponing worry to a set time to reduce rumination.',
        'Increasing reassurance-seeking.',
        'Avoiding responsibilities.',
      ],
      correctIndex: 1,
      rationale: 'Containment weakens the habit loop of constant rumination.',
    ),
    _QuizData(
      question: 'Behavioral experiments aim to…',
      options: [
        'Prove fears true.',
        'Collect real-world data that often disconfirms fears.',
        'Avoid feared situations entirely.',
        'Replace therapy.',
      ],
      correctIndex: 1,
      rationale: 'Small tests often show feared outcomes are less likely/severe.',
    ),
  ],
);

// ADHD
final _CourseData _adhdCourse = _CourseData(
  title: 'Crash Course: ADHD',
  contentSlides: const [
    _ContentSlide(
      heading: 'ADHD Overview',
      bullets: [
        'Differences in executive functions: attention, working memory, inhibition.',
        '“Out of sight, out of mind” is common.',
        'Support is about environment design, not willpower.',
      ],
      tip: 'Make tasks visible at the point-of-performance.',
    ),
    _ContentSlide(
      heading: 'Externalizing Tasks',
      bullets: [
        'Use visible boards, checklists, and alarms.',
        'Keep tools in the open where you need them.',
        'Reduce friction to start (one-tap timers, prepped workspace).',
      ],
    ),
    _ContentSlide(
      heading: 'Time Boxing & Sprints',
      bullets: [
        'Short, capped work sprints (e.g., 20–25 min) plus short breaks.',
        'Use loud/visible timers and clear stop rules.',
        'Start with a “2-minute entry ramp.”',
      ],
      tip: 'End sprints with a tiny note of the very next step.',
    ),
    _ContentSlide(
      heading: 'Body-Doubling & Context',
      bullets: [
        'Work alongside someone (in-person/virtual) to boost initiation.',
        'Choose low-distraction spaces tailored to the task.',
        'Use music/white noise if helpful.',
      ],
    ),
    _ContentSlide(
      heading: 'Task Design',
      bullets: [
        'Break into micro-steps; define “done.”',
        'Front-load easy wins to build momentum.',
        'Batch similar tasks together.',
      ],
    ),
    _ContentSlide(
      heading: 'Tools & Apps',
      bullets: [
        'One-tap timers, calendar alerts, sticky notes, visual kanban.',
        'Use “distraction parking lot” to capture off-task ideas.',
        'Automate recurring routines.',
      ],
    ),
    _ContentSlide(
      heading: 'Environment Tweaks',
      bullets: [
        'Declutter the immediate workspace; remove temptations.',
        'Prepare materials ahead (night-before staging).',
        'Consider standing desk or movement breaks.',
      ],
    ),
    _ContentSlide(
      heading: 'Rewards & Momentum',
      bullets: [
        'Pair tasks with small rewards (music, snack, stretch).',
        'Gamify progress; celebrate micro-completions.',
        'Track streaks visually.',
      ],
    ),
    _ContentSlide(
      heading: 'Energy Management',
      bullets: [
        'Sleep, movement, nutrition strongly affect focus.',
        'Match task difficulty to your best energy windows.',
        'Hydration and protein-rich meals can help steadiness.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek More Help',
      bullets: [
        'If impairments persist, discuss with a clinician.',
        'Coaching and behavioral therapy can add strategies.',
        'Medication may be appropriate; monitor effects carefully.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'Best setup to kickstart focus:',
      options: [
        'Keep everything in your head.',
        'Use a visible timer and a short, capped sprint.',
        'Wait for motivation.',
        'Work where distractions are highest.',
      ],
      correctIndex: 1,
      rationale: 'External timers + short sprints lower activation barriers.',
    ),
    _QuizData(
      question: 'Point-of-performance means…',
      options: [
        'Doing tasks only at night.',
        'Placing cues/tools exactly where the task happens.',
        'Keeping tools hidden to avoid clutter.',
        'Memorizing long to-do lists.',
      ],
      correctIndex: 1,
      rationale: 'Visible cues at the action location prompt initiation.',
    ),
    _QuizData(
      question: 'A sprint should end with…',
      options: [
        'A total clean stop and forget the task.',
        'Writing the very next small step.',
        'Adding 5 more random tasks.',
        'Deleting the timer.',
      ],
      correctIndex: 1,
      rationale: 'Next tiny step lowers friction to restart.',
    ),
    _QuizData(
      question: 'Distraction parking lot helps by…',
      options: [
        'Encouraging multitasking.',
        'Capturing off-task thoughts to return later.',
        'Reminding you to check social media.',
        'Eliminating all distractions forever.',
      ],
      correctIndex: 1,
      rationale: 'It preserves ideas while protecting focus time.',
    ),
    _QuizData(
      question: 'Energy alignment suggests…',
      options: [
        'Do hardest work when you’re most tired.',
        'Match task difficulty to peak energy windows.',
        'Ignore sleep and nutrition.',
        'Only work in long marathons.',
      ],
      correctIndex: 1,
      rationale: 'Timing tasks to energy improves output and reduces friction.',
    ),
  ],
);

// PTSD
final _CourseData _ptsdCourse = _CourseData(
  title: 'Crash Course: PTSD',
  contentSlides: const [
    _ContentSlide(
      heading: 'PTSD Overview',
      bullets: [
        'Symptoms: intrusions, avoidance, negative mood/cognition, arousal.',
        'Triggers can be external (places) or internal (sensations/memories).',
        'Recovery focuses on safety, skills, and gradual processing.',
      ],
      tip: 'Name it: “This is a trauma reminder; I am in the present.”',
    ),
    _ContentSlide(
      heading: 'Grounding Skills',
      bullets: [
        'Orient to present using senses (5–4–3–2–1).',
        'Slow breathing and muscle relaxation lower arousal.',
        'Create a safe place visualization.',
      ],
    ),
    _ContentSlide(
      heading: 'Understanding Avoidance',
      bullets: [
        'Avoidance gives short relief but keeps fear networks alive.',
        'Approach in small, planned steps to relearn safety.',
        'Track triggers and plan graded practices.',
      ],
      tip: 'Work with support; do not force exposure when overwhelmed.',
    ),
    _ContentSlide(
      heading: 'Exposure & Processing',
      bullets: [
        'Therapies (e.g., TF-CBT, CPT, PE, EMDR) help process memories.',
        'Approach reminders in a controlled, titrated way.',
        'Learning: feared cues can be tolerated and reprocessed.',
      ],
    ),
    _ContentSlide(
      heading: 'Nightmares & IRT',
      bullets: [
        'Rewrite recurring nightmares with a safe/empowering ending.',
        'Rehearse new script in daytime to retrain imagery.',
        'Pair with sleep hygiene steps.',
      ],
    ),
    _ContentSlide(
      heading: 'Routines & Predictability',
      bullets: [
        'Regular sleep/meals/movement reduce baseline arousal.',
        'Plan transitions and buffer time.',
        'Use calming rituals (music, scent, light).',
      ],
    ),
    _ContentSlide(
      heading: 'Support Systems',
      bullets: [
        'Identify two safe people and places.',
        'Practice asking for specific support (“sit with me for 10 minutes”).',
        'Consider groups/peer support with boundaries.',
      ],
    ),
    _ContentSlide(
      heading: 'Coping with Intrusions',
      bullets: [
        'Label: “A memory, not danger now.”',
        'Use grounding + present cues (temperature, textures, colors).',
        'Reduce trauma-content media at high-stress times.',
      ],
    ),
    _ContentSlide(
      heading: 'Self-Compassion & Pace',
      bullets: [
        'Healing is nonlinear; expect ups and downs.',
        'Respect your window of tolerance.',
        'Celebrate small gains and rests.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek More Help',
      bullets: [
        'If symptoms impair life or safety concerns arise.',
        'Trauma-focused therapies have strong evidence.',
        'Crisis resources are available 24/7.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'A key mechanism of exposure is…',
      options: [
        'Erasing traumatic memories.',
        'Learning that reminders can be tolerated and reprocessed.',
        'Avoiding triggers forever.',
        'Constant reassurance.',
      ],
      correctIndex: 1,
      rationale: 'Exposure teaches safety by approaching reminders in a controlled way.',
    ),
    _QuizData(
      question: 'Grounding uses…',
      options: [
        'Only thoughts.',
        'Senses and breathing to orient to the present.',
        'Social media.',
        'Skipping sleep.',
      ],
      correctIndex: 1,
      rationale: 'Sensory orientation + slow breathing reduce arousal.',
    ),
    _QuizData(
      question: 'IRT for nightmares involves…',
      options: [
        'Rewatching the nightmare repeatedly before sleep.',
        'Writing a new, safe ending and rehearsing it in daytime.',
        'Avoiding sleep altogether.',
        'Taking long daytime naps.',
      ],
      correctIndex: 1,
      rationale: 'Image Rehearsal Therapy retrains the imagery system.',
    ),
    _QuizData(
      question: 'Avoidance tends to…',
      options: [
        'Increase functioning long-term.',
        'Maintain fear networks despite short-term relief.',
        'Cure PTSD.',
        'Have no effect.',
      ],
      correctIndex: 1,
      rationale: 'Avoidance prevents corrective learning.',
    ),
    _QuizData(
      question: '“Window of tolerance” means…',
      options: [
        'Always push to the max.',
        'A personal arousal zone where learning/coping is possible.',
        'Ignore all feelings.',
        'Stay home forever.',
      ],
      correctIndex: 1,
      rationale: 'Working within this window enables steady, safe progress.',
    ),
  ],
);

// ---------- NEW COURSES (+6) ----------

// Sleep
final _CourseData _sleepCourse = _CourseData(
  title: 'Crash Course: Sleep',
  contentSlides: const [
    _ContentSlide(
      heading: 'Sleep Basics',
      bullets: [
        'Two-process model: sleep pressure + circadian rhythm.',
        'Regularity beats perfection—aim for consistent wake time.',
        'Light and caffeine strongly shape timing and depth.',
      ],
      tip: 'Morning light + movement are powerful anchors.',
    ),
    _ContentSlide(
      heading: 'CBT-I Principles',
      bullets: [
        'Stimulus control: bed = sleep/intimacy only.',
        'Sleep restriction: match time in bed to actual sleep, then expand.',
        'Get up if awake >20 minutes; reset with low light.',
      ],
    ),
    _ContentSlide(
      heading: 'Wind-Down Routine',
      bullets: [
        'Last hour: dim lights, quiet tasks, reduce screens or use filters.',
        'Repeat the same cues nightly to teach the brain.',
        'Pack for tomorrow earlier to avoid late arousal.',
      ],
    ),
    _ContentSlide(
      heading: 'Circadian Tweaks',
      bullets: [
        'Bright light early shifts clock earlier; late light shifts it later.',
        'Keep nights dim and cool; mornings bright and active.',
        'Gradual 15–30 minute shifts are easier to stick to.',
      ],
    ),
    _ContentSlide(
      heading: 'Naps & Caffeine',
      bullets: [
        'Limit naps to ~20 minutes and before late afternoon.',
        'Stop caffeine 6–8 hours before bedtime if sensitive.',
        'Hydration helps; avoid heavy late meals.',
      ],
    ),
    _ContentSlide(
      heading: 'Racing Mind',
      bullets: [
        'Park worries on paper; schedule a “worry window.”',
        'Use breath count (4-in/6-out) or body scan.',
        'If stuck, get up briefly and reset.',
      ],
    ),
    _ContentSlide(
      heading: 'Bedroom Setup',
      bullets: [
        'Dark, cool, quiet; consider mask/earplugs/white noise.',
        'Reserve bed for sleep to strengthen association.',
        'Put clocks out of line of sight.',
      ],
    ),
    _ContentSlide(
      heading: 'Consistency Over Hacks',
      bullets: [
        'Tiny, repeatable habits compound.',
        'Track what helps vs. what is neutral.',
        'Avoid chasing new gadgets every week.',
      ],
    ),
    _ContentSlide(
      heading: 'Travel & Jet Lag',
      bullets: [
        'Shift schedule a bit before travel.',
        'Anchor with local morning light and short walks.',
        'Avoid long naps day one.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek Help',
      bullets: [
        'Persistent insomnia, snoring/choking, or severe daytime sleepiness.',
        'CBT-I and medical evaluation can help.',
        'Safety first when drowsy while driving.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'Strongest cue for your body clock is…',
      options: ['Morning bright light', 'Warm milk', 'Counting sheep', 'Blue bedsheets'],
      correctIndex: 0,
      rationale: 'Bright morning light advances the circadian rhythm.',
    ),
    _QuizData(
      question: 'Stimulus control means…',
      options: [
        'Doing homework in bed to get sleepy.',
        'Using bed only for sleep/intimacy.',
        'Going to bed earlier every time you’re tired.',
        'Checking the clock often.'
      ],
      correctIndex: 1,
      rationale: 'Strengthen the bed–sleep association by limiting other activities.',
    ),
    _QuizData(
      question: 'If awake >20 minutes in bed…',
      options: ['Stay and try harder', 'Scroll on your phone', 'Get up briefly and reset', 'Have a big meal'],
      correctIndex: 2,
      rationale: 'A short reset prevents conditioning of wakefulness in bed.',
    ),
    _QuizData(
      question: 'Best rule for caffeine timing:',
      options: ['Anytime is fine', 'Stop 6–8h before bed', 'Only at night', 'With sleeping pills'],
      correctIndex: 1,
      rationale: 'Caffeine can disrupt sleep even hours later.',
    ),
    _QuizData(
      question: 'Jet lag easing step:',
      options: ['Avoid daylight', 'Long evening nap', 'Morning light/exercise locally', 'Change nothing'],
      correctIndex: 2,
      rationale: 'Local morning light anchors the new schedule.',
    ),
  ],
);

// OCD / ERP
final _CourseData _ocdErpCourse = _CourseData(
  title: 'Crash Course: OCD / ERP',
  contentSlides: const [
    _ContentSlide(
      heading: 'OCD Loop',
      bullets: [
        'Intrusive thoughts → anxiety → compulsions → short relief.',
        'Relief teaches the brain the thought was dangerous.',
        'Goal is to break the ritual cycle.',
      ],
      tip: 'Thoughts are not actions or intentions.',
    ),
    _ContentSlide(
      heading: 'ERP Basics',
      bullets: [
        'Exposure to feared cues while preventing rituals.',
        'Start with a hierarchy from easier to harder.',
        'Repeat until anxiety drops without rituals.',
      ],
    ),
    _ContentSlide(
      heading: 'Building a Hierarchy',
      bullets: [
        'List triggers; rate 0–100 (SUDS).',
        'Design clear “no-ritual” rules.',
        'Plan frequency and duration.',
      ],
    ),
    _ContentSlide(
      heading: 'Delay & Reduce',
      bullets: [
        'Delay a ritual by 5–15 minutes.',
        'Shorten or skip steps to weaken compulsion strength.',
        'Track wins and discomfort.',
      ],
    ),
    _ContentSlide(
      heading: 'Mental Compulsions',
      bullets: [
        'Reassurance in your head counts as a ritual.',
        'Use acceptance/defusion scripts.',
        'Return attention to the task at hand.',
      ],
    ),
    _ContentSlide(
      heading: 'Uncertainty Tolerance',
      bullets: [
        'Practice saying “Maybe, maybe not.”',
        'Aim for “good enough” rather than 100% certainty.',
        'Let the urge rise/fall without acting.',
      ],
    ),
    _ContentSlide(
      heading: 'Support & Tracking',
      bullets: [
        'Involve a coach/clinician if possible.',
        'Daily notes: trigger, urge, ritual resisted, SUDS.',
        'Review trends weekly.',
      ],
    ),
    _ContentSlide(
      heading: 'Common Themes',
      bullets: [
        'Contamination, harm, symmetry, checking, “just-right,” taboo thoughts.',
        'Principles are the same even when content varies.',
        'Exposure targets the feared meaning, not just the object.',
      ],
    ),
    _ContentSlide(
      heading: 'Sticky Thoughts',
      bullets: [
        'Name it as “an OCD story.”',
        'Allow it to be present while living your values.',
        'Ritual prevention is the keystone.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek Help',
      bullets: [
        'Severe impairment or safety concerns.',
        'Specialist ERP therapy is highly effective.',
        'Medication may help alongside ERP.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'ERP pairs exposure with…',
      options: ['More reassurance', 'Ritual prevention', 'Distraction only', 'Avoidance'],
      correctIndex: 1,
      rationale: 'Preventing rituals allows corrective learning.',
    ),
    _QuizData(
      question: 'A mental ritual example:',
      options: ['Taking a walk', 'Repeated mental reviewing', 'Breathing slowly', 'Saying hello'],
      correctIndex: 1,
      rationale: 'Covert checking/reassurance is a compulsion.',
    ),
    _QuizData(
      question: 'Best stance toward uncertainty:',
      options: ['Eliminate it', 'Tolerate “maybe”', 'Ignore it', 'Outthink it perfectly'],
      correctIndex: 1,
      rationale: 'Learning to allow uncertainty weakens OCD.',
    ),
    _QuizData(
      question: 'Hierarchy step rating tool:',
      options: ['SUDS 0–100', 'BMI', 'GPA', 'RPM'],
      correctIndex: 0,
      rationale: 'Subjective Units of Distress guide ERP steps.',
    ),
    _QuizData(
      question: 'Key mistake that maintains OCD:',
      options: ['Ritualizing for quick relief', 'Taking notes', 'Breathing practice', 'Scheduling sessions'],
      correctIndex: 0,
      rationale: 'Relief teaches the brain the obsession was dangerous.',
    ),
  ],
);

// Stress Management
final _CourseData _stressCourse = _CourseData(
  title: 'Crash Course: Stress Management',
  contentSlides: const [
    _ContentSlide(
      heading: 'Stress 101',
      bullets: [
        'Acute stress can be useful; chronic stress drains energy.',
        'Body systems: sympathetic (go) vs. parasympathetic (rest).',
        'Goal: flexible switching between the two.',
      ],
    ),
    _ContentSlide(
      heading: 'Breath & Body',
      bullets: [
        '4-in/6-out breathing lowers arousal.',
        'Progressive muscle relaxation releases tension.',
        'Posture and slow exhale signal safety.',
      ],
    ),
    _ContentSlide(
      heading: 'Grounding & Attention',
      bullets: [
        '5-4-3-2-1 senses; name objects/colors.',
        'Brief “orienting” scan of the room.',
        'One-minute reset beats white-knuckling.',
      ],
    ),
    _ContentSlide(
      heading: 'Time & Energy',
      bullets: [
        'Prioritize top 3; define “enough.”',
        'Batch similar tasks; protect focus blocks.',
        'Schedule recovery micro-breaks.',
      ],
    ),
    _ContentSlide(
      heading: 'Boundaries',
      bullets: [
        'Say no to low-value commitments.',
        'Clarify roles and expectations.',
        'Use templates for common replies.',
      ],
    ),
    _ContentSlide(
      heading: 'Recovery Blocks',
      bullets: [
        'Sleep, nutrition, movement as pillars.',
        'Play/novelty recharges motivation.',
        'Nature and social connection buffer stress.',
      ],
    ),
    _ContentSlide(
      heading: 'Cognitive Skills',
      bullets: [
        'Spot catastrophizing and all-or-nothing.',
        'Reframe with evidence and alternatives.',
        'Make “likely / best / worst” plans.',
      ],
    ),
    _ContentSlide(
      heading: 'Values & Meaning',
      bullets: [
        'Align effort with what matters.',
        'Small acts toward values reduce burnout.',
        'Celebrate completion, not perfection.',
      ],
    ),
    _ContentSlide(
      heading: 'Crisis Toolkit',
      bullets: [
        'Breath + cold water + movement.',
        'Call a friend; reduce inputs.',
        'Short plan for the next hour only.',
      ],
    ),
    _ContentSlide(
      heading: 'Escalation & Help',
      bullets: [
        'Persistent impairment → talk to a clinician.',
        'Look for support groups/peer coaching.',
        'Use workplace resources when available.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'Which breath pattern helps down-shift?',
      options: ['2-in/2-out', '4-in/4-out', '4-in/6-out', '8-in/2-out'],
      correctIndex: 2,
      rationale: 'Longer exhales activate the parasympathetic system.',
    ),
    _QuizData(
      question: 'Best first step when overwhelmed:',
      options: [
        'Do everything at once',
        'Define top 3 priorities',
        'Add more meetings',
        'Ignore messages for days'
      ],
      correctIndex: 1,
      rationale: 'Focus beats scatter when stress is high.',
    ),
    _QuizData(
      question: 'A fast grounding method:',
      options: ['5-4-3-2-1 senses', 'Reading a novel', 'Shopping', 'Napping all day'],
      correctIndex: 0,
      rationale: 'Senses re-anchor attention to the present.',
    ),
    _QuizData(
      question: 'Good boundary practice:',
      options: ['Say yes to all asks', 'Vague timelines', 'Template “no” for low-value tasks', 'Work 24/7'],
      correctIndex: 2,
      rationale: 'Clear boundaries preserve bandwidth.',
    ),
    _QuizData(
      question: 'Burnout buffer not listed:',
      options: ['Play/novelty', 'Isolation', 'Movement', 'Sleep regularity'],
      correctIndex: 1,
      rationale: 'Isolation typically worsens burnout.',
    ),
  ],
);

// Mindfulness
final _CourseData _mindfulnessCourse = _CourseData(
  title: 'Crash Course: Mindfulness',
  contentSlides: const [
    _ContentSlide(
      heading: 'What Mindfulness Is',
      bullets: [
        'Paying attention on purpose, in the present, without judgment.',
        'Training attention + attitude (curiosity, kindness).',
        'A skill built through repetitions.',
      ],
    ),
    _ContentSlide(
      heading: 'Anchors',
      bullets: [
        'Breath, sounds, body sensations, contact with chair/floor.',
        'Return gently when distracted (and notice the return).',
        'Short practices count.',
      ],
    ),
    _ContentSlide(
      heading: 'Body Scan',
      bullets: [
        'Move attention slowly through the body.',
        'Notice tension/temperature/pressure without fixing.',
        'Refocus calmly when the mind wanders.',
      ],
    ),
    _ContentSlide(
      heading: 'Noticing Thoughts',
      bullets: [
        'Label “thinking” and let it pass.',
        'Use images like leaves on a stream.',
        'No need to suppress or analyze during practice.',
      ],
    ),
    _ContentSlide(
      heading: 'Emotion Skills',
      bullets: [
        'Name the feeling → it tames the feeling.',
        'Allow waves to peak and fall.',
        'Bring kindness to discomfort.',
      ],
    ),
    _ContentSlide(
      heading: 'Urge Surfing',
      bullets: [
        'Watch urges as body sensations.',
        'Delay action; ride the wave for 90 seconds.',
        'Choose your value-aligned response.',
      ],
    ),
    _ContentSlide(
      heading: 'Informal Practice',
      bullets: [
        'Single-task one routine (shower, dishes, walk).',
        'Use transition cues: doorways, traffic lights.',
        'Three breaths before opening an app.',
      ],
    ),
    _ContentSlide(
      heading: 'Compassion',
      bullets: [
        'Talk to yourself like a good friend.',
        'Place a hand on the chest; soften tone.',
        'Kindness builds resilience.',
      ],
    ),
    _ContentSlide(
      heading: 'Common Myths',
      bullets: [
        'You do not have to stop thoughts.',
        'It is not a replacement for medical care.',
        'It can be brief and still useful.',
      ],
    ),
    _ContentSlide(
      heading: 'Keeping It Going',
      bullets: [
        'Tiny daily habit > long rare sessions.',
        'Track streaks; pair with an existing routine.',
        'Try guided audio if helpful.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'Mindfulness mainly trains…',
      options: ['Beliefs only', 'Attention and attitude', 'Flexibility', 'Memory only'],
      correctIndex: 1,
      rationale: 'Attention + non-judgmental stance are core.',
    ),
    _QuizData(
      question: 'When you notice distraction…',
      options: ['Scold yourself', 'Quit practice', 'Gently return to the anchor', 'Open social media'],
      correctIndex: 2,
      rationale: 'The return is part of the rep.',
    ),
    _QuizData(
      question: '“Urge surfing” treats urges as…',
      options: ['Emergencies', 'Facts', 'Body sensations that rise/fall', 'Commands'],
      correctIndex: 2,
      rationale: 'Seeing urges as sensations gives choice.',
    ),
    _QuizData(
      question: 'A realistic plan is…',
      options: ['60 minutes daily or nothing', '3 breaths at transitions', 'Only on weekends', 'Never'],
      correctIndex: 1,
      rationale: 'Tiny consistent repetitions build skill.',
    ),
    _QuizData(
      question: 'Good compassion cue:',
      options: ['Harsh self-talk', 'Hand on chest + kind phrase', 'Ignore feelings', 'Compare to others'],
      correctIndex: 1,
      rationale: 'Self-kindness supports regulation.',
    ),
  ],
);

// Eating Regularity
final _CourseData _eatingCourse = _CourseData(
  title: 'Crash Course: Eating Regularity',
  contentSlides: const [
    _ContentSlide(
      heading: 'Regular Eating',
      bullets: [
        'Aim for 3 meals + 2–3 snacks at predictable times.',
        'Regularity stabilizes mood and energy.',
        'Avoid long gaps that trigger binges.',
      ],
    ),
    _ContentSlide(
      heading: 'Hunger & Fullness',
      bullets: [
        'Use a 0–10 scale to check in before/during/after.',
        'Eat to comfortable satisfaction, not stuffed.',
        'Notice patterns without judgment.',
      ],
    ),
    _ContentSlide(
      heading: 'Triggers & HALT',
      bullets: [
        'Hunger, Anger/Anxiety, Loneliness, Tiredness can drive urges.',
        'Check which is present before eating.',
        'Add coping for the non-hunger parts.',
      ],
    ),
    _ContentSlide(
      heading: 'Environment',
      bullets: [
        'Pre-portion snacks; keep tempting foods out of arm’s reach.',
        'Eat at a table when possible.',
        'Reduce multi-tasking during meals.',
      ],
    ),
    _ContentSlide(
      heading: 'Coping Skills',
      bullets: [
        'Delay urge 10–15 minutes and reassess.',
        'Use a short walk, call, or journaling.',
        'Build a list of safe, satisfying foods.',
      ],
    ),
    _ContentSlide(
      heading: 'Grocery & Prep',
      bullets: [
        'Simple plan for the week; repeat favorites.',
        'Prep grab-and-go protein and fruit.',
        'Keep water visible as a cue.',
      ],
    ),
    _ContentSlide(
      heading: 'Mindful Bites',
      bullets: [
        'First three bites slow and noticed.',
        'Put utensil down between bites.',
        'Savor temperature and texture.',
      ],
    ),
    _ContentSlide(
      heading: 'Flexibility Over Rules',
      bullets: [
        'No single food defines success.',
        'All foods can fit with planning.',
        'Curiosity beats shame for learning.',
      ],
    ),
    _ContentSlide(
      heading: 'Social & Travel',
      bullets: [
        'Snack beforehand to avoid arriving over-hungry.',
        'Scan menus for balanced options.',
        'Hydrate; pace desserts.',
      ],
    ),
    _ContentSlide(
      heading: 'When to Seek Help',
      bullets: [
        'If patterns feel unmanageable or unsafe.',
        'Consider RD or therapy specializing in eating.',
        'Medical monitoring when needed.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'A core regularity pattern is…',
      options: ['1 large late meal', '3 meals + 2–3 snacks', 'Only snacks', 'Skip breakfast always'],
      correctIndex: 1,
      rationale: 'Predictable fueling reduces extremes.',
    ),
    _QuizData(
      question: 'HALT stands for…',
      options: [
        'Hot, Airy, Low, Tall',
        'Hunger, Anger/Anxiety, Loneliness, Tiredness',
        'Healthy, Active, Light, Tasty',
        'Hope, Aim, Learn, Try'
      ],
      correctIndex: 1,
      rationale: 'Checking HALT clarifies non-food drivers.',
    ),
    _QuizData(
      question: 'Good urge-delay window:',
      options: ['10–15 minutes', '1 second', 'All day', 'Never pause'],
      correctIndex: 0,
      rationale: 'Urges often peak and pass quickly.',
    ),
    _QuizData(
      question: 'Mindful bite cue:',
      options: ['Eat as fast as possible', 'Put utensil down briefly', 'Scroll phone', 'Stand and pace'],
      correctIndex: 1,
      rationale: 'Slowing increases satisfaction and awareness.',
    ),
    _QuizData(
      question: 'Helpful shopping practice:',
      options: ['No plan at all', 'Repeat simple balanced staples', 'Only desserts', 'Skip produce'],
      correctIndex: 1,
      rationale: 'Simple, repeatable plans support regularity.',
    ),
  ],
);

// Grief & Loss
final _CourseData _griefCourse = _CourseData(
  title: 'Crash Course: Grief & Loss',
  contentSlides: const [
    _ContentSlide(
      heading: 'Grief Basics',
      bullets: [
        'A natural response to loss; waves over time.',
        'No single “right” timeline.',
        'Feelings can coexist (sadness and moments of joy).',
      ],
    ),
    _ContentSlide(
      heading: 'Rituals & Remembrance',
      bullets: [
        'Create personal rituals and memorials.',
        'Storytelling preserves connection.',
        'Anniversaries may intensify feelings.',
      ],
    ),
    _ContentSlide(
      heading: 'Body & Sleep',
      bullets: [
        'Grief is physically tiring—prioritize rest.',
        'Gentle movement helps regulate.',
        'Eat regularly even when appetite dips.',
      ],
    ),
    _ContentSlide(
      heading: 'Support Map',
      bullets: [
        'List two people/places for support.',
        'Ask for specific help (a walk, a ride, company).',
        'Peer groups can reduce isolation.',
      ],
    ),
    _ContentSlide(
      heading: 'Coping Day to Day',
      bullets: [
        'Plan one tiny task and one soothing activity.',
        'Allow tears and laughter both.',
        'Limit major decisions early if possible.',
      ],
    ),
    _ContentSlide(
      heading: 'Kids & Grief',
      bullets: [
        'Use simple, honest language.',
        'Maintain routines and reassurance.',
        'Invite questions repeatedly.',
      ],
    ),
    _ContentSlide(
      heading: 'Meaning & Legacy',
      bullets: [
        'Acts of service or creation can honor the loss.',
        'Write a letter to the person or to yourself.',
        'Keep a memory box or playlist.',
      ],
    ),
    _ContentSlide(
      heading: 'Complicated Grief',
      bullets: [
        'Persistent, impairing grief may need specialized care.',
        'Trauma overlaps can occur; seek support.',
        'There is help; you are not alone.',
      ],
    ),
    _ContentSlide(
      heading: 'Community & Culture',
      bullets: [
        'Lean on faith/community traditions if meaningful.',
        'Adapt rituals to your context.',
        'Grief is personal—compare less.',
      ],
    ),
    _ContentSlide(
      heading: 'Safety',
      bullets: [
        'Reach out if you feel hopeless or unsafe.',
        'Crisis resources and clinicians are available.',
        'Hope can grow even when pain is present.',
      ],
    ),
  ],
  quizzes: const [
    _QuizData(
      question: 'A truth about grief:',
      options: [
        'It has a strict timeline.',
        'Waves are common and normal.',
        'You must be strong and not cry.',
        'It always gets worse.'
      ],
      correctIndex: 1,
      rationale: 'Grief often comes in waves without a fixed schedule.',
    ),
    _QuizData(
      question: 'Helpful support ask:',
      options: ['“Help me with everything.”', 'A specific walk or call', 'Nothing', 'Vague advice requests'],
      correctIndex: 1,
      rationale: 'Specific requests are easier for supporters to meet.',
    ),
    _QuizData(
      question: 'When appetite dips, a step is…',
      options: ['Skip meals', 'Regular small meals/snacks', 'Only coffee', 'Only dessert'],
      correctIndex: 1,
      rationale: 'Regular fueling stabilizes energy and mood.',
    ),
    _QuizData(
      question: 'For children, communication should be…',
      options: ['Complex and abstract', 'Simple and honest', 'Avoidant', 'Filled with euphemisms only'],
      correctIndex: 1,
      rationale: 'Clarity and honesty support coping.',
    ),
    _QuizData(
      question: 'Seek more help when…',
      options: [
        'Impairment persists and safety concerns arise',
        'You cry once',
        'You remember the person',
        'A friend suggests music'
      ],
      correctIndex: 0,
      rationale: 'Complicated grief warrants specialized care.',
    ),
  ],
);

// ---------------- DATA TYPES & FLASHCARDS ----------------

class _Tip {
  final String condition;
  final String short;
  final String details;
  final List<String> tips;
  final List<String> keywords;

  const _Tip({
    required this.condition,
    required this.short,
    required this.details,
    required this.tips,
    this.keywords = const [],
  });
}

_Tip T({
  required String condition,
  required String short,
  required String details,
  required List<String> tips,
  List<String> k = const [],
}) =>
    _Tip(condition: condition, short: short, details: details, tips: tips, keywords: k);

final List<_Tip> _allTips = [
  // Mood (8)
  T(
    condition: 'Major Depressive Disorder',
    short: 'Persistent low mood, anhedonia, sleep/appetite changes.',
    details: 'Treatable with therapy and sometimes medication; action often precedes motivation.',
    tips: ['5-minute rule to start a tiny task.', 'Morning light or short outdoor walk.', 'Text one supportive person.'],
    k: ['MDD', 'depression'],
  ),
  T(
    condition: 'Persistent Depressive Disorder (Dysthymia)',
    short: 'Lower-grade but chronic depression (≥2 years).',
    details: 'Routines and activity scheduling help build momentum.',
    tips: ['Create a daily anchor routine.', 'Track mood vs sleep to spot patterns.'],
  ),
  T(
    condition: 'Seasonal Affective Disorder',
    short: 'Depression pattern tied to seasons (often winter).',
    details: 'Light therapy and activation are common first-line approaches.',
    tips: ['Use 10,000-lux light ~20–30 min post-wake (check guidelines).', 'Plan daylight walks weekly.'],
    k: ['SAD'],
  ),
  T(
    condition: 'Premenstrual Dysphoric Disorder (PMDD)',
    short: 'Severe cyclical mood symptoms pre-menses.',
    details: 'Track cycles; several evidence-based options exist.',
    tips: ['Pre-plan coping days.', 'Moderate caffeine/alcohol late luteal phase.'],
  ),
  T(
    condition: 'Bipolar I Disorder',
    short: 'Mania ± depression.',
    details: 'Sleep protection and relapse plans are essential.',
    tips: ['Avoid all-nighters.', 'Create early-warning sign plan with supports.'],
  ),
  T(
    condition: 'Bipolar II Disorder',
    short: 'Hypomania + depression episodes.',
    details: 'Routine regularity and monitoring help stability.',
    tips: ['Daily anchors (wake/meals/activity).', 'Notice reduced-sleep early signs.'],
  ),
  T(
    condition: 'Cyclothymic Disorder',
    short: 'Fluctuating sub-threshold mood symptoms.',
    details: 'Lifestyle regularity smooths swings.',
    tips: ['Daily mood tracking.', 'Limit alcohol; consistent lights-out.'],
  ),
  T(
    condition: 'Languishing',
    short: 'Stagnation/emptiness; not full depression.',
    details: 'Small wins and connection rebuild momentum.',
    tips: ['Micro-goals with quick wins.', 'Plan one social touchpoint.'],
  ),

  // Anxiety & Related (10)
  T(
    condition: 'Generalized Anxiety Disorder',
    short: 'Excessive worry most days for ≥6 months.',
    details: 'CBT and relaxation skills reduce worry and tension.',
    tips: ['Daily 10-min “worry window”.', '4-in/6-out breathing.'],
    k: ['GAD'],
  ),
  T(
    condition: 'Panic Disorder',
    short: 'Recurrent panic attacks; fear of more.',
    details: 'Interoceptive exposure reduces fear of sensations.',
    tips: ['Label: “This surge will pass.”', 'Extend exhales; relax shoulders.'],
  ),
  T(
    condition: 'Agoraphobia',
    short: 'Fear/avoidance of places where escape feels hard.',
    details: 'Graded exposure is effective.',
    tips: ['Stepwise exposure plan.', 'Pair exposures with breathing.'],
  ),
  T(
    condition: 'Social Anxiety Disorder',
    short: 'Intense fear of negative evaluation.',
    details: 'Exposure and realistic thinking help.',
    tips: ['3-step exposure ladder.', 'List disconfirming evidence post-event.'],
  ),
  T(
    condition: 'Specific Phobia — Animals',
    short: 'Fear of spiders, dogs, etc.',
    details: 'Graduated exposure works well.',
    tips: ['Rank exposures 1–10.', 'Practice daily with support.'],
  ),
  T(
    condition: 'Specific Phobia — Situational',
    short: 'Fear of flying/elevators/driving.',
    details: 'In-vivo/virtual exposures help.',
    tips: ['Script with helper.', 'Track SUDS 0–100.'],
  ),
  T(
    condition: 'Test Anxiety',
    short: 'Performance anxiety in exams.',
    details: 'Timed practice + coping skills.',
    tips: ['Pomodoro practice tests.', 'Breathing before/during exam.'],
  ),
  T(
    condition: 'Public Speaking Anxiety',
    short: 'Fear of speaking to groups.',
    details: 'Recorded repeated practice.',
    tips: ['Record 2-min talks.', 'Join a speaking group.'],
  ),
  T(
    condition: 'Travel Anxiety',
    short: 'Stress about logistics and safety.',
    details: 'Checklists and graded exposures.',
    tips: ['Pack list + buffers.', 'Short practice trips.'],
  ),
  T(
    condition: 'Sunday Scaries',
    short: 'Anxiety before week starts.',
    details: 'Plan + pleasant pairing.',
    tips: ['15-min Monday plan.', 'Sunday joy block.'],
  ),

  // Trauma & Stressor-Related (4)
  T(
    condition: 'Post-Traumatic Stress Disorder',
    short: 'Intrusions, avoidance, negative mood, arousal.',
    details: 'TF-CBT, EMDR, CPT are evidence-based.',
    tips: ['5-4-3-2-1 grounding.', 'Predictable sleep/meal/activity.'],
    k: ['PTSD'],
  ),
  T(
    condition: 'Acute Stress Disorder',
    short: 'PTSD-like symptoms within first month.',
    details: 'Early support + coping skills.',
    tips: ['Normalize reactions.', 'Limit trauma media exposure.'],
  ),
  T(
    condition: 'Adjustment Disorder',
    short: 'Disproportionate distress after a change.',
    details: 'Brief therapy and problem-solving.',
    tips: ['Break problems into tiny steps.', 'Keep sleep/wake steady.'],
  ),
  T(
    condition: 'PTSD — Nightmares',
    short: 'Trauma-related dreams disrupting sleep.',
    details: 'Image Rehearsal Therapy helps.',
    tips: ['Rewrite with safe ending; rehearse.', 'Low light wind-down.'],
  ),

  // OCD & Related (6)
  T(
    condition: 'Obsessive-Compulsive Disorder',
    short: 'Intrusive thoughts + compulsions.',
    details: 'ERP is gold standard.',
    tips: ['Delay rituals by 5 minutes.', 'Track each resisted ritual.'],
    k: ['OCD'],
  ),
  T(
    condition: 'Body Dysmorphic Disorder',
    short: 'Preoccupation with perceived appearance flaws.',
    details: 'ERP and mirror retraining.',
    tips: ['Limit mirror time.', 'Practice neutral descriptions.'],
  ),
  T(
    condition: 'Hoarding Disorder',
    short: 'Difficulty discarding; clutter.',
    details: 'CBT with sorting practice.',
    tips: ['Start with low-emotion items.', 'Use photos for memories.'],
  ),
  T(
    condition: 'Trichotillomania (Hair-Pulling)',
    short: 'Recurrent pulling with attempts to stop.',
    details: 'Habit Reversal Training (HRT).',
    tips: ['Identify triggers; keep hands busy.', 'Barrier styles at high-risk times.'],
  ),
  T(
    condition: 'Excoriation (Skin-Picking) Disorder',
    short: 'Recurrent skin picking causing lesions.',
    details: 'HRT + stimulus control.',
    tips: ['Cover mirrors/soft lighting.', 'Use putty/lotion as competing response.'],
  ),
  T(
    condition: 'OCD — Contamination Theme',
    short: 'Fear of germs; washing rituals.',
    details: 'Contact without washing breaks loop.',
    tips: ['Touch medium-scary surface; delay washing 15 min.', 'Track anxiety drop.'],
  ),

  // Psychotic (3)
  T(
    condition: 'Schizophrenia',
    short: 'Delusions, hallucinations, disorganization.',
    details: 'Coordinated specialty care improves outcomes.',
    tips: ['Keep routines; minimize cannabis/stimulants.', 'Calm sensory space.'],
  ),
  T(
    condition: 'Schizoaffective Disorder',
    short: 'Schizophrenia symptoms + mood episode.',
    details: 'Blend mood and psychosis care.',
    tips: ['Use med organizers.', 'Plan early help steps.'],
  ),
  T(
    condition: 'Brief Psychotic Disorder',
    short: 'Psychosis 1 day–1 month with full return.',
    details: 'Safety and follow-up.',
    tips: ['Prioritize sleep/regularity.', 'Clinician follow-up.'],
  ),

  // Neurodevelopmental (6)
  T(
    condition: 'ADHD — Combined',
    short: 'Inattention + hyperactivity/impulsivity.',
    details: 'Externalize tasks + short sprints.',
    tips: ['Visible timers/boards.', 'Body-doubling.'],
    k: ['ADHD'],
  ),
  T(
    condition: 'ADHD — Inattentive',
    short: 'Primarily inattentive symptoms.',
    details: 'Visual cues and structure.',
    tips: ['Time boxing with alarms.', 'Checklists at point-of-performance.'],
  ),
  T(
    condition: 'ADHD — Hyperactive/Impulsive',
    short: 'Restlessness; impulsivity.',
    details: 'Movement breaks and impulse delay.',
    tips: ['Move before focus blocks.', 'Count to 20 + pick alternative.'],
  ),
  T(
    condition: 'Autism Spectrum Disorder',
    short: 'Social communication differences; sensory processing.',
    details: 'Supportive environments and accommodations.',
    tips: ['Clear, concrete plans/visuals.', 'Low-stim reset zones.'],
  ),
  T(
    condition: 'Time Blindness (ADHD-related)',
    short: 'Losing track of time.',
    details: 'External timers/visual clocks.',
    tips: ['Loud, visible timers.', 'Calendar alarms with lead time.'],
  ),
  T(
    condition: 'Rejection Sensitive Dysphoria',
    short: 'Extreme sensitivity to perceived rejection.',
    details: 'Skills and reframing help.',
    tips: ['Name trigger, delay reaction.', 'Reality-check with trusted person.'],
  ),

  // Eating (4)
  T(
    condition: 'Anorexia Nervosa',
    short: 'Restriction → significantly low weight; body image distortion.',
    details: 'Medical monitoring + specialized care.',
    tips: ['Follow supervised meal plan.', 'Replace body-checking with values activities.'],
  ),
  T(
    condition: 'Bulimia Nervosa',
    short: 'Binge episodes + compensatory behaviors.',
    details: 'CBT-E; regular eating schedules.',
    tips: ['3 meals + 2–3 snacks.', 'Delay urges 15 min; coping cards.'],
  ),
  T(
    condition: 'Binge-Eating Disorder',
    short: 'Recurrent binges without compensatory behaviors.',
    details: 'Structured meals + coping skills.',
    tips: ['Keep tempting foods out of easy reach.', 'Use HALT before eating.'],
  ),
  T(
    condition: 'ARFID',
    short: 'Avoidant/restrictive intake without body-image concerns.',
    details: 'Food exposure + nutrition support.',
    tips: ['Tiny, reinforced exposures.', 'Accommodate texture/sensory needs.'],
  ),

  // Sleep (4)
  T(
    condition: 'Insomnia Disorder',
    short: 'Difficulty initiating/maintaining sleep or early waking.',
    details: 'CBT-I is first-line.',
    tips: ['Fixed wake time; bed only for sleep/intimacy.', 'If awake >20 min, get up briefly under dim light.'],
  ),
  T(
    condition: 'Circadian Rhythm Sleep-Wake Disorder',
    short: 'Clock misaligned with schedule.',
    details: 'Light timing, melatonin, gradual shifts.',
    tips: ['Morning bright light; evening dim.', 'Shift bedtime by 15–30 min.'],
  ),
  T(
    condition: 'Nightmare Disorder (non-trauma)',
    short: 'Frequent dysphoric dreams.',
    details: 'Image Rehearsal Therapy + hygiene.',
    tips: ['Rewrite endings; rehearse daily.', 'Consistent wind-down.'],
  ),
  T(
    condition: 'Sleep Anxiety',
    short: 'Fear of not sleeping makes it worse.',
    details: 'Paradoxical intention + stimulus control.',
    tips: ['Aim to rest, not force sleep.', 'Get up if awake >20 min.'],
  ),

  // Substance/Behavioral (3)
  T(
    condition: 'Alcohol Use Disorder',
    short: 'Loss of control, cravings, continued use despite harm.',
    details: 'Medications, therapy, mutual-help.',
    tips: ['If-then trigger plan.', 'Keep none at home; support contacts.'],
  ),
  T(
    condition: 'Internet Gaming Disorder (proposed)',
    short: 'Gaming dominates life/impairs function.',
    details: 'Cue limits + schedule alternatives.',
    tips: ['Play windows + hard stops.', 'Offline rewarding activities.'],
  ),
  T(
    condition: 'Compulsive Buying (proposed)',
    short: 'Uncontrolled shopping causing harm.',
    details: 'Delay tactics + budget locks.',
    tips: ['72-hour wait rule.', 'Remove saved cards.'],
  ),

  // Somatic & Dissociative & Other (7)
  T(
    condition: 'Somatic Symptom Disorder',
    short: 'Distressing focus on physical symptoms.',
    details: 'Reduce checking; balanced interpretations.',
    tips: ['Limit checks to brief windows.', 'Evidence for/against feared cause.'],
  ),
  T(
    condition: 'Illness Anxiety Disorder',
    short: 'Preoccupation with serious illness.',
    details: 'Cut reassurance/internet checking.',
    tips: ['No “Dr. Google” outside brief window.', 'Track counter-evidence.'],
  ),
  T(
    condition: 'Depersonalization/Derealization',
    short: 'Feeling detached/unreal.',
    details: 'Grounding and CBT help.',
    tips: ['Name it: “Unreal but safe.”', 'Engage senses (ice, colors).'],
  ),
  T(
    condition: 'Grief (Bereavement)',
    short: 'Natural response to loss; nonlinear.',
    details: 'Support and rituals help.',
    tips: ['Daily grief time.', 'Sleep, nutrition, connection.'],
  ),
  T(
    condition: 'Prolonged Grief Disorder',
    short: 'Persistent impairing grief.',
    details: 'Therapy focuses on restoration.',
    tips: ['Small, meaningful goals.', 'Join grief group/counseling.'],
  ),
  T(
    condition: 'Burnout',
    short: 'Exhaustion, cynicism, reduced efficacy.',
    details: 'Rest, boundaries, meaning-aligned activities.',
    tips: ['Recovery blocks.', 'Say “no” to one thing.'],
  ),
  T(
    condition: 'Self-Harm Urges',
    short: 'Urges to cope by self-injury.',
    details: 'Seek professional help; safety first.',
    tips: ['Ice/rubber band/drawing instead.', 'Remove tools; go to public/safe place.'],
  ),
];
