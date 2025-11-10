// lib/pages/crossword.dart
//
// Crossword with balloon-style category chooser, pop-to-start animation,
// difficulty controls, classic evenly spaced crossword grid, bigger clue
// panel, on-screen keyboard, Auto-Check, Reveal Tile, +10 Letters, clue
// navigation banner, animated highlights, and a Mixed category.
// No external assets.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────────────── Theme helpers ─────────────────── */

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
const _good = Color(0xFFA7E0C9);
const _warn = Color(0xFFFFE9A8);
const _bad = Color(0xFFFFC5C5);

/* ─────────────────── Game scaffold ─────────────────── */

class _GameScaffold extends StatelessWidget {
  final String? title; // null => no title text
  final Widget child;
  const _GameScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title:
            title == null ? null : Text(title!, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(decoration: _bg(context), child: SafeArea(child: child)),
    );
  }
}

/* ─────────────────── Score store ─────────────────── */

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

/* ─────────────────── Data: difficulty, categories ─────────────────── */

enum _Difficulty { easy, medium, hard }
enum _Direction { across, down }

enum _Category {
  mixed,
  animals,
  history,
  literature,
  popculture,
  science,
  geography,
  movies,
  music,
  sports,
  food,
}

String _categoryLabel(_Category c) => switch (c) {
      _Category.mixed => 'Mixed',
      _Category.animals => 'Animals',
      _Category.history => 'History',
      _Category.literature => 'Literature',
      _Category.popculture => 'Pop Culture',
      _Category.science => 'Science',
      _Category.geography => 'Geography',
      _Category.movies => 'Movies',
      _Category.music => 'Music',
      _Category.sports => 'Sports',
      _Category.food => 'Food',
    };

IconData _categoryIcon(_Category c) => switch (c) {
      _Category.mixed => Icons.all_inclusive_rounded,
      _Category.animals => Icons.pets_rounded,
      _Category.history => Icons.castle_rounded,
      _Category.literature => Icons.menu_book_rounded,
      _Category.popculture => Icons.emoji_events_rounded,
      _Category.science => Icons.science_rounded,
      _Category.geography => Icons.public_rounded,
      _Category.movies => Icons.movie_rounded,
      _Category.music => Icons.music_note_rounded,
      _Category.sports => Icons.sports_soccer_rounded,
      _Category.food => Icons.restaurant_rounded,
    };

/* ------------- Word banks + clues (keys match word lists) ------------- */

