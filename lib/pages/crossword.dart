// lib/pages/crossword.dart
//
// Crossword with category chooser (shows first), default Easy difficulty,
// descriptive clues, bigger grid / smaller keyboard, spaced keys,
// small themed hint bar, and Back button that returns to Stress Busters.
//
// Adds:
// - Animated/interactive category cards
// - Removed chooser description line
// - Back button styled to match app theme
// - Clear, specific clue definitions
// - Up to 3 hints per game (reveal one correct letter each time)
// - Simple scoring (letters*10 - 15 per hint), with best score persisted
//
// No external assets required.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:new_rezonate/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

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

/* ───────────────── Word + Clue banks (concise & specific) ───────────────── */

final Map<_Category, Map<String, String>> _clueBank = {
  _Category.animals: {
    'LION': 'Maned big cat that lives in prides',
    'TIGER': 'Largest striped cat native to Asia',
    'EAGLE': 'Raptor known for exceptional eyesight',
    'DOLPHIN': 'Social marine mammal that echolocates',
    'PANDA': 'Bear that eats mostly bamboo',
    'KOALA': 'Australian tree-dweller that eats eucalyptus leaves',
    'GIRAFFE': 'Tall hoofed mammal with a very long neck',
    'ZEBRA': 'Equid with black-and-white stripes',
    'OTTER': 'Playful swimmer that cracks shells on rocks',
    'CHEETAH': 'Fastest land animal; spotted sprinter',
  },
  _Category.history: {
    'CAESAR': 'Roman general who crossed the Rubicon',
    'PYRAMID': 'Ancient Egyptian royal tomb with sloped sides',
    'EMPIRE': 'State ruled by an emperor over several peoples',
    'PHARAOH': 'Ruler of ancient Egypt viewed as divine',
    'VIKING': 'Norse seafarer famed for raids and longships',
    'TREATY': 'Formal written agreement between states',
    'REPUBLIC': 'Government with power vested in elected reps',
    'REVOLT': 'Organized uprising against authority',
    'BYZANTINE': 'Eastern Roman Empire centered on Constantinople',
    'ARMADA': 'Spanish fleet defeated by England in 1588',
  },
  _Category.literature: {
    'ODYSSEY': 'Epic of Odysseus’s long voyage home',
    'HAMLET': 'Tragedy of the hesitant Danish prince',
    'GATSBY': 'Jazz Age novel about reinvention and longing',
    'DUNE': 'Sci-fi saga set on Arrakis',
    'NARNIA': 'Fantasy realm entered through a wardrobe',
    'HOBBIT': 'Bilbo’s adventure preceding the Ring quest',
    'ORWELL': 'Author of “1984” and “Animal Farm”',
    'AUSTEN': 'Novelist of wit who wrote “Pride and Prejudice”',
    'POE': 'American master of the macabre and detection',
    'ILIAD': 'Epic focused on Achilles and Troy',
  },
  _Category.popculture: {
    'MARIO': 'Nintendo hero who rescues Princess Peach',
    'POKEMON': 'Series where trainers catch and evolve creatures',
    'BATMAN': 'Gotham vigilante, the Dark Knight',
    'MARVEL': 'Studio behind the Avengers movies',
    'NETFLIX': 'Subscription streaming service for films and shows',
    'TIKTOK': 'Short-video app with a “For You” feed',
    'EMOJI': 'Small pictograph that adds tone to messages',
    'ZELDA': 'Series where Link seeks the Triforce',
    'PODCAST': 'On-demand audio series released in episodes',
    'HASHTAG': 'Clickable topic starting with the # symbol',
  },
  _Category.science: {
    'GRAVITY': 'Attractive force that shapes orbits',
    'ATOM': 'Smallest unit of an element with a nucleus',
    'NEURON': 'Nerve cell that conducts impulses',
    'QUANTUM': 'Physics of discrete energy levels',
    'VACCINE': 'Preparation that trains the immune system',
    'LASER': 'Device producing coherent light',
    'PHOTON': 'Quantum packet of light',
    'ENZYME': 'Protein catalyst for biochemical reactions',
    'ORBIT': 'Curved path around a larger body',
    'SPECIES': 'Group able to interbreed and produce fertile young',
  },
  _Category.geography: {
    'EVEREST': 'Highest peak on the Nepal–Tibet border',
    'SAHARA': 'Vast desert spanning North Africa',
    'AMAZON': 'Immense South American river and rainforest',
    'ANDES': 'Long range along South America’s west',
    'NILE': 'Major African river flowing north',
    'ALPS': 'European range with Mont Blanc and Matterhorn',
    'PACIFIC': 'Largest and deepest ocean',
    'DELTA': 'Fan-shaped river mouth built by silt',
    'ISLAND': 'Land completely surrounded by water',
    'VOLCANO': 'Mountain that erupts lava and ash',
  },
  _Category.movies: {
    'INCEPTION': 'Dream-heist thriller by Christopher Nolan',
    'TITANIC': '1997 romance set on an ocean liner',
    'MATRIX': 'Cyberpunk story of simulated reality',
    'ROCKY': 'Philadelphia underdog boxer',
    'ALIEN': 'Spaceship horror featuring a xenomorph',
    'JAWS': 'Great white shark terrorizes Amity Island',
    'JOKER': 'Origin story of a Gotham villain',
    'PARASITE': 'Korean class satire, Best Picture winner',
    'AMELIE': 'Whimsical Paris romance',
    'AVENGERS': 'Earth’s heroes unite to fight Thanos',
  },
  _Category.music: {
    'BEATLES': 'Liverpool band nicknamed the Fab Four',
    'MOZART': 'Prolific composer of symphonies and operas',
    'JAZZ': 'Improvisation-rich style with swing and blue notes',
    'BLUES': 'Form that shaped rock and soul',
    'OPERA': 'Drama conveyed entirely in music',
    'GUITAR': 'Six-string fretted instrument',
    'PIANO': 'Keyboard with hammers and pedals',
    'CONCERT': 'Public musical performance',
    'CHOPIN': 'Composer famed for piano nocturnes',
    'REGGAE': 'Jamaican style with off-beat rhythm',
  },
  _Category.sports: {
    'SOCCER': 'Global game played on a pitch',
    'TENNIS': 'Racquet sport scored in sets',
    'CRICKET': 'Bat-and-ball game with wickets',
    'BASEBALL': 'Diamond sport with home runs',
    'HOCKEY': 'Ice sport with sticks and a puck',
    'RUGBY': 'Scrum-heavy oval-ball game',
    'OLYMPICS': 'International multi-sport event',
    'MARATHON': '26.2-mile road race',
    'ESPORTS': 'Organized competitive gaming',
    'GOLF': 'Club-and-ball game aiming for par',
  },
  _Category.food: {
    'PIZZA': 'Neapolitan classic with sauce and cheese',
    'SUSHI': 'Japanese vinegared rice with seafood',
    'TACO': 'Folded tortilla filled with meats or veggies',
    'PASTA': 'Italian noodles served with sauce',
    'CURRY': 'Spiced stew with regional varieties',
    'BAGEL': 'Boiled-then-baked bread ring',
    'CHEESE': 'Curds pressed into countless styles',
    'WAFFLE': 'Grid-pattern batter cake',
    'NOODLES': 'Long strands served in soups or stir-fries',
    'BROWNIE': 'Fudgy chocolate bar from a pan',
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

/* ───────────────── Score store (local) ───────────────── */

class _CWScoreStore {
  static const _listKey = 'sbp_crossword';
  static const _bestKey = 'sbp_best_crossword';

  static Future<void> add(int score) async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getStringList(_listKey) ?? <String>[];
    cur.add(score.toString());
    await p.setStringList(_listKey, cur);
  }

  static Future<void> reportBest(int score) async {
    final p = await SharedPreferences.getInstance();
    final prev = p.getInt(_bestKey) ?? 0;
    if (score > prev) {
      await p.setInt(_bestKey, score);
    }
  }
}

/* ───────────────── Game model ───────────────── */

class _Run {
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
  List<_Run> _runs = [];
  int _activeRunIndex = 0;
  int _cursorR = 0, _cursorC = 0;

  // hints & scoring
  int _hintsLeft = 3;

  Map<String, String> get _clues => switch (_category) {
        _Category.mixed || null => _mixedClues,
        _ => _clueBank[_category]!,
      };

  int _sizeFor(_Difficulty d) => switch (d) {
        _Difficulty.easy => 7,
        _Difficulty.medium => 9,
        _Difficulty.hard => 11,
      };

  /* ─────────── Build puzzle ─────────── */

  void _buildPuzzle() {
    n = _sizeFor(_difficulty);

    var pool = _clues.keys.where((w) => w.length <= n).toList();
    pool.shuffle(rnd);

    final grid = List.generate(n, (_) => List<String?>.filled(n, null));

    // Place horizontal runs staggered to create crossings.
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

    // Add vertical overlaps for crossings.
    for (int t = 0; t < n; t++) {
      final c = rnd.nextInt(n);
      for (int rr = 0; rr < n - 2; rr++) {
        if (grid[rr][c] != null && grid[rr + 1][c] == null) {
          grid[rr + 1][c] = grid[rr][c];
        }
      }
    }

    _solution = List.generate(n, (r) => List.generate(n, (c) => grid[r][c]));
    _cells = List.generate(n, (_) => List.generate(n, (_) => ''));
    _numbers = _computeNumbers(_solution);
    _runs = _computeRuns(_solution, _numbers);

    if (_runs.isNotEmpty) {
      _activeRunIndex = 0;
      _cursorR = _runs[0].r;
      _cursorC = _runs[0].c;
    } else {
      _activeRunIndex = 0;
      _cursorR = 0;
      _cursorC = 0;
    }

    _hintsLeft = 3;
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

    for (int r = 0; r < n; r++) {
      int c = 0;
      while (c < n) {
        if (sol[r][c] != null && (c == 0 || sol[r][c - 1] == null)) {
          int cc = c, len = 0;
          while (cc < n && sol[r][cc] != null) {
            len++; cc++;
          }
          if (len >= 2) list.add(_Run(numbers[r][c]!, true, r, c, len));
          c = cc;
        } else {
          c++;
        }
      }
    }
    for (int c = 0; c < n; c++) {
      int r = 0;
      while (r < n) {
        if (sol[r][c] != null && (r == 0 || sol[r - 1][c] == null)) {
          int rr = r, len = 0;
          while (rr < n && sol[rr][c] != null) {
            len++; rr++;
          }
          if (len >= 2) list.add(_Run(numbers[r][c]!, false, r, c, len));
          r = rr;
        } else {
          r++;
        }
      }
    }

    list.sort((a, b) {
      final d = a.number.compareTo(b.number);
      if (d != 0) return d;
      return (a.across ? 0 : 1) - (b.across ? 0 : 1);
    });
    return list;
  }

  /* ─────────── Input handling ─────────── */

  _Run get _run => _runs[_activeRunIndex];

  void _selectCell(int r, int c) {
    final sameDir = _runs.indexWhere((ru) => ru.across == _run.across && ru.contains(r, c));
    final any = _runs.indexWhere((ru) => ru.contains(r, c));
    _activeRunIndex = (sameDir >= 0) ? sameDir : (any >= 0 ? any : _activeRunIndex);
    _cursorR = r;
    _cursorC = c;
    setState(() {});
  }

  void _moveCursor(int delta) {
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
    _moveCursor(1);
    _maybeFinish();
  }

  /* ─────────── Hints & scoring ─────────── */

  void _useHint() {
    if (_hintsLeft <= 0) return;

    // choose a random empty, valid cell anywhere
    final candidates = <(int, int)>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_solution[r][c] != null && _cells[r][c].isEmpty) {
          candidates.add((r, c));
        }
      }
    }
    if (candidates.isEmpty) return;

    final pick = candidates[rnd.nextInt(candidates.length)];
    final r = pick.$1, c = pick.$2;
    _cells[r][c] = _solution[r][c]!;
    _hintsLeft -= 1;
    _cursorR = r;
    _cursorC = c;
    setState(() {});
    _maybeFinish();
  }

  bool _isSolved() {
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final sol = _solution[r][c];
        if (sol == null) continue;
        if (_cells[r][c] != sol) return false;
      }
    }
    return true;
  }

  int _computeScore() {
    int letters = 0;
    for (final row in _solution) {
      for (final ch in row) {
        if (ch != null) letters++;
      }
    }
    final raw = letters * 10 - (15 * (3 - _hintsLeft)); // 15-point penalty per used hint
    return max(0, raw);
  }

  Future<void> _maybeFinish() async {
    if (!_isSolved()) return;
    final score = _computeScore();
    await _CWScoreStore.add(score);
    await _CWScoreStore.reportBest(score);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Puzzle Complete!'),
        content: Text('Score: $score\nHints used: ${3 - _hintsLeft}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _buildPuzzle();
  }

  /* ─────────── Clue text (no length parentheses) ─────────── */

  String _activeClue() {
    final ru = _run;
    final letters = <String>[];
    for (int i = 0; i < ru.len; i++) {
      final rr = ru.across ? ru.r : ru.r + i;
      final cc = ru.across ? ru.c + i : ru.c;
      letters.add(_solution[rr][cc] ?? '');
    }
    final word = letters.join();
    final base = ru.across ? '${ru.number}a' : '${ru.number}d';
    final clueText = _clues[word] ?? '${_categoryLabel(_category!)} word';
    return '$base. $clueText';
  }

  /* ─────────── UI: chooser ─────────── */

  Widget _buildChooser() {
    _difficulty = _Difficulty.easy;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _ink),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: _themeGreen),
              ),
            ),
          ),
        ),
      ),
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
                const SizedBox(height: 12),
                // Description line removed per request
                Expanded(
                  child: GridView.count(
                    physics: const BouncingScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    children: _Category.values.map((c) {
                      return _AnimatedCategoryCard(
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
                    ? const Color(0xFFA7E0C9)
                    : (inActive ? Colors.white : Colors.white.withOpacity(.96)),
                border: Border.all(color: Colors.black54, width: 1),
              ),
              child: Stack(
                children: [
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

  /* ─────────── UI: gameplay ─────────── */

  Widget _buildGame() {
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: (_hintsLeft > 0) ? _useHint : null,
            icon: const Icon(Icons.tips_and_updates_rounded, size: 16),
            label: Text('Hint (${_hintsLeft})'),
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
    if (_category == null) return _buildChooser();
    if (_solution.isEmpty || _runs.isEmpty) {
      _buildPuzzle();
    }
    return _buildGame();
  }

  @override
  void initState() {
    super.initState();
    n = _sizeFor(_difficulty);
    _solution = List.generate(n, (_) => List<String?>.filled(n, null));
    _cells = List.generate(n, (_) => List<String>.filled(n, ''));
    _numbers = List.generate(n, (_) => List<int?>.filled(n, null));
    _runs = [];
  }
}

/* ───────────────── Small widgets ───────────────── */

class _AnimatedCategoryCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AnimatedCategoryCard({required this.icon, required this.label, required this.onTap});

  @override
  State<_AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<_AnimatedCategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  bool _hover = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween(begin: 1.0, end: 1.04).animate(_c);
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        _c.forward();
      },
      onExit: (_) {
        setState(() => _hover = false);
        _c.reverse();
      },
      child: AnimatedScale(
        scale: scale.value,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hover
                    ? const [Color(0xFFE9FFF4), Color(0xFFC9F2E7)]
                    : const [Colors.white, Colors.white],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _ink),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 40, color: _themeGreen),
                const SizedBox(height: 10),
                Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
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
  final String? label;
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
