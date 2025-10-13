// lib/pages/stress_busters.dart
// Stress Busters – calm themed games.
// Only Flutter + shared_preferences (already in pubspec). No extra packages.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────────────── Shared theme helpers ─────────────────── */

BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  // Match Tools/Home gradient but slightly softer to feel relaxing.
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

/* ─────────────────── Main page ─────────────────── */

class StressBustersPage extends StatelessWidget {
  const StressBustersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Stress Busters',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _CalmHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildListDelegate.fixed([
                    _GameCard(
                      title: 'Word Search',
                      subtitle: 'Find all hidden words',
                      colors: const [Color(0xFFE8F8FF), Color(0xFFB6E3FF)],
                      icon: Icons.grid_on_rounded,
                      builder: (_) => const WordSearchPage(),
                    ),
                    _GameCard(
                      title: 'Crossword',
                      subtitle: '7×7 with hints',
                      colors: const [Color(0xFFF7ECFF), Color(0xFFDAC8FF)],
                      icon: Icons.view_quilt_rounded,
                      builder: (_) => const CrosswordPage(),
                    ),
                    _GameCard(
                      title: 'Chess',
                      subtitle: 'Play vs computer',
                      colors: const [Color(0xFFE9FFF4), Color(0xFFC9F2E7)],
                      icon: Icons.sports_esports_rounded,
                      builder: (_) => const ChessVsAiPage(),
                    ),
                    _GameCard(
                      title: 'Matching',
                      subtitle: 'Flip pairs (animated)',
                      colors: const [Color(0xFFFFF6E8), Color(0xFFFFE5BA)],
                      icon: Icons.extension_rounded,
                      builder: (_) => const MatchDifficultPage(),
                    ),
                    _GameCard(
                      title: 'Solitaire',
                      subtitle: 'Klondike (draw 1)',
                      colors: const [Color(0xFFEFF7FF), Color(0xFFCAE2FF)],
                      icon: Icons.style_rounded,
                      builder: (_) => const SolitaireKlondikePage(),
                    ),
                    _GameCard(
                      title: 'Flappy Bird',
                      subtitle: 'Tap to fly',
                      colors: const [Color(0xFFE9FFFE), Color(0xFFBDF5F1)],
                      icon: Icons.flight_rounded,
                      builder: (_) => const FlappyPage(),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalmHeader extends StatefulWidget {
  const _CalmHeader();
  @override
  State<_CalmHeader> createState() => _CalmHeaderState();
}

class _CalmHeaderState extends State<_CalmHeader> {
  int plays = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    int total = 0;
    for (final k in p.getKeys()) {
      if (k.startsWith('sbp_')) total += (p.getStringList(k) ?? []).length;
    }
    if (mounted) setState(() => plays = total);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFBEE8DF), Color(0xFFDCCAF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ink, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            const Icon(Icons.self_improvement_rounded, size: 42, color: Color(0xFF0D7C66)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pick a calm game.\n$plays total plays saved.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title, subtitle;
  final List<Color> colors;
  final IconData icon;
  final WidgetBuilder builder;
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _ink, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: const Color(0xFF0D7C66)),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _ink),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Play', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────── Score storage + High-score popup ─────────── */

class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();

  // Append score to history (for fun stats)
  Future<void> add(String gameKey, double v) async {
    final prefs = await SharedPreferences.getInstance();
    final k = 'sbp_$gameKey';
    final cur = prefs.getStringList(k) ?? [];
    cur.add(v.toString());
    await prefs.setStringList(k, cur);
  }

  // Report and check best (higher is better). Returns true if new high score.
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

  Future<double?> getBest(String gameKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('sbp_best_$gameKey');
  }
}

/* ─────────────────── Game Scaffolding ─────────────────── */

class _GameScaffold extends StatelessWidget {
  final String title;
  final String rule;
  final Widget child;
  final Widget? topBar;
  final Widget? bottom;
  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
    this.topBar,
    this.bottom,
  });

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
                if (bottom != null) ...[const SizedBox(height: 8), bottom!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────── 1) Word Search ─────────────────── */

enum _WsDifficulty { easy, medium, hard }

class WordSearchPage extends StatefulWidget {
  const WordSearchPage({super.key});
  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  // Pools of word lists; each puzzle chooses a subset and fresh grid
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