final Map<_Category, Map<String, String>> _clueBank = {
  _Category.animals: {
    'LION': '“King of the jungle”; maned big cat (4)',
    'TIGER': 'Striped big cat of Asia (5)',
    'EAGLE': 'National bird of the U.S. (5)',
    'DOLPHIN': 'Clever marine mammal (7)',
    'PANDA': 'Bamboo-munching bear (5)',
    'KANGAROO': 'Hopping marsupial (8)',
    'KOALA': 'Eucalyptus snacker (5)',
    'PENGUIN': 'Tuxedoed bird that can’t fly (7)',
    'GIRAFFE': 'Tallest land animal (7)',
    'ZEBRA': 'Striped grazer (5)',
    'OTTER': 'River raft-loving mammal (5)',
    'RHINO': 'Horned heavyweight (5)',
    'CHEETAH': 'Fastest sprinter (7)',
    'JAGUAR': 'Spotted American big cat (6)',
    'WALRUS': 'Arctic tusker (6)',
    'MEERKAT': 'Sentry mongoose relative (7)',
    'RACCOON': 'Masked scavenger (7)',
    'PLATYPUS': 'Bill-bearing egg-layer (8)',
    'HEDGEHOG': 'Spiny insect eater (8)',
    'ORANGUTAN': 'Red ape; “man of the forest” (9)',
    'SEAHORSE': 'Curly-tailed fish (8)',
    'BISON': 'Massive grazer (5)',
    'COYOTE': 'Wily canid (6)',
  },
  _Category.history: {
    'CAESAR': 'Julius ___, Roman statesman (6)',
    'PYRAMID': 'Ancient tomb (7)',
    'EMPIRE': 'Realm of an emperor (6)',
    'RENAISSANCE': 'European “rebirth” (11)',
    'PHARAOH': 'Egyptian ruler title (7)',
    'SPARTA': 'Warrior city-state (6)',
    'VIKING': 'Norse seafarer (6)',
    'COLONY': 'Overseas possession (6)',
    'MONARCH': 'King or queen (7)',
    'CONSTITUTION': 'Foundational law (12)',
    'CRUSADE': 'Medieval holy war (7)',
    'REPUBLIC': 'State without a monarch (8)',
    'ARMADA': 'Spanish fleet 1588 (6)',
    'TREATY': 'Formal pact (6)',
    'REVOLT': 'Uprising (6)',
    'BYZANTINE': 'Eastern Roman culture (9)',
    'AZTEC': 'Empire of Tenochtitlán (5)',
    'MAYA': 'Yucatán civilization (4)',
    'PILGRIM': 'Mayflower settler (7)',
    'COLOSSEUM': 'Roman amphitheater (9)',
  },
  _Category.literature: {
    'ODYSSEY': 'Homer’s voyage home (7)',
    'HAMLET': 'Prince of Denmark (6)',
    'GATSBY': 'Jazz-Age dreamer (6)',
    'QUIXOTE': 'Windmill-tilting knight (6)',
    'INFERNO': 'Dante’s first cantica (7)',
    'ILIAD': 'Wrath of Achilles (5)',
    'DUNE': 'Arrakis saga (4)',
    'NARNIA': 'Wardrobe world (6)',
    'SHERLOCK': 'Baker Street sleuth (8)',
    'ORWELL': '“1984” author (6)',
    'POE': 'Master of the macabre (3)',
    'AUSTEN': '“Pride and Prejudice” author (6)',
    'BRONTE': 'Sisters of the moors (6)',
    'HOBBIT': 'Bilbo’s tale (6)',
    'POTTER': 'Boy wizard (6)',
    'ATTICUS': 'Finch of Maycomb (7)',
    'TWAIN': 'Humorist of Huck Finn (5)',
    'AENEID': 'Virgil’s epic (6)',
    'FAULKNER': 'Southern Nobel writer (8)',
    'WONDERLAND': 'Alice’s destination (10)',
  },
  _Category.popculture: {
    'MARIO': 'Nintendo plumber (5)',
    'POKEMON': 'Catch ’em all (7)',
    'AVATAR': 'Na’vi on Pandora (6)',
    'BATMAN': 'Dark Knight (6)',
    'STARWARS': 'The Force saga (8)',
    'MARVEL': 'Avengers studio (6)',
    'DISNEY': 'Mickey’s house (6)',
    'NETFLIX': 'Streaming giant (7)',
    'TIKTOK': 'Short-video app (6)',
    'MEME': 'Viral in-joke (4)',
    'INSTAGRAM': 'Photo-sharing app (9)',
    'YOUTUBE': 'Creators’ platform (7)',
    'SPIDERMAN': 'Friendly neighborhood hero (9)',
    'FORTNITE': 'Battle royale hit (8)',
    'ZELDA': 'Link’s adventures (5)',
    'HASHTAG': 'Tagged phrase (7)',
    'STREAMER': 'Live content host (8)',
    'PODCAST': 'On-demand audio (7)',
    'EMOJI': 'Tiny pictograph (5)',
  },
  _Category.science: {
    'GRAVITY': 'Keeps planets in orbit (7)',
    'ATOM': 'Element’s basic unit (4)',
    'NEURON': 'Nerve cell (6)',
    'QUANTUM': 'Realm of the tiny (7)',
    'EVOLUTION': 'Change across generations (9)',
    'DNA': 'Double helix (3)',
    'PROTEIN': 'Amino-acid chain (7)',
    'PLANET': 'Orbits a star (6)',
    'GALAXY': 'Milky Way is one (6)',
    'VACCINE': 'Primes immunity (7)',
    'LASER': 'Coherent light (5)',
    'PHOTON': 'Light quantum (6)',
    'ION': 'Charged atom (3)',
    'ENZYME': 'Biological catalyst (6)',
    'CELL': 'Unit of life (4)',
    'ORBIT': 'Curved path (5)',
    'FUSION': 'Nuclei join (6)',
    'NANOTECH': 'Engineering tiny things (8)',
    'CLIMATE': 'Long-term weather (7)',
    'SPECIES': 'Interbreeding group (7)',
    'TESLA': 'SI unit of magnetic flux density (5)',
  },
  _Category.geography: {
    'EVEREST': 'Highest mountain (7)',
    'SAHARA': 'North African desert (6)',
    'AMAZON': 'Rainforest & river (6)',
    'ANDES': 'Long S. American range (5)',
    'NILE': 'Flows north to Med (4)',
    'ALPS': 'European range (4)',
    'PACIFIC': 'Largest ocean (7)',
    'ATLANTIC': 'Ocean between continents (8)',
    'ISLAND': 'Land in water (6)',
    'VOLCANO': 'Eruptive mountain (7)',
    'URALS': 'Europe–Asia divide (5)',
    'BALKANS': 'SE European peninsula (7)',
    'SAVANNA': 'Tropical grassland (7)',
    'TAIGA': 'Subarctic forest (5)',
    'ISTHMUS': 'Narrow land bridge (7)',
    'DELTA': 'River mouth fan (5)',
    'HIMALAYA': 'Roof of the World (8)',
    'CARIBBEAN': 'Sea of islands (9)',
    'PENINSULA': 'Almost an island (9)',
  },
  _Category.movies: {
    'INCEPTION': 'Nolan dream-heist (9)',
    'TITANIC': '1997 ocean tragedy (7)',
    'MATRIX': 'Red pill, blue pill (6)',
    'GODFATHER': 'Corleone classic (9)',
    'FROZEN': 'Disney sisters (6)',
    'ROCKY': 'Philly boxer (5)',
    'ALIEN': 'Xenomorph horror (5)',
    'JAWS': 'Shark thriller (4)',
    'PSYCHO': 'Shower scene (6)',
    'CASABLANCA': 'Wartime romance (10)',
    'AVENGERS': 'Earth’s heroes unite (8)',
    'GLADIATOR': '“Are you not entertained?” (9)',
    'ARRIVAL': 'Linguistics & aliens (7)',
    'WHIPLASH': 'Jazz obsession (8)',
    'PARASITE': 'Class satire (8)',
    'JOKER': 'Gotham antihero (5)',
    'AMELIE': 'Whimsical Paris romance (6)',
    'SKYFALL': 'Bond returns home (7)',
    'LALALAND': 'City of stars (8)',
  },
  _Category.music: {
    'BEATLES': 'Liverpool legends (7)',
    'MOZART': 'Salzburg prodigy (6)',
    'BEETHOVEN': 'Fifth Symphony (9)',
    'JAZZ': 'Improvised art form (4)',
    'BLUES': '12-bar roots genre (5)',
    'HIPHOP': 'Rap + DJ culture (6)',
    'OPERA': 'Sung drama (5)',
    'GUITAR': 'Six-string staple (6)',
    'PIANO': 'Hammered keys (5)',
    'CONCERT': 'Live performance (7)',
    'BACH': 'Counterpoint master (4)',
    'CHOPIN': 'Poet of the piano (6)',
    'ADELE': '“Hello” singer (5)',
    'RIHANNA': 'Fenty founder (7)',
    'DRAKE': 'Toronto rapper (5)',
    'EDM': 'Festival sound (3)',
    'KPOP': 'Korean pop (4)',
    'COUNTRY': 'Nashville twang (7)',
    'TECHNO': 'Detroit electronic (6)',
    'REGGAE': 'Jamaican groove (6)',
  },
  _Category.sports: {
    'SOCCER': 'World game (6)',
    'BASKETBALL': 'Hoops & dunks (10)',
    'TENNIS': 'Racquet sport (6)',
    'CRICKET': 'Bat & wickets (7)',
    'BASEBALL': 'Diamond pastime (8)',
    'HOCKEY': 'Ice sport (6)',
    'GOLF': 'Greens & birdies (4)',
    'RUGBY': 'Scrums & tries (5)',
    'OLYMPICS': 'Global games (8)',
    'MARATHON': '26.2-mile race (8)',
    'TRIATHLON': 'Swim-bike-run (9)',
    'SNOWBOARD': 'Sideways on snow (9)',
    'FREESTYLE': 'Trick-heavy style (9)',
    'ESPORTS': 'Competitive gaming (7)',
    'FORMULAONE': 'Grand prix series (10)',
    'POLEVAULT': 'Jump with a pole (9)',
    'HANDBALL': 'Fast indoor game (8)',
    'BILLIARDS': 'Cues and pockets (9)',
    'EQUESTRIAN': 'Horse events (10)',
  },
  _Category.food: {
    'PIZZA': 'Neapolitan classic (5)',
    'SUSHI': 'Rice + fish (5)',
    'TACO': 'Folded tortilla (4)',
    'BURRITO': 'Wrapped cylinder (7)',
    'PASTA': 'Italian noodles (5)',
    'CURRY': 'Spiced stew (5)',
    'CHOCOLATE': 'Cacao treat (9)',
    'BAGEL': 'Boiled then baked ring (5)',
    'CHEESE': 'Milk made solid (6)',
    'WAFFLE': 'Grid breakfast (6)',
    'AVOCADO': 'Toast topper (7)',
    'NOODLES': 'Ramen or udon (7)',
    'RISOTTO': 'Creamy rice (7)',
    'GNOCCHI': 'Potato pillows (7)',
    'RAMEN': 'Japanese noodle soup (5)',
    'BIBIMBAP': 'Mixed Korean bowl (8)',
    'SAMOSA': 'Triangular pastry (6)',
    'BROWNIE': 'Fudgy square (7)',
    'SMOOTHIE': 'Blended drink (8)',
    'PINEAPPLE': 'Spiky tropical fruit (9)',
    'STRAWBERRY': 'Seed-speckled berry (10)',
    'LASAGNA': 'Layered pasta bake (7)',
  },
};

