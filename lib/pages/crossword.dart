// lib/pages/crossword.dart
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

class CrosswordPage extends StatefulWidget {
  const CrosswordPage({super.key});
  @override
  State<CrosswordPage> createState() => _CrosswordPageState();
}

class _CrosswordPageState extends State<CrosswordPage> {
  static const puzzles = [
    (
      grid: [
        'C L A R I T Y',
        'O # R E S T #',
        'M I N D F U L',
        'P E A C E F U',
        'O # B R E A T',
        'S E R E N E #',
        'E A S E F U L',
      ],
      cluesA: {
        1: 'Clear state (7)',
        3: 'Relax period (4)',
        5: 'Attentive awareness (8)',
        7: 'Tranquil (8)',
        8: 'Breath in/out base (5)',
        9: 'Calm quality (7)',
      },
      cluesD: {
        1: 'Opposite of chaos (5)',
        2: 'Not hard (4)',
        3: 'To take a break (4)',
        4: 'Comfortable (7)',
        6: 'Composed (7)',
      }
    ),
    (
      grid: [
        'S T I L L N E',
        'O # B A L A N',
        'F O C U S E D',
        'T R A N Q U I',
        'L # C E N T E',
        'R E S I L I #',
        'E A S Y G O I',
      ],
      cluesA: {
        1: 'Motionless (7)',
        2: 'Even steadiness (6)',
        3: 'Concentrated (7)',
        4: 'Calm, quiet (7)',
        5: 'Middle (6)',
        6: 'Able to bounce back (7)',
        7: 'Relaxed attitude (8)',
      },
      cluesD: {
        1: 'Serene (7)',
        2: 'Focus direction (5)',
        3: 'Opposite of hard (4)',
        4: 'Core (6)',
        5: 'Equanimity (9)',
      }
    ),
  ];

  static const _saveActive = 'cw_active_idx';
  static const _saveCells = 'cw_active_cells';

  late int _puzzleIndex;
  late List<List<String>> _solution;
  late List<List<String?>> _cells;
  late List<List<int?>> _numbers;
  late DateTime _startTime;

  @override
  void initState() { super.initState(); _restoreOrNew(); }