  // Board state
  late int size;
  late List<List<String>> grid;
  late List<String> words;
  late Set<String> remaining;

  // Drag selection
  final _selCells = <Point<int>>{};
  Point<int>? _lastCell;
  bool _dragging = false;

  // Persist unfinished puzzle
  static const _saveKey = 'ws_active';
  static const _saveDiff = 'ws_active_diff';
  static const _saveWords = 'ws_active_words';
  static const _saveGrid = 'ws_active_grid';

  // Timer for scoring (words/sec)
  late DateTime _startTime;

  final rnd = Random();

  @override
  void initState() {
    super.initState();
    _tryRestoreOrNew();
  }

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
    _startTime = DateTime.now();
    _persistActive();
    setState(() {});
  }

  void _resetCurrent() {
    // Rebuild the same word list on a fresh grid
    grid = List.generate(size, (_) => List.filled(size, ''));
    remaining = words.toSet();
    _placeWords();
    _fillRandom();
    _selCells.clear();
    _lastCell = null;
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
    // Build contiguous line from first to last if straight
    final a = _selCells.first;
    final b = _selCells.last;
    int dx = b.x - a.x, dy = b.y - a.y;
    final steps = max(dx.abs(), dy.abs());
    if (!(dx == 0 || dy == 0 || dx.abs() == dy.abs())) return; // straight/diagonal only
    dx = dx.sign; dy = dy.sign;
    final buff = StringBuffer();
    int r = a.y, c = a.x;
    for (int i = 0; i <= steps; i++) {
      buff.write(grid[r][c]);
      r += dy; c += dx;
    }
    final s = buff.toString();
    final rs = s.split('').reversed.join();
    String? found;
    if (remaining.contains(s)) found = s; else if (remaining.contains(rs)) found = rs;
    if (found != null) {
      remaining.remove(found);
      await _persistActive();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Found: $found')));
      }
      if (remaining.isEmpty) {
        await _clearPersisted();
        final secs = DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
        final score = words.length / secs; // words per second
        await ScoreStore.instance.add('wordsearch', score);
        final isHigh = await ScoreStore.instance.reportBest('wordsearch', score);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(isHigh ? 'New High Score!' : 'Puzzle Complete'),
            content: Text(isHigh
                ? 'Speed: ${score.toStringAsFixed(3)} words/sec'
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
                  child: Listener( // fine-grained pointer -> smoother drag
                    onPointerDown: (e) => _onPanStart(e.localPosition, cons),
                    onPointerMove: (e) => _onPanUpdate(e.localPosition, cons),
                    onPointerUp: (_) => _onPanEnd(),
                    child: CustomPaint(
                      painter: _WsPainter(grid, _selCells),
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
  _WsPainter(this.g, this.sel);
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
  }
  @override
  bool shouldRepaint(covariant _WsPainter old) => old.g != g || old.sel != sel;
}

/* ─────────────────── 2) Crossword (7×7, clues + hints) ─────────────────── */

class CrosswordPage extends StatefulWidget {
  const CrosswordPage({super.key});
  @override
  State<CrosswordPage> createState() => _CrosswordPageState();
}

class _CrosswordPageState extends State<CrosswordPage> {
  // A couple of tiny 7×7 puzzles.
  // '#' = block; letters = solution. Keep them uppercase.
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
  late List<List<String?>> _cells; // null = block, ""/letter = user

  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _restoreOrNew();
  }

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
    // Fill a random incorrect/empty cell
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
                  return TextField(
                    controller: TextEditingController(text: _cells[r][c]),
                    onChanged: (v) async {
                      _cells[r][c] = v.isEmpty ? '' : v.substring(0, 1).toUpperCase();
                      await _persist();
                      setState(() {});
                      if (_complete()) {
                        await _clearPersisted();
                        final secs = DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
                        final score = 1 / secs; // higher is better (faster)
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _ink),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Clues
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ink),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ClueList(title: 'Across', clues: across),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ClueList(title: 'Down', clues: down),
                ),
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

/* ─────────────────── 3) Chess – playable vs simple AI ─────────────────── */

class ChessVsAiPage extends StatefulWidget {
  const ChessVsAiPage({super.key});
  @override
  State<ChessVsAiPage> createState() => _ChessVsAiPageState();
}

class _ChessVsAiPageState extends State<ChessVsAiPage> {
  // Pieces: white positive, black negative.
  // 1=P, 2=N, 3=B, 4=R, 5=Q, 6=K
  late List<int> b; // 64
  bool whiteTurn = true;
  int? sel;
  List<int> legal = [];
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    // Standard start (no castling/en passant; promotions to queen)
    b = [
      -4,-2,-3,-5,-6,-3,-2,-4,
      -1,-1,-1,-1,-1,-1,-1,-1,
      0,0,0,0,0,0,0,0,
      0,0,0,0,0,0,0,0,
      0,0,0,0,0,0,0,0,
      0,0,0,0,0,0,0,0,
      1,1,1,1,1,1,1,1,
      4,2,3,5,6,3,2,4,
    ];
    whiteTurn = true;
    sel = null;
    legal = [];
    gameOver = false;
    setState(() {});
  }

  int color(int p) => p == 0 ? 0 : (p > 0 ? 1 : -1);
  int at(int i) => b[i];
  void setAt(int i, int v) { b[i] = v; }

  List<int> _genMoves(int idx, {List<int>? board}) {
    board ??= b;
    final p = board[idx];
    if (p == 0) return [];
    final me = color(p);
    final List<int> out = [];
    int r = idx ~/ 8, c = idx % 8;

    bool add(int rr, int cc, {bool stopOnFirst = false}) {
      if (rr < 0 || rr >= 8 || cc < 0 || cc >= 8) return false;
      final to = rr * 8 + cc;
      final q = board?[to];
      if (q == 0) {
        out.add(to);
        return true; // can continue sliding
      } else if (color(q!) != me) {
        out.add(to);
        return false; // capture, stop
      } else {
        return false; // blocked
      }
    }

    final a = p.abs();
    if (a == 1) {
      // pawn
      final dir = me == 1 ? -1 : 1;
      final startRow = me == 1 ? 6 : 1;
      if (r + dir >= 0 && r + dir < 8) {
        if (board[(r + dir) * 8 + c] == 0) {
          out.add((r + dir) * 8 + c);
          if (r == startRow && board[(r + 2 * dir) * 8 + c] == 0) {
            out.add((r + 2 * dir) * 8 + c);
          }
        }
        for (final dc in [-1, 1]) {
          final cc = c + dc;
          if (cc >= 0 && cc < 8) {
            final to = (r + dir) * 8 + cc;
            if (board[to] != 0 && color(board[to]) != me) out.add(to);
          }
        }
      }
    } else if (a == 2) {
      // knight
      const d = [
        [2,1],[1,2],[-1,2],[-2,1],[-2,-1],[-1,-2],[1,-2],[2,-1]
      ];
      for (final v in d) {
        final rr = r + v[0], cc = c + v[1];
        if (rr < 0 || rr >= 8 || cc < 0 || cc >= 8) continue;
        final to = rr * 8 + cc;
        if (color(board[to]) != me) out.add(to);
      }
    } else if (a == 3 || a == 4 || a == 5) {
      final dirs = <List<int>>[];
      if (a != 3) dirs.addAll([[1,0],[-1,0],[0,1],[0,-1]]); // rook/queen
      if (a != 4) dirs.addAll([[1,1],[1,-1],[-1,1],[-1,-1]]); // bishop/queen
      for (final d in dirs) {
        int rr = r + d[0], cc = c + d[1];
        while (true) {
          if (!add(rr, cc)) break;
          rr += d[0]; cc += d[1];
        }
      }
    } else if (a == 6) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final rr = r + dr, cc = c + dc;
          if (rr < 0 || rr >= 8 || cc < 0 || cc >= 8) continue;
          final to = rr * 8 + cc;
          if (color(board[to]) != me) out.add(to);
        }
      }
    }
    // filter out moves that leave own king in check
    return out.where((to) => !_leavesKingInCheck(idx, to, board!)).toList();
  }

  bool _leavesKingInCheck(int from, int to, List<int> board) {
    final tmp = List<int>.from(board);
    final side = color(board[from]);
    tmp[to] = tmp[from];
    tmp[from] = 0;
    // promotion
    if (tmp[to].abs() == 1) {
      final r = to ~/ 8;
      if ((side == 1 && r == 0) || (side == -1 && r == 7)) tmp[to] = side * 5; // queen
    }
    return _inCheck(side, tmp);
  }

  bool _inCheck(int side, List<int> board) {
    int king = -1;
    for (int i = 0; i < 64; i++) if (board[i] == side * 6) { king = i; break; }
    if (king == -1) return true;
    for (int i = 0; i < 64; i++) {
      if (board[i] == 0 || color(board[i]) == side) continue;
      if (_genMoves(i, board: board).contains(king)) return true;
    }
    return false;
  }

  List<(int from,int to)> _allMoves(bool white, List<int> board) {
    final side = white ? 1 : -1;
    final out = <(int,int)>[];
    for (int i = 0; i < 64; i++) {
      if (board[i] == 0 || color(board[i]) != side) continue;
      final moves = _genMoves(i, board: board);
      for (final m in moves) { out.add((i, m)); }
    }
    return out;
  }

  Future<void> _aiMove() async {
    if (gameOver) return;
    await Future.delayed(const Duration(milliseconds: 200));
    final moves = _allMoves(false, b);
    if (moves.isEmpty) {
      // stalemate or mate
      gameOver = true;
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(title: Text('Game over'), content: Text('No legal moves for Black.')),
        );
        _newGame();
      }
      return;
    }
    // random legal move
    final mv = moves[Random().nextInt(moves.length)];
    setState(() {
      final p = b[mv.$1];
      b[mv.$2] = p;
      b[mv.$1] = 0;
      // promotion:
      if ((p == -1 && mv.$2 ~/ 8 == 7)) b[mv.$2] = -5;
      whiteTurn = true;
      sel = null;
      legal = [];
    });
    if (_isMate(true)) {
      gameOver = true;
      if (!mounted) return;
      await ScoreStore.instance.add('chess_ai', 1.0);
      final high = await ScoreStore.instance.reportBest('chess_ai', 1.0);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(high ? 'New High Score!' : 'Checkmate'),
          content: const Text('You beat the computer!'),
        ),
      );
      _newGame();
    }
  }

  bool _isMate(bool whiteSide) {
    final side = whiteSide ? 1 : -1;
    if (!_inCheck(-side, b)) return false;
    return _allMoves(!whiteSide, b).isEmpty;
  }

  void _tap(int i) async {
    if (gameOver) return;
    if (whiteTurn) {
      if (sel == null) {
        if (b[i] > 0) {
          setState(() { sel = i; legal = _genMoves(i); });
        }
      } else {
        if (i == sel) { setState(() { sel = null; legal = []; }); return; }
        if (legal.contains(i)) {
          // make move
          setState(() {
            final p = b[sel!];
            b[i] = p; b[sel!] = 0;
            // promotion:
            if (p == 1 && i ~/ 8 == 0) b[i] = 5;
            whiteTurn = false; sel = null; legal = [];
          });
          if (_isMate(false)) {
            gameOver = true;
            if (!mounted) return;
            await ScoreStore.instance.add('chess_ai', 1.0);
            final high = await ScoreStore.instance.reportBest('chess_ai', 1.0);
            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(high ? 'New High Score!' : 'Checkmate'),
                content: const Text('You checkmated Black!'),
              ),
            );
            _newGame();
            return;
          }
          await _aiMove();
        } else {
          if (b[i] > 0) { setState(() { sel = i; legal = _genMoves(i); }); }
        }
      }
    }
  }

  Widget _sq(int idx) {
    final f = idx % 8, r = idx ~/ 8;
    final dark = (f + r) % 2 == 1;
    Color c = dark ? const Color(0xFF769656) : const Color(0xFFEEEED2);
    if (sel == idx) c = Colors.amber.withOpacity(.8);
    if (legal.contains(idx)) c = Colors.lightGreenAccent.shade700.withOpacity(.6);
    String glyph = '';
    switch (b[idx]) {
      case 1: glyph = '♙'; break;
      case 2: glyph = '♘'; break;
      case 3: glyph = '♗'; break;
      case 4: glyph = '♖'; break;
      case 5: glyph = '♕'; break;
      case 6: glyph = '♔'; break;
      case -1: glyph = '♟︎'; break;
      case -2: glyph = '♞'; break;
      case -3: glyph = '♝'; break;
      case -4: glyph = '♜'; break;
      case -5: glyph = '♛'; break;
      case -6: glyph = '♚'; break;
    }
    final isWhite = b[idx] > 0;
    return GestureDetector(
      onTap: () => _tap(idx),
      child: Container(
        color: c,
        child: Center(child: Text(glyph, style: TextStyle(fontSize: 26, color: isWhite ? Colors.white : Colors.black))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'Chess (vs AI)',
      rule: 'Play White. Simple rules (no castling/en-passant, promotions → queen).',
      topBar: Row(
        children: [
          Text(whiteTurn ? 'Your move' : 'Computer thinking...', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _newGame,
            icon: const Icon(Icons.fiber_new_rounded, size: 18),
            label: const Text('New Game'),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
          itemCount: 64,
          itemBuilder: (_, i) => _sq(i),
        ),
      ),
    );
  }
}

/* ─────────────────── 4) Matching – designs + animation ─────────────────── */

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

/* ─────────────────── 5) Solitaire (Klondike-lite, draw-1) ─────────────────── */

class SolitaireKlondikePage extends StatefulWidget {
  const SolitaireKlondikePage({super.key});
  @override
  State<SolitaireKlondikePage> createState() => _SolitaireKlondikePageState();
}

// small helper for drag data (avoids Dart record syntax issues)
class TableauDrag {
  final int from;
  final List<int> stack;
  const TableauDrag(this.from, this.stack);
}

class _SolitaireKlondikePageState extends State<SolitaireKlondikePage> {
  // Cards 0..51; suit = ~/13, rank = %13 (A..K)
  final rnd = Random();
  late List<int> stock, waste;
  late List<List<int>> tableau; // 7 piles (face up all for simplicity after deal top)
  late List<List<int>> faceDown; // not shown; flip as in Klondike
  late List<List<int>> foundation; // 4 piles

  @override
  void initState() { super.initState(); _deal(); }

  void _deal() {
    final deck = List.generate(52, (i) => i)..shuffle(rnd);
    tableau = List.generate(7, (_) => []);
    faceDown = List.generate(7, (_) => []);
    foundation = List.generate(4, (_) => []);
    int idx = 0;
    for (int p = 0; p < 7; p++) {
      for (int j = 0; j <= p; j++) {
        if (j == p) { tableau[p].add(deck[idx++]); }
        else { faceDown[p].add(deck[idx++]); }
      }
    }
    stock = deck.sublist(idx);
    waste = [];
    setState(() {});
  }

  int suit(int c) => c ~/ 13;
  int rank(int c) => c % 13; // 0=A .. 12=K
  Color cardColor(int c) => (suit(c) % 2 == 0) ? Colors.red : Colors.black;
  String rankStr(int r) => const ['A','2','3','4','5','6','7','8','9','10','J','Q','K'][r];
  String suitStr(int s) => const ['♥','♠','♦','♣'][s];

  bool canMoveToTableau(int card, int pile) {
    if (tableau[pile].isEmpty) return rank(card) == 12; // K
    final top = tableau[pile].last;
    final alternating = (cardColor(card) != cardColor(top));
    return alternating && (rank(card) == rank(top) - 1);
  }

  bool canMoveToFoundation(int card, int f) {
    if (foundation[f].isEmpty) return rank(card) == 0; // A
    final top = foundation[f].last;
    return suit(card) == suit(top) && rank(card) == rank(top) + 1;
  }

  void drawStock() {
    if (stock.isEmpty) {
      stock = List.from(waste.reversed);
      waste.clear();
    } else {
      waste.add(stock.removeLast());
    }
    setState(() {});
  }

  void moveWasteToTableau(int p) {
    if (waste.isEmpty) return;
    final card = waste.last;
    if (canMoveToTableau(card, p)) {
      tableau[p].add(waste.removeLast());
      setState(() {});
    }
  }

  void moveWasteToFoundation(int f) {
    if (waste.isEmpty) return;
    final card = waste.last;
    if (canMoveToFoundation(card, f)) { foundation[f].add(waste.removeLast()); setState(() {}); }
  }

  void moveTableauToFoundation(int p, int f) {
    if (tableau[p].isEmpty) return;
    final card = tableau[p].last;
    if (canMoveToFoundation(card, f)) {
      foundation[f].add(tableau[p].removeLast());
      if (tableau[p].isEmpty && faceDown[p].isNotEmpty) {
        tableau[p].add(faceDown[p].removeLast()); // flip
      }
      setState(() {});
    }
  }

  void moveBetweenTableau(int from, int to) {
    if (tableau[from].isEmpty) return;
    // move a run starting at some index
    for (int i = 0; i < tableau[from].length; i++) {
      final moving = tableau[from].sublist(i);
      // verify the stack is descending alternating
      bool ok = true;
      for (int j = 0; j < moving.length - 1; j++) {
        final a = moving[j], b = moving[j + 1];
        if (!(cardColor(a) != cardColor(b) && rank(a) == rank(b) + 1)) { ok = false; break; }
      }
      if (!ok) continue;
      if (moving.isNotEmpty && canMoveToTableau(moving.first, to)) {
        tableau[to].addAll(moving);
        tableau[from].removeRange(i, tableau[from].length);
        if (tableau[from].isEmpty && faceDown[from].isNotEmpty) {
          tableau[from].add(faceDown[from].removeLast());
        }
        setState(() {});
        return;
      }
    }
  }

  bool _win() => foundation.fold<int>(0, (a, f) => a + f.length) == 52;

  Widget _card(int c, {bool small=false}) {
    return Container(
      width: small ? 44 : 56,
      height: small ? 60 : 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ink, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Center(
        child: Text('${rankStr(rank(c))}${suitStr(suit(c))}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cardColor(c),
              fontSize: small ? 14 : 18,
            )),
      ),
    );
  }

  Widget _slot({String? label}) => Container(
        width: 56, height: 78,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _ink),
        ),
        child: label == null ? null : Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
      );

  @override
  Widget build(BuildContext context) {
    final topBar = Row(
      children: [
        FilledButton.icon(
          onPressed: () { _deal(); },
          icon: const Icon(Icons.fiber_new_rounded, size: 18),
          label: const Text('New Game'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            drawStock();
          },
          icon: const Icon(Icons.unarchive_rounded, size: 18),
          label: const Text('Draw'),
        ),
        const Spacer(),
        if (_win())
          const Text('You win!', style: TextStyle(fontWeight: FontWeight.w900)),
      ],
    );

    return _GameScaffold(
      title: 'Solitaire',
      rule: 'Klondike-lite: draw-1. Build foundations A→K by suit; tableau in alternating colors descending.',
      topBar: topBar,
      child: Column(
        children: [
          // Stock / Waste / Foundations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(onTap: drawStock, child: stock.isNotEmpty ? _slot(label: '${stock.length}') : _slot(label: 'Stock')),
              const SizedBox(width: 8),
              waste.isNotEmpty ? _card(waste.last) : _slot(label: 'Waste'),
              const Spacer(),
              ...List.generate(4, (f) {
                return GestureDetector(
                  onTap: () => moveWasteToFoundation(f),
                  child: foundation[f].isNotEmpty ? _card(foundation[f].last) : _slot(label: 'A'),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          // Tableau
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (p) {
                  final pile = tableau[p];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => moveWasteToTableau(p),
                      onDoubleTap: () => moveTableauToFoundation(p, 0), // quick move try to F0
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (int i = 0; i < pile.length; i++)
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 24),
                                child: Draggable<TableauDrag>(
                                  data: TableauDrag(p, pile.sublist(i)),
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Column(
                                      children: pile.sublist(i).map((c) => _card(c, small: true)).toList(),
                                    ),
                                  ),
                                  childWhenDragging: const SizedBox.shrink(),
                                  child: _card(pile[i]),
                                ),
                              ),
                            const SizedBox(height: 12),
                            DragTarget<TableauDrag>(
                              onWillAccept: (d) {
                                if (d == null || d.stack.isEmpty) return false;
                                return canMoveToTableau(d.stack.first, p);
                              },
                              onAccept: (d) {
                                if (!canMoveToTableau(d.stack.first, p)) return;
                                tableau[p].addAll(d.stack);
                                tableau[d.from].removeRange(tableau[d.from].length - d.stack.length, tableau[d.from].length);
                                if (tableau[d.from].isEmpty && faceDown[d.from].isNotEmpty) {
                                  tableau[d.from].add(faceDown[d.from].removeLast());
                                }
                                setState(() {});
                              },
                              builder: (_, __, ___) => const SizedBox(height: 40),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────── 6) Flappy Bird (tap to flap + bird sprite) ─────────────────── */

class FlappyPage extends StatefulWidget {
  const FlappyPage({super.key});
  @override
  State<FlappyPage> createState() => _FlappyPageState();
}
class _FlappyPageState extends State<FlappyPage> {
  double y = 0, v = 0;
  Timer? t;
  final rnd = Random();
  List<double> pipes = [];
  double gapY = 0;
  int score = 0;

  void _start() { y = 0; v = 0; pipes = [1.2, 1.8]; gapY = 0; score = 0; _tick(); }
  void _tick() {
    t?.cancel();
    t = Timer.periodic(const Duration(milliseconds: 16), (timer) async {
      v += 0.0026; y += v;
      for (int i = 0; i < pipes.length; i++) pipes[i] -= 0.008;
      if (pipes.first < -0.1) { pipes.removeAt(0); pipes.add(1.1); gapY = rnd.nextDouble() * .8 - .4; score++; }
      if (y > .95 || y < -1 || _collide()) {
        timer.cancel();
        final s = score.toDouble();
        await ScoreStore.instance.add('flappy', s);
        final high = await ScoreStore.instance.reportBest('flappy', s);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(high ? 'New High Score!' : 'Game Over'),
            content: Text('Score: $score'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      }
      if (mounted) setState(() {});
    });
  }
  bool _collide() {
    for (final x in pipes) {
      if ((x - .2).abs() < .07) {
        if (y < gapY - .15 || y > gapY + .15) return true;
      }
    }
    return false;
  }
  void _flap() => setState(() => v = -0.045);
  @override
  void dispose() { t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final topBar = Row(
      children: [
        Text('Score: $score', style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Start'),
        )
      ],
    );
    return _GameScaffold(
      title: 'Flappy Bird',
      rule: 'Tap anywhere to flap through the gaps.',
      topBar: topBar,
      child: GestureDetector(
        onTap: _flap,
        child: CustomPaint(painter: _FlappyPainter(y, pipes, gapY), child: const SizedBox.expand()),
      ),
    );
  }
}

class _FlappyPainter extends CustomPainter {
  final double y; final List<double> pipes; final double gapY;
  _FlappyPainter(this.y, this.pipes, this.gapY);
  @override
  void paint(Canvas c, Size s) {
    final pipe = Paint()..color = Colors.green.shade700;
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white.withOpacity(.3));
    for (final x in pipes) {
      final px = x * s.width;
      final topH = (gapY - .15 + 1) * s.height / 2;
      final bottomY = (gapY + .15 + 1) * s.height / 2;
      c.drawRect(Rect.fromLTWH(px, 0, 34, topH.clamp(0, s.height)), pipe);
      c.drawRect(Rect.fromLTWH(px, bottomY, 34, s.height - bottomY), pipe);
    }
    // Bird (body, wing, beak)
    final center = Offset(s.width * .2, s.height * (.5 + y / 2));
    c.drawCircle(center, 14, Paint()..color = const Color(0xFFFFD54F));
    c.drawCircle(center + const Offset(-6, -4), 7, Paint()..color = const Color(0xFFFFF59D)); // wing
    final beak = Path()
      ..moveTo(center.dx + 12, center.dy)
      ..lineTo(center.dx + 18, center.dy - 4)
      ..lineTo(center.dx + 18, center.dy + 4)
      ..close();
    c.drawPath(beak, Paint()..color = const Color(0xFFFF7043));
    c.drawCircle(center + const Offset(4, -4), 2, Paint()..color = Colors.black);
  }
  @override
  bool shouldRepaint(covariant _FlappyPainter old) => y != old.y || gapY != old.gapY || pipes != old.pipes;
}

/* ─────────── small util ─────────── */
int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
