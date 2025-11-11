// lib/pages/word_search.dart
//
// Category chooser + themed Word Search.
// - Difficulty now changes ONLY the number of words (board size/position stay the same):
//     Easy   = 8 words
//     Medium = 12 words
//     Hard   = 15 words
// - Fixed: no accidental extra category words appear in the grid (we detect & break them).
// - Letters render directly on the gradient (no white board).
// - Capsule “bubble” bands when selecting/found.
// - Score history + best score (SharedPreferences).
//
// NOTE: The board’s position and size are unchanged across difficulties.

import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────── Theme ─────────── */

const _ink = Colors.black;
const _themeGreen = Color(0xFF0D7C66);

const _headerTextStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w900,
);

BoxDecoration _bg(BuildContext context, [String? _unusedCategory]) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
          : const [Color(0xFFE9D9FF), Color(0xFFBEE8E0)],
    ),
  );
}

/* ─────────── iOS back ─────────── */

class _BackButtonIOS extends StatelessWidget {
  const _BackButtonIOS({this.onPressed, this.iconSize = 22, super.key});
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2B2B2B)),
      iconSize: iconSize,
      padding: const EdgeInsets.only(left: 6),
      constraints: const BoxConstraints.tightFor(width: 52, height: 52),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}

/* ─────────── Score Store ─────────── */

