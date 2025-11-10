// lib/pages/crossword.dart
//
// Crossword with category chooser (first), default Easy difficulty,
// descriptive clues, bigger grid / smaller keyboard, spaced keys,
// small themed hint bar, and no overflow. Fully self-contained.
// No external assets required.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;

/* ───────────────── Theme helpers ───────────────── */

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

const _themeGreen = Color(0xFF0D7C66);
const _ink = Colors.black;

/* ───────────────── Category / Difficulty ───────────────── */

enum _Difficulty { easy, medium, hard }

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

/* ───────────────── Word + Clue banks (descriptive) ───────────────── */

final Map<_Category, Map<String, String>> _clueBank = {
  _Category.animals: {
    'LION': '“King of the jungle” (4) — pride leader',
    'TIGER': 'Striped big cat of Asia (5)',
    'EAGLE': 'U.S. national bird (5)',
    'DOLPHIN': 'Clever marine mammal (7)',
    'PANDA': 'Bamboo-munching bear (5)',
    'KOALA': 'Eucalyptus snacker (5) — not a bear',
    'GIRAFFE': 'Tallest land animal (7)',
    'ZEBRA': 'Striped grazer (5)',
    'OTTER': 'Playful river mammal (5)',
    'CHEETAH': 'Fastest sprinter (7)',
  },
  _Category.history: {
    'CAESAR': 'Julius ___, Roman statesman (6)',
    'PYRAMID': 'Ancient tomb of Egypt (7)',
    'EMPIRE': 'Realm of an emperor (6)',
    'PHARAOH': 'Egyptian ruler title (7)',
    'VIKING': 'Norse seafarer (6)',
    'TREATY': 'Formal pact (6)',
    'REPUBLIC': 'State without a monarch (8)',
    'REVOLT': 'Uprising (6)',
    'BYZANTINE': 'Eastern Roman culture (9)',
    'ARMADA': 'Spanish fleet (6)',
  },
  _Category.literature: {
    'ODYSSEY': 'Homer’s voyage home (7)',
    'HAMLET': 'Prince of Denmark (6)',
    'GATSBY': 'Jazz-Age dreamer (6)',
    'DUNE': 'Arrakis saga (4)',
    'NARNIA': 'Wardrobe world (6)',
    'HOBBIT': 'Bilbo’s tale (6)',
    'ORWELL': 'Author of “1984” (6)',
    'AUSTEN': '“Pride and Prejudice” author (6)',
    'POE': 'Master of the macabre (3)',
    'ILIAD': 'Wrath of Achilles (5)',
  },
  _Category.popculture: {
    'MARIO': 'Nintendo plumber (5)',
    'POKEMON': 'Catch ’em all (7)',
    'BATMAN': 'Dark Knight (6)',
    'MARVEL': 'Avengers studio (6)',
    'NETFLIX': 'Red-N streamer (7)',
    'TIKTOK': 'Short video app (6)',
    'EMOJI': 'Tiny pictograph (5)',
    'ZELDA': 'Link’s adventures (5)',
    'PODCAST': 'On-demand audio (7)',
    'HASHTAG': 'Tagged phrase (7)',
  },
  _Category.science: {
    'GRAVITY': 'Keeps planets in orbit (7)',
    'ATOM': 'Basic unit of matter (4)',
    'NEURON': 'Nerve cell (6)',
    'QUANTUM': 'Realm of the tiny (7)',
    'VACCINE': 'Primes immunity (7)',
    'LASER': 'Coherent light (5)',
    'PHOTON': 'Light quantum (6)',
    'ENZYME': 'Biological catalyst (6)',
    'ORBIT': 'Curved path (5)',
    'SPECIES': 'Taxonomic group (7)',
  },
  _Category.geography: {
    'EVEREST': 'Highest mountain (7)',
    'SAHARA': 'Vast desert (6)',
    'AMAZON': 'Rainforest & river (6)',
    'ANDES': 'Long S. American range (5)',
    'NILE': 'River flowing north (4)',
    'ALPS': 'European range (4)',
    'PACIFIC': 'Largest ocean (7)',
    'DELTA': 'River-mouth fan (5)',
    'ISLAND': 'Land in water (6)',
    'VOLCANO': 'Eruptive mountain (7)',
  },
  _Category.movies: {
    'INCEPTION': 'Nolan dream-heist (9)',
    'TITANIC': '1997 ocean tragedy (7)',
    'MATRIX': 'Red pill, blue pill (6)',
    'ROCKY': 'Philly boxer (5)',
    'ALIEN': 'Xenomorph horror (5)',
    'JAWS': 'Shark thriller (4)',
    'JOKER': 'Gotham antihero (5)',
    'PARASITE': 'Class satire (8)',
    'AMELIE': 'Whimsical Paris romance (6)',
    'AVENGERS': 'Earth’s heroes unite (8)',
  },
  _Category.music: {
    'BEATLES': 'Liverpool legends (7)',
    'MOZART': 'Salzburg prodigy (6)',
    'JAZZ': 'Improvised art form (4)',
    'BLUES': 'Roots genre (5)',
    'OPERA': 'Sung drama (5)',
    'GUITAR': 'Six-string staple (6)',
    'PIANO': 'Hammered keys (5)',
    'CONCERT': 'Live performance (7)',
    'CHOPIN': 'Poet of the piano (6)',
    'REGGAE': 'Jamaican groove (6)',
  },
  _Category.sports: {
    'SOCCER': 'World game (6)',
    'TENNIS': 'Racquet sport (6)',
    'CRICKET': 'Bat & wickets (7)',
    'BASEBALL': 'Diamond pastime (8)',
    'HOCKEY': 'Ice sport (6)',
    'RUGBY': 'Scrums & tries (5)',
    'OLYMPICS': 'Global games (8)',
    'MARATHON': '26.2-mile race (8)',
    'ESPORTS': 'Competitive gaming (7)',
    'GOLF': 'Greens & birdies (4)',
  },
  _Category.food: {
    'PIZZA': 'Neapolitan classic (5)',
    'SUSHI': 'Rice + fish (5)',
    'TACO': 'Folded tortilla (4)',
    'PASTA': 'Italian noodles (5)',
    'CURRY': 'Spiced stew (5)',
    'BAGEL': 'Boiled then baked ring (5)',
    'CHEESE': 'Milk made solid (6)',
    'WAFFLE': 'Grid breakfast (6)',
    'NOODLES': 'Ramen or udon (7)',
    'BROWNIE': 'Fudgy square (7)',
  },
};

