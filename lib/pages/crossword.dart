// lib/pages/crossword.dart
//
// Crossword with balloon-style category chooser, pop-to-start animation,
// difficulty controls, classic evenly spaced crossword grid, bigger clue
// panel, and no title text in the app bar.
// No external assets.
//
// Tip: The category screen shows floating background bubbles. Tapping a
// category bubble "pops" it, then launches the crossword for that category.

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
        title: title == null ? null : Text(title!, style: const TextStyle(fontWeight: FontWeight.w900)),
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

enum _Category {
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
    'LION': '“King of the jungle”; maned big cat (4) — pride leader',
    'TIGER': 'Striped big cat of Asia (5) — apex hunter',
    'EAGLE': 'National bird of the U.S. (5) — keen vision',
    'DOLPHIN': 'Clever marine mammal; uses clicks (7) — sonar user',
    'PANDA': 'Bamboo-munching bear (5) — black and white',
    'KANGAROO': 'Hopping marsupial (8) — has a pouch',
    'KOALA': 'Eucalyptus snacker (5) — not a bear',
    'PENGUIN': 'Tuxedoed bird that can’t fly (7) — waddler',
    'GIRAFFE': 'Tallest land animal (7) — long neck',
    'ZEBRA': 'Striped grazer (5) — horse relative',
    'OTTER': 'River raft-loving mammal (5) — playful',
    'RHINO': 'Horned heavyweight (5) — thick skin',
    'CHEETAH': 'Fastest sprinter (7) — spotted',
    'JAGUAR': 'Spotted American big cat (6) — rosette pattern',
    'WALRUS': 'Arctic tusker (6) — whiskers',
    'MEERKAT': 'Sentry mongoose relative (7) — stands upright',
    'RACCOON': 'Masked scavenger (7) — ringed tail',
    'PLATYPUS': 'Bill-bearing egg-layer (8) — odd mammal',
    'HEDGEHOG': 'Spiny insect eater (8) — curls up',
    'ORANGUTAN': 'Red ape; “man of the forest” (9) — Borneo/Sumatra',
    'SEAHORSE': 'Curly-tailed fish (8) — males carry young',
    'BISON': 'Massive grazer (5) — American plains',
    'COYOTE': 'Wily canid (6) — howler',
  },
  _Category.history: {
    'CAESAR': 'Julius ___, Roman statesman (6) — dictator',
    'PYRAMID': 'Ancient tomb (7) — Giza silhouette',
    'EMPIRE': 'Realm of an emperor (6) — vast rule',
    'RENAISSANCE': 'European “rebirth” (11) — art & science',
    'PHARAOH': 'Egyptian ruler title (7) — divine king',
    'SPARTA': 'Warrior city-state (6) — hoplites',
    'VIKING': 'Norse seafarer (6) — longship raider',
    'COLONY': 'Overseas possession (6) — settlement',
    'MONARCH': 'King or queen (7) — sovereign',
    'CONSTITUTION': 'Foundational law (12) — supreme charter',
    'CRUSADE': 'Medieval holy war (7) — pilgrimage in arms',
    'REPUBLIC': 'State without a monarch (8) — elected rule',
    'ARMADA': 'Spanish fleet 1588 (6) — blown off course',
    'TREATY': 'Formal pact (6) — accord',
    'REVOLT': 'Uprising (6) — insurrection',
    'BYZANTINE': 'Eastern Roman culture (9) — Constantinople',
    'AZTEC': 'Empire of Tenochtitlán (5) — Nahuatl',
    'MAYA': 'Yucatán civilization (4) — glyphs',
    'PILGRIM': 'Mayflower settler (7) — Plymouth',
    'COLOSSEUM': 'Roman amphitheater (9) — gladiators',
  },
  _Category.literature: {
    'ODYSSEY': 'Homer’s voyage home (7) — Ithaca goal',
    'HAMLET': 'Prince of Denmark (6) — “To be…”',
    'GATSBY': 'Jazz-Age dreamer (6) — green light',
    'QUIXOTE': 'Windmill tilting knight (6) — Sancho Panza',
    'INFERNO': 'First part of Dante’s epic (7) — nine circles',
    'ILIAD': 'Wrath of Achilles (5) — Trojan War',
    'DUNE': 'Arrakis saga (4) — spice',
    'NARNIA': 'Wardrobe world (6) — Aslan',
    'SHERLOCK': 'Baker Street sleuth (8) — deerstalker',
    'ORWELL': 'Wrote “1984” (6) — dystopia',
    'POE': 'Master of the macabre (3) — raven',
    'AUSTEN': '“Pride and Prejudice” author (6) — Bennet',
    'BRONTE': 'Sisters of the moors (6) — Jane Eyre',
    'HOBBIT': 'Bilbo’s tale (6) — ring',
    'POTTER': 'Boy wizard (6) — Hogwarts',
    'ATTICUS': 'Finch of Maycomb (7) — lawyer',
    'TWAIN': 'Humorist of Huck Finn (5) — Mississippi',
    'AENEID': 'Virgil’s epic (6) — Rome’s founding',
    'FAULKNER': 'Southern Nobel writer (8) — Yoknapatawpha',
    'WONDERLAND': 'Alice’s destination (10) — white rabbit',
  },
  _Category.popculture: {
    'MARIO': 'Nintendo plumber (5) — mushrooms',
    'POKEMON': 'Catch ’em all (7) — Pikachu',
    'AVATAR': 'Na’vi on Pandora (6) — blue',
    'BATMAN': 'Dark Knight (6) — Gotham',
    'STARWARS': 'The Force saga (8) — lightsabers',
    'MARVEL': 'Avengers studio (6) — MCU',
    'DISNEY': 'Mickey’s house (6) — castle logo',
    'NETFLIX': 'Red-N streamer (7) — binge',
    'TIKTOK': 'Short video app (6) — For You',
    'MEME': 'Viral in-joke (4) — template',
    'INSTAGRAM': 'Stories & reels (9) — filters',
    'YOUTUBE': 'Creators’ platform (7) — subscribe',
    'SPIDERMAN': 'Friendly neighborhood hero (9) — web',
    'FORTNITE': 'Battle royale hit (8) — Victory Royale',
    'ZELDA': 'Link’s adventures (5) — triforce',
    'HASHTAG': 'Tagged phrase (7) — #',
    'STREAMER': 'Live content host (8) — chat',
    'PODCAST': 'On-demand audio (7) — episodes',
    'EMOJI': 'Tiny pictograph (5) — 🙂',
  },
  _Category.science: {
    'GRAVITY': 'Keeps planets in orbit (7) — attraction',
    'ATOM': 'Element’s basic unit (4) — nucleus',
    'NEURON': 'Nerve cell (6) — axon',
    'QUANTUM': 'Realm of the tiny (7) — Planck',
    'EVOLUTION': 'Change over generations (9) — selection',
    'DNA': 'Double helix (3) — bases',
    'PROTEIN': 'Amino-acid chain (7) — enzyme',
    'PLANET': 'Orbits a star (6) — clears neighborhood',
    'GALAXY': 'Milky Way is one (6) — billions of stars',
    'VACCINE': 'Primes immunity (7) — antigen',
    'LASER': 'Coherent light (5) — amplification',
    'PHOTON': 'Light quantum (6) — packet',
    'ION': 'Charged atom (3) — cation/anion',
    'ENZYME': 'Biological catalyst (6) — lowers Ea',
    'CELL': 'Unit of life (4) — membrane',
    'ORBIT': 'Curved path (5) — ellipse',
    'FUSION': 'Nuclei join (6) — sun’s power',
    'NANOTECH': 'Engineering tiny things (8) — nm scale',
    'CLIMATE': 'Long-term weather (7) — trends',
    'SPECIES': 'Interbreeding group (7) — taxonomy',
    'TESLA': 'Magnetic flux density unit (5) — SI',
  },
  _Category.geography: {
    'EVEREST': 'Highest mountain (7) — Sagarmatha',
    'SAHARA': 'North African desert (6) — dunes',
    'AMAZON': 'Rainforest & river (6) — basin',
    'ANDES': 'Long S. American range (5) — condors',
    'NILE': 'Flows north to Med (4) — delta',
    'ALPS': 'European range (4) — Matterhorn',
    'PACIFIC': 'Largest ocean (7) — ring of fire',
    'ATLANTIC': 'Ocean between continents (8) — Gulf Stream',
    'ISLAND': 'Land in water (6) — archipelago',
    'VOLCANO': 'Eruptive mountain (7) — lava',
    'URALS': 'Europe–Asia divide (5) — Russia',
    'BALKANS': 'SE European peninsula (7) — Adriatic',
    'SAVANNA': 'Tropical grassland (7) — acacia',
    'TAIGA': 'Subarctic forest (5) — boreal',
    'ISTHMUS': 'Narrow land bridge (7) — Panama',
    'DELTA': 'River mouth fan (5) — silt',
    'HIMALAYA': 'Roof of the World (8) — Nepal/Tibet',
    'CARIBBEAN': 'Sea of islands (9) — Antilles',
    'PENINSULA': 'Nearly surrounded by water (9) — spit',
  },
  _Category.movies: {
    'INCEPTION': 'Nolan dream-heist (9) — spinning top',
    'TITANIC': '1997 ocean tragedy (7) — iceberg',
    'MATRIX': 'Red pill, blue pill (6) — bullet time',
    'GODFATHER': 'Cannoli quote classic (9) — Corleone',
    'FROZEN': 'Disney sisters (6) — “Let It Go”',
    'ROCKY': 'Philly boxer (5) — steps',
    'ALIEN': 'Xenomorph horror (5) — Ripley',
    'JAWS': 'Shark thriller (4) — Amity',
    'PSYCHO': 'Shower scene (6) — Bates',
    'CASABLANCA': '“Looking at you, kid.” (10) — wartime',
    'AVENGERS': 'Earth’s heroes unite (8) — Thanos',
    'GLADIATOR': '“Are you not entertained?” (9) — arena',
    'ARRIVAL': 'Linguistics & aliens (7) — heptapods',
    'WHIPLASH': 'Jazz obsession (8) — Fletcher',
    'PARASITE': 'Class satire (8) — basement',
    'JOKER': 'Gotham antihero (5) — Arthur',
    'AMELIE': 'Whimsical Paris romance (6) — gnome',
    'SKYFALL': 'Bond returns home (7) — M',
    'LALALAND': 'City of stars (8) — musical',
  },
  _Category.music: {
    'BEATLES': 'Liverpool legends (7) — Fab Four',
    'MOZART': 'Salzburg prodigy (6) — Requiem',
    'BEETHOVEN': 'Fifth Symphony (9) — deaf composer',
    'JAZZ': 'Improvised art form (4) — swing',
    'BLUES': 'Roots genre (5) — 12-bar',
    'HIPHOP': 'Rap + DJing culture (6) — breakdance',
    'OPERA': 'Sung drama (5) — aria',
    'GUITAR': 'Six-string staple (6) — fretboard',
    'PIANO': 'Hammered keys (5) — pedals',
    'CONCERT': 'Live performance (7) — recital',
    'BACH': 'Counterpoint master (4) — Baroque',
    'CHOPIN': 'Poet of the piano (6) — nocturnes',
    'ADELE': '“Hello” singer (5) — powerhouse',
    'RIHANNA': 'Umbrella singer (7) — Fenty',
    'DRAKE': 'Toronto rapper (5) — OVO',
    'EDM': 'Festival sound (3) — drops',
    'KPOP': 'Korean pop (4) — idols',
    'COUNTRY': 'Twangy tales (7) — Nashville',
    'TECHNO': 'Detroit electronic (6) — four-on-the-floor',
    'REGGAE': 'Jamaican groove (6) — offbeat',
  },
  _Category.sports: {
    'SOCCER': 'World game (6) — pitch',
    'BASKETBALL': 'Hoops & dunks (10) — three-pointer',
    'TENNIS': 'Racquet sport (6) — deuce',
    'CRICKET': 'Bat & wickets (7) — overs',
    'BASEBALL': 'Diamond pastime (8) — home run',
    'HOCKEY': 'Ice sport (6) — puck',
    'GOLF': 'Greens & birdies (4) — par',
    'RUGBY': 'Scrums & tries (5) — oval ball',
    'OLYMPICS': 'Global games (8) — rings',
    'MARATHON': '26.2-mile race (8) — endurance',
    'TRIATHLON': 'Swim-bike-run (9) — transition',
    'SNOWBOARD': 'Sideways on snow (9) — carving',
    'FREESTYLE': 'Swimming/skiing style (9) — tricks',
    'ESPORTS': 'Competitive gaming (7) — arena',
    'FORMULAONE': 'Grand prix series (10) — pit stop',
    'POLEVAULT': 'Jump with a pole (9) — bar',
    'HANDBALL': 'Fast indoor game (8) — 7-a-side',
    'BILLIARDS': 'Cues and pockets (9) — cue ball',
    'EQUESTRIAN': 'Horse events (10) — dressage',
  },
  _Category.food: {
    'PIZZA': 'Neapolitan classic (5) — slice',
    'SUSHI': 'Rice + fish (5) — nigiri',
    'TACO': 'Folded tortilla (4) — street food',
    'BURRITO': 'Wrapped cylinder (7) — foil',
    'PASTA': 'Italian noodles (5) — al dente',
    'CURRY': 'Spiced stew (5) — masala',
    'CHOCOLATE': 'Cacao treat (9) — cocoa',
    'BAGEL': 'Boiled then baked ring (5) — schmear',
    'CHEESE': 'Milk made solid (6) — rind',
    'WAFFLE': 'Grid breakfast (6) — syrup',
    'AVOCADO': 'Toast topper (7) — guacamole',
    'NOODLES': 'Ramen or udon (7) — broth',
    'RISOTTO': 'Creamy rice (7) — arborio',
    'GNOCCHI': 'Potato pillows (7) — dumplings',
    'RAMEN': 'Japanese noodle soup (5) — toppings',
    'BIBIMBAP': 'Mixed Korean bowl (8) — gochujang',
    'SAMOSA': 'Triangular pastry (6) — chutney',
    'BROWNIE': 'Fudgy square (7) — dessert',
    'SMOOTHIE': 'Blended drink (8) — fruit',
    'PINEAPPLE': 'Spiky tropical fruit (9) — bromelain',
    'STRAWBERRY': 'Seed-speckled berry (10) — shortcake',
    'LASAGNA': 'Layered pasta bake (7) — ricotta',
  },
};