// For each category, the playable word list is its clue keys.
Map<_Category, List<String>> get _wordBank {
  final base = _clueBank.map((k, v) => MapEntry(k, v.keys.toList()));
  // Mixed = union of all others
  base[_Category.mixed] = _clueBank.entries
      .where((e) => e.key != _Category.mixed)
      .expand((e) => e.value.keys)
      .toSet()
      .toList();
  return base;
}

// Clues map for Mixed = union of all
Map<String, String> get _mixedClues {
  final m = <String, String>{};
  _clueBank.forEach((cat, map) {
    if (cat == _Category.mixed) return;
    m.addAll(map);
  });
  return m;
}

/* ─────────────────── Crossword page ─────────────────── */

class CrosswordPage extends StatefulWidget {
  const CrosswordPage({super.key});
  @override
  State<CrosswordPage> createState() => _CrosswordPageState();
}

class _CrosswordPageState extends State<CrosswordPage>
    with SingleTickerProviderStateMixin {
  // persistence keys
  static const _saveDifficulty = 'cw4_diff';
  static const _saveCategory = 'cw4_cat';
  static const _saveGrid = 'cw4_grid';
  static const _saveUser = 'cw4_user';
  static const _saveSize = 'cw4_size';
  static const _saveStart = 'cw4_start';
  static const _saveDir = 'cw4_dir';
  static const _saveCursor = 'cw4_cursor';

  final rnd = Random();

  _Difficulty difficulty = _Difficulty.easy;
  _Category? category;

  late int n;
  late List<List<String?>> _solution; // null = block; else single letter
  late List<List<String?>> _cells; // null = block; "" or "A"
  late DateTime _startTime;

  late List<List<int?>> _numbers;
  late Map<int, String> _cluesAcross;
  late Map<int, String> _cluesDown;

  // Interaction
  _Direction _dir = _Direction.across;
  int _curR = 0, _curC = 0; // current cursor
  bool _autoCheck = true;

  bool _hasSave = false;

  // Anim for highlight pulse
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _restoreOrChooser();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /* ─────────── generator ─────────── */

  void _buildPuzzle() {
    n = switch (difficulty) {
      _Difficulty.easy => 7,
      _Difficulty.medium => 9,
      _Difficulty.hard => 11,
    };

    // choose words from category or mixed
    List<String> bank;
    if (category == _Category.mixed) {
      bank = List<String>.from(_mixedClues.keys);
    } else {
      bank = List<String>.from(_wordBank[category!]!);
    }
    bank.shuffle(rnd);

    final grid = List.generate(n, (_) => List<String?>.filled(n, null));

    // Lay horizontal theme words with alternating offsets
    final offset = (n == 11) ? 3 : 2;
    int rowsToUse = min(n, bank.length);
    for (int r = 0; r < rowsToUse; r++) {
      final w = bank[r];
      final start = (r.isOdd) ? offset : 0;
      if (w.length > n - start) continue;
      for (int i = 0; i < w.length; i++) {
        grid[r][start + i] = w[i];
      }
    }

    // Turn nulls into blocks for clean entries.
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        grid[r][c] ??= '#';
      }
    }

    // Simple vertical encouragement
    for (int tries = 0; tries < n; tries++) {
      final c = rnd.nextInt(n);
      for (int r = 0; r < n - 2; r++) {
        if (grid[r][c] != '#' && grid[r + 1][c] == '#' && grid[r + 2][c] == '#') {
          grid[r + 1][c] = grid[r][c];
        }
      }
    }

    _solution = List.generate(
      n,
      (r) => List.generate(n, (c) => grid[r][c] == '#' ? null : grid[r][c]),
    );
    _cells = List.generate(
      n,
      (r) => List.generate(n, (c) => _solution[r][c] == null ? null : ''),
    );
    _numbers = _computeNumbers(_solution);
    final (ac, dn) = _makeClues(_solution, _numbers);
    _cluesAcross = ac;
    _cluesDown = dn;
    _startTime = DateTime.now();

    // Set cursor to first non-block cell
    outer:
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_solution[r][c] != null) {
          _curR = r;
          _curC = c;
          break outer;
        }
      }
    }
    _dir = _Direction.across;
  }

  List<List<int?>> _computeNumbers(List<List<String?>> sol) {
    final nums = List.generate(n, (_) => List<int?>.filled(n, null));
    int counter = 0;
    bool isStartAcross(int r, int c) =>
        sol[r][c] != null &&
        (c == 0 || sol[r][c - 1] == null) &&
        (c + 1 < n && sol[r][c + 1] != null);
    bool isStartDown(int r, int c) =>
        sol[r][c] != null &&
        (r == 0 || sol[r - 1][c] == null) &&
        (r + 1 < n && sol[r + 1][c] != null);
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (sol[r][c] == null) continue;
        if (isStartAcross(r, c) || isStartDown(r, c)) {
          counter++;
          nums[r][c] = counter;
        }
      }
    }
    return nums;
  }

  (Map<int, String>, Map<int, String>) _makeClues(
      List<List<String?>> sol, List<List<int?>> nums) {
    final across = <int, String>{};
    final down = <int, String>{};
    final catClues =
        (category == _Category.mixed) ? _mixedClues : _clueBank[category!]!;

    // Across
    for (int r = 0; r < n; r++) {
      int c = 0;
      while (c < n) {
        if (sol[r][c] != null && (c == 0 || sol[r][c - 1] == null)) {
          int cc = c;
          final sb = StringBuffer();
          while (cc < n && sol[r][cc] != null) {
            sb.write(sol[r][cc]);
            cc++;
          }
          final word = sb.toString();
          if (word.length >= 2 && nums[r][c] != null) {
            final num = nums[r][c]!;
            across[num] = catClues[word] ?? '${_categoryLabel(category!)} word (${word.length})';
          }
          c = cc;
        } else {
          c++;
        }
      }
    }

    // Down
    for (int c = 0; c < n; c++) {
      int r = 0;
      while (r < n) {
        if (sol[r][c] != null && (r == 0 || sol[r - 1][c] == null)) {
          int rr = r;
          final sb = StringBuffer();
          while (rr < n && sol[rr][c] != null) {
            sb.write(sol[rr][c]);
            rr++;
          }
          final word = sb.toString();
          if (word.length >= 2 && nums[r][c] != null) {
            final num = nums[r][c]!;
            down[num] = catClues[word] ?? '${_categoryLabel(category!)} word (${word.length})';
          }
          r = rr;
        } else {
          r++;
        }
      }
    }

    return (across, down);
  }

  /* ─────────── helpers for active clue ─────────── */

  bool _isBlock(int r, int c) => _solution[r][c] == null;

  List<Point<int>> _cellsForRunFrom(int r, int c, _Direction dir) {
    if (_isBlock(r, c)) return const [];
    // move to start
    int sr = r, sc = c;
    if (dir == _Direction.across) {
      while (sc - 1 >= 0 && !_isBlock(sr, sc - 1)) sc--;
      final cells = <Point<int>>[];
      while (sc < n && !_isBlock(sr, sc)) {
        cells.add(Point(sr, sc));
        sc++;
      }
      return cells;
    } else {
      while (sr - 1 >= 0 && !_isBlock(sr - 1, sc)) sr--;
      final cells = <Point<int>>[];
      while (sr < n && !_isBlock(sr, sc)) {
        cells.add(Point(sr, sc));
        sr++;
      }
      return cells;
    }
  }

  int? _numberForStart(int r, int c) => _numbers[r][c];

  int? get _activeNumber {
    final cells = _cellsForRunFrom(_curR, _curC, _dir);
    if (cells.isEmpty) return null;
    final start = cells.first;
    return _numberForStart(start.x, start.y);
  }

  String get _activeClue {
    final num = _activeNumber;
    if (num == null) return '';
    return _dir == _Direction.across
        ? (_cluesAcross[num] ?? '')
        : (_cluesDown[num] ?? '');
  }

  void _selectCell(int r, int c) {
    if (_curR == r && _curC == c) {
      // toggle direction if tapping same cell and other run exists
      final hasAcross =
          _cellsForRunFrom(r, c, _Direction.across).length > 1;
      final hasDown = _cellsForRunFrom(r, c, _Direction.down).length > 1;
      if (hasAcross && hasDown) {
        _dir = _dir == _Direction.across ? _Direction.down : _Direction.across;
      }
    } else {
      // default prefer across if run > 1
      final acrossLen = _cellsForRunFrom(r, c, _Direction.across).length;
      final downLen = _cellsForRunFrom(r, c, _Direction.down).length;
      if (acrossLen >= downLen) {
        _dir = _Direction.across;
      } else {
        _dir = _Direction.down;
      }
      _curR = r;
      _curC = c;
    }
    _persist();
    setState(() {});
  }

  void _moveNextInRun() {
    final run = _cellsForRunFrom(_curR, _curC, _dir);
    if (run.isEmpty) return;
    final idx = run.indexWhere((p) => p.x == _curR && p.y == _curC);
    final next = (idx < run.length - 1) ? run[idx + 1] : run.last;
    _curR = next.x;
    _curC = next.y;
  }

  void _movePrevInRun() {
    final run = _cellsForRunFrom(_curR, _curC, _dir);
    if (run.isEmpty) return;
    final idx = run.indexWhere((p) => p.x == _curR && p.y == _curC);
    final prev = (idx > 0) ? run[idx - 1] : run.first;
    _curR = prev.x;
    _curC = prev.y;
  }

  List<int> _orderedNumbers(_Direction dir) {
    final keys = (dir == _Direction.across ? _cluesAcross : _cluesDown).keys.toList()
      ..sort();
    return keys;
  }

  void _gotoNextClue() {
    final list = _orderedNumbers(_dir);
    final cur = _activeNumber;
    if (cur == null || list.isEmpty) return;
    final i = list.indexOf(cur);
    final target = list[(i + 1) % list.length];
    _gotoClue(target, _dir);
  }

  void _gotoPrevClue() {
    final list = _orderedNumbers(_dir);
    final cur = _activeNumber;
    if (cur == null || list.isEmpty) return;
    final i = list.indexOf(cur);
    final target = list[(i - 1 + list.length) % list.length];
    _gotoClue(target, _dir);
  }

  void _gotoClue(int number, _Direction dir) {
    // find the cell with this number that starts the run for that dir
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_numbers[r][c] == number) {
          final run = _cellsForRunFrom(r, c, dir);
          if (run.isNotEmpty) {
            _dir = dir;
            // place cursor at first empty in run or at start
            final idx =
                run.indexWhere((p) => (_cells[p.x][p.y] ?? '').isEmpty);
            final p = idx == -1 ? run.first : run[idx];
            _curR = p.x;
            _curC = p.y;
            _persist();
            setState(() {});
            return;
          }
        }
      }
    }
  }

  /* ─────────── persistence ─────────── */

  Future<void> _persist() async {
    if (category == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_saveSize, n);
    await p.setInt(_saveDifficulty, difficulty.index);
    await p.setInt(_saveCategory, category!.index);
    await p.setInt(_saveStart, _startTime.millisecondsSinceEpoch);
    await p.setInt(_saveDir, _dir.index);
    await p.setString(_saveCursor, '$_curR:$_curC');

    final flatGrid = <String>[];
    final flatUser = <String>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        flatGrid.add(_solution[r][c] ?? '#');
        final u = _cells[r][c];
        flatUser.add(u == null ? '#' : (u!.isEmpty ? '' : u!));
      }
    }
    await p.setStringList(_saveGrid, flatGrid);
    await p.setStringList(_saveUser, flatUser);
    _hasSave = true;
  }

  Future<void> _clearPersisted() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_saveSize);
    await p.remove(_saveDifficulty);
    await p.remove(_saveCategory);
    await p.remove(_saveGrid);
    await p.remove(_saveUser);
    await p.remove(_saveStart);
    await p.remove(_saveDir);
    await p.remove(_saveCursor);
    _hasSave = false;
  }

  Future<void> _restoreOrChooser() async {
    final p = await SharedPreferences.getInstance();
    final savedN = p.getInt(_saveSize);
    final dIdx = p.getInt(_saveDifficulty);
    final cIdx = p.getInt(_saveCategory);
    final flatGrid = p.getStringList(_saveGrid);
    final flatUser = p.getStringList(_saveUser);
    final start = p.getInt(_saveStart);

    if (savedN != null &&
        dIdx != null &&
        cIdx != null &&
        flatGrid != null &&
        flatUser != null) {
      try {
        n = savedN;
        difficulty = _Difficulty.values[dIdx];
        category = _Category.values[cIdx];
        _solution = List.generate(
          n,
          (r) => List.generate(
            n,
            (c) => (flatGrid[r * n + c] == '#') ? null : flatGrid[r * n + c],
          ),
        );
        _cells = List.generate(
          n,
          (r) => List.generate(
            n,
            (c) {
              final v = flatUser[r * n + c];
              return v == '#'
                  ? null
                  : (v.isEmpty ? '' : v);
            },
          ),
        );
        _numbers = _computeNumbers(_solution);
        final (ac, dn) = _makeClues(_solution, _numbers);
        _cluesAcross = ac;
        _cluesDown = dn;
        _dir = _Direction.values[p.getInt(_saveDir) ?? 0];
        final cur = (p.getString(_saveCursor) ?? '0:0').split(':');
        _curR = int.tryParse(cur[0]) ?? 0;
        _curC = int.tryParse(cur[1]) ?? 0;
        _startTime = DateTime.fromMillisecondsSinceEpoch(
            start ?? DateTime.now().millisecondsSinceEpoch);
        _hasSave = true;
        setState(() {});
        return;
      } catch (_) {/* ignore and fall through */}
    }
    // No save — show chooser first.
    category = null;
    setState(() {});
  }

  void _newPuzzle() {
    _buildPuzzle();
    _persist();
    setState(() {});
  }

  void _resetPuzzle() {
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_cells[r][c] != null) _cells[r][c] = '';
      }
    }
    _startTime = DateTime.now();
    _persist();
    setState(() {});
  }

  bool _complete() {
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final sol = _solution[r][c];
        final cur = _cells[r][c];
        if (sol == null) continue;
        if ((cur ?? '').toUpperCase() != sol) return false;
      }
    }
    return true;
  }

  Future<void> _revealOne({Point<int>? at}) async {
    // reveal specific cell or a random incorrect one
    final points = <Point<int>>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_solution[r][c] == null) continue;
        if ((_cells[r][c] ?? '') != _solution[r][c]) points.add(Point(r, c));
      }
    }
    if (points.isEmpty) return;
    final p = at ?? points[rnd.nextInt(points.length)];
    _cells[p.x][p.y] = _solution[p.x][p.y];
    await _persist();
    setState(() {});
  }

  Future<void> _revealTen() async {
    int left = 10;
    while (left-- > 0) {
      await _revealOne();
    }
  }

  /* ─────────── input from soft keyboard ─────────── */

  void _typeLetter(String ch) async {
    if (category == null) return;
    if (_isBlock(_curR, _curC)) return;
    if (ch == '⌫') {
      if ((_cells[_curR][_curC] ?? '').isEmpty) {
        _movePrevInRun();
      }
      _cells[_curR][_curC] = '';
    } else {
      _cells[_curR][_curC] = ch.toUpperCase();
      _moveNextInRun();
    }
    await _persist();
    setState(() {});

    if (_complete()) {
      await _clearPersisted();
      final secs =
          DateTime.now().difference(_startTime).inSeconds.clamp(1, 99999);
      final score = 1 / secs;
      await ScoreStore.instance.add('crossword', score);
      final high = await ScoreStore.instance.reportBest('crossword', score);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(high ? 'New High Score!' : 'Crossword complete'),
          content: Text('Time: ${secs}s'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
            FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _newPuzzle();
                },
                child: const Text('New')),
          ],
        ),
      );
    }
  }

  /* ─────────── UI ─────────── */

  @override
  Widget build(BuildContext context) {
    // CHOOSER (balloons/bubbles)
    if (category == null) {
      return _GameScaffold(
        title: null,
        child: Stack(
          children: [
            const _SoftBubblesBackground(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'Choose a Category',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.count(
                      physics: const BouncingScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: _Category.values.map((c) {
                        return _BubbleCategoryTile(
                          icon: _categoryIcon(c),
                          label: _categoryLabel(c),
                          onSelected: () {
                            setState(() => category = c);
                            _newPuzzle();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // GAME
    final topBar = Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ink),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              await _clearPersisted();
              setState(() => category = null);
            },
            style: OutlinedButton.styleFrom(
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            icon: const Icon(Icons.bubble_chart_rounded, size: 16),
            label: const Text('Categories'),
          ),
          const SizedBox(width: 6),
          const Text('Difficulty:',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          DropdownButton<_Difficulty>(
            value: difficulty,
            isDense: true,
            iconSize: 16,
            items: const [
              DropdownMenuItem(value: _Difficulty.easy, child: Text('Easy (7×7)')),
              DropdownMenuItem(value: _Difficulty.medium, child: Text('Medium (9×9)')),
              DropdownMenuItem(value: _Difficulty.hard, child: Text('Hard (11×11)')),
            ],
            onChanged: (d) {
              if (d == null) return;
              setState(() => difficulty = d);
              _newPuzzle();
            },
          ),
          FilterChip(
            label: const Text('Auto-Check'),
            avatar: Icon(_autoCheck ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
            selected: _autoCheck,
            onSelected: (v) => setState(() => _autoCheck = v),
            selectedColor: const Color(0xFFEFFAF0),
            side: const BorderSide(color: _ink),
            backgroundColor: Colors.white,
          ),
          FilledButton.icon(
            onPressed: () => _revealOne(at: Point(_curR, _curC)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            icon: const Icon(Icons.text_fields_rounded, size: 16),
            label: const Text('Reveal Tile'),
          ),
          OutlinedButton.icon(
            onPressed: _revealTen,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            icon: const Icon(Icons.pending_actions_rounded, size: 16),
            label: const Text('+10 Letters'),
          ),
          OutlinedButton.icon(
            onPressed: _resetPuzzle,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset'),
          ),
          OutlinedButton.icon(
            onPressed: _newPuzzle,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            icon: const Icon(Icons.fiber_new_rounded, size: 16),
            label: const Text('New'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Chip(
              label: Text(_categoryLabel(category!)),
              avatar: Icon(_categoryIcon(category!), size: 16),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),
        ],
      ),
    );

    // Clue banner like screenshots (yellow bar with arrows)
    final clueBanner = Container(
      color: const Color(0xFFFFD54F),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _gotoPrevClue,
            icon: const Icon(Icons.arrow_back_rounded),
            splashRadius: 20,
          ),
          Expanded(
            child: Text(
              '${_activeNumber ?? ''}${_dir == _Direction.across ? 'a' : 'd'}. ${_activeClue}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton(
            onPressed: _gotoNextClue,
            icon: const Icon(Icons.arrow_forward_rounded),
            splashRadius: 20,
          ),
        ],
      ),
    );

    final keyboard = _Keyboard(onKey: _typeLetter);

    return _GameScaffold(
      title: null,
      child: Column(
        children: [
          topBar,
          clueBanner,
          // GRID
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: n,
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                  ),
                  itemCount: n * n,
                  itemBuilder: (_, i) {
                    final r = i ~/ n, c = i % n;
                    if (_solution[r][c] == null) {
                      return Container(color: Colors.black87);
                    }

                    final activeRun = _cellsForRunFrom(_curR, _curC, _dir);
                    final inActive = activeRun.any((p) => p.x == r && p.y == c);
                    final isCursor = (_curR == r && _curC == c);

                    final sol = _solution[r][c]!;
                    final cur = (_cells[r][c] ?? '').toUpperCase();
                    Color fill = Colors.white;
                    if (isCursor) {
                      final t = (0.85 + 0.15 * (sin(_pulse.value * 2 * pi) + 1) / 2);
                      fill = Color.lerp(_warn, Colors.white, t)!;
                    } else if (inActive) {
                      fill = _warn.withOpacity(.55);
                    }
                    if (_autoCheck && cur.isNotEmpty) {
                      if (cur == sol) {
                        fill = _good;
                      } else {
                        fill = _bad;
                      }
                    }

                    final number = _numbers[r][c];

                    return GestureDetector(
                      onTap: () => _selectCell(r, c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: fill,
                          border: Border.all(color: Colors.black54, width: 1),
                        ),
                        child: Stack(
                          children: [
                            if (number != null)
                              Positioned(
                                left: 3,
                                top: 2,
                                child: Text(
                                  '$number',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            Center(
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 120),
                                scale: isCursor ? 1.1 : 1.0,
                                child: Text(
                                  cur,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Keyboard & utility row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: keyboard),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────── Soft keyboard ─────────────────── */

class _Keyboard extends StatelessWidget {
  final void Function(String) onKey;
  const _Keyboard({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Q','W','E','R','T','Y','U','I','O','P'],
      ['A','S','D','F','G','H','J','K','L'],
      ['Z','X','C','V','B','N','M'],
      ['⌫']
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: rows[i].map((label) {
                final wide = label == '⌫';
                return SizedBox(
                  width: wide ? 64 : 36,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          wide ? const Color(0xFFB6E3FF) : const Color(0xFFBEE8DF),
                      elevation: 1.5,
                      shadowColor: Colors.black26,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => onKey(label),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/* ─────────────────── Bubble Category Tile ─────────────────── */

class _BubbleCategoryTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  const _BubbleCategoryTile({
    required this.icon,
    required this.label,
    required this.onSelected,
    Key? key,
  }) : super(key: key);

  @override
  State<_BubbleCategoryTile> createState() => _BubbleCategoryTileState();
}

class _BubbleCategoryTileState extends State<_BubbleCategoryTile>
    with TickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);
  late final Animation<double> _bobAnim =
      Tween(begin: -4.0, end: 4.0).animate(CurvedAnimation(parent: _bob, curve: Curves.easeInOut));

  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final Animation<double> _scale =
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
      ]).animate(_pop);
  late final Animation<double> _fade =
      Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _pop, curve: Curves.easeIn));

  @override
  void dispose() {
    _bob.dispose();
    _pop.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _pop.forward();
    if (!mounted) return;
    widget.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final themeGreen = const Color(0xFF0D7C66);
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _pop]),
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _bobAnim.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_pop.value > 0)
                Opacity(
                  opacity: (1 - _pop.value).clamp(0.0, 1.0),
                  child: Container(
                    width: 120 + 120 * _pop.value,
                    height: 120 + 120 * _pop.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6 * (1 - _pop.value)), width: 2),
                    ),
                  ),
                ),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: GestureDetector(
                    onTap: _handleTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEFF9F6), Color(0xFFE5F0FF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: themeGreen.withOpacity(.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: Colors.black54, width: 1),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 16,
                                top: 14,
                                child: Container(
                                  width: 28,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.7),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                              Center(child: Icon(widget.icon, size: 44, color: themeGreen)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.label,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ─────────────────── Floating Background Bubbles ─────────────────── */

class _SoftBubblesBackground extends StatefulWidget {
  const _SoftBubblesBackground();

  @override
  State<_SoftBubblesBackground> createState() => _SoftBubblesBackgroundState();
}

class _SoftBubblesBackgroundState extends State<_SoftBubblesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  final rnd = Random();
  late final List<_Bubble> _bubbles = List.generate(
    18,
    (i) => _Bubble(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      r: .02 + rnd.nextDouble() * .05,
      dx: (rnd.nextDouble() - 0.5) * .015,
      dy: (-.015 + rnd.nextDouble() * .01),
      a: .18 + rnd.nextDouble() * .18,
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          painter: _BubblesPainter(_bubbles, _c.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Bubble {
  double x, y, r, dx, dy, a;
  _Bubble({required this.x, required this.y, required this.r, required this.dx, required this.dy, required this.a});
}

class _BubblesPainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double t; // 0..1
  _BubblesPainter(this.bubbles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final b in bubbles) {
      final x = (b.x + b.dx * t) % 1.0;
      final y = (b.y + b.dy * t) % 1.0;
      final center = Offset(x * size.width, y * size.height);
      final radius = b.r * size.shortestSide * (1 + 0.05 * sin(2 * pi * t));
      paint.color = const Color(0xFF0D7C66).withOpacity(b.a * 0.45);
      canvas.drawCircle(center, radius, paint);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF0D7C66).withOpacity(b.a * 0.55);
      canvas.drawCircle(center, radius, rim);
      final highlight = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(.35 * b.a);
      canvas.drawCircle(center.translate(-radius * .35, -radius * .35), radius * .25, highlight);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => true;
}
