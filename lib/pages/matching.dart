// lib/pages/matching.dart
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
  final String title;
  final String rule;
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
        surfaceTintColor: Colors.transparent,
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
    final prefs = await SharedPreferences.getInstance();
    final k = 'sbp_$gameKey';
    final cur = prefs.getStringList(k) ?? [];
    cur.add(v.toString());
    await prefs.setStringList(k, cur);
  }
  Future<bool> reportBest(String gameKey, double score) async {
    final prefs = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$gameKey';
    final prev = prefs.getDouble(bestKey) ?? double.negativeInfinity;
    if (score > prev) {
      await prefs.setDouble(bestKey, score);
      return true;
    }
    return false;
  }
}

class MatchDifficultPage extends StatefulWidget {
  const MatchDifficultPage({super.key});
  @override
  State<MatchDifficultPage> createState() => _MatchDifficultPageState();
}

class _MatchDifficultPageState extends State<MatchDifficultPage> with TickerProviderStateMixin {
  static const int pairs = 10; // 20 cards
  final rnd = Random();
  late List<int> deck;   // two of each id
  late List<bool> faceUp;
  int? first;
  int moves = 0;
  int matched = 0;
  late DateTime _start;

  late List<IconData> _iconSet;

  @override
  void initState() { super.initState(); _new(); }
  void _new() {
    _iconSet = [
      Icons.spa_rounded,
      Icons.ac_unit_rounded,
      Icons.waves_rounded,
      Icons.star_rounded,
      Icons.favorite_rounded,
      Icons.landscape_rounded,
      Icons.pets_rounded,
      Icons.local_florist_rounded,
      Icons.park_rounded,
      Icons.flutter_dash,
    ]..shuffle(rnd);
    deck = List.generate(pairs, (i) => i)..addAll(List.generate(pairs, (i) => i));
    deck.shuffle(rnd);
    faceUp = List.filled(deck.length, false);
    first = null; moves = 0; matched = 0;
    _start = DateTime.now();
    setState(() {});
  }

  Future<void> _flip(int i) async {
    if (faceUp[i]) return;
    setState(() { faceUp[i] = true; });
    if (first == null) {
      first = i;
    } else if (first != i) {
      moves++;
      if (deck[first!] == deck[i]) {
        matched += 2;
        if (matched == deck.length) {
          final secs = DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
          final score = (pairs / secs);
          await ScoreStore.instance.add('matchhard', score);
          final high = await ScoreStore.instance.reportBest('matchhard', score);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(high ? 'New high score!' : 'Done in $moves moves'),
          ));
        }
        first = null;
      } else {
        final prev = first!;
        first = null;
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() { faceUp[i] = false; faceUp[prev] = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Colors.primaries.take(pairs).toList();
    return _GameScaffold(
      title: 'Matching',
      rule: 'Flip cards to find pairs. New icons & colors each shuffle.',
      topBar: Row(
        children: [
          Text('Moves: $moves', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _new,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('Shuffle'),
          ),
        ],
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: deck.length,
        itemBuilder: (_, i) {
          final open = faceUp[i];
          final id = deck[i];
          return GestureDetector(
            onTap: () => _flip(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.identity()..scale(open ? 1.0 : 0.98),
              decoration: BoxDecoration(
                gradient: open
                    ? LinearGradient(colors: [palette[id].shade200, palette[id].shade400])
                    : const LinearGradient(colors: [Colors.white, Color(0xFFF6F6F6)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ink),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: open
                    ? Icon(_iconSet[id], key: const ValueKey('open'), size: 28, color: palette[id].shade900)
                    : const Icon(Icons.help_outline_rounded, key: ValueKey('closed'), color: Colors.black54),
              ),
            ),
          );
        },
      ),
    );
  }
}
