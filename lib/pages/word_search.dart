// lib/pages/word_search.dart
//
// Category chooser + themed Word Search.
// - 6 broad categories (50+ words each).
// - Original game behavior preserved: difficulty selector, randomized words,
//   drag with 8-direction snap, strike-through lines, "New" button.
// - Headers match Stress Busters vibe; compact title text and iOS-style back.
// - Categories page: animated aurora + floating **transparent bubbles**.
// - **No asset images used anywhere** (prevents "Unable to load asset" errors).

import 'dart:math';
import 'dart:ui' as ui; // for gradient shaders
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────── Theme ─────────── */

const _ink = Colors.black;
const _themeGreen = Color(0xFF0D7C66);

// Compact header text (same scale as Stress Busters)
const _headerTextStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w900,
);

BoxDecoration _bg(BuildContext context, [String? _unusedCategory]) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  // Soft vertical gradient only (no assets)
  final colors = dark
      ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
      : const [Color(0xFFE9D9FF), Color(0xFFBEE8E0)];
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ),
  );
}

/* ─────────── iOS-style back button (compact) ─────────── */

class _BackButtonIOS extends StatelessWidget {
  const _BackButtonIOS({
    this.onPressed,
    this.iconSize = 22,
    super.key,
  });

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

/* ─────────── Score Tracker ─────────── */

class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();
  Future<bool> reportBest(String key, double score) async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getDouble('best_$key') ?? double.negativeInfinity;
    final isHigh = score > prev;
    if (isHigh) await prefs.setDouble('best_$key', score);
    return isHigh;
  }
}

/* ─────────── Animated Category Chooser ─────────── */

class WordSearchCategoryPage extends StatefulWidget {
  final void Function(String category)? onPick;
  const WordSearchCategoryPage({super.key, this.onPick});

  @override
  State<WordSearchCategoryPage> createState() => _WordSearchCategoryPageState();
}

