// lib/pages/scramble.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ───────────────── Shared look & scaffold ───────────────── */

BoxDecoration _bg(BuildContext context) {
  // Use a constant gradient so it fills the area behind the system status bar.
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
  const _GameScaffold({
    required this.title,
    required this.rule,
    required this.child,
    this.topBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // removes the black band behind status bar
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
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

  Future<void> add(String key, double v) async {
    final p = await SharedPreferences.getInstance();
    final k = 'sbp_$key';
    final cur = p.getStringList(k) ?? [];
    cur.add(v.toString());
    await p.setStringList(k, cur);
  }

  Future<bool> reportBest(String key, double score) async {
    final p = await SharedPreferences.getInstance();
    final bestKey = 'sbp_best_$key';
    final prev = p.getDouble(bestKey) ?? double.negativeInfinity;
    if (score > prev) {
      await p.setDouble(bestKey, score);
      return true;
    }
    return false;
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
  // ── Category word lists (10 categories × 30 words = 300 words) ──
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
  int _wins = 0; // increases on each solve; level up every 5 wins

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
  int _animSeed = 0; // to retrigger tile entrance animations

  // Hint
  bool _hintUsed = false;
  String? _hintPreview;

  // Category toggle
  bool _showCategory = false;

  // Wrong-guess word bank (for current round)
  final List<String> _wrongGuesses = [];

  bool _ready = true;

  String get _categoryLabel => _wordToCategory[target] ?? 'General';

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _loadState().then((_) => _new());
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

  // Returns [minLen, maxLen] based on level (harder => longer words).
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
    if (pool.isEmpty) {
      return _allWords[rnd.nextInt(_allWords.length)];
    }
    return pool[rnd.nextInt(pool.length)];
  }

  // ── Scramble the visible tiles without changing the target.
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

  // New round: build new state then swap in one setState.
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
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldBoxes) {
        try { c.dispose(); } catch (_) {}
      }
      for (final f in oldFocus) {
        try { f.dispose(); } catch (_) {}
      }
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

  Future<void> _check() async {
    final guess = _answer.join();
    if (guess == target) {
      final secs =
          DateTime.now().difference(_start).inSeconds.clamp(1, 99999);
      final score = 1.0 / secs;
      await ScoreStore.instance.add('scramble', score);
      await ScoreStore.instance.reportBest('scramble', score);

      // Level progress: level up AFTER every 5 solved games
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
      final filled = _answer.where((e) => e.isNotEmpty).length;
      if (filled > 0) {
        _recordWrongGuess(guess);
      }
      if (!_shakeCtrl.isAnimating) {
        _shakeCtrl.forward(from: 0);
      }
      if (!mounted) return;
      setState(() {}); // refresh wrong guesses list
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return _GameScaffold(
        title: 'Scramble',
        rule: 'Unscramble the letters to make a word. One hint per round.',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Consistent gaps; push gameplay a bit further down for spacing
    const vGap = SizedBox(height: 14);

    return _GameScaffold(
      title: 'Scramble',
      rule: 'Unscramble the letters to make a word. One hint per round.',
      topBar: Wrap(
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
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8), // push content a bit further down

            // Scrambled tiles – entrance animation
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
                  // NOTE: Curves like easeOutBack overshoot <0 or >1. Clamp before Opacity.
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
                    final double o = k.clamp(0.0, 1.0); // <-- FIX: keep opacity in [0,1]
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

            // Category chip (optional)
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

            // ANSWER BOXES (single-letter TextFields)
            AnimatedBuilder(
              animation: _shakeCtrl,
              builder: (context, child) {
                final double t = _shakeCtrl.value; // 0..1
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
                    child: TextField(
                      controller: _boxes[i],
                      focusNode: _boxFocus[i],
                      readOnly: locked,
                      maxLength: 1,
                      buildCounter: (_,
                              {required int currentLength,
                              required bool isFocused,
                              int? maxLength}) =>
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
                        if (up.isNotEmpty) {
                          _moveFocusToNext(i);
                        }
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
                  );
                }),
              ),
            ),

            vGap,

            SizedBox(
              width: 200,
              child: FilledButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Check'),
              ),
            ),

            const SizedBox(height: 14),

            // Wrong guesses "word bank"
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
    );
  }
}
