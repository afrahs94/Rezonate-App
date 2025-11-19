// lib/pages/trivia.dart
//
// Trivia game (Trivia Star–style) with a NEON category chooser and
// a LAVA-LAMP background during the quiz.
// - Back button in the QUIZ view returns to the category chooser.
// - Everything else unchanged from the previous version.
//
// No external assets.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

/* ───────────────── THEME ───────────────── */

BoxDecoration _bg(BuildContext context) => const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF08090D), Color(0xFF0A0C12), Color(0xFF091317)],
      ),
    );

const _ink = Colors.white;
const _panel = Color(0xFF111319);
const _panelLite = Color(0xFF171A22);

const _neonPink = Color(0xFFFF2D95);
const _neonCyan = Color(0xFF10F7F2);
const _neonLime = Color(0xFF7CFF3A);
const _neonPurple = Color(0xFF8A5BFF);
const _neonYellow = Color(0xFFFFF95E);
const _frame = _neonCyan;
const _green = Color(0xFF00E19A);

/* ───────────────── DATA ───────────────── */

enum _Cat {
  mixed,
  general,
  history,
  science,
  geography,
  movies,
  music,
  sports,
  literature,
}

String _catLabel(_Cat c) => switch (c) {
      _Cat.mixed => 'Mixed',
      _Cat.general => 'General',
      _Cat.history => 'History',
      _Cat.science => 'Science',
      _Cat.geography => 'Geography',
      _Cat.movies => 'Movies',
      _Cat.music => 'Music',
      _Cat.sports => 'Sports',
      _Cat.literature => 'Literature',
    };

IconData _catIcon(_Cat c) => switch (c) {
      _Cat.mixed => Icons.all_inclusive_rounded,
      _Cat.general => Icons.star_border_rounded,
      _Cat.history => Icons.castle_rounded,
      _Cat.science => Icons.science_rounded,
      _Cat.geography => Icons.public_rounded,
      _Cat.movies => Icons.movie_rounded,
      _Cat.music => Icons.music_note_rounded,
      _Cat.sports => Icons.sports_soccer_rounded,
      _Cat.literature => Icons.menu_book_rounded,
    };

class _Q {
  final String q;
  final List<String> choices; // length 4
  final int correct; // index 0..3
  final _Cat cat;
  const _Q(this.q, this.choices, this.correct, this.cat);
}

_Q q(_Cat c, String t, String a, String b, String c1, String d, String correct) {
  final opts = [a, b, c1, d];
  final i = opts.indexOf(correct);
  return _Q(t, opts, i < 0 ? 0 : i, c);
}

