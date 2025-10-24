// lib/pages/crossword.dart
//
// Crossword with categories + difficulty and responsive top bar.
// - Difficulty: Easy(7×7), Medium(9×9), Hard(11×11)
// - Categories (10): Animals, History, Literature, Pop Culture, Science,
//                    Geography, Movies, Music, Sports, Food
// - Specific clues per category (curated).
//
// Only Flutter + shared_preferences.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ─────────────────── Shared look & scaffold ─────────────────── */

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

class _GameScaffold extends StatelessWidget {
  final String title;
  final String rule;
  final Widget child;
  final Widget? topBar;
  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
    this.topBar,
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
                  child: Text(
                    rule,
                    textAlign: TextAlign.center,
                  ),
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

/* ─────────────────── Difficulty + categories ─────────────────── */

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

/* ------------- Word banks + clues (keys match word lists) ------------- */
// All caps words (A–Z). Each bank has ~10–14 entries to keep puzzles fresh.

final Map<_Category, Map<String, String>> _clueBank = {
  _Category.animals: {
    'LION': '“King of the jungle,” big cat with a mane (4)',
    'TIGER': 'Striped big cat found in India and Siberia (5)',
    'EAGLE': 'Bird on the Great Seal of the United States (5)',
    'DOLPHIN': 'Smart marine mammal known for sonar clicks (7)',
    'PANDA': 'Bamboo-munching bear of China (5)',
    'KANGAROO': 'Marsupial that boxes in cartoons (8)',
    'KOALA': 'Tree-hugger from Australia (5)',
    'PENGUIN': 'Tuxedoed bird that can’t fly (7)',
    'GIRAFFE': 'Tallest land animal (7)',
    'ZEBRA': 'Black-and-white striped grazer (5)',
    'OTTER': 'River mammal that loves to raft (5)',
    'RHINO': 'Horned heavyweight of the savanna (5)',
  },
  _Category.history: {
    'CAESAR': 'Julius ___, Roman general and statesman (6)',
    'PYRAMID': 'Ancient triangular tomb in Giza (7)',
    'EMPIRE': 'Realm ruled by an emperor (6)',
    'RENAISSANCE': 'European “rebirth” of art and learning (11)',
    'PHARAOH': 'Title of an ancient Egyptian ruler (7)',
    'SPARTA': 'Greek city-state famed for warriors (6)',
    'VIKING': 'Norse seafarer of the early Middle Ages (6)',
    'COLONY': 'Overseas possession of a power (6)',
    'MONARCH': 'King or queen (7)',
    'CONSTITUTION': 'Foundational law of a nation (12)',
    'CRUSADE': 'Medieval religious military expedition (7)',
  },
  _Category.literature: {
    'ODYSSEY': 'Homer’s epic about a long voyage home (7)',
    'HAMLET': 'Prince of Denmark in a Shakespeare tragedy (6)',
    'GATSBY': 'Nick Carraway narrates this Jazz-Age tale (6)',
    'QUIXOTE': 'Don ___ tilts at windmills (6)',
    'INFERNO': 'First cantica of Dante’s “Divine Comedy” (7)',
    'ILIAD': 'Epic about the wrath of Achilles (5)',
    'DUNE': 'Desert planet Arrakis features in this saga (4)',
    'NARNIA': 'Wardrobe opens into this country (6)',
    'SHERLOCK': 'Holmes, Baker Street detective (8)',
    'ORWELL': 'Author of “1984” and “Animal Farm” (6)',
    'POE': 'Master of the macabre; wrote “The Raven” (3)',
  },
  _Category.popculture: {
    'MARIO': 'Nintendo plumber who stomps Goombas (5)',
    'POKEMON': 'Gotta catch ’em all! (7)',
    'AVATAR': 'Blue Na’vi on Pandora; 2009 blockbuster (6)',
    'BATMAN': 'Dark Knight of Gotham City (6)',
    'STARWARS': 'Lightsabers and the Force (8)',
    'MARVEL': 'MCU studio behind the Avengers (6)',
    'DISNEY': 'Mickey’s company (6)',
    'NETFLIX': 'Streaming giant with red N (7)',
    'TIKTOK': 'Short-form video app (6)',
    'MEME': 'Viral internet in-joke (4)',
  },
  _Category.science: {
    'GRAVITY': 'Force that keeps planets in orbit (7)',
    'ATOM': 'Smallest unit of a chemical element (4)',
    'NEURON': 'Signal-sending brain cell (6)',
    'QUANTUM': 'Physics realm of the very small (7)',
    'EVOLUTION': 'Darwin’s big idea (9)',
    'DNA': 'Double-helix genetic material (3)',
    'PROTEIN': 'Chains of amino acids (7)',
    'PLANET': 'Non-stellar body orbiting a star (6)',
    'GALAXY': 'Milky Way is one (6)',
    'VACCINE': 'Prepares immune system for a pathogen (7)',
    'LASER': 'Coherent light source (5)',
  },
  _Category.geography: {
    'EVEREST': 'World’s highest mountain (7)',
    'SAHARA': 'Vast desert of North Africa (6)',
    'AMAZON': 'Largest rainforest / mighty river (6)',
    'ANDES': 'Long mountain range along S. America (5)',
    'NILE': 'River that flows north to the Med (4)',
    'ALPS': 'Range spanning France to Slovenia (4)',
    'PACIFIC': 'Largest ocean (7)',
    'ATLANTIC': 'Ocean between the Americas and Europe/Africa (8)',
    'ISLAND': 'Land surrounded by water (6)',
    'VOLCANO': 'Mountain that can erupt (7)',
  },
  _Category.movies: {
    'INCEPTION': 'Dream-heist film by Christopher Nolan (9)',
    'TITANIC': '1997 shipboard romance disaster (7)',
    'MATRIX': 'Red pill, blue pill sci-fi (6)',
    'GODFATHER': '“Leave the gun, take the cannoli.” (9)',
    'FROZEN': 'Disney hit featuring Elsa and Anna (6)',
    'ROCKY': 'Underdog boxer from Philly (5)',
    'ALIEN': 'Xenomorph stalks a spaceship (5)',
    'JAWS': 'Shark terrorizes Amity Island (4)',
    'PSYCHO': 'Hitchcock thriller with a famous shower scene (6)',
    'CASABLANCA': '“Here’s looking at you, kid.” (10)',
  },
  _Category.music: {
    'BEATLES': 'Liverpool band: John, Paul, George, Ringo (7)',
    'MOZART': 'Classical prodigy from Salzburg (6)',
    'BEETHOVEN': 'Composer of the Fifth Symphony (9)',
    'JAZZ': 'Improvisational American art form (4)',
    'BLUES': 'Genre rooted in work songs and spirituals (5)',
    'HIPHOP': 'Rap + DJing + breakdance + graffiti (6)',
    'OPERA': 'Staged drama set to music (5)',
    'GUITAR': 'Six-string staple of rock bands (6)',
    'PIANO': 'Keyboard instrument with hammers (5)',
    'CONCERT': 'Live musical performance (7)',
  },
  _Category.sports: {
    'SOCCER': 'World’s most popular sport (6)',
    'BASKETBALL': 'Hoops, three-pointers, slam dunks (10)',
    'TENNIS': 'Racquets at Wimbledon (6)',
    'CRICKET': 'Bat-and-ball with wickets (7)',
    'BASEBALL': 'Home runs and curveballs (8)',
    'HOCKEY': 'Ice rink and a puck (6)',
    'GOLF': 'Birdies and bogeys (4)',
    'RUGBY': 'Scrums and tries (5)',
    'OLYMPICS': 'Global multi-sport event every four years (8)',
    'MARATHON': '26.2-mile race (8)',
  },
  _Category.food: {
    'PIZZA': 'Cheesy pie from Naples (5)',
    'SUSHI': 'Rice + fish; Japanese staple (5)',
    'TACO': 'Folded tortilla handheld (4)',
    'BURRITO': 'Wrapped tortilla cylinder (7)',
    'PASTA': 'Italian noodles of many shapes (5)',
    'CURRY': 'Spiced stew; Indian classic (5)',
    'CHOCOLATE': 'Cacao-based treat (9)',
    'BAGEL': 'Boiled-then-baked breakfast ring (5)',
    'CHEESE': 'Milk turned delicious (6)',
    'WAFFLE': 'Grid-pattern breakfast favorite (6)',
    'AVOCADO': 'Green fruit beloved on toast (7)',
    'NOODLES': 'Ramen or udon, for instance (7)',
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
  static const _saveDifficulty = 'cw3_diff';
  static const _saveCategory = 'cw3_cat';
  static const _saveGrid = 'cw3_grid';
  static const _saveUser = 'cw3_user';
  static const _saveSize = 'cw3_size';
  static const _saveStart = 'cw3_start';

  final rnd = Random();

  _Difficulty difficulty = _Difficulty.easy;
  _Category category = _Category.popculture;

  late int n;
  late List<List<String?>> _solution; // null = block; else single letter
  late List<List<String?>> _cells; // null = block; "" or "A"
  late DateTime _startTime;

  late List<List<int?>> _numbers;
  late Map<int, String> _cluesAcross;
  late Map<int, String> _cluesDown;

  @override
  void initState() {
    super.initState();
    _restoreOrNew();
  }

  /* ─────────── generator ─────────── */

  void _buildPuzzle() {
    n = switch (difficulty) {
      _Difficulty.easy => 7,
      _Difficulty.medium => 9,
      _Difficulty.hard => 11,
    };

    final bank = List<String>.from(_wordBank[category]!);
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
    _cells = List.generate(n, (r) => List.generate(n, (c) => _solution[r][c] == null ? null : ''));
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
    final catClues = _clueBank[category]!;

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
            across[num] = catClues[word] ?? '${_categoryLabel(category)} item (${
                word.length})';
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
            down[num] = catClues[word] ?? '${_categoryLabel(category)} item (${
                word.length})';
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
    final p = await SharedPreferences.getInstance();
    await p.setInt(_saveSize, n);
    await p.setInt(_saveDifficulty, difficulty.index);
    await p.setInt(_saveCategory, category.index);
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
  }

  Future<void> _clearPersisted() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_saveSize);
    await p.remove(_saveDifficulty);
    await p.remove(_saveCategory);
    await p.remove(_saveGrid);
    await p.remove(_saveUser);
    await p.remove(_saveStart);
  }

  Future<void> _restoreOrNew() async {
    final p = await SharedPreferences.getInstance();
    final savedN = p.getInt(_saveSize);
    final dIdx = p.getInt(_saveDifficulty);
    final cIdx = p.getInt(_saveCategory);
    final flatGrid = p.getStringList(_saveGrid);
    final flatUser = p.getStringList(_saveUser);
    final start = p.getInt(_saveStart);

    if (savedN != null && dIdx != null && cIdx != null && flatGrid != null && flatUser != null) {
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
        setState(() {});
        return;
      } catch (_) {
        // fall back to new
      }
    }
    _newPuzzle();
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
    final topBar = LayoutBuilder(
      builder: (context, cons) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _ink),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Difficulty:', style: TextStyle(fontWeight: FontWeight.w800)),
              DropdownButton<_Difficulty>(
                value: difficulty,
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
              const SizedBox(width: 4),
              const Text('Category:', style: TextStyle(fontWeight: FontWeight.w800)),
              DropdownButton<_Category>(
                value: category,
                items: _Category.values
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(_categoryLabel(c))))
                    .toList(),
                onChanged: (c) {
                  if (c == null) return;
                  setState(() => category = c);
                  _newPuzzle();
                },
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _hint,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: const Text('Hint'),
              ),
              OutlinedButton.icon(
                onPressed: _resetPuzzle,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
              ),
              OutlinedButton.icon(
                onPressed: _newPuzzle,
                icon: const Icon(Icons.fiber_new_rounded, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
        );
      },
    );

    return _GameScaffold(
      title: 'Crossword',
      rule:
          'Choose a category and fill the grid. Use Hint if you’re stuck. Higher difficulty uses larger grids.',
      topBar: topBar,
      child: Column(
        children: [
          // GRID
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: n,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: n * n,
                itemBuilder: (_, i) {
                  final r = i ~/ n, c = i % n;
                  if (_solution[r][c] == null) {
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
                                title: Text(high
                                    ? 'New High Score!'
                                    : 'Crossword complete'),
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
                          filled: true,
                          fillColor:
                              ok ? const Color(0xFFA7E0C9) : Colors.white,
                          contentPadding:
                              const EdgeInsets.only(top: 14), // space for number
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
          // CLUES
          Container(
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
    final entries = clues.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (entries.isEmpty) const Text('—'),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${e.key}. ${e.value}'),
          ),
        ),
      ],
    );
  }
}