// Mixed = union of all others.
Map<String, String> get _mixedClues {
  final out = <String, String>{};
  _clueBank.forEach((_Category k, v) {
    if (k == _Category.mixed) return;
    out.addAll(v);
  });
  return out;
}

/* ───────────────── Game model ───────────────── */

class _Run {
  // consecutive non-block cells
  final int number; // clue number
  final bool across; // true: across; false: down
  final int r, c, len;
  _Run(this.number, this.across, this.r, this.c, this.len);
  bool contains(int rr, int cc) =>
      across ? (rr == r && cc >= c && cc < c + len) : (cc == c && rr >= r && rr < r + len);
}

/* ───────────────── Page ───────────────── */

class CrosswordPage extends StatefulWidget {
  const CrosswordPage({super.key});
  @override
  State<CrosswordPage> createState() => _CrosswordPageState();
}

class _CrosswordPageState extends State<CrosswordPage> {
  final rnd = Random();

  // chooser -> then game. Start at chooser (category null).
  _Category? _category;
  _Difficulty _difficulty = _Difficulty.easy;

  // grid
  late int n;
  late List<List<String?>> _solution; // null => block; else single letter
  late List<List<String>> _cells; // "" for empty, "A" for typed
  late List<List<int?>> _numbers;
  List<_Run> _runs = []; // initialize empty to avoid LateInitializationError
  int _activeRunIndex = 0;
  int _cursorR = 0, _cursorC = 0;

  // ————— Utilities
  Map<String, String> get _clues => switch (_category) {
        _Category.mixed || null => _mixedClues,
        _ => _clueBank[_category]!,
      };

  int _sizeFor(_Difficulty d) => switch (d) {
        _Difficulty.easy => 7,
        _Difficulty.medium => 9,
        _Difficulty.hard => 11,
      };

  /* ─────────── Build puzzle (simple compact generator) ─────────── */