// For each category, the playable word list is its clue keys.
Map<_Category, List<String>> get _wordBank =>
    _clueBank.map((k, v) => MapEntry(k, v.keys.toList()));

/* ─────────────────── Crossword page ─────────────────── */

class CrosswordPage extends StatefulWidget {
  const CrosswordPage({super.key});
  @override
  State<CrosswordPage> createState() => _CrosswordPageState();
}

class _CrosswordPageState extends State<CrosswordPage> {
  // persistence keys
  static const _saveDifficulty = 'cw4_diff';
  static const _saveCategory = 'cw4_cat';
  static const _saveGrid = 'cw4_grid';
  static const _saveUser = 'cw4_user';
  static const _saveSize = 'cw4_size';
  static const _saveStart = 'cw4_start';

  final rnd = Random();

  _Difficulty difficulty = _Difficulty.easy;
  _Category? category; // choose first, like Word Search

  late int n;
  late List<List<String?>> _solution; // null = block; else single letter
  late List<List<String?>> _cells; // null = block; "" or "A"
  late DateTime _startTime;

  late List<List<int?>> _numbers;
  late Map<int, String> _cluesAcross;
  late Map<int, String> _cluesDown;

  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    _restoreOrChooser();
  }

  /* ─────────── generator ─────────── */

  void _buildPuzzle() {
    n = switch (difficulty) {
      _Difficulty.easy => 7,
      _Difficulty.medium => 9,
      _Difficulty.hard => 11,
    };

    final bank = List<String>.from(_wordBank[category!]!);
    bank.shuffle(rnd);

    final grid = List.generate(n, (_) => List<String?>.filled(n, null));

    // Lay horizontal theme words with alternating offsets to promote crossings.
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

    // Light vertical encouragement: copy letters downward to create 2+ runs.
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
    final catClues = _clueBank[category!]!;

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
          if (word.length >= 2) {
            final num = nums[r][c]!;
            across[num] =
                catClues[word] ?? '${_categoryLabel(category!)} item (${word.length})';
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
          if (word.length >= 2) {
            final num = nums[r][c]!;
            down[num] =
                catClues[word] ?? '${_categoryLabel(category!)} item (${word.length})';
          }
          r = rr;
        } else {
          r++;
        }
      }
    }

    return (across, down);
  }

  /* ─────────── persistence ─────────── */

  Future<void> _persist() async {
    if (category == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_saveSize, n);
    await p.setInt(_saveDifficulty, difficulty.index);
    await p.setInt(_saveCategory, category!.index);
    await p.setInt(_saveStart, _startTime.millisecondsSinceEpoch);

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
        _startTime = DateTime.fromMillisecondsSinceEpoch(
            start ?? DateTime.now().millisecondsSinceEpoch);
        _hasSave = true;
        setState(() {});
        return;
      } catch (_) {
        // fall through to chooser
      }
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

  Future<void> _hint() async {
    final points = <Point<int>>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_solution[r][c] == null) continue;
        if ((_cells[r][c] ?? '') != _solution[r][c]) points.add(Point(r, c));
      }
    }
    if (points.isEmpty) return;
    final p = points[rnd.nextInt(points.length)];
    _cells[p.x][p.y] = _solution[p.x][p.y];
    await _persist();
    setState(() {});
  }

  /* ─────────── UI ─────────── */

  @override
  Widget build(BuildContext context) {
    // CHOOSER (balloons/bubbles): pick a category first
    if (category == null) {
      return _GameScaffold(
        title: null, // remove "Crossword" at the top
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
                            _newPuzzle(); // start after pop
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
          // Back to category bubbles
          OutlinedButton.icon(
            onPressed: () async {
              await _clearPersisted();
              setState(() {
                category = null;
              });
            },
            style: OutlinedButton.styleFrom(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
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
          FilledButton.icon(
            onPressed: _hint,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
            label: const Text('Hint'),
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
          if (_hasSave)
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

    return _GameScaffold(
      title: null, // keep no title on gameplay too for consistency
      child: Column(
        children: [
          topBar,
          // GRID: classic crossword look (even spacing, black blocks)
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

                    final ok =
                        (_cells[r][c] ?? '').toUpperCase() == _solution[r][c];
                    final number = _numbers[r][c];

                    return Stack(
                      children: [
                        // Cell frame
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black54, width: 1),
                            ),
                          ),
                        ),
                        // Number
                        if (number != null)
                          Positioned(
                            left: 4,
                            top: 2,
                            child: IgnorePointer(
                              child: Text(
                                '$number',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        // Input
                        TextField(
                          controller: TextEditingController(text: _cells[r][c]),
                          onChanged: (v) async {
                            _cells[r][c] =
                                v.isEmpty ? '' : v.substring(0, 1).toUpperCase();
                            await _persist();
                            setState(() {});
                            if (_complete()) {
                              await _clearPersisted();
                              final secs = DateTime.now()
                                  .difference(_startTime)
                                  .inSeconds
                                  .clamp(1, 99999);
                              final score = 1 / secs;
                              await ScoreStore.instance.add('crossword', score);
                              final high = await ScoreStore.instance
                                  .reportBest('crossword', score);
                              if (!mounted) return;
                              await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(
                                      high ? 'New High Score!' : 'Crossword complete'),
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
                          },
                          maxLength: 1,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            counterText: '',
                            border: InputBorder.none, // frame handled by container
                            isCollapsed: true,
                            filled: true,
                            fillColor: ok
                                ? const Color(0xFFA7E0C9)
                                : Colors.white,
                            contentPadding: const EdgeInsets.only(top: 10),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // CLUES
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _ink),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ClueList(title: 'Across', clues: _cluesAcross)),
                    const SizedBox(width: 12),
                    Expanded(child: _ClueList(title: 'Down', clues: _cluesDown)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────── Widgets ─────────────────── */

class _ClueList extends StatelessWidget {
  final String title;
  final Map<int, String> clues;
  const _ClueList({required this.title, required this.clues});
  @override
  Widget build(BuildContext context) {
    final entries = clues.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          const Text('—', style: TextStyle(fontSize: 12)),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${e.key}. ${e.value}',
              style: const TextStyle(fontSize: 12.5, height: 1.2),
              softWrap: true,
            ),
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
              // Ripple when popping
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
                        // Bubble
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
                              // Soft highlight to feel like a balloon
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
      // Bubble body
      paint.color = const Color(0xFF0D7C66).withOpacity(b.a * 0.45);
      canvas.drawCircle(center, radius, paint);
      // Bubble rim
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF0D7C66).withOpacity(b.a * 0.55);
      canvas.drawCircle(center, radius, rim);
      // Highlight
      final highlight = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(.35 * b.a);
      canvas.drawCircle(center.translate(-radius * .35, -radius * .35), radius * .25, highlight);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => true;
}