class _WordSearchCategoryPageState extends State<WordSearchCategoryPage>
    with TickerProviderStateMixin {
  static const _categories = [
    'Animals',
    'Food',
    'Sports',
    'Travel',
    'Movies',
    'Technology'
  ];

  // Nullable to avoid late-init crash on hot reloads.
  AnimationController? _aurora; // background motion

  // per-card interactive state
  final Map<String, double> _scale = {for (final c in _categories) c: 1.0};
  final Map<String, double> _tiltTurns = {for (final c in _categories) c: 0.0};

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
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

  void _pressDown(String cat) {
    setState(() {
      _scale[cat] = 0.94;
      // playful 2–3.5° tilt
      final sign = Random().nextBool() ? 1 : -1;
      _tiltTurns[cat] = sign * (Random().nextDouble() * 0.006 + 0.003); // turns
    });
  }

  void _pressUp(String cat) {
    setState(() {
      _scale[cat] = 1.0;
      _tiltTurns[cat] = 0.0;
    });
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Animals':
        return Icons.pets_rounded;
      case 'Food':
        return Icons.restaurant_menu_rounded;
      case 'Sports':
        return Icons.sports_soccer_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Movies':
        return Icons.movie_creation_rounded;
      case 'Technology':
        return Icons.memory_rounded;
      default:
        return Icons.category_rounded;
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
      ),
      body: Container(
        decoration: _bg(context),
        child: Stack(
          children: [
            // Animated aurora / blob painter behind content
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
            // Floating **transparent bubbles** layer
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
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Wrap(
                          spacing: 22,
                          runSpacing: 22,
                          alignment: WrapAlignment.center,
                          children: _categories.map((cat) {
                            final glowStrength =
                                0.14 + 0.08 * sin(((_aurora?.value ?? 0.0) * 2 * pi) + cat.hashCode);
                            return GestureDetector(
                              onTapDown: (_) => _pressDown(cat),
                              onTapUp: (_) => _pressUp(cat),
                              onTapCancel: () => _pressUp(cat),
                              onTap: () => _navigateToCategory(cat),
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 120),
                                scale: _scale[cat]!,
                                child: AnimatedRotation(
                                  duration: const Duration(milliseconds: 160),
                                  turns: _tiltTurns[cat]!,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 280),
                                    width: 148,
                                    height: 136,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.90),
                                          Colors.white.withOpacity(0.84),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: _themeGreen.withOpacity(0.85),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _themeGreen.withOpacity(glowStrength),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF0D7C66).withOpacity(0.10),
                                          ),
                                          child: Icon(
                                            _iconForCategory(cat),
                                            color: _themeGreen,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          cat,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: _ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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

/* ─────────── Game Core ─────────── */

enum _WsDifficulty { easy, medium, hard }

class WordSearchPage extends StatefulWidget {
  final String category; // required: open a specific themed game
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

  int size = 0;
  _WsDifficulty difficulty = _WsDifficulty.easy;
  late DateTime _startTime;

  /* ─────────── 6 word pools (50+) ─────────── */
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

  /* ─────────── Puzzle Generator ─────────── */

  void _newPuzzle() {
    setState(() => _loading = true);

    final pool = _wordPools[widget.category] ?? _wordPools.values.first;
    final shuffled = List<String>.from(pool)..shuffle(rnd);

    if (difficulty == _WsDifficulty.easy) {
      size = 12;
      words = shuffled.take(8).toList();
    } else if (difficulty == _WsDifficulty.medium) {
      size = 13;
      words = shuffled.take(12).toList();
    } else {
      size = 14;
      words = shuffled.take(16).toList();
    }

    remaining = words.toSet();
    grid = List.generate(size, (_) => List.filled(size, ''));
    _placeWords(words);
    _fillRandom();

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
      for (int tries = 0; tries < 400 && !placed; tries++) {
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

  /* ─────────── Interaction ─────────── */

  Point<int>? _posToCell(Offset pos, BoxConstraints cons) {
    final cellSize = cons.maxWidth / size;
    final gx = (pos.dx / cellSize).floor();
    final gy = (pos.dy / cellSize).floor();
    if (gx < 0 || gx >= size || gy < 0 || gy >= size) return null;
    return Point(gx, gy);
  }

  Point<int>? _snapDirection(int dx, int dy) {
    if (dx == 0 && dy == 0) return null;
    double angle = atan2(dy.toDouble(), dx.toDouble());
    const step = pi / 4; // snap to 8 directions
    angle = (angle / step).round() * step;
    final snappedDx = cos(angle).round();
    final snappedDy = sin(angle).round();
    if (snappedDx == 0 && snappedDy == 0) return null;
    return Point(snappedDx, snappedDy);
  }

  void _onPanStart(Offset pos, BoxConstraints cons) {
    final cell = _posToCell(pos, cons);
    if (cell == null) return;
    _dragging = true;
    _selCells.clear();
    _startCell = cell;
    _lastCell = cell;
    _selCells.add(cell);
    setState(() {});
  }

  void _onPanUpdate(Offset pos, BoxConstraints cons) {
    if (!_dragging || _startCell == null) return;
    final current = _posToCell(pos, cons);
    if (current == null) return;
    final dx = current.x - _startCell!.x;
    final dy = current.y - _startCell!.y;
    final dir = _snapDirection(dx, dy);
    if (dir == null) return;

    _selCells.clear();
    int x = _startCell!.x, y = _startCell!.y;
    while (x >= 0 && x < size && y >= 0 && y < size &&
        (dir.x == 0 || (dir.x > 0 ? x <= current.x : x >= current.x)) &&
        (dir.y == 0 || (dir.y > 0 ? y <= current.y : y >= current.y))) {
      _selCells.add(Point(x, y));
      x += dir.x; y += dir.y;
    }
    _lastCell = current;
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
    final score = words.length / secs;
    final isHigh = await ScoreStore.instance.reportBest('wordsearch', score);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isHigh ? 'New High Score!' : 'Puzzle Complete'),
        content: Text('Speed: ${score.toStringAsFixed(3)} words/sec'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _newPuzzle();
            },
            child: const Text('New'),
          ),
        ],
      ),
    );
  }

  /* ─────────── UI ─────────── */

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

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: words.map((w) {
        final found = !remaining.contains(w);
        return Chip(
          label: Text(
            w,
            style: TextStyle(
              decoration: found ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor:
              found ? const Color(0xFFA7E0C9) : Colors.white.withOpacity(.95),
          side: const BorderSide(color: _ink),
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
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() => difficulty = v);
              _newPuzzle();
            },
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
                chips,
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, cons) => AspectRatio(
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
                    ),
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

/* ─────────── Painter for the board ─────────── */

class _WsPainter extends CustomPainter {
  final List<List<String>> g;
  final Set<Point<int>> sel;
  final List<List<Point<int>>> foundPaths;
  _WsPainter(this.g, this.sel, this.foundPaths);

  @override
  void paint(Canvas c, Size s) {
    final n = g.length;
    if (n == 0) return;
    final cell = s.width / n;

    final border = Paint()
      ..color = _ink.withOpacity(.25)
      ..style = PaintingStyle.stroke;
    final selBg = Paint()..color = const Color(0xFFFFF1A6);

    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final r = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)),
          border,
        );
        if (sel.contains(Point(x, y))) {
          c.drawRRect(
            RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)),
            selBg,
          );
        }
        tp.text = TextSpan(
          text: g[y][x],
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        );
        tp.layout(minWidth: cell, maxWidth: cell);
        tp.paint(c, Offset(x * cell, y * cell + (cell - tp.height) / 2));
      }
    }

    // draw strike lines for found words
    final linePaint = Paint()
      ..color = _themeGreen.withOpacity(.85)
      ..strokeWidth = cell * 0.20
      ..strokeCap = StrokeCap.round;

    for (final path in foundPaths) {
      if (path.isEmpty) continue;
      final p1 = Offset(path.first.x * cell + cell / 2,
          path.first.y * cell + cell / 2);
      final p2 = Offset(path.last.x * cell + cell / 2,
          path.last.y * cell + cell / 2);
      c.drawLine(p1, p2, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WsPainter old) =>
      old.g != g || old.sel != sel || old.foundPaths != foundPaths;
}

