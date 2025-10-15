// lib/pages/tools.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_rezonate/main.dart' as app;

import 'home.dart';
import 'journal.dart';
import 'vision_board.dart';
import 'habit_tracker.dart';
import 'sleep_tracker.dart';
import 'meditation.dart';
import 'tips.dart';
import 'resources.dart';
import 'exercises.dart';
import 'ai_chatbot.dart';
import 'stress_busters.dart';
import 'affirmations.dart';

/// Page transition with no animation
class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder})
    : super(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> a,
    Animation<double> b,
    Widget child,
  ) => child;
}

/// Background gradient
BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors:
          dark
              ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
              : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    ),
  );
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key, required this.userName});
  final String userName;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Iterable<_ToolItem> get _filteredItems {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((t) => t.label.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 820;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      automaticallyImplyLeading: false,
                      pinned: true,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final tRaw =
                              (constraints.biggest.height - kToolbarHeight) /
                              (96 - kToolbarHeight);
                          final t = tRaw.clamp(0.0, 1.0);
                          final size = 24.0 + (26.0 - 24.0) * t;
                          return FlexibleSpaceBar(
                            titlePadding: const EdgeInsetsDirectional.only(
                              start: 16,
                              bottom: 10,
                            ),
                            expandedTitleScale: 1.0,
                            title: IgnorePointer(child: Opacity(opacity: t)),
                          );
                        },
                      ),
                    ),

                    /// Search bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _SearchField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onClear: () {
                            _searchCtrl.clear();
                            _searchFocus.requestFocus();
                            HapticFeedback.selectionClick();
                          },
                        ),
                      ),
                    ),

                    /// Tool grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          childAspectRatio: isWide ? 1.05 : 1.10,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final t = _filteredItems.elementAt(i);
                          return _ToolTile(
                            label: t.label,
                            icon: t.icon,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).push(
                                NoTransitionPageRoute(builder: (_) => t.page),
                              );
                            },
                          );
                        }, childCount: _filteredItems.length),
                      ),
                    ),
                  ],
                ),
              ),
              _BottomNav(index: 2, userName: widget.userName),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------- Search Field --------------------

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final baseColor =
        (dark
            ? const Color.fromARGB(134, 0, 0, 0)
            : const Color.fromARGB(146, 255, 255, 255));
    final outlineColor = const Color.fromARGB(120, 54, 113, 56);

    return AnimatedScale(
      scale: _focused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: SizedBox(
        height: 48,
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search tools…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  widget.controller.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear',
                        onPressed: widget.onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              filled: true,
              fillColor: baseColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: outlineColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: outlineColor, width: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// -------------------- Tool Tile --------------------

class _ToolTile extends StatefulWidget {
  const _ToolTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final color = const Color(0xFF0D7C66);
    final bg =
        dark
            ? Colors.black.withOpacity(0.2)
            : const Color.fromARGB(213, 255, 255, 255);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color.fromARGB(120, 80, 80, 80), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 38, color: color),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// -------------------- Data --------------------

class _ToolItem {
  final String label;
  final IconData icon;
  final Widget page;
  const _ToolItem(this.label, this.icon, this.page);
}

final _items = <_ToolItem>[
  const _ToolItem(
    'Vision Board',
    Icons.dashboard_customize_rounded,
    VisionBoardPage(),
  ),
  const _ToolItem(
    'Habit Tracker',
    Icons.checklist_rtl_rounded,
    HabitTrackerPage(),
  ),
  const _ToolItem('Sleep Tracker', Icons.bedtime_rounded, SleepTrackerPage()),
  const _ToolItem(
    'Meditation',
    Icons.self_improvement_rounded,
    MeditationPage(),
  ),
  const _ToolItem('Tips', Icons.tips_and_updates_rounded, TipsPage()),
  const _ToolItem('Resources', Icons.library_books_rounded, ResourcesPage()),
  const _ToolItem('Exercises', Icons.fitness_center_rounded, ExercisesPage()),
  const _ToolItem('AI Chatbot', Icons.forum_rounded, AIChatbotPage()),
  const _ToolItem(
    'Stress Busters',
    Icons.videogame_asset_rounded,
    StressBustersPage(),
  ),
  const _ToolItem(
    'Affirmations',
    Icons.auto_awesome_rounded,
    AffirmationsPage(),
  ),
];

/// -------------------- Bottom Nav --------------------

class _BottomNav extends StatelessWidget {
  final int index;
  final String userName;
  const _BottomNav({required this.index, required this.userName});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7C66);
    const darkSelected = Color(0xFFBDA9DB);

    Color c(int i) {
      final dark = app.ThemeControllerScope.of(context).isDark;
      if (i == index) return dark ? darkSelected : green;
      return Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: c(0)),
            onPressed:
                index == 0
                    ? null
                    : () => Navigator.pushReplacement(
                      context,
                      NoTransitionPageRoute(
                        builder: (_) => HomePage(userName: userName),
                      ),
                    ),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: c(1)),
            onPressed:
                index == 1
                    ? null
                    : () => Navigator.pushReplacement(
                      context,
                      NoTransitionPageRoute(
                        builder: (_) => JournalPage(userName: userName),
                      ),
                    ),
          ),
          IconButton(
            icon: Icon(Icons.dashboard, color: c(2)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