class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();

  static const String wsBestKey = 'word_search_best';
  static const String wsHistKey = 'word_search_history';

  Future<int> getWordSearchBest() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(wsBestKey) ?? 0;
  }

  Future<bool> updateWordSearchBest(int score) async {
    final p = await SharedPreferences.getInstance();
    final prev = p.getInt(wsBestKey) ?? 0;
    final isHigh = score > prev;
    if (isHigh) await p.setInt(wsBestKey, score);
    return isHigh;
  }

  Future<void> addWordSearchHistory({
    required int score,
    required String difficulty,
    required String category,
    required int seconds,
    required int words,
  }) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(wsHistKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = json.decode(raw);
        if (d is List) {
          list = d.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    list.insert(0, {
      'ts': DateTime.now().toIso8601String(),
      'score': score,
      'difficulty': difficulty,
      'category': category,
      'seconds': seconds,
      'words': words,
    });
    if (list.length > 50) list = list.take(50).toList();
    await p.setString(wsHistKey, json.encode(list));
  }

  Future<List<Map<String, dynamic>>> loadWordSearchHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(wsHistKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final d = json.decode(raw);
      if (d is List) {
        return d.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    return [];
  }
}

/* ─────────── Category Chooser ─────────── */

class WordSearchCategoryPage extends StatefulWidget {
  final void Function(String category)? onPick;
  const WordSearchCategoryPage({super.key, this.onPick});

  @override
  State<WordSearchCategoryPage> createState() => _WordSearchCategoryPageState();
}

class _WordSearchCategoryPageState extends State<WordSearchCategoryPage>
    with TickerProviderStateMixin {
  static const _categories = [
    'Animals','Food','Sports','Travel','Movies','Technology'
  ];

  AnimationController? _aurora;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _loadBest();
  }

  Future<void> _loadBest() async {
    _best = await ScoreStore.instance.getWordSearchBest();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _aurora?.dispose();
    super.dispose();
  }

  void _navigateToCategory(String cat) {
    if (widget.onPick != null) {
      widget.onPick!(cat);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WordSearchPage(category: cat)),
      );
    }
  }

  Future<void> _showHistory() async {
    final hist = await ScoreStore.instance.loadWordSearchHistory();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _ink),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 44, margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(20))),
              const Text('Word Search – Score History',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              if (hist.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No scores yet. Finish a puzzle to record one!'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: hist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = hist[i];
                      final when = DateTime.tryParse(e['ts'] ?? '') ?? DateTime.now();
                      final stamp =
                          '${when.month}/${when.day}/${when.year} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.emoji_events_rounded, color: _themeGreen),
                        title: Text('Score ${e['score']}  •  ${e['difficulty']}'),
                        subtitle: Text('${e['category']} • ${e['seconds']}s • ${e['words']} words\n$stamp'),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Animals': return Icons.pets_rounded;
      case 'Food': return Icons.restaurant_menu_rounded;
      case 'Sports': return Icons.sports_soccer_rounded;
      case 'Travel': return Icons.flight_takeoff_rounded;
      case 'Movies': return Icons.movie_creation_rounded;
      case 'Technology': return Icons.memory_rounded;
      default: return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        leadingWidth: 52,
        leading: _BackButtonIOS(
          onPressed: () => Navigator.pop(context),
          iconSize: 22,
        ),
        title: const Text('Choose a Category', style: _headerTextStyle),
        actions: [
          IconButton(
            tooltip: 'Score history',
            icon: const Icon(Icons.bar_chart_rounded, color: _ink),
            onPressed: _showHistory,
          ),
        ],
      ),
      body: Container(
        decoration: _bg(context),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _aurora ?? const AlwaysStoppedAnimation(0.0),
                  builder: (context, _) => CustomPaint(
                    painter: _AuroraPainter((_aurora?.value ?? 0.0), dark),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _aurora ?? const AlwaysStoppedAnimation(0.0),
                  builder: (context, _) => CustomPaint(
                    painter: _BubblesPainter((_aurora?.value ?? 0.0), dark),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.95),
                          border: Border.all(color: _ink),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: _themeGreen, size: 18),
                            const SizedBox(width: 8),
                            Text('Best Score: $_best',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Center(
                        child: Wrap(
                          spacing: 22,
                          runSpacing: 22,
                          alignment: WrapAlignment.center,
                          children: _categories.map((cat) {
                            return _CategoryBubble(
                              cat: cat,
                              icon: _iconForCategory(cat),
                              onTap: () => _navigateToCategory(cat),
                              t: (_aurora?.value ?? 0.0),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({required this.cat, required this.icon, required this.onTap, required this.t});
  final String cat;
  final IconData icon;
  final VoidCallback onTap;
  final double t;

  @override
  Widget build(BuildContext context) {
    final glow = 0.14 + 0.08 * sin((t * 2 * pi) + cat.hashCode);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 148,
        height: 136,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.86)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _themeGreen.withOpacity(0.85), width: 2),
          boxShadow: [BoxShadow(color: _themeGreen.withOpacity(glow), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0D7C66).withOpacity(0.10)),
              child: Icon(icon, color: _themeGreen, size: 30),
            ),
            const SizedBox(height: 12),
            Text(cat, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
          ],
        ),
      ),
    );
  }
}

/* ─────────── Game Core ─────────── */

enum _WsDifficulty { easy, medium, hard }

class WordSearchPage extends StatefulWidget {
  final String category;
  const WordSearchPage({super.key, required this.category});

  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  final rnd = Random();

  bool _loading = true;
  late List<List<String>> grid;
  late List<String> words;
  late Set<String> remaining;

  final _selCells = <Point<int>>{};
  final List<List<Point<int>>> _foundPaths = [];

  Point<int>? _startCell;
  Point<int>? _lastCell;
  bool _dragging = false;

  int size = 12; // board stays 12x12 (unchanged)
  _WsDifficulty difficulty = _WsDifficulty.easy;
  late DateTime _startTime;

  static const Map<String, List<String>> _wordPools = {
    'Animals': [
      'LION','TIGER','ELEPHANT','BEAR','ZEBRA','HORSE','DOG','CAT','EAGLE','SNAKE',
      'DOLPHIN','WOLF','FROG','PANDA','CAMEL','MONKEY','COW','SHEEP','CHICKEN','KANGAROO',
      'OWL','SHARK','WHALE','GIRAFFE','FOX','DEER','MOUSE','BAT','CROCODILE','RABBIT',
      'TURTLE','PENGUIN','PARROT','FLAMINGO','ANT','BEE','CRAB','FISH','SPIDER','DUCK',
      'OTTER','RHINO','BUFFALO','GOAT','DONKEY','LEOPARD','SEAL','LIZARD','GORILLA','HIPPO'
    ],
    'Food': [
      'PIZZA','BURGER','PASTA','SALAD','BREAD','CAKE','COOKIE','SUSHI','STEAK','SANDWICH',
      'RICE','SOUP','NOODLE','CHOCOLATE','APPLE','BANANA','ORANGE','GRAPE','MANGO','BERRY',
      'COFFEE','TEA','JUICE','PANCAKE','WAFFLE','ICECREAM','OMELET','CHEESE','BUTTER','YOGURT',
      'CARROT','POTATO','TOMATO','CORN','BEANS','GARLIC','ONION','CHILI','BROCCOLI','SPINACH',
      'TURKEY','BACON','SALMON','TACO','HOTDOG','CURRY','MEATBALL','CUPCAKE','DONUT','MUFFIN'
    ],
    'Sports': [
      'SOCCER','BASKETBALL','BASEBALL','TENNIS','FOOTBALL','HOCKEY','GOLF','SWIMMING','BOXING','CRICKET',
      'VOLLEYBALL','RUNNING','CYCLING','SKIING','SURFING','SKATING','ROWING','ARCHERY','FENCING','BADMINTON',
      'CLIMBING','DIVING','RUGBY','GYMNASTICS','SKATEBOARD','WEIGHTLIFT','TRACK','FIELD','JUDO','KARATE',
      'TAEKWONDO','TABLETENNIS','BOWLING','HANDBALL','CURLING','POLO','SQUASH','SNOWBOARD','RACING','MARATHON',
      'WRESTLING','YOGA','ZUMBA','CROSSFIT','DARTS','EQUESTRIAN','KAYAK','SAILING','LACROSSE','BILLIARDS'
    ],
    'Travel': [
      'AIRPLANE','TRAIN','CAR','SHIP','BUS','SUBWAY','CITY','BEACH','MOUNTAIN','ISLAND',
      'CAMPING','HOTEL','MAP','JOURNEY','ADVENTURE','PASSPORT','LUGGAGE','CRUISE','FLIGHT','TICKET',
      'TOUR','GUIDE','RESORT','EXPLORE','NATURE','ROAD','BRIDGE','TEMPLE','CASTLE','DESERT',
      'OCEAN','RIVER','FOREST','WILDLIFE','TRIP','VACATION','HIKE','TRAVELER','BACKPACK','JUNGLE',
      'MUSEUM','CULTURE','EXPEDITION','LANDMARK','TRAIL','SUNSET','TROPICAL','SNOW','MARKET','SAFARI'
    ],
    'Movies': [
      'ACTOR','DIRECTOR','CAMERA','FILM','SCENE','SCREEN','ACTION','DRAMA','COMEDY','THRILLER',
      'HORROR','ROMANCE','FANTASY','ANIMATION','MUSIC','AWARD','SCRIPT','TRAILER','POP','BLOCKBUSTER',
      'EDIT','STORY','HERO','VILLAIN','MOVIE','CINEMA','STUDIO','POSTER','LIGHTS','SOUND',
      'TICKET','SEQUEL','SERIES','SHOW','BROADCAST','MARVEL','DISNEY','PIXAR','NETFLIX','OSCAR',
      'HBO','STUNT','CLAPPER','DIRECT','WRITE','ACT','CUT','REEL','CREDITS','CAST'
    ],
    'Technology': [
      'COMPUTER','ROBOT','AI','CODE','SOFTWARE','HARDWARE','CHIP','DATA','CLOUD','SERVER',
      'PHONE','TABLET','INTERNET','BROWSER','KEYBOARD','SCREEN','MONITOR','DRONE','CAMERA','VIDEO',
      'EMAIL','MESSAGE','SOCIAL','MEDIA','NETWORK','WIRELESS','GADGET','APP','PROGRAM','WEBSITE',
      'SECURITY','ENCRYPT','PASSWORD','SEARCH','ALGORITHM','DATABASE','ENGINE','TECH','AUTOMATION','ELECTRIC',
      'CHARGER','SATELLITE','SYSTEM','PLATFORM','SMART','DEVICE','CYBER','DIGITAL','INNOVATE','UPLOAD'
    ],
  };

  @override
  void initState() {
    super.initState();
    _newPuzzle();
  }

  // Difficulty → number of words only (board stays the same).
  void _newPuzzle() {
    setState(() => _loading = true);

    final pool = _wordPools[widget.category] ?? _wordPools.values.first;
    final shuffled = List<String>.from(pool)..shuffle(rnd);

    final count = switch (difficulty) {
      _WsDifficulty.easy => 8,
      _WsDifficulty.medium => 12,
      _WsDifficulty.hard => 15,
    };

    words = shuffled.take(count).toList();

    size = 12; // board fixed

    remaining = words.toSet();
    grid = List.generate(size, (_) => List.filled(size, ''));
    _placeWords(words);
    _fillRandom();
    _breakIncidentalWords(pool, words);

    _foundPaths.clear();
    _selCells.clear();
    _startCell = null;
    _lastCell = null;
    _startTime = DateTime.now();

    setState(() => _loading = false);
  }

  void _fillRandom() {
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (grid[y][x].isEmpty) {
          grid[y][x] = String.fromCharCode(65 + rnd.nextInt(26));
        }
      }
    }
  }

  void _placeWords(List<String> ws) {
    final dirs = [
      const Point(1, 0), const Point(0, 1), const Point(1, 1), const Point(-1, 1),
      const Point(-1, 0), const Point(0, -1), const Point(-1, -1), const Point(1, -1),
    ];
    for (final w in ws) {
      bool placed = false;
      for (int tries = 0; tries < 600 && !placed; tries++) {
        final d = dirs[rnd.nextInt(dirs.length)];
        final r0 = rnd.nextInt(size);
        final c0 = rnd.nextInt(size);
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
        for (int i = 0; i < w.length; i++) {
          grid[r][c] = w[i];
          r += d.y; c += d.x;
        }
        placed = true;
      }
    }
  }

  /* ─────────── Prevent unintended extra words ─────────── */

  List<Point<int>>? _findWordPath(String word) {
    final target = word.toUpperCase();
    final n = size;
    final dirs = const [
      Point(1, 0), Point(0, 1), Point(1, 1), Point(-1, 1),
      Point(-1, 0), Point(0, -1), Point(-1, -1), Point(1, -1),
    ];
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        for (final d in dirs) {
          int cx = x, cy = y;
          int i = 0;
          final path = <Point<int>>[];
          while (i < target.length &&
              cx >= 0 && cy >= 0 && cx < n && cy < n &&
              grid[cy][cx] == target[i]) {
            path.add(Point(cx, cy));
            cx += d.x; cy += d.y; i++;
          }
          if (i == target.length) return path;
        }
      }
    }
    return null;
  }

  void _breakIncidentalWords(List<String> pool, List<String> chosen) {
    final placed = chosen.toSet();
    final candidates = pool.where((w) => !placed.contains(w) && w.length >= 4).toList();

    final placedPaths = <String>{};
    for (final w in chosen) {
      final p = _findWordPath(w);
      if (p != null) placedPaths.add(p.toString());
      final pr = _findWordPath(String.fromCharCodes(w.runes.toList().reversed));
      if (pr != null) placedPaths.add(pr.toString());
    }

    int safety = 0;
    while (safety++ < 400) {
      bool changed = false;
      for (final w in candidates) {
        final p = _findWordPath(w) ?? _findWordPath(w.split('').reversed.join());
        if (p != null && !placedPaths.contains(p.toString())) {
          int idx = p.length ~/ 2;
          int attempts = 0;
          while (attempts++ < p.length) {
            final cell = p[idx];
            final isPartOfPlaced = placedPaths.any((s) => s.contains(cell.toString()));
            if (!isPartOfPlaced) {
              final cur = grid[cell.y][cell.x];
              String next;
              do {
                next = String.fromCharCode(65 + rnd.nextInt(26));
              } while (next == cur);
              grid[cell.y][cell.x] = next;
              changed = true;
              break;
            }
            idx = (idx + 1) % p.length;
          }
        }
      }
      if (!changed) break;
    }
  }

  /* ─────────── Interaction – precise snap with projection ─────────── */

  Point<int>? _posToCell(Offset pos, BoxConstraints cons) {
    final cellSize = cons.maxWidth / size;
    final gx = (pos.dx / cellSize).floor();
    final gy = (pos.dy / cellSize).floor();
    if (gx < 0 || gx >= size || gy < 0 || gy >= size) return null;
    return Point(gx, gy);
  }

  // Quantize any angle to one of 8 directions.
  Point<int>? _snapDirectionByAngle(double dxCells, double dyCells) {
    if (dxCells == 0 && dyCells == 0) return null;
    double angle = atan2(dyCells, dxCells);
    const step = pi / 4;
    angle = (angle / step).round() * step;
    final sx = cos(angle).round();
    final sy = sin(angle).round();
    if (sx == 0 && sy == 0) return null;
    return Point(sx, sy);
  }

  void _onPanStart(Offset pos, BoxConstraints cons) {
    final cell = _posToCell(pos, cons);
    if (cell == null) return;
    _dragging = true;
    _selCells
      ..clear()
      ..add(cell);
    _startCell = cell;
    _lastCell = cell;
    setState(() {});
  }

  void _onPanUpdate(Offset pos, BoxConstraints cons) {
    if (!_dragging || _startCell == null) return;

    final cellSize = cons.maxWidth / size;
    final startCenter = Offset((_startCell!.x + 0.5) * cellSize, (_startCell!.y + 0.5) * cellSize);
    final delta = pos - startCenter;

    final dxCells = delta.dx / cellSize;
    final dyCells = delta.dy / cellSize;

    final dir = _snapDirectionByAngle(dxCells, dyCells);
    if (dir == null) {
      _selCells
        ..clear()
        ..add(_startCell!);
      _lastCell = _startCell;
      setState(() {});
      return;
    }

    // Projection of movement onto snapped direction (so diagonals count correctly).
    double L = dxCells * dir.x + dyCells * dir.y; // signed length in cells along dir
    if (L < 0) L = 0;

    // Small jitter guard: keep selection at start until ~0.2 cell.
    if (L < 0.20) {
      _selCells
        ..clear()
        ..add(_startCell!);
      _lastCell = _startCell;
      setState(() {});
      return;
    }

    // Steps: lenient ceil so the last letter is included even if you haven't
    // crossed the exact center of the final cell yet.
    int steps = L.ceil();

    // Clamp to board edge from the start cell.
    int edgeX = dir.x > 0 ? (size - 1 - _startCell!.x) : (dir.x < 0 ? _startCell!.x : 1 << 30);
    int edgeY = dir.y > 0 ? (size - 1 - _startCell!.y) : (dir.y < 0 ? _startCell!.y : 1 << 30);
    int edge = min(edgeX, edgeY);
    if (steps > edge) steps = edge;
    if (steps < 1) steps = 1;

    _selCells.clear();
    for (int k = 0; k <= steps; k++) {
      final x = _startCell!.x + dir.x * k;
      final y = _startCell!.y + dir.y * k;
      if (x < 0 || x >= size || y < 0 || y >= size) break;
      _selCells.add(Point(x, y));
    }
    _lastCell = Point(_startCell!.x + dir.x * steps, _startCell!.y + dir.y * steps);
    setState(() {});
  }

  void _onPanEnd() {
    if (_dragging) _checkSelection();
    _dragging = false;
    _selCells.clear();
    _startCell = null;
    _lastCell = null;
    setState(() {});
  }

  void _checkSelection() {
    if (_selCells.length < 2) return;

    final a = _selCells.first;
    final b = _selCells.last;
    final dx = (b.x - a.x).sign;
    final dy = (b.y - a.y).sign;
    final steps = max((b.x - a.x).abs(), (b.y - a.y).abs());

    final sb = StringBuffer();
    final path = <Point<int>>[];
    int r = a.y, c = a.x;
    for (int i = 0; i <= steps; i++) {
      sb.write(grid[r][c]);
      path.add(Point(c, r));
      r += dy;
      c += dx;
    }

    final s = sb.toString();
    final rs = s.split('').reversed.join();

    String? found;
    if (remaining.contains(s)) {
      found = s;
    } else if (remaining.contains(rs)) {
      found = rs;
    }

    if (found != null) {
      remaining.remove(found);
      _foundPaths.add(path);
      setState(() {});
      if (remaining.isEmpty) _onWin();
    }
  }

  Future<void> _onWin() async {
    final secs = DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
    final intScore = (1000 * words.length / secs).round();

    final isHigh = await ScoreStore.instance.updateWordSearchBest(intScore);
    await ScoreStore.instance.addWordSearchHistory(
      score: intScore,
      difficulty: difficulty.name,
      category: widget.category,
      seconds: secs,
      words: words.length,
    );

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isHigh ? 'New High Score!' : 'Puzzle Complete'),
        content: Text('Score: $intScore\nTime: ${secs}s • Words: ${words.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(
            onPressed: () { Navigator.pop(context); _newPuzzle(); },
            child: const Text('New'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: _bg(context, widget.category),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // WORD CHIPS — reserved height keeps the board in the same place always.
    final chipFontSize = switch (difficulty) {
      _WsDifficulty.easy => 13.0,
      _WsDifficulty.medium => 12.0,
      _WsDifficulty.hard => 11.0,
    };
    final chipHPad = switch (difficulty) {
      _WsDifficulty.easy => 8.0,
      _WsDifficulty.medium => 7.0,
      _WsDifficulty.hard => 6.0,
    };
    final chipSpacing = switch (difficulty) {
      _WsDifficulty.easy => 8.0,
      _WsDifficulty.medium => 7.0,
      _WsDifficulty.hard => 6.0,
    };

    final chipLabelStyle = TextStyle(
      fontSize: chipFontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: .2,
      color: _ink,
    );

    final chipsWidget = Wrap(
      spacing: chipSpacing,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: words.map((w) {
        final found = !remaining.contains(w);
        return Chip(
          label: Text(
            w,
            style: chipLabelStyle.copyWith(
              decoration: found ? TextDecoration.lineThrough : null,
            ),
          ),
          backgroundColor:
              found ? const Color(0xFFA7E0C9) : Colors.white.withOpacity(.95),
          side: const BorderSide(color: _ink),
          labelPadding: EdgeInsets.symmetric(horizontal: chipHPad, vertical: 0),
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );

    final topBar = Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _themeGreen.withOpacity(.6), width: 1.5),
          ),
          child: DropdownButton<_WsDifficulty>(
            value: difficulty,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(10),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _ink),
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 15),
            onChanged: (v) { if (v == null) return; setState(() => difficulty = v); _newPuzzle(); },
            items: const [
              DropdownMenuItem(value: _WsDifficulty.easy, child: Text('Easy')),
              DropdownMenuItem(value: _WsDifficulty.medium, child: Text('Medium')),
              DropdownMenuItem(value: _WsDifficulty.hard, child: Text('Hard')),
            ],
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _newPuzzle,
          style: FilledButton.styleFrom(
            backgroundColor: _themeGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('New'),
        ),
      ],
    );

    // Keep the board fixed; only chip area scroll/pad changes.
    const double reservedChipsHeight = 116;
    final double extraTop = switch (difficulty) {
      _WsDifficulty.easy => 24.0,
      _WsDifficulty.medium => 12.0, // medium clipping fix retained
      _WsDifficulty.hard => 14.0,
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 56,
        leadingWidth: 52,
        title: Text(widget.category, style: _headerTextStyle),
        leading: _BackButtonIOS(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WordSearchCategoryPage()),
            );
          },
          iconSize: 22,
        ),
        actions: [
          IconButton(
            tooltip: 'Score history',
            icon: const Icon(Icons.bar_chart_rounded, color: _ink),
            onPressed: () async {
              final hist = await ScoreStore.instance.loadWordSearchHistory();
              if (!mounted) return;
              await showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _ink),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(height: 4, width: 44, margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(20))),
                        const Text('Word Search – Score History',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (hist.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('No scores yet. Finish a puzzle to record one!'),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: hist.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final e = hist[i];
                                final when = DateTime.tryParse(e['ts'] ?? '') ?? DateTime.now();
                                final stamp =
                                    '${when.month}/${when.day}/${when.year} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.emoji_events_rounded, color: _themeGreen),
                                  title: Text('Score ${e['score']}  •  ${e['difficulty']}'),
                                  subtitle: Text('${e['category']} • ${e['seconds']}s • ${e['words']} words\n$stamp'),
                                  isThreeLine: true,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: _bg(context, widget.category),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                topBar,
                const SizedBox(height: 8),
                SizedBox(
                  height: reservedChipsHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.only(top: extraTop, bottom: 8),
                        child: chipsWidget,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, cons) {
                      final side = min(cons.maxWidth, cons.maxHeight) * 0.90;
                      final tight = BoxConstraints.tight(Size(side, side));
                      return Center(
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: Listener(
                            onPointerDown: (e) => _onPanStart(e.localPosition, tight),
                            onPointerMove: (e) => _onPanUpdate(e.localPosition, tight),
                            onPointerUp: (_) => _onPanEnd(),
                            child: CustomPaint(
                              painter: _WsPainterCapsules(
                                grid,
                                _selCells,
                                _foundPaths,
                                _startCell,
                                _lastCell,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      );
                    },
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

/* ─────────── Capsule Painter ─────────── */

class _WsPainterCapsules extends CustomPainter {
  final List<List<String>> g;
  final Set<Point<int>> sel;
  final List<List<Point<int>>> foundPaths;
  final Point<int>? dragStart;
  final Point<int>? dragEnd;

  _WsPainterCapsules(this.g, this.sel, this.foundPaths, this.dragStart, this.dragEnd);

  static const List<Color> _bandPalette = [
    Color(0xFF76E4C3),
    Color(0xFFB7A8FF),
    Color(0xFFFFA8B4),
    Color(0xFF7FD3FF),
    Color(0xFFFFD38E),
  ];

  void _drawCapsule(Canvas c, Offset p1, Offset p2, double thickness, Color color,
      {double strokeAlpha = 0.16, double extend = 0.0}) {
    final dir = p2 - p1;
    final len = dir.distance;
    if (len <= 0.0001) return;

    final ux = dir.dx / len, uy = dir.dy / len;
    final e1 = Offset(p1.dx - ux * extend, p1.dy - uy * extend);
    final e2 = Offset(p2.dx + ux * extend, p2.dy + uy * extend); // extend forward correctly

    final angle = atan2(e2.dy - e1.dy, e2.dx - e1.dx);
    final drawLen = (e2 - e1).distance;

    c.save();
    c.translate(e1.dx, e1.dy);
    c.rotate(angle);

    final rect = Rect.fromLTWH(0, -thickness / 2, drawLen, thickness);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(thickness / 2));

    final shadow = Paint()
      ..color = Colors.black12
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    c.drawRRect(rrect.shift(const Offset(0, 1.2)), shadow);

    c.drawRRect(rrect, Paint()..color = color);

    c.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withOpacity(strokeAlpha),
    );

    c.restore();
  }

  @override
  void paint(Canvas c, Size s) {
    final n = g.length;
    if (n == 0) return;
    final cell = s.width / n;
    final center = cell / 2;

    for (int i = 0; i < foundPaths.length; i++) {
      final path = foundPaths[i];
      if (path.isEmpty) continue;
      final p1 = Offset(path.first.x * cell + center, path.first.y * cell + center);
      final p2 = Offset(path.last.x * cell + center, path.last.y * cell + center);
      final color = _bandPalette[i % _bandPalette.length];
      _drawCapsule(c, p1, p2, cell * 0.82, color, extend: cell * 0.46);
    }

    if (dragStart != null && dragEnd != null && sel.length >= 2) {
      final p1 = Offset(dragStart!.x * cell + center, dragStart!.y * cell + center);
      final p2 = Offset(dragEnd!.x * cell + center, dragEnd!.y * cell + center);
      _drawCapsule(c, p1, p2, cell * 0.78, const Color(0xFFB7E0FF), extend: cell * 0.44);
    }

    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    final fontSize = cell * 0.56;
    final letterStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
      shadows: const [
        Shadow(color: Colors.white70, blurRadius: 2.5),
        Shadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 1.2),
      ],
    );

    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        tp.text = TextSpan(text: g[y][x], style: letterStyle);
        tp.layout(minWidth: cell, maxWidth: cell);
        tp.paint(c, Offset(x * cell, y * cell + (cell - tp.height) / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WsPainterCapsules old) =>
      old.g != g ||
      old.sel != sel ||
      old.foundPaths != foundPaths ||
      old.dragStart != dragStart ||
      old.dragEnd != dragEnd;
}

/* ─────────── Background Painters ─────────── */

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.dark);
  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx1 = size.width * (0.25 + 0.15 * sin(2 * pi * (t + 0.10)));
    final cy1 = size.height * (0.28 + 0.10 * cos(2 * pi * (t + 0.20)));
    final cx2 = size.width * (0.72 + 0.12 * cos(2 * pi * (t + 0.45)));
    final cy2 = size.height * (0.62 + 0.12 * sin(2 * pi * (t + 0.05)));

    final r1 = size.shortestSide * 0.55;
    final r2 = size.shortestSide * 0.60;

    final c1a = const Color(0xFF18C8A0).withOpacity(dark ? 0.16 : 0.18);
    final c1b = const Color(0xFF18C8A0).withOpacity(0.0);
    final c2a = const Color(0xFFA48DFF).withOpacity(dark ? 0.16 : 0.18);
    final c2b = const Color(0xFFA48DFF).withOpacity(0.0);

    final p1 = Paint()..shader = ui.Gradient.radial(Offset(cx1, cy1), r1, [c1a, c1b], [0.0, 1.0]);
    final p2 = Paint()..shader = ui.Gradient.radial(Offset(cx2, cy2), r2, [c2a, c2b], [0.0, 1.0]);

    canvas.drawCircle(Offset(cx1, cy1), r1, p1);
    canvas.drawCircle(Offset(cx2, cy2), r2, p2);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.dark != dark;
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.t, this.dark);
  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final baseAlpha = dark ? 0.10 : 0.12;
    final palette = [
      const Color(0xFF0D7C66).withOpacity(baseAlpha),
      const Color(0xFF7A5AF8).withOpacity(baseAlpha),
      const Color(0xFF00BFA6).withOpacity(baseAlpha),
    ];

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withOpacity(0.32);

    final innerShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black.withOpacity(0.08);

    for (int i = 0; i < 12; i++) {
      final phase = i * 0.12;
      final w = size.width, h = size.height;
      final x = w * (0.10 + (i % 5) * 0.18) + 12 * sin(2 * pi * (t + phase * 0.8));
      final y = h * (0.18 + 0.64 * (0.5 + 0.5 * sin(2 * pi * (t * 0.75 + phase))));
      final r = 8.0 + (i % 4) * 5.0;

      final glow = Paint()
        ..style = PaintingStyle.fill
        ..color = palette[i % palette.length]
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
      canvas.drawCircle(Offset(x, y), r * 1.35, glow);

      final highlightCenter = Offset(x - r * 0.38, y - r * 0.38);
      final fill = Paint()
        ..shader = ui.Gradient.radial(
          highlightCenter,
          r,
          [Colors.white.withOpacity(0.40), Colors.white.withOpacity(0.18),
           palette[i % palette.length].withOpacity(0.12), Colors.transparent],
          const [0.0, 0.35, 0.75, 1.0],
        );
      canvas.drawCircle(Offset(x, y), r, fill);

      canvas.drawCircle(Offset(x, y), r, rim);
      canvas.drawCircle(Offset(x, y), r - 0.9, innerShadow);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.22);
      final arcRect = Rect.fromCircle(center: Offset(x, y), radius: r * 0.86);
      canvas.drawArc(arcRect, -2.6, 1.1, false, arcPaint);

      final sparkle = Paint()..color = Colors.white.withOpacity(0.70);
      canvas.drawCircle(Offset(x - r * 0.45, y - r * 0.50), r * 0.16, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter old) =>
      old.t != t || old.dark != dark;
}