  Future<void> _restoreOrNew() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt(_saveActive);
    final saved = p.getStringList(_saveCells);
    if (idx != null && saved != null) {
      _puzzleIndex = idx;
      final raw = puzzles[_puzzleIndex].grid;
      _solution = raw.map((r) => r.split(' ')).toList();
      _cells = List.generate(7, (r) => List.generate(7, (c) {
            final s = _solution[r][c];
            if (s == '#') return null;
            final ch = saved[r * 7 + c];
            return ch.isEmpty ? '' : ch;
          }));
      _numbers = _computeNumbers(_solution);
      _startTime = DateTime.now();
      setState(() {});
      return;
    }
    _newPuzzle();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_saveActive, _puzzleIndex);
    final flat = <String>[];
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final v = _cells[r][c];
        flat.add(v == null ? '' : v);
      }
    }
    await p.setStringList(_saveCells, flat);
  }

  Future<void> _clearPersisted() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_saveActive);
    await p.remove(_saveCells);
  }

  void _newPuzzle() {
    _puzzleIndex = Random().nextInt(puzzles.length);
    final raw = puzzles[_puzzleIndex].grid;
    _solution = raw.map((r) => r.split(' ')).toList();
    _cells = List.generate(7, (r) => List.generate(7, (c) {
          final s = _solution[r][c];
          return s == '#' ? null : '';
        }));
    _numbers = _computeNumbers(_solution);
    _startTime = DateTime.now();
    _persist();
    setState(() {});
  }

  void _resetPuzzle() {
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        if (_cells[r][c] != null) _cells[r][c] = '';
      }
    }
    _startTime = DateTime.now();
    _persist();
    setState(() {});
  }

  List<List<int?>> _computeNumbers(List<List<String>> sol) {
    int n = 7, counter = 0;
    final nums = List.generate(n, (_) => List<int?>.filled(n, null));
    bool isStartAcross(int r, int c) =>
        sol[r][c] != '#' && (c == 0 || sol[r][c - 1] == '#') && (c + 1 < n && sol[r][c + 1] != '#');
    bool isStartDown(int r, int c) =>
        sol[r][c] != '#' && (r == 0 || sol[r - 1][c] == '#') && (r + 1 < n && sol[r + 1][c] != '#');
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (sol[r][c] == '#') continue;
        if (isStartAcross(r, c) || isStartDown(r, c)) {
          counter += 1;
          nums[r][c] = counter;
        }
      }
    }
    return nums;
  }

  bool _complete() {
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final sol = _solution[r][c];
        final cur = _cells[r][c];
        if (sol == '#') continue;
        if ((cur ?? '').toUpperCase() != sol) return false;
      }
    }
    return true;
  }

  void _hint() {
    final list = <Point<int>>[];
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        if (_solution[r][c] == '#') continue;
        if ((_cells[r][c] ?? '') != _solution[r][c]) list.add(Point(r, c));
      }
    }
    if (list.isEmpty) return;
    final p = list[Random().nextInt(list.length)];
    _cells[p.x][p.y] = _solution[p.x][p.y];
    _persist();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final across = puzzles[_puzzleIndex].cluesA;
    final down = puzzles[_puzzleIndex].cluesD;

    final topBar = Row(
      children: [
        FilledButton.icon(
          onPressed: _hint,
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
          label: const Text('Hint'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _resetPuzzle,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () { _newPuzzle(); },
          icon: const Icon(Icons.fiber_new_rounded, size: 18),
          label: const Text('New'),
        ),
      ],
    );

    return _GameScaffold(
      title: 'Crossword',
      rule: '7×7 crossword with Across/Down clues. Use “Hint” for a letter.',
      topBar: topBar,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                padding: const EdgeInsets.all(8),
                itemCount: 49,
                itemBuilder: (_, i) {
                  final r = i ~/ 7, c = i % 7;
                  if (_solution[r][c] == '#') {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ink),
                      ),
                    );
                  }
                  final ok = (_cells[r][c] ?? '').toUpperCase() == _solution[r][c];
                  final number = _numbers[r][c];

                  return Stack(
                    children: [
                      TextField(
                        controller: TextEditingController(text: _cells[r][c]),
                        onChanged: (v) async {
                          _cells[r][c] = v.isEmpty ? '' : v.substring(0, 1).toUpperCase();
                          await _persist();
                          setState(() {});
                          if (_complete()) {
                            await _clearPersisted();
                            final secs = DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
                            final score = 1 / secs;
                            await ScoreStore.instance.add('crossword', score);
                            final high = await ScoreStore.instance.reportBest('crossword', score);
                            if (!mounted) return;
                            await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(high ? 'New High Score!' : 'Crossword complete'),
                                content: Text(high
                                    ? 'Speed: ${(1/score).toStringAsFixed(0)} sec'
                                    : 'Good job! Want another?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                  FilledButton(onPressed: () { Navigator.pop(context); _newPuzzle(); }, child: const Text('New')),
                                ],
                              ),
                            );
                          }
                        },
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: ok ? const Color(0xFFA7E0C9) : Colors.white,
                          contentPadding: const EdgeInsets.only(top: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _ink),
                          ),
                        ),
                      ),
                      if (number != null)
                        Positioned(
                          left: 6,
                          top: 2,
                          child: IgnorePointer(
                            child: Text(
                              '$number',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ink),
            ),
            child: Row(
              children: [
                Expanded(child: _ClueList(title: 'Across', clues: across)),
                const SizedBox(width: 12),
                Expanded(child: _ClueList(title: 'Down', clues: down)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClueList extends StatelessWidget {
  final String title;
  final Map<int, String> clues;
  const _ClueList({required this.title, required this.clues});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ...clues.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${e.key}. ${e.value}'),
            )),
      ],
    );
  }
}