/// Compact bank (extend later freely)
final List<_Q> _bank = [
  // General
  q(_Cat.general, 'What is the capital of France?', 'Berlin', 'Madrid', 'Paris', 'Rome', 'Paris'),
  q(_Cat.general, 'How many continents are there?', '5', '6', '7', '8', '7'),
  q(_Cat.general, 'Which planet is known as the Red Planet?', 'Earth', 'Mars', 'Venus', 'Jupiter', 'Mars'),
  q(_Cat.general, 'H2O is the chemical formula for…', 'Oxygen', 'Salt', 'Water', 'Hydrogen', 'Water'),
  q(_Cat.general, 'The tallest animal is the…', 'Elephant', 'Giraffe', 'Rhino', 'Hippo', 'Giraffe'),
  q(_Cat.general, 'What do bees use to make honey?', 'Pollen', 'Seeds', 'Nectar', 'Sap', 'Nectar'),
  q(_Cat.general, 'How many days in a leap year?', '364', '365', '366', '367', '366'),
  q(_Cat.general, 'The hardest natural substance is…', 'Iron', 'Diamond', 'Quartz', 'Gold', 'Diamond'),
  q(_Cat.general, 'Primary colors include red, blue, and…', 'Black', 'White', 'Green', 'Yellow', 'Yellow'),
  q(_Cat.general, 'Which ocean is the largest?', 'Atlantic', 'Indian', 'Pacific', 'Arctic', 'Pacific'),

  // History
  q(_Cat.history, 'Who was the first U.S. President?', 'Lincoln', 'Washington', 'Jefferson', 'Adams', 'Washington'),
  q(_Cat.history, 'The Great Wall is in which country?', 'India', 'China', 'Japan', 'Mongolia', 'China'),
  q(_Cat.history, 'Pompeii was destroyed by which volcano?', 'Krakatoa', 'Etna', 'Vesuvius', 'Fuji', 'Vesuvius'),
  q(_Cat.history, 'The Renaissance began primarily in…', 'France', 'Spain', 'Italy', 'Germany', 'Italy'),
  q(_Cat.history, 'Magna Carta was signed in…', '1066', '1215', '1492', '1776', '1215'),
  q(_Cat.history, 'Who discovered penicillin?', 'Fleming', 'Curie', 'Pasteur', 'Salk', 'Fleming'),
  q(_Cat.history, 'The Titanic sank in…', '1910', '1912', '1914', '1920', '1912'),
  q(_Cat.history, 'Who was called the Maid of Orléans?', 'Cleopatra', 'Joan of Arc', 'Boleyn', 'Eleanor', 'Joan of Arc'),
  q(_Cat.history, 'Which empire built Machu Picchu?', 'Aztec', 'Maya', 'Inca', 'Olmec', 'Inca'),
  q(_Cat.history, 'The Cold War ended around…', '1969', '1979', '1989', '1999', '1989'),

  // Science
  q(_Cat.science, 'What gas do plants absorb?', 'Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Helium', 'Carbon Dioxide'),
  q(_Cat.science, 'Speed of light is ~… km/s', '150,000', '200,000', '300,000', '500,000', '300,000'),
  q(_Cat.science, 'Universal donor blood type:', 'AB+', 'O−', 'A−', 'B+', 'O−'),
  q(_Cat.science, 'Adult human bones:', '106', '206', '250', '300', '206'),
  q(_Cat.science, 'pH < 7 indicates…', 'Neutral', 'Acidic', 'Basic', 'None', 'Acidic'),
  q(_Cat.science, 'Which particle has negative charge?', 'Proton', 'Neutron', 'Electron', 'Photon', 'Electron'),
  q(_Cat.science, 'Photosynthesis occurs in…', 'Mitochondria', 'Chloroplasts', 'Nucleus', 'Ribosome', 'Chloroplasts'),
  q(_Cat.science, 'Earth’s core mainly:', 'Iron & Nickel', 'Silicon', 'Carbon', 'Water', 'Iron & Nickel'),
  q(_Cat.science, 'SI unit of force:', 'Joule', 'Pascal', 'Newton', 'Watt', 'Newton'),
  q(_Cat.science, 'A light-year measures…', 'Time', 'Speed', 'Distance', 'Mass', 'Distance'),

  // Geography
  q(_Cat.geography, 'Mount Everest lies in…', 'Nepal/China', 'India/Bhutan', 'China/Pakistan', 'Nepal/India', 'Nepal/China'),
  q(_Cat.geography, 'The Nile flows into the…', 'Red Sea', 'Indian Ocean', 'Mediterranean', 'Atlantic', 'Mediterranean'),
  q(_Cat.geography, 'Largest hot desert:', 'Gobi', 'Sahara', 'Atacama', 'Kalahari', 'Sahara'),
  q(_Cat.geography, 'Capital of Canada:', 'Toronto', 'Vancouver', 'Ottawa', 'Montreal', 'Ottawa'),
  q(_Cat.geography, 'Country with most islands:', 'Greece', 'Indonesia', 'Sweden', 'Philippines', 'Sweden'),
  q(_Cat.geography, 'Amazon River is in…', 'Africa', 'Asia', 'South America', 'Europe', 'South America'),
  q(_Cat.geography, 'Istanbul straddles…', 'Asia & Africa', 'Europe & Asia', 'Europe & Africa', 'Asia & Oceania', 'Europe & Asia'),
  q(_Cat.geography, 'Uluru is in…', 'NZ', 'Australia', 'USA', 'South Africa', 'Australia'),
  q(_Cat.geography, 'The Danube flows to the…', 'Baltic', 'Black Sea', 'North Sea', 'Caspian', 'Black Sea'),
  q(_Cat.geography, 'Aloha State:', 'Hawaii', 'Alaska', 'Florida', 'California', 'Hawaii'),

  // Movies
  q(_Cat.movies, '“May the Force be with you” from…', 'Star Trek', 'Star Wars', 'Avatar', 'Alien', 'Star Wars'),
  q(_Cat.movies, 'Director of “Inception”', 'Cameron', 'Nolan', 'Fincher', 'Scott', 'Nolan'),
  q(_Cat.movies, 'Blue Na’vi appear in…', 'Dune', 'Avatar', 'Prometheus', 'Arrival', 'Avatar'),
  q(_Cat.movies, 'Oscars are held in…', 'NYC', 'Los Angeles', 'Chicago', 'Miami', 'Los Angeles'),
  q(_Cat.movies, '“The Godfather” family name:', 'Soprano', 'Corleone', 'Falcone', 'Maroni', 'Corleone'),
  q(_Cat.movies, '“Wakanda Forever” belongs to…', 'DC', 'Marvel', 'Image', 'Dark Horse', 'Marvel'),
  q(_Cat.movies, 'Hobbits live in the…', 'Shire', 'Mordor', 'Gondor', 'Rivendell', 'Shire'),
  q(_Cat.movies, '“I’ll be back” is said by…', 'Rambo', 'Terminator', 'Robocop', 'Predator', 'Terminator'),
  q(_Cat.movies, 'Best Picture (2020):', '1917', 'Joker', 'Parasite', 'Ferrari', 'Parasite'),
  q(_Cat.movies, 'Pixar robot left to clean Earth:', 'EVA', 'WALL-E', 'R2-D2', 'Data', 'WALL-E'),

  // Music
  q(_Cat.music, 'Beatles are from…', 'Manchester', 'Liverpool', 'London', 'Bristol', 'Liverpool'),
  q(_Cat.music, '“King of Pop”', 'Elvis', 'Jackson', 'Prince', 'Bowie', 'Jackson'),
  q(_Cat.music, 'Piano has how many keys?', '76', '82', '88', '96', '88'),
  q(_Cat.music, 'Reggae began in…', 'USA', 'Jamaica', 'Brazil', 'Ghana', 'Jamaica'),
  q(_Cat.music, 'Mozart era:', 'Baroque', 'Classical', 'Romantic', 'Modern', 'Classical'),
  q(_Cat.music, '3 beats per bar:', '4/4', '2/4', '3/4', '6/8', '3/4'),
  q(_Cat.music, 'Freddie Mercury fronted…', 'Queen', 'U2', 'ABBA', 'Eagles', 'Queen'),
  q(_Cat.music, 'Instrument with valves:', 'Cello', 'Oboe', 'Trumpet', 'Viola', 'Trumpet'),
  q(_Cat.music, 'Singer of “Hello” (2015):', 'Rihanna', 'Adele', 'Sia', 'Beyoncé', 'Adele'),
  q(_Cat.music, 'Largest orchestra section:', 'Percussion', 'Strings', 'Woodwind', 'Brass', 'Strings'),

  // Sports
  q(_Cat.sports, 'Players on a soccer team (on field):', '9', '10', '11', '12', '11'),
  q(_Cat.sports, 'Grand slam NOT on grass:', 'Wimbledon', 'US Open', 'French Open', 'None', 'French Open'),
  q(_Cat.sports, 'Basketball hoop height (ft):', '9', '10', '11', '12', '10'),
  q(_Cat.sports, 'Super Bowl is…', 'Baseball', 'American Football', 'Basketball', 'Hockey', 'American Football'),
  q(_Cat.sports, 'The “Masters” is in…', 'Tennis', 'Golf', 'Cycling', 'Skiing', 'Golf'),
  q(_Cat.sports, 'Ronaldo plays…', 'Cricket', 'Soccer', 'Rugby', 'Tennis', 'Soccer'),
  q(_Cat.sports, 'Hat-trick means…', '3 goals', '3 fouls', '3 corners', '3 assists', '3 goals'),
  q(_Cat.sports, 'Olympic rings:', '4', '5', '6', '7', '5'),
  q(_Cat.sports, 'Baseball bases:', '3', '4', '5', '6', '4'),
  q(_Cat.sports, 'NHL plays on…', 'Grass', 'Ice', 'Clay', 'Hardcourt', 'Ice'),

  // Literature
  q(_Cat.literature, '“Romeo and Juliet” by…', 'Marlowe', 'Shakespeare', 'Beckett', 'Shaw', 'Shakespeare'),
  q(_Cat.literature, 'Author of “1984”', 'Huxley', 'Orwell', 'Bradbury', 'Atwood', 'Orwell'),
  q(_Cat.literature, 'Holmes’ companion:', 'Watson', 'Moriarty', 'Lestrade', 'Hudson', 'Watson'),
  q(_Cat.literature, '“Hobbit” author', 'Tolkien', 'Lewis', 'Rowling', 'Martin', 'Tolkien'),
  q(_Cat.literature, '“Pride and Prejudice” by…', 'Eliot', 'Bronte', 'Austen', 'Dickens', 'Austen'),
  q(_Cat.literature, 'Muse of epic poetry:', 'Calliope', 'Clio', 'Euterpe', 'Erato', 'Calliope'),
  q(_Cat.literature, 'Poem with 14 lines:', 'Haiku', 'Sonnet', 'Ode', 'Elegy', 'Sonnet'),
  q(_Cat.literature, '“The Raven” poet:', 'Frost', 'Poe', 'Whitman', 'Blake', 'Poe'),
  q(_Cat.literature, 'Wizard school name:', 'Beauxbatons', 'Durmstrang', 'Hogwarts', 'Ilvermorny', 'Hogwarts'),
  q(_Cat.literature, 'Hero of “The Odyssey”:', 'Aeneas', 'Odysseus', 'Achilles', 'Agamemnon', 'Odysseus'),
];

