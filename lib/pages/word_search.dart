// lib/pages/word_search.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* Shared look & scaffold (same as original) */
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

/* Score storage (same behavior/keys as original) */
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

enum _WsDifficulty { easy, medium, hard }

class WordSearchPage extends StatefulWidget {
  const WordSearchPage({super.key});
  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  static const Map<_WsDifficulty, List<List<String>>> _pools = {
    _WsDifficulty.easy: [
      ['CALM', 'BREATHE', 'FOCUS', 'PAUSE', 'SMILE'],
      ['PEACE', 'REST', 'KIND', 'WARM', 'SOFT'],
      ['OCEAN', 'CLOUD', 'LEAF', 'QUIET', 'EASE'],
    ],
    _WsDifficulty.medium: [
      ['BALANCE', 'GROUND', 'MINDFUL', 'RELAX'],
      ['GRATITUDE', 'SERENITY', 'STEADY'],
      ['SUNLIGHT', 'BREEZE', 'GENTLE', 'CENTER'],
    ],
    _WsDifficulty.hard: [
      ['RESILIENCE', 'TRANQUIL', 'PATIENCE', 'HARMONY'],
      ['COMPOSURE', 'BREATHWORK', 'EQUANIMITY'],
      ['MEDITATION', 'STILLNESS', 'PRESENCE'],
    ],
  };

  _WsDifficulty difficulty = _WsDifficulty.easy;
  late int size;
  late List<List<String>> grid;
  late List<String> words;
  late Set<String> remaining;

  final _selCells = <Point<int>>{};
  Point<int>? _lastCell;
  bool _dragging = false;

  final List<List<Point<int>>> _foundPaths = [];

  static const _saveKey = 'ws_active';
  static const _saveDiff = 'ws_active_diff';
  static const _saveWords = 'ws_active_words';
  static const _saveGrid = 'ws_active_grid';
  late DateTime _startTime;

  final rnd = Random();

  @override
  void initState() { super.initState(); _tryRestoreOrNew(); }

  Future<void> _tryRestoreOrNew() async {
    final p = await SharedPreferences.getInstance();
    final diffIdx = p.getInt(_saveDiff);
    final wordsSaved = p.getStringList(_saveWords);
    final gridSaved = p.getStringList(_saveGrid);
    if (diffIdx != null && wordsSaved != null && gridSaved != null) {
      difficulty = _WsDifficulty.values[diffIdx];
      size = sqrt(gridSaved.length).round();
      grid = List.generate(size, (r) => List.generate(size, (c) => gridSaved[r * size + c]));
      words = List.from(wordsSaved);
      remaining = p.getStringList(_saveKey)?.toSet() ?? words.toSet();
      _startTime = DateTime.now();
      setState(() {});
      return;
    }
    _newPuzzle(resetDifficulty: false);
  }

