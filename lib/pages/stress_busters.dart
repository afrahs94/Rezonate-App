// lib/pages/stress_busters.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:new_rezonate/main.dart' as app;

// Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Game pages
import 'word_search.dart';
import 'crossword.dart';
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

/* ─────────────────── Scoreboard (Firestore) ─────────────────── */
/*
  users/{uid}/stats/stress_busters
  {
    scores: {
      word_search: <int>, crossword: <int>, matching: <int>,
      sudoku: <int>, uplingo: <int>, scramble: <int>
    },
    updatedAt: <server timestamp>
  }
*/

const _gameKeys = <String>[
  'word_search',
  'crossword',
  'matching',
  'sudoku',
  'uplingo',
  'scramble',
];

const _gameTitles = <String, String>{
  'word_search': 'Word Search',
  'crossword': 'Crossword',
  'matching': 'Matching',
  'sudoku': 'Sudoku',
  'uplingo': 'Uplingo',
  'scramble': 'Scramble',
};

DocumentReference<Map<String, dynamic>> _scoreDoc(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('stress_busters');

/// Call from games to record a new high score.
/// Only overwrites when [score] is greater than stored value.
Future<void> submitHighScore(String gameKey, int score) async {
  if (!_gameKeys.contains(gameKey)) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final ref = _scoreDoc(user.uid);
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final data = (snap.data() ?? <String, dynamic>{});
    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    final current = (scores[gameKey] is num) ? (scores[gameKey] as num).toInt() : 0;
    if (score > current) {
      scores[gameKey] = score;
      tx.set(ref, {
        'scores': scores,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  });
}

/* ─────────────────── Main page ─────────────────── */

class StressBustersPage extends StatefulWidget {
  const StressBustersPage({super.key});

  @override
  State<StressBustersPage> createState() => _StressBustersPageState();
}

class _StressBustersPageState extends State<StressBustersPage> {
  // kept for compatibility with existing onPlayed wiring
  void _recordPlay() {}

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
          // a bit smaller than before
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: CustomScrollView(
            slivers: [
              // Collapsible scoreboard (default hidden each time)
              const SliverToBoxAdapter(child: _ScoreboardHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      onPlayed: _recordPlay,
                      builder: (_) => const WordSearchCategoryPage(),
                    ),
                    _GameCard(
                      title: 'Crossword',
                      subtitle: 'Fill the mini grid',
                      colors: const [Color(0xFFE9FFFE), Color(0xFFBDF5F1)],
                      icon: Icons.view_quilt_rounded,
                      iconColor: const Color(0xFF0C5E4D),
                      onPlayed: _recordPlay,
                      builder: (_) => const CrosswordPage(),
                    ),
                    _GameCard(
                      title: 'Matching',
                      subtitle: 'Flip & match pairs',
                      colors: const [Color(0xFFFFF6E8), Color(0xFFFFE5BA)],
                      icon: Icons.extension_rounded,
                      iconColor: const Color(0xFF916D00),
                      onPlayed: _recordPlay,
                      builder: (_) => const MatchDifficultPage(),
                    ),
                    _GameCard(
                      title: 'Sudoku',
                      subtitle: 'Relaxed 9×9 play',
                      colors: const [Color(0xFFEFF7FF), Color(0xFFCAE2FF)],
                      icon: Icons.grid_4x4_rounded,
                      iconColor: const Color(0xFF0A4C7A),
                      onPlayed: _recordPlay,
                      builder: (_) => const SudokuPage(),
                    ),
                    _GameCard(
                      title: 'Uplingo',
                      subtitle: 'Six tries, one word',
                      colors: const [Color(0xFFE9FFF4), Color(0xFFC9F2E7)],
                      icon: Icons.emoji_emotions_rounded,
                      iconColor: const Color(0xFF146548),
                      onPlayed: _recordPlay,
                      builder: (_) => const UplingoPage(),
                    ),
                    _GameCard(
                      title: 'Scramble',
                      subtitle: 'Unscramble to solve',
                      colors: const [Color(0xFFF7ECFF), Color(0xFFDAC8FF)],
                      icon: Icons.text_fields_rounded,
                      iconColor: const Color(0xFF5B2785),
                      onPlayed: _recordPlay,
                      builder: (_) => const ScramblePage(),
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

/* ─────────────────── Scoreboard header (collapsible) ─────────────────── */

class _ScoreboardHeader extends StatefulWidget {
  const _ScoreboardHeader();

  @override
  State<_ScoreboardHeader> createState() => _ScoreboardHeaderState();
}

class _ScoreboardHeaderState extends State<_ScoreboardHeader>
    with SingleTickerProviderStateMixin {
  // Default hidden each time page opens.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        // smaller overall footprint
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDDEFEA), Color(0xFFE9DDF7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(.75), width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            // Header row with chevron toggle
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    size: 24, color: Color(0xFF0D7C66)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Scoreboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                // round outlined chevron button
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 1),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                    ),
                    child: Icon(
                      _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 22,
                      color: const Color(0xFF0D7C66),
                    ),
                  ),
                ),
              ],
            ),
            // Collapsible content
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                heightFactor: _open ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: user == null
                      ? Row(
                          children: const [
                            Icon(Icons.person_outline, color: Color(0xFF0D7C66)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sign in to save your high scores across all games.',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        )
                      : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _scoreDoc(user.uid).snapshots(),
                          builder: (context, snap) {
                            final scores = Map<String, dynamic>.from(
                                (snap.data?.data()?['scores'] as Map?) ?? const {});
                            final display = <String, int>{
                              for (final k in _gameKeys)
                                k: (scores[k] is num) ? (scores[k] as num).toInt() : 0
                            };

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ScoreGrid(scores: display),
                                const SizedBox(height: 2),
                                const Text(
                                  'Highest scores saved per game.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.black87),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────── Grid / Rows ─────────────────── */

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.scores});
  final Map<String, int> scores;

  @override
  Widget build(BuildContext context) {
    final rows = _gameKeys
        .map((k) => _ScoreRow(title: _gameTitles[k]!, score: scores[k] ?? 0))
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(width: 220, child: Column(children: rows.take(3).toList())),
        SizedBox(width: 220, child: Column(children: rows.skip(3).toList())),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.title, required this.score});
  final String title;
  final int score;

  @override
  Widget build(BuildContext context) {
    final hasScore = score > 0;

    return Container(
      height: 40, // smaller row height
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF5FBFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.black87, width: 1),
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded,
              size: 16, color: hasScore ? const Color(0xFF0D7C66) : Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // score pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D7C66),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$score',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────── Game Card ─────────────────── */

class _GameCard extends StatelessWidget {
  final String title, subtitle;
  final List<Color> colors;
  final IconData icon;
  final WidgetBuilder builder;
  final Color? iconColor;
  final VoidCallback onPlayed;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.builder,
    required this.onPlayed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          onPlayed(); // retained no-op
          Navigator.of(context).push(MaterialPageRoute(builder: builder));
        },
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
