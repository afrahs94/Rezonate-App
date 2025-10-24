// lib/pages/hangman.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* Shared look & scaffold */
BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF6FD6C1)],
    ),
  );
}
const _ink = Colors.black;
class _GameScaffold extends StatelessWidget {
  final String title, rule;
  final Widget child;
  final Widget? topBar;
  const _GameScaffold({required this.title, required this.rule, required this.child, this.topBar});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ink),
                  ),
                  child: Text(rule, textAlign: TextAlign.center),
                ),
                if (topBar != null) ...[const SizedBox(height: 8), topBar!],
                const SizedBox(height: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* Score store */
class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();
  Future<void> add(String gameKey, double v) async {
    final p = await SharedPreferences.getInstance();
    final k = 'sbp_$gameKey';
    final cur = p.getStringList(k) ?? [];
    cur.add(v.toString());
    await p.setStringList(k, cur);
  }
  Future<bool> reportBest(String gameKey, double score) async {
    final p = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$gameKey';
    final prev = p.getDouble(bestKey) ?? double.negativeInfinity;
    if (score > prev) { await p.setDouble(bestKey, score); return true; }
    return false;
  }
}

class HangmanPage extends StatefulWidget {
  const HangmanPage({super.key});
  @override
  State<HangmanPage> createState() => _HangmanPageState();
}

class _HangmanPageState extends State<HangmanPage> {
  static const words = [
    'CALM','PEACE','BREATHE','GENTLE','SERENE','BALANCE','QUIET','SOFT',
    'RELAX','KIND','CENTER','PATIENCE','HARMONY','GRACE','STILL','MINDFUL'
  ];
  final rnd = Random();
  late String target;
  late Set<String> guessed;
  int mistakes = 0;
  late DateTime _start;

  @override
  void initState() { super.initState(); _new(); }
  void _new() {
    target = words[rnd.nextInt(words.length)];
    guessed = {};
    mistakes = 0;
    _start = DateTime.now();
    setState(() {});
  }

  String get masked {
    return target.split('').map((ch) => guessed.contains(ch) ? ch : '_').join(' ');
  }

  bool get won => target.split('').every((ch) => guessed.contains(ch));
  bool get lost => mistakes >= 6;

  void _guess(String ch) async {
    if (won || lost) return;
    setState(() { guessed.add(ch); if (!target.contains(ch)) mistakes++; });
    if (won) {
      final secs = DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
      final score = 1.0 / secs;
      await ScoreStore.instance.add('hangman', score);
      await ScoreStore.instance.reportBest('hangman', score);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You won!')));
    } else if (lost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You lost. Word was $target')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    return _GameScaffold(
      title: 'Hangman',
      rule: 'Guess the word. You can make up to 6 mistakes.',
      topBar: Row(
        children: [
          Text('Mistakes: $mistakes/6', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          OutlinedButton.icon(onPressed: _new, icon: const Icon(Icons.fiber_new_rounded, size: 18), label: const Text('New')),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _HangmanPainter(mistakes),
              child: Center(
                child: Text(masked,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
          ),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: letters.map((ch) {
              final used = guessed.contains(ch);
              return SizedBox(
                width: 36, height: 36,
                child: ElevatedButton(
                  onPressed: used || won || lost ? null : () => _guess(ch),
                  child: Text(ch, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HangmanPainter extends CustomPainter {
  final int m;
  _HangmanPainter(this.m);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.black..strokeWidth = 4..style = PaintingStyle.stroke;
    final baseY = s.height * .75;
    // Gallows
    c.drawLine(Offset(s.width*.15, baseY), Offset(s.width*.45, baseY), p);
    c.drawLine(Offset(s.width*.2, baseY), Offset(s.width*.2, s.height*.2), p);
    c.drawLine(Offset(s.width*.2, s.height*.2), Offset(s.width*.45, s.height*.2), p);
    c.drawLine(Offset(s.width*.45, s.height*.2), Offset(s.width*.45, s.height*.28), p);
    // Body parts (6)
    if (m>=1) c.drawCircle(Offset(s.width*.45, s.height*.33), 20, p); // head
    if (m>=2) c.drawLine(Offset(s.width*.45, s.height*.35), Offset(s.width*.45, s.height*.5), p); // torso
    if (m>=3) c.drawLine(Offset(s.width*.45, s.height*.38), Offset(s.width*.40, s.height*.45), p); // left arm
    if (m>=4) c.drawLine(Offset(s.width*.45, s.height*.38), Offset(s.width*.50, s.height*.45), p); // right arm
    if (m>=5) c.drawLine(Offset(s.width*.45, s.height*.5), Offset(s.width*.40, s.height*.58), p);  // left leg
    if (m>=6) c.drawLine(Offset(s.width*.45, s.height*.5), Offset(s.width*.50, s.height*.58), p);  // right leg
  }
  @override
  bool shouldRepaint(covariant _HangmanPainter old) => m != old.m;
}