List<_Q> _poolFor(_Cat c) {
  if (c == _Cat.mixed) return List<_Q>.from(_bank)..shuffle();
  return _bank.where((e) => e.cat == c).toList()..shuffle();
}

/* ───────────────── PERSISTENCE ───────────────── */

class _Store {
  static const _kCoins = 'trivia_coins';
  static const _kBestPrefix = 'trivia_best_';
  static const _kHist = 'trivia_hist_v1';

  Future<int> coins() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kCoins) ?? 0;
  }

  Future<void> addCoins(int delta) async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt(_kCoins) ?? 0;
    await p.setInt(_kCoins, max(0, cur + delta));
  }

  Future<int> best(_Cat c) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('$_kBestPrefix${c.name}') ?? 0;
  }

  Future<void> reportBest(_Cat c, int score) async {
    final p = await SharedPreferences.getInstance();
    final k = '$_kBestPrefix${c.name}';
    final cur = p.getInt(k) ?? 0;
    if (score > cur) await p.setInt(k, score);
  }

  Future<List<String>> history() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_kHist) ?? const [];
  }

  Future<void> pushHistory({_Cat? c, required int score}) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kHist) ?? <String>[];
    final entry =
        '${DateTime.now().toIso8601String()}|${c?.name ?? 'mixed'}|$score';
    list.insert(0, entry);
    if (list.length > 100) list.removeRange(100, list.length);
    await p.setStringList(_kHist, list);
  }
}

