// lib/pages/scramble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ───────────────── Shared look & scaffold ───────────────── */

BoxDecoration _bg(BuildContext context) {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFD7C3F1),
        Color(0xFF6FD6C1),
      ],
    ),
  );
}

const _ink = Colors.black;

class _GameScaffold extends StatelessWidget {
  final String title, rule;
  final Widget child;
  final Widget? topBar;
  final List<Widget>? actions; // right-side app bar actions

  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
    this.topBar,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: actions,
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
                if (topBar != null) ...[
                  const SizedBox(height: 12),
                  topBar!,
                ],
                const SizedBox(height: 12),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────── Score store ───────────────── */

class ScoreStore {
  ScoreStore._();
  static final instance = ScoreStore._();

  // store history as strings (robust to past versions), but coerce to INT
  Future<void> add(String key, num v) async {
    final p = await SharedPreferences.getInstance();
    final k = 'sbp_$key';
    final cur = p.getStringList(k) ?? [];
    final asInt = v.round().clamp(-2147483648, 2147483647);
    cur.add(asInt.toString());
    await p.setStringList(k, cur);
  }

  // keep best under a dedicated key; compare numerically; store as INT
  Future<bool> reportBest(String key, num score) async {
    final p = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$key';

    double prev = p.getDouble(bestKey) ?? double.negativeInfinity;
    final maybeInt = p.getInt(bestKey);
    if (maybeInt != null) prev = prev.isFinite ? max(prev, maybeInt.toDouble()) : maybeInt.toDouble();

    final next = score.round().toDouble();
    final beat = next > (prev.isFinite ? prev : double.negativeInfinity);

    if (beat) {
      await p.setDouble(bestKey, next);
      await p.setInt(bestKey, next.toInt());
      return true;
    }
    return false;
  }