  Future<void> _persistActive() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_saveDiff, difficulty.index);
    await p.setStringList(_saveWords, words);
    await p.setStringList(_saveKey, remaining.toList());
    final flat = <String>[];
    for (final r in grid) { flat.addAll(r); }
    await p.setStringList(_saveGrid, flat);
  }

  Future<void> _clearPersisted() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_saveDiff);
    await p.remove(_saveWords);
    await p.remove(_saveKey);
    await p.remove(_saveGrid);
  }

  void _newPuzzle({bool resetDifficulty = false}) {
    if (resetDifficulty) difficulty = _WsDifficulty.easy;
    final pool = _pools[difficulty]!;
    final list = List<List<String>>.from(pool)..shuffle(rnd);
    words = List<String>.from(list.first)..shuffle(rnd);
    size = (difficulty == _WsDifficulty.easy)
        ? 12
        : (difficulty == _WsDifficulty.medium ? 13 : 14);
    grid = List.generate(size, (_) => List.filled(size, ''));
    remaining = words.toSet();
    _placeWords();
    _fillRandom();
    _selCells.clear();
    _lastCell = null;
    _foundPaths.clear();
    _startTime = DateTime.now();
    _persistActive();
    setState(() {});
  }

  void _resetCurrent() {
    grid = List.generate(size, (_) => List.filled(size, ''));
    remaining = words.toSet();
    _placeWords();
    _fillRandom();
    _selCells.clear();
    _lastCell = null;
    _foundPaths.clear();
    _startTime = DateTime.now();
    _persistActive();
    setState(() {});
  }

  void _placeWords() {
    final dirs = [
      const Point(1,0), const Point(0,1), const Point(1,1), const Point(-1,1),
      const Point(-1,0), const Point(0,-1), const Point(-1,-1), const Point(1,-1),
    ];
    for (final w in words) {
      bool placed = false;
      for (int tries = 0; tries < 400 && !placed; tries++) {
        final d = dirs[rnd.nextInt(dirs.length)];
        final r0 = rnd.nextInt(size), c0 = rnd.nextInt(size);
        int r = r0, c = c0;
        bool ok = true;
        for (int i = 0; i < w.length; i++) {
          if (r < 0 || r >= size || c < 0 || c >= size) { ok = false; break; }
          final ch = grid[r][c];
          if (ch.isNotEmpty && ch != w[i]) { ok = false; break; }
          r += d.y; c += d.x;
        }
        if (!ok) continue;
        r = r0; c = c0;
        for (int i = 0; i < w.length; i++) { grid[r][c] = w[i]; r += d.y; c += d.x; }
        placed = true;
      }
    }
  }

  void _fillRandom() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c].isEmpty) {
          grid[r][c] = String.fromCharCode(65 + rnd.nextInt(26));
        }
      }
    }
  }

  void _onPanStart(Offset pos, BoxConstraints cons) {
    _dragging = true;
    _selCells.clear();
    _lastCell = null;
    _addCellFromPosition(pos, cons);
  }

  void _onPanUpdate(Offset pos, BoxConstraints cons) {
    if (!_dragging) return;
    _addCellFromPosition(pos, cons);
  }

  void _onPanEnd() {
    _dragging = false;
    _checkSelection();
    _selCells.clear();
    _lastCell = null;
    setState(() {});
  }

  void _addCellFromPosition(Offset pos, BoxConstraints cons) {
    final cellSize = cons.maxWidth / size;
    final gx = (pos.dx / cellSize).floor();
    final gy = (pos.dy / cellSize).floor();
    if (gx < 0 || gx >= size || gy < 0 || gy >= size) return;
    final pt = Point(gx, gy);
    if (_lastCell == null || _lastCell != pt) {
      _selCells.add(pt);
      _lastCell = pt;
      setState(() {});
    }
  }

  void _checkSelection() async {
    if (_selCells.length < 2) return;
    final a = _selCells.first;
    final b = _selCells.last;
    int dx = b.x - a.x, dy = b.y - a.y;
    final steps = max(dx.abs(), dy.abs());
    if (!(dx == 0 || dy == 0 || dx.abs() == dy.abs())) return;
    dx = dx.sign; dy = dy.sign;

    final buff = StringBuffer();
    final path = <Point<int>>[];
    int r = a.y, c = a.x;
    for (int i = 0; i <= steps; i++) {
      buff.write(grid[r][c]);
      path.add(Point(c, r));
      r += dy; c += dx;
    }
    final s = buff.toString();
    final rs = s.split('').reversed.join();

    String? found;
    List<Point<int>>? foundPath;
    if (remaining.contains(s)) { found = s; foundPath = path; }
    else if (remaining.contains(rs)) { found = rs; foundPath = path.reversed.toList(); }

    if (found != null) {
      remaining.remove(found);
      if (foundPath != null) _foundPaths.add(foundPath);
      await _persistActive();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Found: $found')));
      }
      if (remaining.isEmpty) {
        await _clearPersisted();
        final secs = DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
        final score = words.length / secs;
        await ScoreStore.instance.add('wordsearch', score);
        final isHigh = await ScoreStore.instance.reportBest('wordsearch', score);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(isHigh ? 'New High Score!' : 'Puzzle Complete'),
            content: Text(isHigh
                ? 'Speed: ${score.toString().padRight(5, '0') } words/sec'
                : 'Nice work! Want a fresh grid?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              FilledButton(onPressed: () { Navigator.pop(context); _newPuzzle(); }, child: const Text('New')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: words.map((w) {
        final found = !remaining.contains(w);
        return Chip(
          label: Text(
            w,
            style: TextStyle(
              decoration: found ? TextDecoration.lineThrough : TextDecoration.none,
              decorationThickness: 2,
              decorationColor: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: found ? const Color(0xFFA7E0C9) : Colors.white,
          side: const BorderSide(color: _ink),
        );
      }).toList(),
    );

    final topControls = Row(
      children: [
        const Text('Difficulty:', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        DropdownButton<_WsDifficulty>(
          value: difficulty,
          onChanged: (d) {
            if (d == null) return;
            setState(() => difficulty = d);
            _newPuzzle();
          },
          items: const [
            DropdownMenuItem(value: _WsDifficulty.easy, child: Text('Easy')),
            DropdownMenuItem(value: _WsDifficulty.medium, child: Text('Medium')),
            DropdownMenuItem(value: _WsDifficulty.hard, child: Text('Hard')),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _resetCurrent,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reset'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _newPuzzle,
          icon: const Icon(Icons.fiber_new_rounded, size: 18),
          label: const Text('New'),
        ),
      ],
    );

    return _GameScaffold(
      title: 'Word Search',
      rule: 'Drag across letters in a straight line (any direction) to select a word.',
      topBar: topControls,
      child: Column(
        children: [
          wordChips,
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final board = AspectRatio(
                  aspectRatio: 1,
                  child: Listener(
                    onPointerDown: (e) => _onPanStart(e.localPosition, cons),
                    onPointerMove: (e) => _onPanUpdate(e.localPosition, cons),
                    onPointerUp: (_) => _onPanEnd(),
                    child: CustomPaint(
                      painter: _WsPainter(grid, _selCells, _foundPaths),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
                return Center(child: board);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WsPainter extends CustomPainter {
  final List<List<String>> g;
  final Set<Point<int>> sel;
  final List<List<Point<int>>> foundPaths;
  _WsPainter(this.g, this.sel, this.foundPaths);

  @override
  void paint(Canvas c, Size s) {
    final n = g.length;
    final cell = s.width / n;
    final border = Paint()..color = _ink.withOpacity(.25)..style = PaintingStyle.stroke;
    final selBg = Paint()..color = const Color(0xFFFFF1A6);
    final txt = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final r = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        c.drawRRect(RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)), border);
        if (sel.contains(Point(x, y))) {
          c.drawRRect(RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)), selBg);
        }
        txt.text = TextSpan(
          text: g[y][x],
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
        );
        txt.layout(minWidth: cell, maxWidth: cell);
        txt.paint(c, Offset(x * cell, y * cell + (cell - txt.height) / 2));
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF0D7C66).withOpacity(.85)
      ..strokeWidth = cell * 0.20
      ..strokeCap = StrokeCap.round;

    for (final path in foundPaths) {
      if (path.isEmpty) continue;
      final first = path.first;
      final last = path.last;
      final p1 = Offset(first.x * cell + cell / 2, first.y * cell + cell / 2);
      final p2 = Offset(last.x * cell + cell / 2, last.y * cell + cell / 2);
      c.drawLine(p1, p2, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WsPainter old) =>
      old.g != g || old.sel != sel || old.foundPaths != foundPaths;
}