  void _buildPuzzle() {
    n = _sizeFor(_difficulty);

    // pool of words for this category; make sure all are <= n
    var pool = _clues.keys.where((w) => w.length <= n).toList();
    pool.shuffle(rnd);

    // start with empty (null) = block
    final grid = List.generate(n, (_) => List<String?>.filled(n, null));

    // place across seed words on alternating rows, offset to create crossings
    final offset = (n == 11) ? 3 : 2;
    int r = 0;
    int placed = 0;
    while (r < n && placed < pool.length) {
      final w = pool[placed];
      final start = (r.isOdd) ? offset : 0;
      if (w.length <= n - start) {
        for (int i = 0; i < w.length; i++) {
          grid[r][start + i] = w[i];
        }
      }
      placed++;
      r++;
    }

    // encourage some vertical runs by copying letters downward occasionally
    for (int t = 0; t < n; t++) {
      final c = rnd.nextInt(n);
      for (int rr = 0; rr < n - 2; rr++) {
        if (grid[rr][c] != null && grid[rr + 1][c] == null) {
          grid[rr + 1][c] = grid[rr][c];
        }
      }
    }

    // convert to solution/cell matrices
    _solution = List.generate(
      n,
      (r) => List.generate(n, (c) => grid[r][c]),
    );
    _cells = List.generate(n, (_) => List.generate(n, (_) => ''));

    _numbers = _computeNumbers(_solution);
    _runs = _computeRuns(_solution, _numbers);
    // place cursor at first run
    if (_runs.isEmpty) {
      // fallback: at least one cell
      _cursorR = 0;
      _cursorC = 0;
      _activeRunIndex = 0;
    } else {
      _activeRunIndex = 0;
      _cursorR = _runs[0].r;
      _cursorC = _runs[0].c;
    }

    setState(() {});
  }