  Future<List<int>> history(String key) async {
    final p = await SharedPreferences.getInstance();
    final k = 'sbp_$key';
    final raw = p.getStringList(k) ?? const [];
    final out = <int>[];
    for (final s in raw) {
      final n = int.tryParse(s) ?? double.tryParse(s)?.round();
      if (n != null) out.add(n);
    }
    return out;
  }
}

/* ───────────────── Game ───────────────── */

class ScramblePage extends StatefulWidget {
  const ScramblePage({super.key});
  @override
  State<ScramblePage> createState() => _ScramblePageState();
}

class _ScramblePageState extends State<ScramblePage>
    with SingleTickerProviderStateMixin {
  static const Map<String, List<String>> _categoryWords = {
    'Animals': [
      'CAT','DOG','LION','TIGER','BEAR','WOLF','FOX','DEER','HORSE','SHEEP',
      'GOAT','PIG','COW','ZEBRA','GIRAFFE','MONKEY','OTTER','SEAL','SHARK','DOLPHIN',
      'OWL','EAGLE','DUCK','RABBIT','MOOSE','LLAMA','PANDA','CAMEL','BUFFALO','RHINO',
    ],
    'Food & Drinks': [
      'PIZZA','PASTA','BURGER','SALAD','SUSHI','TACO','BAGEL','BREAD','BUTTER','CHEESE',
      'MILK','COFFEE','TEA','JUICE','WATER','ORANGE','APPLE','BANANA','GRAPES','PEACH',
      'PEAR','CHERRY','LEMON','LIME','ONION','GARLIC','PEPPER','CHILI','COOKIE','CAKE',
    ],
    'Nature & Weather': [
      'RIVER','LAKE','OCEAN','SEA','FOREST','DESERT','ISLAND','MOUNTAIN','VALLEY','CANYON',
      'GLACIER','MEADOW','PLAINS','PRAIRIE','SWAMP','JUNGLE','RAINFOREST','STORM','THUNDER','LIGHTNING',
      'RAIN','DRIZZLE','SNOW','HAIL','CLOUD','SUNSET','SUNRISE','BREEZE','WINTER','SUMMER',
    ],
    'Places & Travel': [
      'AIRPORT','STATION','HARBOR','PORT','BRIDGE','ROAD','HIGHWAY','TUNNEL','METRO','SUBWAY',
      'TRAIN','BUS','TAXI','HOTEL','HOSTEL','RESORT','MUSEUM','THEATER','LIBRARY','PARK',
      'STADIUM','MARKET','PLAZA','CASTLE','PALACE','TEMPLE','CHURCH','MOSQUE','SCHOOL','COLLEGE',
    ],
    'School & Tech': [
      'COMPUTER','LAPTOP','TABLET','PHONE','ROBOT','DRONE','SERVER','DATABASE','ALGORITHM','NETWORK',
      'SOFTWARE','HARDWARE','KEYBOARD','MONITOR','PRINTER','PROJECTOR','PYTHON','JAVASCRIPT','SWIFT','KOTLIN',
      'VARIABLE','FUNCTION','PACKAGE','MODULE','ROUTER','FIRMWARE','CHIPSET','PROCESSOR','INPUT','OUTPUT',
    ],
    'Sports & Fitness': [
      'SOCCER','FOOTBALL','BASKETBALL','BASEBALL','CRICKET','HOCKEY','TENNIS','GOLF','BOXING','WRESTLING',
      'RUNNING','SWIMMING','CYCLING','ROWING','SKIING','SURFING','SKATING','CLIMBING','YOGA','PILATES',
      'AEROBICS','MARATHON','SPRINT','TRIATHLON','JAVELIN','DISCUS','ARCHERY','TAEKWONDO','KARATE','RUGBY',
    ],
    'Arts & Music': [
      'MUSIC','MELODY','RHYTHM','HARMONY','ORCHESTRA','PIANO','VIOLIN','GUITAR','DRUMS','TRUMPET',
      'FLUTE','CLARINET','SAXOPHONE','PAINTING','SCULPTURE','DANCING','THEATRE','POETRY','NOVEL','STORY',
      'ACTOR','ARTIST','DESIGN','SKETCH','GRAPHIC','PHOTOGRAPHY','CINEMA','CAMERA','LYRICS','CHORUS',
    ],
    'Household Items': [
      'CHAIR','TABLE','SOFA','COUCH','BED','PILLOW','BLANKET','SHEET','MATTRESS','LAMP',
      'LIGHT','WINDOW','DOOR','CLOCK','WATCH','STOVE','OVEN','TOASTER','FRIDGE','FREEZER',
      'SINK','FAUCET','MIRROR','CURTAIN','RUG','CARPET','VACUUM','BROOM','BUCKET','TRASHCAN',
    ],
    'Colors & Fashion': [
      'RED','BLUE','GREEN','YELLOW','PURPLE','VIOLET','PINK','BROWN','BLACK','WHITE',
      'GRAY','SILVER','GOLD','BEIGE','INDIGO','TURQUOISE','TEAL','MAROON','NAVY','SCARF',
      'JACKET','SHIRT','PANTS','SKIRT','DRESS','SNEAKERS','BOOTS','HAT','GLOVES','BELT',
    ],
    'Emotions & Traits': [
      'HAPPY','SAD','ANGRY','CALM','BRAVE','KIND','HONEST','LOYAL','PROUD','RELAXED',
      'ANXIOUS','TIRED','ENERGETIC','FRIENDLY','HELPFUL','WISE','SMART','CREATIVE','FOCUSED','CONFIDENT',
      'MODEST','PATIENT','GRATEFUL','COURAGEOUS','GENEROUS','JOYFUL','PEACEFUL','SERENE','CURIOUS','HOPEFUL',
    ],
  };

  static final List<String> _allWords =
      _categoryWords.values.expand((e) => e).toList(growable: false);

  static final Map<String, String> _wordToCategory = () {
    final m = <String, String>{};
    _categoryWords.forEach((cat, words) {
      for (final w in words) {
        m[w] = cat;
      }
    });
    return m;
  }();

  final rnd = Random();

  // Leveling
  int _level = 1;
  int _wins = 0;

  String target = '';
  List<String> scrambled = const [];
  List<String> _answer = const [];
  final Set<int> _locked = {};

  late DateTime _start;

  // Per-box typing
  List<TextEditingController> _boxes = [];
  List<FocusNode> _boxFocus = [];

  // Animations
  late final AnimationController _shakeCtrl;
  int _animSeed = 0;

  // Hint
  bool _hintUsed = false;
  String? _hintPreview;

  // Category toggle
  bool _showCategory = false;

  // Wrong-guess word bank (for current round)
  final List<String> _wrongGuesses = [];

  bool _ready = true;
  bool _normalizing = false; // guard to avoid re-entrancy

  String get _categoryLabel => _wordToCategory[target] ?? 'General';

  // ── Scramble-only Best Score (for display chip like Uplingo)
  static const List<String> _scrambleBestKeys = [
    'sbp_best_scramble',
    'sb_best_scramble',
    'scramble_best',
    'best_scramble',
    'scBest',
  ];
  double _scrambleBest = 0.0;

  String _fmtScore(num v) {
    if (v.isNaN || v.isInfinite) return '0';
    return v.round().toString();
  }

  Future<double> _loadBestFromKeys(List<String> keys) async {
    final p = await SharedPreferences.getInstance();
    double best = 0.0;
    for (final k in keys) {
      final d = p.getDouble(k);
      if (d != null && d > best) {
        best = d;
        continue;
      }
      final i = p.getInt(k);
      if (i != null && i.toDouble() > best) {
        best = i.toDouble();
      }
    }
    return best;
  }

  Future<void> _loadScrambleBest() async {
    final v = await _loadBestFromKeys(_scrambleBestKeys);
    if (!mounted) return;
    setState(() => _scrambleBest = v);
  }

  // ── Result banner (Correct / Incorrect)
  String? _resultMsg;
  bool _resultOk = false;
  int _resultToken = 0;

  void _showResult(bool ok, String msg) {
    final token = DateTime.now().microsecondsSinceEpoch;
    _resultToken = token;
    setState(() {
      _resultOk = ok;
      _resultMsg = msg;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _resultToken != token) return;
      setState(() => _resultMsg = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _loadState().then((_) {
      _new();
      _loadScrambleBest(); // read Scramble’s own best for the top chip
    });
  }

  Future<void> _loadState() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _level = (p.getInt('scramble_level') ?? 1).clamp(1, 99999);
      _wins = (p.getInt('scramble_wins') ?? 0).clamp(0, 9999999);
    });
  }

