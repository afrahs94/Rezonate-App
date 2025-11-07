// lib/pages/stress_busters.dart
// Stress Busters – calm themed games, now each on its own page.
// Only Flutter + shared_preferences (already in pubspec). No extra packages.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_rezonate/main.dart' as app;

// Import the six game pages:
import 'word_search.dart';
import 'crossword.dart';
import 'matching.dart';
import 'sudoku.dart';
import 'hangman.dart';
import 'scramble.dart';

/* ─────────────────── Shared theme helpers ─────────────────── */

BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  // Match Tools/Home gradient but slightly softer to feel relaxing.
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

/* ─────────────────── Main page ─────────────────── */

class StressBustersPage extends StatelessWidget {
  const StressBustersPage({super.key});

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
        title: const Text('Stress Busters',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _CalmHeader()),
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
                      subtitle: 'Find all hidden words',
                      colors: const [Color(0xFFE8F8FF), Color(0xFFB6E3FF)],
                      icon: Icons.grid_on_rounded,
                       iconColor: const Color(0xFF1C638C),
                      builder: (_) => const WordSearchPage(),
                    ),
                    _GameCard(
                      title: 'Crossword',
                      subtitle: '7×7 with hints',
                      colors: const [Color(0xFFE9FFFE), Color(0xFFBDF5F1)],
                      icon: Icons.view_quilt_rounded,
                      iconColor: const Color(0xFF0C5E4D),
                      builder: (_) => const CrosswordPage(),
                    ),
                    _GameCard(
                      title: 'Matching',
                      subtitle: 'Flip pairs (animated)',
                      colors: const [Color(0xFFFFF6E8), Color(0xFFFFE5BA)],
                      icon: Icons.extension_rounded,
                      iconColor: const Color(0xFF916D00),
                      builder: (_) => const MatchDifficultPage(),
                    ),
                    _GameCard(
                      title: 'Sudoku',
                      subtitle: 'Relaxing 9×9 logic',
                      colors: const [Color(0xFFEFF7FF), Color(0xFFCAE2FF)],
                      icon: Icons.grid_4x4_rounded,
                      iconColor: const Color(0xFF0A4C7A),
                      builder: (_) => const SudokuPage(),
                    ),
                    _GameCard(
                      title: 'Hangman',
                      subtitle: 'Guess the calm word',
                      colors: const [Color(0xFFE9FFF4), Color(0xFFC9F2E7)],
                      icon: Icons.emoji_emotions_rounded,
                      iconColor: const Color(0xFF146548),
                      builder: (_) => const HangmanPage(),
                    ),
                    _GameCard(
                      title: 'Scramble',
                      subtitle: 'Unscramble letters',
                      colors: const [Color(0xFFF7ECFF), Color(0xFFDAC8FF)],
                      icon: Icons.text_fields_rounded,
                      iconColor: const Color(0xFF5B2785),
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

class _CalmHeader extends StatefulWidget {
  const _CalmHeader();
  @override
  State<_CalmHeader> createState() => _CalmHeaderState();
}

class _CalmHeaderState extends State<_CalmHeader> {
  int plays = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    int total = 0;
    for (final k in p.getKeys()) {
      if (k.startsWith('sbp_')) total += (p.getStringList(k) ?? []).length;
    }
    if (mounted) setState(() => plays = total);
  }

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
            const Icon(Icons.self_improvement_rounded, size: 42, color: Color(0xFF0D7C66)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pick a calm game.\n$plays total plays saved.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title, subtitle;
  final List<Color> colors;
  final IconData icon;
  final WidgetBuilder builder;
  final Color? iconColor;
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.builder,
     this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
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
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
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
                    child: const Text('Play', style: TextStyle(fontWeight: FontWeight.w800)),
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