  List<List<int?>> _computeNumbers(List<List<String?>> sol) {
    final nums = List.generate(n, (_) => List<int?>.filled(n, null));
    int counter = 0;
    bool startAcross(int r, int c) =>
        sol[r][c] != null &&
        (c == 0 || sol[r][c - 1] == null) &&
        (c + 1 < n && sol[r][c + 1] != null);
    bool startDown(int r, int c) =>
        sol[r][c] != null &&
        (r == 0 || sol[r - 1][c] == null) &&
        (r + 1 < n && sol[r + 1][c] != null);

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (sol[r][c] == null) continue;
        if (startAcross(r, c) || startDown(r, c)) {
          nums[r][c] = ++counter;
        }
      }
    }
    return nums;
  }

  List<_Run> _computeRuns(List<List<String?>> sol, List<List<int?>> numbers) {
    final list = <_Run>[];

    // across
    for (int r = 0; r < n; r++) {
      int c = 0;
      while (c < n) {
        if (sol[r][c] != null && (c == 0 || sol[r][c - 1] == null)) {
          int cc = c;
          int len = 0;
          while (cc < n && sol[r][cc] != null) {
            len++;
            cc++;
          }
          if (len >= 2) {
            list.add(_Run(numbers[r][c]!, true, r, c, len));
          }
          c = cc;
        } else {
          c++;
        }
      }
    }
    // down
    for (int c = 0; c < n; c++) {
      int r = 0;
      while (r < n) {
        if (sol[r][c] != null && (r == 0 || sol[r - 1][c] == null)) {
          int rr = r;
          int len = 0;
          while (rr < n && sol[rr][c] != null) {
            len++;
            rr++;
          }
          if (len >= 2) {
            list.add(_Run(numbers[r][c]!, false, r, c, len));
          }
          r = rr;
        } else {
          r++;
        }
      }
    }

    // order by clue number then across before down for same start
    list.sort((a, b) {
      final d = a.number.compareTo(b.number);
      if (d != 0) return d;
      // prefer across first like standard crosswords
      return (a.across ? 0 : 1) - (b.across ? 0 : 1);
    });
    return list;
  }

  /* ─────────── Input handling ─────────── */

  _Run get _run => _runs[_activeRunIndex];

  void _selectCell(int r, int c) {
    // try to pick the run that contains the cell and matches current direction;
    // otherwise pick any run containing it.
    final sameDir = _runs.indexWhere((ru) => ru.across == _run.across && ru.contains(r, c));
    final any = _runs.indexWhere((ru) => ru.contains(r, c));
    _activeRunIndex = (sameDir >= 0) ? sameDir : (any >= 0 ? any : _activeRunIndex);
    _cursorR = r;
    _cursorC = c;
    setState(() {});
  }

  void _moveCursor(int delta) {
    // delta = ±1 along active run
    final r = _run.r, c = _run.c, len = _run.len;
    if (_run.across) {
      int idx = (_cursorC - c) + delta;
      idx = idx.clamp(0, len - 1);
      _cursorC = c + idx;
    } else {
      int idx = (_cursorR - r) + delta;
      idx = idx.clamp(0, len - 1);
      _cursorR = r + idx;
    }
    setState(() {});
  }

  void _nextRun(int dir) {
    // dir = +1 next, -1 prev
    if (_runs.isEmpty) return;
    _activeRunIndex = (_activeRunIndex + dir) % _runs.length;
    if (_activeRunIndex < 0) _activeRunIndex += _runs.length;
    final ru = _runs[_activeRunIndex];
    _cursorR = ru.r;
    _cursorC = ru.c;
    setState(() {});
  }

  void _onKey(String label) {
    if (_runs.isEmpty) return;
    if (label == '⌫') {
      if (_solution[_cursorR][_cursorC] != null) {
        _cells[_cursorR][_cursorC] = '';
      }
      _moveCursor(-1);
      return;
    }
    if (!RegExp(r'^[A-Za-z]$').hasMatch(label)) return;
    final ch = label.toUpperCase();
    if (_solution[_cursorR][_cursorC] != null) {
      _cells[_cursorR][_cursorC] = ch;
    }
    // move forward
    _moveCursor(1);
  }

  /* ─────────── Clue text for active run ─────────── */

  String _activeClue() {
    final ru = _run;
    // build word string from solution for lookup
    final letters = <String>[];
    for (int i = 0; i < ru.len; i++) {
      final rr = ru.across ? ru.r : ru.r + i;
      final cc = ru.across ? ru.c + i : ru.c;
      letters.add(_solution[rr][cc] ?? '');
    }
    final word = letters.join();
    final base = ru.across ? '${ru.number}a' : '${ru.number}d';
    final clueText = _clues[word] ?? '${_categoryLabel(_category!)} word';
    return '$base. $clueText (${ru.len})';
  }

  /* ─────────── UI: chooser ─────────── */

  Widget _buildChooser() {
    // default to Easy
    _difficulty = _Difficulty.easy;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a Category',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Starts on Easy (7×7). You can change difficulty in-game.',
                    style: TextStyle(fontSize: 12.5)),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.count(
                    physics: const BouncingScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    children: _Category.values.map((c) {
                      return _CategoryCard(
                        icon: _categoryIcon(c),
                        label: _categoryLabel(c),
                        onTap: () {
                          setState(() {
                            _category = c;
                            _buildPuzzle();
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ─────────── UI: keyboard ─────────── */

  Widget _keyboard() {
    const rows = [
      ['Q','W','E','R','T','Y','U','I','O','P'],
      ['A','S','D','F','G','H','J','K','L'],
      ['Z','X','C','V','B','N','M'],
    ];

    // LayoutBuilder to compute key width so nothing overflows.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final maxRowLen = rows.map((r) => r.length).reduce(max);
        final baseKeyW = ((constraints.maxWidth - gap * (maxRowLen - 1)) / maxRowLen)
            .clamp(30.0, 50.0);
        final keyH = 44.0;
        final ctrlW = baseKeyW * 1.25;

        Widget buildRow(List<String> letters, {double indent = 0}) {
          return Padding(
            padding: EdgeInsets.only(left: indent),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: letters
                  .map((ch) => SizedBox(
                        width: baseKeyW,
                        height: keyH,
                        child: _KeyButton(label: ch, onTap: () => _onKey(ch)),
                      ))
                  .toList(),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildRow(rows[0]),
            const SizedBox(height: 6),
            buildRow(rows[1], indent: baseKeyW * .4),
            const SizedBox(height: 6),
            buildRow(rows[2], indent: baseKeyW * 1.3),
            const SizedBox(height: 8),
            // controls row: Backspace / Prev / Next
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: ctrlW,
                  height: keyH,
                  child: _KeyIconButton(
                    icon: Icons.backspace_rounded,
                    label: '⌫',
                    onTap: () => _onKey('⌫'),
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: ctrlW,
                  height: keyH,
                  child: _KeyIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _nextRun(-1),
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: ctrlW,
                  height: keyH,
                  child: _KeyIconButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => _nextRun(1),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /* ─────────── UI: grid ─────────── */

  Widget _grid() {
    // bigger grid, crisp borders, highlight active run + cursor
    return AspectRatio(
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
          final sol = _solution[r][c];
          if (sol == null) {
            return Container(color: Colors.black87);
          }
          final inActive = _run.contains(r, c);
          final isCursor = (r == _cursorR && c == _cursorC);

          return InkWell(
            onTap: () => _selectCell(r, c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: isCursor
                    ? const Color(0xFFA7E0C9) // cursor cell
                    : (inActive ? Colors.white : Colors.white.withOpacity(.96)),
                border: Border.all(color: Colors.black54, width: 1),
              ),
              child: Stack(
                children: [
                  // clue number
                  if (_numbers[r][c] != null)
                    Positioned(
                      left: 3,
                      top: 1.5,
                      child: Text(
                        '${_numbers[r][c]}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  // letter
                  Center(
                    child: Text(
                      (_cells[r][c].isEmpty) ? '' : _cells[r][c],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
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

  /* ─────────── UI: gameplay scaffold ─────────── */

  Widget _buildGame() {
    // small themed hint bar
    final hintBar = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4C4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3BC32)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: _themeGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _activeClue(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14, // smaller
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // difficulty switcher
          DropdownButton<_Difficulty>(
            value: _difficulty,
            underline: const SizedBox.shrink(),
            iconSize: 18,
            items: const [
              DropdownMenuItem(value: _Difficulty.easy, child: Text('Easy')),
              DropdownMenuItem(value: _Difficulty.medium, child: Text('Med')),
              DropdownMenuItem(value: _Difficulty.hard, child: Text('Hard')),
            ],
            onChanged: (d) {
              if (d == null) return;
              setState(() => _difficulty = d);
              _buildPuzzle();
            },
          ),
        ],
      ),
    );

    final topControls = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _category = null; // back to categories
            }),
            icon: const Icon(Icons.bubble_chart_rounded, size: 16),
            label: const Text('Categories'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _buildPuzzle(),
            icon: const Icon(Icons.fiber_new_rounded, size: 16),
            label: const Text('New'),
          ),
          const Spacer(),
          Chip(
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            avatar: Icon(_categoryIcon(_category!), size: 16),
            label: Text(_categoryLabel(_category!)),
          ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: Column(
            children: [
              topControls,
              hintBar,
              // Bigger grid, smaller keyboard (no overflow)
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _grid(),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _keyboard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ─────────── lifecycle ─────────── */

  @override
  Widget build(BuildContext context) {
    // Always go to category chooser first (default Easy).
    if (_category == null) return _buildChooser();
    // Ensure we have a built puzzle if someone hot-reloads on the game view.
    if (_solution.isEmpty || _runs.isEmpty) {
      _buildPuzzle();
    }
    return _buildGame();
  }

  @override
  void initState() {
    super.initState();
    // important: initialize matrices to avoid late errors before first build
    n = _sizeFor(_difficulty);
    _solution = List.generate(n, (_) => List<String?>.filled(n, null));
    _cells = List.generate(n, (_) => List<String>.filled(n, ''));
    _numbers = List.generate(n, (_) => List<int?>.filled(n, null));
    _runs = [];
  }
}

/* ───────────────── Small widgets ───────────────── */

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CategoryCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ink),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: _themeGreen),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _KeyButton({required this.label, required this.onTap});

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: .95).animate(_c),
      child: ElevatedButton(
        onPressed: () async {
          await _c.forward(from: 0);
          widget.onTap();
          _c.reverse();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE1F6F0),
          elevation: 1.5,
          shadowColor: Colors.black26,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _KeyIconButton extends StatelessWidget {
  final IconData icon;
  final String? label; // use either icon or label (for backspace symbol)
  final VoidCallback onTap;
  const _KeyIconButton({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE1F6F0),
        elevation: 1.5,
        shadowColor: Colors.black26,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Colors.black26),
      ),
      child: label != null
          ? Text(label!,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black))
          : Icon(icon, color: Colors.black, size: 18),
    );
  }
}