/* ───────────────── PAGE ───────────────── */

class TriviaPage extends StatefulWidget {
  const TriviaPage({super.key});
  @override
  State<TriviaPage> createState() => _TriviaPageState();
}

class _TriviaPageState extends State<TriviaPage>
    with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final _store = _Store();

  _Cat? _category;
  late List<_Q> _levelQs; // 10 per level
  int _qIndex = 0;

  int _score = 0;
  int _best = 0;
  int _coins = 0;
  int _lives = 3;
  int _streak = 0;

  static const int _maxSeconds = 15;
  late int _secondsLeft;
  Timer? _t;

  int? _selected;
  bool _locked = false;
  Set<int> _eliminated = {};
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _maxSeconds;
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _loadBestCoins() async {
    final b = await _store.best(_category ?? _Cat.mixed);
    final c = await _store.coins();
    if (!mounted) return;
    setState(() {
      _best = b;
      _coins = c;
    });
  }

  void _startChooser() {
    setState(() {
      _category = null;
      _t?.cancel();
    });
  }

  void _startLevel(_Cat c) {
    _category = c;
    final pool = _poolFor(c);
    _levelQs = pool.take(10).toList();
    _qIndex = 0;
    _score = 0;
    _streak = 0;
    _lives = 3;
    _selected = null;
    _eliminated.clear();
    _secondsLeft = _maxSeconds;
    _locked = false;
    _loadBestCoins();
    _runTimer();
    setState(() {});
  }

  void _runTimer() {
    _t?.cancel();
    _secondsLeft = _maxSeconds;
    _t = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_locked) return;
      if (_secondsLeft <= 1) {
        _timeUp();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _timeUp() {
    _t?.cancel();
    setState(() {
      _locked = true;
      _selected = null;
      _lives -= 1;
    });
    Future.delayed(const Duration(milliseconds: 650), _next);
  }

  void _answer(int i) {
    if (_locked) return;
    if (_eliminated.contains(i)) return;
    setState(() {
      _selected = i;
      _locked = true;
    });
    final q = _levelQs[_qIndex];
    final correct = (i == q.correct);
    if (correct) {
      final timeBonus = _secondsLeft;
      int delta = 100 + timeBonus;
      _streak += 1;
      if (_streak >= 3) delta += 20;
      _score += delta;
      _store.addCoins(5);
    } else {
      _streak = 0;
      _lives -= 1;
    }
    _store.coins().then((c) {
      if (mounted) setState(() => _coins = c);
    });
    _t?.cancel();
    Future.delayed(const Duration(milliseconds: 650), _next);
  }

  void _next() async {
    if (!mounted) return;
    if (_lives <= 0) {
      await _endLevel(win: false);
      return;
    }
    if (_qIndex >= _levelQs.length - 1) {
      await _endLevel(win: true);
      return;
    }
    setState(() {
      _qIndex++;
      _selected = null;
      _locked = false;
      _eliminated.clear();
    });
    _runTimer();
  }

  Future<void> _endLevel({required bool win}) async {
    _t?.cancel();
    await _store.reportBest(_category!, _score);
    await _store.pushHistory(c: _category, score: _score);
    final newBest = await _store.best(_category!);
    setState(() => _best = newBest);

    int stars;
    final approxCorrect = (_score / 100).floor().clamp(0, 10);
    if (approxCorrect >= 8) {
      stars = 3;
    } else if (approxCorrect >= 6) {
      stars = 2;
    } else {
      stars = 1;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ResultDialog(
        win: win,
        stars: stars,
        score: _score,
        coins: _coins,
        onNext: () {
          Navigator.pop(context);
          _level += 1;
          _startLevel(_category!);
        },
        onRetry: () {
          Navigator.pop(context);
          _startLevel(_category!);
        },
        onCategories: () {
          Navigator.pop(context);
          _startChooser();
        },
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.black87,
      content: Text(msg, style: const TextStyle(color: _ink)),
    ));
  }

  void _use5050() async {
    if (_locked) return;
    if (_coins < 10) return _toast('Not enough coins (need 10).');
    final q = _levelQs[_qIndex];
    final wrong = <int>{0, 1, 2, 3}..remove(q.correct);
    wrong.toList().shuffle(_rnd);
    setState(() => _eliminated = wrong.take(2).toSet());
    await _store.addCoins(-10);
    final c = await _store.coins();
    if (mounted) setState(() => _coins = c);
  }

  void _skip() async {
    if (_locked) return;
    if (_coins < 20) return _toast('Not enough coins (need 20).');
    await _store.addCoins(-20);
    final c = await _store.coins();
    if (!mounted) return;
    setState(() => _coins = c);
    _selected = _levelQs[_qIndex].correct;
    _locked = true;
    _score += 100;
    _t?.cancel();
    Future.delayed(const Duration(milliseconds: 450), _next);
  }

  Future<void> _openHistory() async {
    final hist = await _store.history();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: _frame),
                    const SizedBox(width: 8),
                    Text('Trivia Scores',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w900, color: _ink)),
                    const Spacer(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: _frame),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: _neonCyan, blurRadius: 10)
                        ],
                      ),
                      child: Text('Best: $_best',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: _ink)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: hist.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No scores yet — play a round!',
                              style: TextStyle(color: _ink)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: hist.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (_, i) {
                            final parts = hist[i].split('|');
                            final when =
                                DateTime.tryParse(parts[0]) ?? DateTime.now();
                            final cat = parts.length > 1 ? parts[1] : 'mixed';
                            final sc =
                                parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
                            final label = _Cat.values
                                .firstWhere((e) => e.name == cat,
                                    orElse: () => _Cat.mixed)
                                .name;
                            return ListTile(
                              leading: const Icon(Icons.emoji_events_outlined,
                                  size: 22, color: _frame),
                              title: Text('Score: $sc',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _ink)),
                              subtitle: Text(
                                  '${label[0].toUpperCase()}${label.substring(1)} • ${when.toLocal()}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
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

  /* ─────────── UI ─────────── */

  @override
  Widget build(BuildContext context) {
    if (_category == null) return _buildChooser();

    final q = _levelQs[_qIndex];
    final progress = (_qIndex + 1);
    final pct = _secondsLeft / _maxSeconds;

    // Intercept system back (iOS swipe / Android back) to go to category chooser.
    return WillPopScope(
      onWillPop: () async {
        _startChooser();
        return false; // do not pop the page
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _ink),
            onPressed: _startChooser, // ← goes to categories
          ),
          title: const Text('Trivia',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'Scores',
              icon: const Icon(Icons.bar_chart_rounded, color: _ink),
              onPressed: _openHistory,
            ),
          ],
        ),
        // LAVA-LAMP background for the QUIZ view
        body: Stack(
          children: [
            const _LavaLamp(), // animated background
            // soft vignette for readability
            Container(decoration: _bg(context).copyWith()),
            SafeArea(
              top: true,
              child: Column(
                children: [
                  // Rule card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _frame),
                        boxShadow: const [
                          BoxShadow(color: _neonCyan, blurRadius: 12)
                        ],
                      ),
                      child: const Text(
                        'Pop-quiz time! Pick the correct answer. '
                        'Score +100 plus a time bonus for each correct answer.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _ink),
                      ),
                    ),
                  ),

                  // Top chips row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(
                          avatar:
                              Icon(_catIcon(_category!), size: 18, color: _frame),
                          label: Text(_catLabel(_category!),
                              style: const TextStyle(color: _ink)),
                          backgroundColor: _panel,
                          side: const BorderSide(color: _frame),
                        ),
                        Chip(
                          avatar: const Icon(Icons.trending_up_rounded,
                              size: 18, color: _frame),
                          label: Text('Q $progress / ${_levelQs.length}',
                              style: const TextStyle(color: _ink)),
                          backgroundColor: _panel,
                          side: const BorderSide(color: _frame),
                        ),
                        Chip(
                          avatar: const Icon(Icons.emoji_events_outlined,
                              color: _green),
                          label: Text('Best: $_best',
                              style: const TextStyle(color: _ink)),
                          backgroundColor: _panel,
                          side: const BorderSide(color: _frame),
                        ),
                        Chip(
                          avatar: const Icon(Icons.favorite_rounded,
                              color: Colors.redAccent),
                          label: Text('$_lives',
                              style: const TextStyle(color: _ink)),
                          backgroundColor: _panel,
                          side: const BorderSide(color: _frame),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.monetization_on_rounded,
                              size: 18, color: _green),
                          label: Text('$_coins',
                              style: const TextStyle(color: _ink)),
                          onPressed: () => _toast(
                              '+5 per correct • 50/50 costs 10 • Skip costs 20'),
                          backgroundColor: _panel,
                          side: const BorderSide(color: _frame),
                        ),
                      ],
                    ),
                  ),

                  // Timer bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        color: pct > .5
                            ? _green
                            : (pct > .2
                                ? Colors.orangeAccent
                                : Colors.redAccent),
                      ),
                    ),
                  ),

                  // Score chip
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Chip(
                      avatar: const Icon(Icons.grade_outlined, color: _green),
                      label: Text('Score: $_score',
                          style: const TextStyle(color: _ink)),
                      backgroundColor: _panel,
                      side: const BorderSide(color: _frame),
                    ),
                  ),

                  // Question bubble
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _frame),
                        boxShadow: const [
                          BoxShadow(color: _neonCyan, blurRadius: 10)
                        ],
                      ),
                      child: Text(
                        '“${q.q}”',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: _ink),
                      ),
                    ),
                  ),

                  // Options
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: ListView.separated(
                        itemCount: 4,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final text = q.choices[i];
                          final isSel = _selected == i;
                          final isCorrect = i == q.correct;
                          Color bg = _panelLite;
                          Color border = _neonPink; // different from question bubble
                          if (_locked) {
                            if (isCorrect) {
                              bg = const Color(0xFF0E1A15);
                              border = _green;
                            } else if (isSel) {
                              bg = const Color(0xFF1C1010);
                              border = Colors.redAccent;
                            }
                          } else if (_eliminated.contains(i)) {
                            bg = _panelLite.withOpacity(.55);
                            border = Colors.white24;
                          }
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            child: ElevatedButton(
                              onPressed: (_locked || _eliminated.contains(i))
                                  ? null
                                  : () => _answer(i),
                              style: ElevatedButton.styleFrom(
                                elevation: 4,
                                backgroundColor: bg,
                                foregroundColor: _ink,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side:
                                      BorderSide(color: border, width: 1.2),
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Hint bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _use5050,
                            icon:
                                const Icon(Icons.filter_2_rounded, size: 18),
                            label: const Text('50/50 (10)',
                                style: TextStyle(color: _ink)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _frame),
                              backgroundColor: _panelLite,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _skip,
                            icon: const Icon(Icons.skip_next_rounded,
                                size: 18),
                            label: const Text('Skip (20)',
                                style: TextStyle(color: _ink)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _frame),
                              backgroundColor: _panelLite,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ─────────── NEON CHOOSER (floating categories) ─────────── */

  Widget _buildChooser() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text('Trivia',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: _ink),
        actions: [
          IconButton(
            tooltip: 'Scores',
            icon: const Icon(Icons.bar_chart_rounded, color: _ink),
            onPressed: _openHistory,
          ),
        ],
      ),
      body: Container(
        decoration: _bg(context),
        child: Stack(
          children: [
            const _NeonBokeh(),
            SafeArea(
              top: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a Category',
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headlineSmall?.fontSize ??
                                24,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                        shadows: const [
                          Shadow(color: _neonPink, blurRadius: 18),
                          Shadow(color: _neonCyan, blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Each level has 10 timed questions. Good luck!',
                      style: TextStyle(fontSize: 12.5, color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, cons) {
                          final cards = <Widget>[];
                          for (final c in _Cat.values) {
                            final phase = c.index * 0.6;
                            final colors = [
                              _neonPink,
                              _neonCyan,
                              _neonLime,
                              _neonPurple,
                              _neonYellow,
                            ]..shuffle(Random(c.index));
                            cards.add(_FloatingNeon(
                              phase: phase,
                              child: _NeonCatCard(
                                icon: _catIcon(c),
                                label: _catLabel(c),
                                onTap: () => _startLevel(c),
                                colors: colors,
                              ),
                            ));
                          }
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: cards
                                  .map((w) => SizedBox(
                                        width: (cons.maxWidth - 14) / 2 - 7,
                                        height: 120,
                                        child: w,
                                      ))
                                  .toList(),
                            ),
                          );
                        },
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

/* ───────────────── Neon utilities ───────────────── */

class _NeonBokeh extends StatefulWidget {
  const _NeonBokeh();
  @override
  State<_NeonBokeh> createState() => _NeonBokehState();
}

class _NeonBokehState extends State<_NeonBokeh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
        ..repeat();
  final _rnd = Random();
  late final List<_Dot> _dots = List.generate(18, (_) => _Dot.random(_rnd));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) =>
            CustomPaint(painter: _BokehPainter(_dots, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _Dot {
  final double x, y, r, speed;
  final Color color;
  _Dot(this.x, this.y, this.r, this.speed, this.color);
  factory _Dot.random(Random rnd) {
    final colors = [_neonPink, _neonCyan, _neonLime, _neonPurple, _neonYellow];
    return _Dot(
      rnd.nextDouble(),
      rnd.nextDouble(),
      40 + rnd.nextDouble() * 80,
      .02 + rnd.nextDouble() * .04,
      colors[rnd.nextInt(colors.length)].withOpacity(.28),
    );
  }
}

class _BokehPainter extends CustomPainter {
  final List<_Dot> dots;
  final double t; // 0..1
  _BokehPainter(this.dots, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dots) {
      final dy = (d.y + d.speed * t) % 1.2;
      final center = Offset(d.x * size.width, dy * size.height);
      final paint = Paint()
        ..color = d.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(center, d.r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BokehPainter oldDelegate) => true;
}

class _FloatingNeon extends StatefulWidget {
  final double phase;
  final Widget child;
  const _FloatingNeon({required this.phase, required this.child});
  @override
  State<_FloatingNeon> createState() => _FloatingNeonState();
}

class _FloatingNeonState extends State<_FloatingNeon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = (sin((_c.value + widget.phase) * pi * 2) + 1) / 2;
        final dx = sin((_c.value * 0.7 + widget.phase) * pi * 2) * 4;
        final dy = (t - .5) * 8;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: widget.child,
    );
  }
}

class _NeonCatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color> colors;
  const _NeonCatCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  State<_NeonCatCard> createState() => _NeonCatCardState();
}

class _NeonCatCardState extends State<_NeonCatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);
  bool _pressed = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final g = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors[0], colors[1], t)!,
            Color.lerp(colors[2], colors[3], (t * .8) % 1)!,
            colors[4],
          ],
        );
        return Transform.scale(
          scale: _pressed ? 0.98 : 1.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () {
              setState(() => _pressed = false);
              widget.onTap();
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: g,
                boxShadow: [
                  BoxShadow(color: colors[0].withOpacity(.65), blurRadius: 20),
                  BoxShadow(color: colors[1].withOpacity(.45), blurRadius: 26),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _panel,
                  border: Border.all(color: _frame),
                  boxShadow: const [
                    BoxShadow(color: _neonCyan, blurRadius: 12),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => g.createShader(r),
                      child: Icon(widget.icon, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _ink,
                        shadows: [
                          Shadow(color: colors[0].withOpacity(.7), blurRadius: 8)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ───────────────── LAVA-LAMP BACKGROUND (quiz view) ───────────────── */

class _LavaLamp extends StatefulWidget {
  const _LavaLamp();
  @override
  State<_LavaLamp> createState() => _LavaLampState();
}

class _LavaLampState extends State<_LavaLamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();

  final List<_BlobSeed> _seeds = List.generate(
    7,
    (i) => _BlobSeed.random(Random(100 + i)),
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
      builder: (_, __) => CustomPaint(
        painter: _LavaPainter(_seeds, _c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _BlobSeed {
  final double r; // radius factor
  final double fx, fy; // frequency
  final double phx, phy; // phase
  final Color color;
  _BlobSeed(
      {required this.r,
      required this.fx,
      required this.fy,
      required this.phx,
      required this.phy,
      required this.color});
  factory _BlobSeed.random(Random rnd) {
    final colors = [
      _neonPink.withOpacity(.55),
      _neonPurple.withOpacity(.55),
      _neonCyan.withOpacity(.55),
      _neonLime.withOpacity(.55),
      Colors.deepOrangeAccent.withOpacity(.55),
    ];
    return _BlobSeed(
      r: .12 + rnd.nextDouble() * .18,
      fx: .5 + rnd.nextDouble() * 1.0,
      fy: .5 + rnd.nextDouble() * 1.0,
      phx: rnd.nextDouble() * pi * 2,
      phy: rnd.nextDouble() * pi * 2,
      color: colors[rnd.nextInt(colors.length)],
    );
  }
}

class _LavaPainter extends CustomPainter {
  final List<_BlobSeed> seeds;
  final double t; // 0..1
  _LavaPainter(this.seeds, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Blend layer so colors add up like lava lamp
    canvas.saveLayer(rect, Paint());
    for (final s in seeds) {
      final cx = (0.5 + 0.4 * sin((t * 2 * pi * s.fx) + s.phx)) * size.width;
      final cy = (0.5 + 0.4 * cos((t * 2 * pi * s.fy) + s.phy)) * size.height;
      final radius = min(size.width, size.height) * s.r;
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
        ..shader = RadialGradient(
          colors: [
            s.color,
            s.color.withOpacity(.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LavaPainter oldDelegate) => true;
}

/* ───────────────── Result dialog ───────────────── */

class _ResultDialog extends StatelessWidget {
  final bool win;
  final int stars;
  final int score;
  final int coins;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onCategories;

  const _ResultDialog({
    required this.win,
    required this.stars,
    required this.score,
    required this.coins,
    required this.onNext,
    required this.onRetry,
    required this.onCategories,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _frame),
      ),
      title: Row(
        children: [
          Icon(win ? Icons.celebration_rounded : Icons.restart_alt_rounded,
              color: _green),
          const SizedBox(width: 8),
          Text(win ? 'Level Complete!' : 'Out of Lives',
              style: const TextStyle(fontWeight: FontWeight.w900, color: _ink)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Chip(
            avatar: const Icon(Icons.grade_outlined, color: _green),
            label: Text('Score: $score',
                style: const TextStyle(color: _ink)),
            backgroundColor: _panelLite,
            side: const BorderSide(color: _frame),
          ),
          const SizedBox(height: 6),
          Chip(
            avatar: const Icon(Icons.monetization_on_rounded, color: _green),
            label: Text('Coins: $coins',
                style: const TextStyle(color: _ink)),
            backgroundColor: _panelLite,
            side: const BorderSide(color: _frame),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: onCategories,
            child: const Text('Categories', style: TextStyle(color: _ink))),
        if (win)
          FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('Next Level'))
        else
          FilledButton(
              onPressed: onRetry,
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Retry')),
      ],
    );
  }
}
