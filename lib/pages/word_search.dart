// lib/pages/word_search.dart
//
// Word Search with persistent strike-through lines.
// - Saves: difficulty, words, grid, remaining words, and the exact paths
//   for found words. When you come back, the crossed-off lines reappear.
// - If an older save (pre-paths) is loaded, it reconstructs paths by
//   searching the grid for each already-found word.
//

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────────────── Shared look (same as Stress Busters) ─────────────────── */

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

/* ─────────── Score storage (shared key style) ─────────── */

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

/* ─────────────────── Game wrapper used elsewhere ─────────────────── */

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

/* ─────────────────── Word Search ─────────────────── */

enum _WsDifficulty { easy, medium, hard }

class WordSearchPage extends StatefulWidget {
  const WordSearchPage({super.key});
  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> with TickerProviderStateMixin {
  // Expanded word pools (added more words)
  static const Map<_WsDifficulty, List<List<String>>> _pools = {
    _WsDifficulty.easy: [
      ['CALM', 'BREATHE', 'FOCUS', 'PAUSE', 'SMILE', 'REST', 'NAP', 'EASY'],
      ['PEACE', 'REST', 'KIND', 'WARM', 'SOFT', 'JOY', 'HUG', 'NICE'],
      ['OCEAN', 'CLOUD', 'LEAF', 'QUIET', 'EASE', 'BIRD', 'LILY', 'MILD'],
      ['COZY', 'SLOW', 'ZEN', 'CARE', 'KINDLY', 'SUN', 'MOON', 'RAIN'],
    ],
    _WsDifficulty.medium: [
      ['BALANCE', 'GROUND', 'MINDFUL', 'RELAX', 'GENTLE', 'CENTER', 'STEADY'],
      ['GRATITUDE', 'SERENITY', 'STEADY', 'BREATHER', 'FEATHER', 'SUNLIGHT'],
      ['SUNLIGHT', 'BREEZE', 'GENTLE', 'CENTER', 'HARMONY', 'SOOTHING'],
      ['KINDNESS', 'PAUSING', 'REFRESH', 'RECENTER', 'SOFTNESS'],
    ],
    _WsDifficulty.hard: [
      ['RESILIENCE', 'TRANQUIL', 'PATIENCE', 'HARMONY', 'CONTENTMENT'],
      ['COMPOSURE', 'BREATHWORK', 'EQUANIMITY', 'STILLNESS', 'PRESENCE'],
      ['MEDITATION', 'STILLNESS', 'PRESENCE', 'ACCEPTANCE', 'ATTUNEMENT'],
      ['TRANQUILITY', 'EVENHANDED', 'MINDFULNESS', 'REFLECTION'],
    ],
  };

  _WsDifficulty difficulty = _WsDifficulty.easy;

  // Board
  late int size;
  late List<List<String>> grid;
  late List<String> words;
  late Set<String> remaining;

  // Selection & found paths
  final _selCells = <Point<int>>{};
  Point<int>? _lastCell;
  bool _dragging = false;

  /// Persistent strike-throughs (each is an ordered list of points).
  final List<List<Point<int>>> _foundPaths = [];

  // Persistence keys
  static const _saveKey = 'ws_active';
  static const _saveDiff = 'ws_active_diff';
  static const _saveWords = 'ws_active_words';
  static const _saveGrid = 'ws_active_grid';
  static const _savePaths = 'ws_active_paths'; // List<String> of serialized paths

  // Timer (score)
  late DateTime _startTime;

  final rnd = Random();

  // Win animation overlay
  OverlayEntry? _winOverlay;

  @override
  void initState() {
    super.initState();
    _tryRestoreOrNew();
  }

  /* ─────────── Persistence helpers ─────────── */

  String _encodePath(List<Point<int>> p) =>
      p.map((pt) => '${pt.x},${pt.y}').join('|');

  List<Point<int>> _decodePath(String s) {
    final out = <Point<int>>[];
    for (final seg in s.split('|')) {
      if (seg.isEmpty) continue;
      final parts = seg.split(',');
      if (parts.length == 2) {
        final x = int.tryParse(parts[0]);
        final y = int.tryParse(parts[1]);
        if (x != null && y != null) out.add(Point(x, y));
      }
    }
    return out;
  }

  Future<void> _persistActive() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_saveDiff, difficulty.index);
    await p.setStringList(_saveWords, words);
    await p.setStringList(_saveKey, remaining.toList());
    final flat = <String>[];
    for (final r in grid) { flat.addAll(r); }
    await p.setStringList(_saveGrid, flat);
    final enc = _foundPaths.map(_encodePath).toList();
    await p.setStringList(_savePaths, enc);
  }

  Future<void> _clearPersisted() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_saveDiff);
    await p.remove(_saveWords);
    await p.remove(_saveKey);
    await p.remove(_saveGrid);
    await p.remove(_savePaths);
  }

  Future<void> _tryRestoreOrNew() async {
    final p = await SharedPreferences.getInstance();
    final diffIdx = p.getInt(_saveDiff);
    final wordsSaved = p.getStringList(_saveWords);
    final gridSaved = p.getStringList(_saveGrid);
    final pathsSaved = p.getStringList(_savePaths);
    if (diffIdx != null && wordsSaved != null && gridSaved != null) {
      difficulty = _WsDifficulty.values[diffIdx];
      size = sqrt(gridSaved.length).round();
      grid = List.generate(size, (r) => List.generate(size, (c) => gridSaved[r * size + c]));
      words = List.from(wordsSaved);
      remaining = p.getStringList(_saveKey)?.toSet() ?? words.toSet();
      _foundPaths.clear();
      if (pathsSaved != null && pathsSaved.isNotEmpty) {
        for (final s in pathsSaved) {
          final path = _decodePath(s);
          if (path.isNotEmpty) _foundPaths.add(path);
        }
      } else {
        final foundWords = words.where((w) => !remaining.contains(w)).toList();
        for (final w in foundWords) {
          final path = _findWordPath(w);
          if (path != null) _foundPaths.add(path);
        }
        await _persistActive();
      }
      _startTime = DateTime.now();
      setState(() {});
      return;
    }
    _newPuzzle(resetDifficulty: false);
  }

  /* ─────────── Build / reset ─────────── */

  void _newPuzzle({bool resetDifficulty = false}) {
    if (resetDifficulty) difficulty = _WsDifficulty.easy;
    final pool = _pools[difficulty]!;
    final list = List<List<String>>.from(pool)..shuffle(rnd);
    words = List<String>.from(list.first)..shuffle(rnd);

    size = (difficulty == _WsDifficulty.easy)
        ? 12
        : (difficulty == _WsDifficulty.medium ? 13 : 14);

    grid = List.generate(size, (_) => List.filled(size, ''));
    // placeWords now returns the actually placed words to avoid "overfill" issues
    words = _placeWords(words);
    remaining = words.toSet();
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
    // Re-place only the current words; keep only those that fit to prevent overfill
    words = _placeWords(words);
    remaining = words.toSet();
    _fillRandom();
    _selCells.clear();
    _lastCell = null;
    _foundPaths.clear();
    _startTime = DateTime.now();
    _persistActive();
    setState(() {});
  }

  /* ─────────── Grid gen ─────────── */

  /// Places as many words as fit. Returns the list of actually placed words.
  List<String> _placeWords(List<String> source) {
    final dirs = [
      const Point(1,0), const Point(0,1), const Point(1,1), const Point(-1,1),
      const Point(-1,0), const Point(0,-1), const Point(-1,-1), const Point(1,-1),
    ];
    final placedWords = <String>[];

    for (final w in source) {
      bool placed = false;
      for (int tries = 0; tries < 500 && !placed; tries++) {
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
        placedWords.add(w);
      }
    }
    return placedWords;
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

  /* ─────────── Restore helper for old saves ─────────── */

  List<Point<int>>? _findWordPath(String word) {
    final dirs = [
      const Point(1,0), const Point(0,1), const Point(1,1), const Point(-1,1),
      const Point(-1,0), const Point(0,-1), const Point(-1,-1), const Point(1,-1),
    ];
    bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

    for (final target in [word, String.fromCharCodes(word.runes.toList().reversed)]) {
      for (int r0 = 0; r0 < size; r0++) {
        for (int c0 = 0; c0 < size; c0++) {
          for (final d in dirs) {
            int r = r0, c = c0;
            bool ok = true;
            final path = <Point<int>>[];
            for (int i = 0; i < target.length; i++) {
              if (!inBounds(r, c) || grid[r][c] != target[i]) { ok = false; break; }
              path.add(Point(c, r));
              r += d.y; c += d.x;
            }
            if (ok) return path;
          }
        }
      }
    }
    return null;
  }

  /* ─────────── Gesture → selection (only exact squares under pointer) ─────────── */

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

    // Only add the exact cell currently under the pointer; no interpolation to neighbors.
    if (_lastCell == null || _lastCell != pt) {
      _selCells.add(pt);
      _lastCell = pt;
      setState(() {});
    }
  }

  Future<void> _checkSelection() async {
    if (_selCells.length < 2) return;
    final a = _selCells.first;
    final b = _selCells.last;
    int dx = b.x - a.x, dy = b.y - a.y;
    final steps = max(dx.abs(), dy.abs());
    if (!(dx == 0 || dy == 0 || dx.abs() == dy.abs())) return; // straight/diag only
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
        await _onWin();
      }
    }
  }

  Future<void> _onWin() async {
    await _clearPersisted();
    final secs = DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
    final score = words.length / secs; // words per second
    await ScoreStore.instance.add('wordsearch', score);
    final isHigh = await ScoreStore.instance.reportBest('wordsearch', score);

    _showWinAnimation();
    await Future.delayed(const Duration(milliseconds: 1400));
    _hideWinAnimation();

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

  /* ─────────── Win animation (confetti-like burst) ─────────── */

  void _showWinAnimation() {
    if (_winOverlay != null) return;
    final entry = OverlayEntry(
      builder: (ctx) => _WinConfettiOverlay(vsync: this),
    );
    _winOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _hideWinAnimation() {
    _winOverlay?.remove();
    _winOverlay = null;
  }

  /* ─────────── UI ─────────── */

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

/* ─────────── Painter ─────────── */

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

    // grid + selection
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

    // strike-through lines for found words (persisted)
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

/* ─────────── Win confetti overlay ─────────── */

class _WinConfettiOverlay extends StatefulWidget {
  final TickerProvider vsync;
  const _WinConfettiOverlay({required this.vsync});

  @override
  State<_WinConfettiOverlay> createState() => _WinConfettiOverlayState();
}

class _WinConfettiOverlayState extends State<_WinConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  final _particles = <_Particle>[];
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _spawn();
    _ctrl.forward();
  }

  void _spawn() {
    // spawn a handful of particles
    for (int i = 0; i < 60; i++) {
      _particles.add(
        _Particle(
          dx: (_rnd.nextDouble() * 2 - 1) * 180,
          dy: (_rnd.nextDouble() * 2 - 1) * 180,
          size: 6 + _rnd.nextDouble() * 10,
          rotation: _rnd.nextDouble() * pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final double t = _anim.value;
          final double clamped = (t.clamp(0.0, 1.0) as double);
          final double opacity = 1.0 - clamped;

          return Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: Stack(
                children: [
                  // subtle backdrop flash
                  Container(color: const Color(0xFFFFFFFF).withOpacity(0.2 * opacity)),
                  // burst from center
                  ..._particles.map((p) {
                    final dx = p.dx * t;
                    final dy = p.dy * t;
                    final scale = 0.6 + 0.6 * (1 - (t - 0.3).abs());
                    return Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: p.rotation * (1 + t),
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: p.size,
                              height: p.size,
                              decoration: BoxDecoration(
                                color: _randColor(p.hashCode),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  // center trophy
                  Align(
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * (1 - (t - 0.2).abs()),
                      child: const Icon(Icons.emoji_events_rounded, size: 96, color: Color(0xFF0D7C66)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _randColor(int seed) {
    final r = (seed * 97) % 255;
    final g = (seed * 57) % 255;
    final b = (seed * 127) % 255;
    return Color.fromARGB(255, r, g, b);
  }
}

class _Particle {
  final double dx, dy, size, rotation;
  _Particle({required this.dx, required this.dy, required this.size, required this.rotation});
}