  Future<void> _saveState() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('scramble_level', _level);
    await p.setInt('scramble_wins', _wins);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    for (final c in _boxes) {
      c.dispose();
    }
    for (final f in _boxFocus) {
      f.dispose();
    }
    super.dispose();
  }

  List<int> _lengthRangeForLevel(int level) {
    if (level <= 1) return [3, 5];
    if (level <= 3) return [4, 6];
    if (level <= 5) return [5, 7];
    if (level <= 7) return [6, 8];
    if (level <= 9) return [7, 9];
    if (level <= 12) return [8, 10];
    return [9, 12];
  }

  String _pickWord() {
    final range = _lengthRangeForLevel(_level);
    final minLen = range[0], maxLen = range[1];
    final pool = _allWords.where((w) => w.length >= minLen && w.length <= maxLen).toList();
    if (pool.isEmpty) return _allWords[rnd.nextInt(_allWords.length)];
    return pool[rnd.nextInt(pool.length)];
  }

  void _reshuffle() {
    if (scrambled.length <= 1) return;
    final before = scrambled.join();
    int tries = 0;
    do {
      scrambled = List<String>.from(scrambled)..shuffle(rnd);
      tries++;
    } while (scrambled.join() == before && tries < 10);
    setState(() => _animSeed++); // retrigger entrance animation
  }

  void _new() {
    final nextTarget = _pickWord();
    final nextScrambled = nextTarget.split('')..shuffle(rnd);

    if (nextScrambled.length > 1) {
      int tries = 0;
      while (nextScrambled.join() == nextTarget && tries < 20) {
        nextScrambled.shuffle(rnd);
        tries++;
      }
    }

    final newBoxes = List.generate(nextTarget.length, (_) => TextEditingController());
    final newFocus = List.generate(nextTarget.length, (_) => FocusNode());
    final newAnswer = List<String>.filled(nextTarget.length, '');

    final oldBoxes = _boxes;
    final oldFocus = _boxFocus;

    setState(() {
      target = nextTarget;
      scrambled = nextScrambled;
      _start = DateTime.now();
      _locked.clear();
      _hintUsed = false;
      _hintPreview = null;
      _wrongGuesses.clear();
      _animSeed = rnd.nextInt(1 << 30);
      _boxes = newBoxes;
      _boxFocus = newFocus;
      _answer = newAnswer;
      _ready = true;
      _resultMsg = null; // reset banner on new word
    });

    // Make sure old nodes are detached safely.
    for (final f in oldFocus) {
      try { f.unfocus(); } catch (_) {}
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldBoxes) {
        try { c.dispose(); } catch (_) {}
      }
      for (final f in oldFocus) {
        try { f.dispose(); } catch (_) {}
      }
    });
  }

  // If any list length drifts from target.length, fix it (next frame).
  void _normalizeControllerLengths() {
    if (_normalizing) return;
    final int len = target.length;
    if (_boxes.length == len && _boxFocus.length == len && _answer.length == len) return;

    _normalizing = true;

    final oldBoxes = _boxes;
    final oldFocus = _boxFocus;

    final newBoxes = List<TextEditingController>.generate(len, (i) {
      if (i < oldBoxes.length) return oldBoxes[i];
      return TextEditingController();
    });
    final newFocus = List<FocusNode>.generate(len, (i) {
      if (i < oldFocus.length) return oldFocus[i];
      return FocusNode();
    });
    final newAnswer = List<String>.generate(
      len,
      (i) => (i < _answer.length) ? _answer[i] : '',
    );

    // Unfocus anything we're about to drop.
    for (int i = len; i < oldFocus.length; i++) {
      try { oldFocus[i].unfocus(); } catch (_) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _boxes = newBoxes;
        _boxFocus = newFocus;
        _answer = newAnswer;
      });
      WidgetsBinding.instance.addPostFrameCallback((__) {
        for (int i = len; i < oldBoxes.length; i++) {
          try { oldBoxes[i].dispose(); } catch (_) {}
        }
        for (int i = len; i < oldFocus.length; i++) {
          try { oldFocus[i].dispose(); } catch (_) {}
        }
        _normalizing = false;
      });
    });
  }

  void _moveFocusToNext(int from) {
    for (int i = from + 1; i < target.length; i++) {
      if (!_locked.contains(i)) {
        _boxFocus[i].requestFocus();
        return;
      }
    }
    FocusScope.of(context).unfocus();
  }

  void _moveFocusToPrev(int from) {
    for (int i = from - 1; i >= 0; i--) {
      if (!_locked.contains(i)) {
        _boxFocus[i].requestFocus();
        if (_boxes[i].text.isNotEmpty) {
          _boxes[i].text = '';
          _answer[i] = '';
        }
        _boxes[i].selection = const TextSelection.collapsed(offset: 0);
        setState(() {});
        return;
      }
    }
  }

  void _useHint() {
    if (_hintUsed || target.isEmpty) return;

    final candidates = <int>[];
    for (int i = 0; i < target.length; i++) {
      if (!_locked.contains(i) && _answer[i] != target[i]) {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) {
      setState(() => _hintPreview = 'No letters to reveal');
      return;
    }

    final idx = candidates[rnd.nextInt(candidates.length)];
    _locked.add(idx);
    final letter = target[idx];
    _answer[idx] = letter;
    _boxes[idx].text = letter;
    _boxes[idx].selection = const TextSelection.collapsed(offset: 1);
    _hintUsed = true;
    _hintPreview = 'Revealed letter #${idx + 1}';
    _moveFocusToNext(idx);
    setState(() {});
  }

  String _formatTime(int totalSec) {
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    if (min == 0) return "$sec seconds";
    if (min == 1 && sec == 0) return "1 minute";
    if (min == 1) return "1 minute $sec seconds";
    if (sec == 0) return "$min minutes";
    return "$min minutes $sec seconds";
  }

  void _recordWrongGuess(String guess) {
    final g = guess.toUpperCase();
    if (g.isEmpty) return;
    if (g == target) return;
    if (_wrongGuesses.contains(g)) return;
    _wrongGuesses.add(g);
  }

  // open modal list of ALL past scores (latest first)
  Future<void> _openScores() async {
    final all = await ScoreStore.instance.history('scramble');
    final list = List<int>.from(all.reversed);
    if (!mounted) return;
    final best = list.isEmpty ? 0 : list.reduce(max);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 22),
                    const SizedBox(width: 8),
                    const Text('Scramble Scores',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFFAF0),
                        border: Border.all(color: _ink),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Best: ${_fmtScore(best)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('No scores yet. Play a round!'))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = list[i];
                            return ListTile(
                              leading: const Icon(Icons.emoji_events_outlined),
                              title: Text('Score: ${_fmtScore(s)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              dense: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _check() async {
    final guess = _answer.join();
    if (guess == target) {
      _showResult(true, 'Correct!');
      final secs =
          DateTime.now().difference(_start).inSeconds.clamp(1, 99999);

      // INTEGER scoring (higher is better): simple time-based points
      final int score = max(1, (1000 / secs).round());

      await ScoreStore.instance.add('scramble', score);
      final newRecord = await ScoreStore.instance.reportBest('scramble', score);
      if (newRecord) setState(() => _scrambleBest = score.toDouble());

      _wins += 1;
      bool leveled = false;
      if (_wins % 5 == 0) {
        _level += 1;
        leveled = true;
      }
      await _saveState();

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: leveled ? const Text('Level Up!') : const Text('Nice!'),
          content: Text(
            'You solved "${target.toUpperCase()}" in ${_formatTime(secs)}.\n\n'
            'Score: ${_fmtScore(score)}\n'
            'Level: $_level • Progress: ${_wins % 5}/5 to next level.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      _new();
    } else {
      _showResult(false, 'Incorrect');
      final filled = _answer.where((e) => e.isNotEmpty).length;
      if (filled > 0) _recordWrongGuess(guess);
      if (!_shakeCtrl.isAnimating) _shakeCtrl.forward(from: 0);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure controllers/focus lists always match the current word length.
    _normalizeControllerLengths();

    if (!_ready) {
      return _GameScaffold(
        title: 'Scramble',
        rule: 'Unscramble the letters to make a word. One hint per round.',
        actions: [
          IconButton(
            tooltip: 'Scores',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: _openScores,
          ),
        ],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    const vGap = SizedBox(height: 14);

    return _GameScaffold(
      title: 'Scramble',
      rule: 'Unscramble the letters to make a word. One hint per round.',
      actions: [
        IconButton(
          tooltip: 'Scores',
          icon: const Icon(Icons.bar_chart_rounded),
          onPressed: _openScores, // top-right score icon
        ),
      ],
      topBar: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _new,
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text('New'),
          ),
          OutlinedButton.icon(
            onPressed: _reshuffle,
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: const Text('Scramble letters'),
          ),
          OutlinedButton.icon(
            onPressed: _hintUsed ? null : _useHint,
            icon: const Icon(Icons.tips_and_updates_rounded, size: 18),
            label: const Text('Hint'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('How leveling works'),
                  content: Text(
                    'You level up every 5 words you solve correctly. '
                    'Your progress counter resets after each level-up.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.stacked_line_chart, size: 18),
            label: Text('Level $_level • ${_wins % 5}/5'),
          ),
          FilterChip(
            avatar: const Icon(Icons.category_outlined, size: 18),
            label: const Text('Category'),
            selected: _showCategory,
            onSelected: (v) => setState(() => _showCategory = v),
            selectedColor: const Color(0xFFEFFAF0),
            side: const BorderSide(color: _ink),
            backgroundColor: Colors.white,
          ),

          // Scramble-only score chip (same trophy vibe)
          Chip(
            avatar: const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFF0D7C66)),
            label: Text(
              'Best Score: ${_fmtScore(_scrambleBest)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: _ink),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // Scrambled tiles
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List.generate(scrambled.length, (i) {
                    final String ch = scrambled[i];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('tile-$_animSeed-$i'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _ink),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: Text(
                          ch,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ),
                      builder: (context, k, child) {
                        final double o = k.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: o,
                          child: Transform.scale(
                            scale: 0.85 + 0.15 * o,
                            child: child,
                          ),
                        );
                      },
                    );
                  }),
                ),

                vGap,

                // Hint chip
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _hintPreview == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: const ValueKey('hint'),
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Chip(
                            avatar: const Icon(Icons.lightbulb_outline, size: 18),
                            label: Text(
                              _hintPreview!,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: _ink),
                          ),
                        ),
                ),

                // Category chip
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: !_showCategory
                      ? const SizedBox.shrink()
                      : Padding(
                          key: const ValueKey('category'),
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Chip(
                            avatar: const Icon(Icons.label_important_outline, size: 18),
                            label: Text(
                              'Category: $_categoryLabel',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: _ink),
                          ),
                        ),
                ),

                vGap,

                // ANSWER BOXES
                AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (context, child) {
                    final double t = _shakeCtrl.value;
                    final double dx = sin(t * pi * 4) * (10.0 * (1.0 - t));
                    return Transform.translate(offset: Offset(dx, 0.0), child: child);
                  },
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(target.length, (i) {
                      final bool locked = _locked.contains(i);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 42,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: locked ? const Color(0xFFEFFAF0) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _ink),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: Focus(
                          onKeyEvent: (node, KeyEvent event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.backspace &&
                                _boxes[i].text.isEmpty) {
                              _moveFocusToPrev(i);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _boxes[i],
                            focusNode: _boxFocus[i],
                            readOnly: locked,
                            maxLength: 1,
                            buildCounter: (_, {required int currentLength, required bool isFocused, int? maxLength}) =>
                                const SizedBox.shrink(),
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                              LengthLimitingTextInputFormatter(1),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.only(bottom: 4),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: locked ? const Color(0xFF0D7C66) : Colors.black,
                            ),
                            onChanged: (v) {
                              final up = v.toUpperCase();
                              if (v != up) {
                                _boxes[i].value = TextEditingValue(
                                  text: up,
                                  selection: TextSelection.collapsed(offset: up.length),
                                );
                              }
                              _answer[i] = up;
                              if (up.isNotEmpty) _moveFocusToNext(i);
                              setState(() {});
                            },
                            onTap: () {
                              final text = _boxes[i].text;
                              _boxes[i].selection =
                                  TextSelection.collapsed(offset: text.length);
                            },
                            onSubmitted: (_) {
                              if (i == target.length - 1) {
                                _check();
                              } else {
                                _moveFocusToNext(i);
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 10),

                // Result banner (Correct / Incorrect)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _resultMsg == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(_resultMsg),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _ink),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _resultOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                color: _resultOk ? const Color(0xFF0D7C66) : Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _resultMsg!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _resultOk ? const Color(0xFF0D7C66) : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: 200,
                  child: FilledButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Check'),
                  ),
                ),

                const SizedBox(height: 14),

                if (_wrongGuesses.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _ink),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wrong guesses',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _wrongGuesses
                              .map((g) => Chip(
                                    label: Text(g),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: _ink),
                                  ))
                              .toList(),
                        ),
                      ],
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
