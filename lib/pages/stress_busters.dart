// lib/pages/stress_busters.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:new_rezonate/main.dart' as app;

// Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Local fallback
import 'package:shared_preferences/shared_preferences.dart';

// Game pages
import 'word_search.dart';
import 'trivia.dart';
import 'matching.dart';
import 'sudoku.dart';
import 'uplingo.dart';
import 'scramble.dart';

/* ─────────────────── Shared theme helpers ─────────────────── */

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

/* ─────────────────── Scoreboard helpers ─────────────────── */

class _GameId {
  static const wordSearch = 'word_search';
  static const crossword  = 'crossword';
  static const matching   = 'matching';
  static const sudoku     = 'sudoku';
  static const uplingo    = 'uplingo';
  static const scramble   = 'scramble';
}

const Map<String, String> _gameLabel = {
  _GameId.wordSearch: 'Word Search',
  _GameId.crossword : 'Crossword',
  _GameId.matching  : 'Matching',
  _GameId.sudoku    : 'Sudoku',
  _GameId.uplingo   : 'Uplingo',
  _GameId.scramble  : 'Scramble',
};

final List<String> _allGames = [
  _GameId.wordSearch,
  _GameId.crossword,
  _GameId.matching,
  _GameId.sudoku,
  _GameId.uplingo,
  _GameId.scramble,
];

List<DocumentReference<Map<String, dynamic>>> _candidateDocs(String uid, String game) {
  final fs = FirebaseFirestore.instance;
  return [
    fs.collection('users').doc(uid).collection('stats').doc('stress_busters'),
    fs.collection('users').doc(uid).collection('scores').doc(game),
    fs.collection('users').doc(uid).collection('game_stats').doc(game),
  ];
}

List<String> _fieldCandidates(String game) {
  final short = {
    _GameId.wordSearch: 'ws',
    _GameId.crossword : 'cw',
    _GameId.matching  : 'mt',
    _GameId.sudoku    : 'sd',
    _GameId.uplingo   : 'ul',
    _GameId.scramble  : 'sc',
  }[game]!;
  final camel = game.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join();

  // Existing possibilities + the SharedPreferences keys used by the games.
  final keys = <String>[
    // generic/old patterns
    '${game}_best',
    'best_$game',
    '${camel}Best',
    '${short}Best',
    game,
    'best',
    'high',
    'highScore',
    'max',
    'score',
    // new common keys used by mini-games
    'sb_best_$game',
    'sbp_best_$game',
  ];

  // Matching historically also wrote to "*matchhard*" keys — include them.
  if (game == _GameId.matching) {
    keys.addAll([
      'sbp_best_matchhard',
      'sb_best_matchhard',
    ]);
  }

  // Explicitly include Uplingo high-score keys that its page might write.
  if (game == _GameId.uplingo) {
    keys.addAll([
      'uplingo_best',
      'sb_best_uplingo',
      // high score variants
      'uplingo_high',
      'uplingoHigh',
      'uplingo_high_score',
      'uplingoHighScore',
      'sb_high_uplingo',
      'sbp_high_uplingo',
      // sometimes saved as a namespaced generic
      'best_uplingo',
      'high_uplingo',
      'highScore_uplingo',
    ]);
  }

  return keys;
}

Future<int> _readBestForGame(String game) async {
  final user = FirebaseAuth.instance.currentUser;
  int best = 0;

  // Firestore (if signed in)
  if (user != null) {
    for (final doc in _candidateDocs(user.uid, game)) {
      try {
        final snap = await doc.get();
        if (!snap.exists) continue;
        final data = snap.data();
        if (data == null) continue;
        for (final f in _fieldCandidates(game)) {
          final v = data[f];
          if (v is num) best = best < v.toInt() ? v.toInt() : best;
        }
      } catch (_) {}
    }
  }

  // Local SharedPreferences fallback
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final f in _fieldCandidates(game)) {
      final v = prefs.getInt(f);
      if (v != null) best = best < v ? v : best;
    }
  } catch (_) {}

  return best;
}

Future<Map<String, int>> _readAllBest() async {
  final out = <String, int>{};
  for (final g in _allGames) {
    out[g] = await _readBestForGame(g);
  }
  return out;
}

/* ─────────────────── Main page ─────────────────── */

class StressBustersPage extends StatefulWidget {
  const StressBustersPage({super.key});

