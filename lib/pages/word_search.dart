// lib/pages/word_search.dart
//
// Category chooser + themed Word Search.
// - 6 broad categories (50+ words each).
// - Original game behavior preserved: difficulty selector, randomized words,
//   drag with 8-direction snap, strike-through lines, "New" button.
// - Animated, playful category menu.
// - Visual polish update: balanced spacing, translucent cards, modern layout.
// - Header shows only category; smaller back button; subtle category patterns.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────── Theme ─────────── */

const _ink = Colors.black;
const _themeGreen = Color(0xFF0D7C66);

BoxDecoration _bg(BuildContext context, [String? category]) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  final colors = dark
      ? const [Color(0xFF2A2336), Color(0xFF1B4F4A)]
      : const [Color(0xFFE9D9FF), Color(0xFFBEE8E0)];

  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ),
    image: DecorationImage(
      image: _patternForCategory(category),
      repeat: ImageRepeat.repeat,
      // faint white overlay; a touch stronger on light theme
      colorFilter: ColorFilter.mode(
        Colors.white.withOpacity(dark ? 0.05 : 0.08),
        BlendMode.srcATop,
      ),
    ),
  );
}

AssetImage _patternForCategory(String? category) {
  switch (category) {
    case 'Animals':
      return const AssetImage('assets/patterns/paws.png');
    case 'Food':
      return const AssetImage('assets/patterns/utensils.png');
    case 'Sports':
      return const AssetImage('assets/patterns/balls.png');
    case 'Travel':
      return const AssetImage('assets/patterns/planes.png');
    case 'Movies':
      return const AssetImage('assets/patterns/film.png');
    case 'Technology':
      return const AssetImage('assets/patterns/circuits.png');
    default:
      return const AssetImage('assets/patterns/dots.png');
  }
}

/* ─────────── iOS-style Chevron Back Button (smaller) ─────────── */

class _BackChevron extends StatelessWidget {
  const _BackChevron({
    this.onTap,
    this.color = const Color(0xFF2B2B2B),
    this.size = 16, // smaller than before (was 22)
    super.key,
  });
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: CustomPaint(size: Size(size, size), painter: _ChevronPainter(color)),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.12
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final p1 = Offset(size.width * 0.75, size.height * 0.15);
    final p2 = Offset(size.width * 0.25, size.height * 0.50);
    final p3 = Offset(size.width * 0.75, size.height * 0.85);

    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p2, p3, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.color != color;
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

  late final AnimationController _fadeController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
          ..forward();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
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

  void _onTapDown() => _bounceController.forward();
  void _onTapUp() => _bounceController.reverse();

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
    return Scaffold(
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    _BackChevron(
                      onTap: () => Navigator.pop(context),
                      color: const Color(0xFF2B2B2B),
                      size: 18,
                    ),
                    const Expanded(
                      child: Text(
                        'Choose a Category',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 30),
                  ],
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity:
                      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
                  child: Column(
                    children: const [
                      Icon(Icons.grid_view_rounded, size: 64, color: _themeGreen),
                      SizedBox(height: 14),
                      Text(
                        'Tap a theme to begin your Word Search!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 22,
                      runSpacing: 22,
                      alignment: WrapAlignment.center,
                      children: _categories.map((cat) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                            CurvedAnimation(
                              parent: _bounceController,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: GestureDetector(
                            onTapDown: (_) => _onTapDown(),
                            onTapUp: (_) => _onTapUp(),
                            onTapCancel: () => _onTapUp(),
                            onTap: () => _navigateToCategory(cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 140,
                              height: 130,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: _themeGreen.withOpacity(0.9), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: _themeGreen.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_iconForCategory(cat),
                                      color: _themeGreen, size: 36),
                                  const SizedBox(height: 10),
                                  Text(
                                    cat,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _ink,
                                    ),
                                  ),
                                ],
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.category, // 🔹 only category shown
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _BackChevron(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WordSearchCategoryPage()),
            );
          },
          color: const Color(0xFF2B2B2B),
          size: 18, // 🔹 smaller back button
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

/* ─────────── Painter ─────────── */

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
