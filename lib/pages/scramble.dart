// lib/pages/scramble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* Shared look & scaffold */
BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
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
  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
    this.topBar,
  });

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
                if (topBar != null) ...[
                  const SizedBox(height: 8),
                  topBar!
                ],
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

  Future<void> add(String key, double v) async {
    final p = await SharedPreferences.getInstance();
    final k = 'sbp_$key';
    final cur = p.getStringList(k) ?? [];
    cur.add(v.toString());
    await p.setStringList(k, cur);
  }

  Future<bool> reportBest(String key, double score) async {
    final p = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$key';
    final prev = p.getDouble(bestKey) ?? double.negativeInfinity;
    if (score > prev) {
      await p.setDouble(bestKey, score);
      return true;
    }
    return false;
  }
}

class ScramblePage extends StatefulWidget {
  const ScramblePage({super.key});
  @override
  State<ScramblePage> createState() => _ScramblePageState();
}

class _ScramblePageState extends State<ScramblePage> {
  static const _wordBank = [
    'CALM', 'PEACE', 'BREATHE', 'GENTLE', 'SERENE', 'BALANCE', 'QUIET', 'SOFT',
    'RELAX', 'KIND', 'CENTER', 'PATIENCE', 'HARMONY', 'GRACE', 'STILL',
    'MINDFUL', 'HEAL', 'HOPE', 'BRIGHT', 'FLOW', 'TRUST', 'LIGHT', 'OCEAN',
    'CLOUD', 'SUNNY', 'BLOSSOM', 'NATURE', 'SMILE', 'STRONG', 'BREEZE',
    'COURAGE', 'UNITY', 'WARMTH', 'SOUL', 'SPIRIT', 'CALMER', 'SOOTHE'
  ];

  final rnd = Random();
  late String target;
  late List<String> scrambled;
  late DateTime _start;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _new();
  }

  void _new() {
    target = _wordBank[rnd.nextInt(_wordBank.length)];
    scrambled = target.split('');
    do {
      scrambled.shuffle(rnd);
    } while (scrambled.join() == target);

    _start = DateTime.now();
    ctrl.clear();
    setState(() {});
  }

  String formatTime(int totalSec) {
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    if (min == 0) return "$sec seconds";
    if (min == 1 && sec == 0) return "1 minute";
    if (min == 1) return "1 minute $sec seconds";
    if (sec == 0) return "$min minutes";
    return "$min minutes $sec seconds";
  }

  Future<void> _check() async {
    if (ctrl.text.trim().toUpperCase() == target) {
      final secs = DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
      final score = 1.0 / secs;
      await ScoreStore.instance.add('scramble', score);
      await ScoreStore.instance.reportBest('scramble', score);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nice!'),
          content: Text(
            'You solved "${target.toUpperCase()}" in ${formatTime(secs)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      _new();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'Scramble',
      rule: 'Unscramble the letters to form a calming word.',
      topBar: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _new,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('New'),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: scrambled.map((ch) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _ink),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ch,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Type your guess',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ink),
              ),
            ),
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Check'),
          ),
        ],
      ),
    );
  }
}