/* ─────────── Aurora Background Painter (categories page) ─────────── */

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.dark);
  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Two drifting radial gradients ("blobs")
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

    final p1 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx1, cy1),
        r1,
        [c1a, c1b],
        [0.0, 1.0],
      );
    final p2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx2, cy2),
        r2,
        [c2a, c2b],
        [0.0, 1.0],
      );

    canvas.drawCircle(Offset(cx1, cy1), r1, p1);
    canvas.drawCircle(Offset(cx2, cy2), r2, p2);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.dark != dark;
}

/* ─────────── Bubbles Painter (more transparent / bubble-like) ─────────── */

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.t, this.dark);
  final double t;   // 0..1 from controller
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final baseAlpha = dark ? 0.10 : 0.12; // more transparent overall
    final palette = [
      const Color(0xFF0D7C66).withOpacity(baseAlpha),
      const Color(0xFF7A5AF8).withOpacity(baseAlpha),
      const Color(0xFF00BFA6).withOpacity(baseAlpha),
    ];

    // very thin rim for glassy look
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withOpacity(0.32);

    final innerShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black.withOpacity(0.08);

    // 12 floating bubbles with gentle wobble and shine
    for (int i = 0; i < 12; i++) {
      final phase = i * 0.12;
      final w = size.width;
      final h = size.height;

      final x = w * (0.10 + (i % 5) * 0.18) + 12 * sin(2 * pi * (t + phase * 0.8));
      final y = h * (0.18 + 0.64 * (0.5 + 0.5 * sin(2 * pi * (t * 0.75 + phase))));

      final r = 8.0 + (i % 4) * 5.0;

      // soft outer glow (very transparent)
      final glow = Paint()
        ..style = PaintingStyle.fill
        ..color = palette[i % palette.length]
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(x, y), r * 1.35, glow);

      // bubble fill with airy transparency: bright highlight to fully transparent edge
      final highlightCenter = Offset(x - r * 0.38, y - r * 0.38);
      final fill = Paint()
        ..shader = ui.Gradient.radial(
          highlightCenter,
          r,
          [
            Colors.white.withOpacity(0.40),   // specular center
            Colors.white.withOpacity(0.18),   // soft core
            palette[i % palette.length].withOpacity(0.12), // faint tint
            Colors.transparent,               // clear edge
          ],
          const [0.0, 0.35, 0.75, 1.0],
        );
      canvas.drawCircle(Offset(x, y), r, fill);

      // crisp rim + subtle inner shadow for refraction
      canvas.drawCircle(Offset(x, y), r, rim);
      canvas.drawCircle(Offset(x, y), r - 0.9, innerShadow);

      // small crescent highlight along the upper-left (thin arc)
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.22);
      final arcRect = Rect.fromCircle(center: Offset(x, y), radius: r * 0.86);
      canvas.drawArc(arcRect, -2.6, 1.1, false, arcPaint);

      // tiny sparkle dot
      final sparkle = Paint()..color = Colors.white.withOpacity(0.70);
      canvas.drawCircle(Offset(x - r * 0.45, y - r * 0.50), r * 0.16, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.dark != dark;
}

