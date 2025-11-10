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

/* ─────────────────── Firestore helpers ─────────────────── */

DocumentReference<Map<String, dynamic>> _playsDoc(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('stress_busters');

Future<int> _fetchTotalPlays() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 0;
  final snap = await _playsDoc(user.uid).get();
  final data = snap.data();
  return (data?['totalPlays'] ?? 0 as num).toInt();
}

Future<void> _incrementTotalPlays() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await _playsDoc(user.uid).set(
    {'totalPlays': FieldValue.increment(1)},
    SetOptions(merge: true),
  );
}

/* ─────────────────── Main page ─────────────────── */

class StressBustersPage extends StatefulWidget {
  const StressBustersPage({super.key});

  @override
  State<StressBustersPage> createState() => _StressBustersPageState();
}

class _StressBustersPageState extends State<StressBustersPage> {
  // Local notifier for the header count.
  final ValueNotifier<int> _plays = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _initPlays();
  }

  Future<void> _initPlays() async {
    final total = await _fetchTotalPlays();
    _plays.value = total;
  }

  void _recordPlay() {
    _plays.value = _plays.value + 1; // instant UI update
    _incrementTotalPlays();          // async Firestore write
  }

  @override
  void dispose() {
    _plays.dispose();
    super.dispose();
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
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _CalmHeader(playsNotifier: _plays)),
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
                      subtitle: 'Find the hidden words',
                      colors: const [Color(0xFFE8F8FF), Color(0xFFB6E3FF)],
                      icon: Icons.grid_on_rounded,
                      iconColor: const Color(0xFF1C638C),
                      onPlayed: _recordPlay,
                      builder: (_) => const WordSearchCategoryPage(),
                    ),
                    _GameCard(
                      title: 'Crossword',
                      subtitle: 'Quick 7×7 mini',
                      colors: const [Color(0xFFE9FFFE), Color(0xFFBDF5F1)],
                      icon: Icons.view_quilt_rounded,
                      iconColor: const Color(0xFF0C5E4D),
                      onPlayed: _recordPlay,
                      builder: (_) => const CrosswordPage(),
                    ),
                    _GameCard(
                      title: 'Matching',
                      subtitle: 'Match the card pairs',
                      colors: const [Color(0xFFFFF6E8), Color(0xFFFFE5BA)],
                      icon: Icons.extension_rounded,
                      iconColor: const Color(0xFF916D00),
                      onPlayed: _recordPlay,
                      builder: (_) => const MatchDifficultPage(),
                    ),
                    _GameCard(
                      title: 'Sudoku',
                      subtitle: 'Classic 9×9',
                      colors: const [Color(0xFFEFF7FF), Color(0xFFCAE2FF)],
                      icon: Icons.grid_4x4_rounded,
                      iconColor: const Color(0xFF0A4C7A),
                      onPlayed: _recordPlay,
                      builder: (_) => const SudokuPage(),
                    ),
                    _GameCard(
                      title: 'Uplingo',
                      subtitle: 'Guess the secret word',
                      colors: const [Color(0xFFE9FFF4), Color(0xFFC9F2E7)],
                      icon: Icons.emoji_emotions_rounded,
                      iconColor: const Color(0xFF146548),
                      onPlayed: _recordPlay,
                      builder: (_) => const UplingoPage(),
                    ),
                    _GameCard(
                      title: 'Scramble',
                      subtitle: 'Unscramble the letters',
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

/* ─────────────────── Calm header ─────────────────── */

class _CalmHeader extends StatelessWidget {
  const _CalmHeader({required this.playsNotifier});
  final ValueNotifier<int> playsNotifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFBEE8DF), Color(0xFFDCCAF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ink, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.self_improvement_rounded,
              size: 42,
              color: Color(0xFF0D7C66),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: playsNotifier,
                builder: (_, total, __) => Text(
                  'Pick a calm game.\n$total total plays saved.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
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
          onPlayed(); // bump local + Firestore
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