  @override
  State<StressBustersPage> createState() => _StressBustersPageState();
}

class _StressBustersPageState extends State<StressBustersPage> {
  Map<String, int> _best = { for (final g in _allGames) g: 0 };
  bool _showBoard = false; // default hidden

  @override
  void initState() {
    super.initState();
    _pullScores();
  }

  Future<void> _pullScores() async {
    final m = await _readAllBest();
    if (!mounted) return;
    setState(() => _best = m);
  }

  Future<void> _openGame(WidgetBuilder builder) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    await _pullScores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Stress Busters',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ScoreboardCard(
                  show: _showBoard,
                  scores: _best,
                  onToggle: () => setState(() => _showBoard = !_showBoard),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildListDelegate.fixed([
                    _GameCard(
                      title: 'Word Search',
                      subtitle: 'Swipe to find words',
                      colors: const [Color(0xFFE8F8FF), Color(0xFFB6E3FF)],
                      icon: Icons.grid_on_rounded,
                      iconColor: const Color(0xFF1C638C),
                      onTap: () => _openGame((_) => const WordSearchCategoryPage()),
                    ),
                    _GameCard(
                      title: 'Trivia',
                      subtitle: 'Test your knowledge',
                      colors: const [Color(0xFFE9FFFE), Color(0xFFBDF5F1)],
                      icon: Icons.view_quilt_rounded,
                      iconColor: const Color(0xFF0C5E4D),
                      onTap: () => _openGame((_) => const TriviaPage()),
                    ),
                    _GameCard(
                      title: 'Matching',
                      subtitle: 'Flip & match pairs',
                      colors: const [Color(0xFFFFF6E8), Color(0xFFFFE5BA)],
                      icon: Icons.extension_rounded,
                      iconColor: const Color(0xFF916D00),
                      onTap: () => _openGame((_) => const MatchDifficultPage()),
                    ),
                    _GameCard(
                      title: 'Sudoku',
                      subtitle: 'Relaxed 9×9 play',
                      colors: const [Color(0xFFEFF7FF), Color(0xFFCAE2FF)],
                      icon: Icons.grid_4x4_rounded,
                      iconColor: const Color(0xFF0A4C7A),
                      onTap: () => _openGame((_) => const SudokuPage()),
                    ),
                    _GameCard(
                      title: 'Uplingo',
                      subtitle: 'Six tries, one word',
                      colors: const [Color(0xFFE9FFF4), Color(0xFFC9F2E7)],
                      icon: Icons.emoji_emotions_rounded,
                      iconColor: const Color(0xFF146548),
                      onTap: () => _openGame((_) => const UplingoPage()),
                    ),
                    _GameCard(
                      title: 'Scramble',
                      subtitle: 'Unscramble to solve',
                      colors: const [Color(0xFFF7ECFF), Color(0xFFDAC8FF)],
                      icon: Icons.text_fields_rounded,
                      iconColor: const Color(0xFF5B2785),
                      onTap: () => _openGame((_) => const ScramblePage()),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────── Scoreboard UI ─────────────────── */

class _ScoreboardCard extends StatelessWidget {
  const _ScoreboardCard({
    required this.show,
    required this.scores,
    required this.onToggle,
  });

  final bool show;
  final Map<String, int> scores;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // slightly tighter outer spacing
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        // smaller internal padding
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFBEE8DF), Color(0xFFDCCAF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16), // down from 18
          border: Border.all(color: _ink, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 7)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Color(0xFF0D7C66), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Scoreboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _ink),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                    ),
                    child: Icon(
                      show ? Icons.keyboard_arrow_up_rounded
                           : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: const Color(0xFF0D7C66),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                // tighter list spacing
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: Column(
                  children: _allGames.map((g) {
                    final v = scores[g] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _ink),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3.5)],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sports_esports_rounded, color: Color(0xFF0D7C66), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _gameLabel[g]!,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D7C66),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      '$v',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              crossFadeState: show ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
            if (show)
              const SizedBox(height: 4),
            if (show)
              const Text(
                'Highest scores saved per game.',
                style: TextStyle(color: Colors.black87, fontSize: 12.5),
              ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────── Game Card ─────────────────── */

class _GameCard extends StatelessWidget {
  final String title, subtitle;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _ink, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: iconColor ?? const Color(0xFF0D7C66)),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _ink),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Play',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
