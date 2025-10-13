// lib/pages/tools.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_rezonate/main.dart' as app;

import 'home.dart';
import 'journal.dart';
import 'vision_board.dart';
import 'habit_tracker.dart';

// These should match the files/classes you already have in the project.
import 'sleep_tracker.dart';
import 'meditation.dart';
import 'tips.dart';
import 'resources.dart';
import 'exercises.dart';        // <-- Exercises page (class: ExercisesPage)
import 'ai_chatbot.dart';      // <-- AI chatbot page (class: AIChatbotPage)
import 'stress_busters.dart';  // <-- Stress Busters page (class: StressBustersPage)
import 'affirmations.dart';    // <-- Affirmations page (class: AffirmationsPage)

class NoTransitionPageRoute<T> extends MaterialPageRoute<T> {
  NoTransitionPageRoute({required WidgetBuilder builder}) : super(builder: builder);
  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> b, Widget child) => child;
}

BoxDecoration _bg(BuildContext context) {
  final dark = app.ThemeControllerScope.of(context).isDark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
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

    const double expandedHeight = 96.0; // compact header to move content up

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _bg(context),
        child: SafeArea(
          top: true,
          bottom: true, // <-- match Home: include bottom inset so nav isn't too low
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      snap: false,
                      expandedHeight: expandedHeight,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      centerTitle: false,
                      automaticallyImplyLeading: false,
                      title: null, // remove compact top-left title
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final double tRaw = (constraints.biggest.height - kToolbarHeight) /
                              (expandedHeight - kToolbarHeight);
                          final double t = tRaw.clamp(0.0, 1.0);
                          final double size = 24.0 + (26.0 - 24.0) * t;

                          return FlexibleSpaceBar(
                            titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 10),
                            expandedTitleScale: 1.0,
                            title: IgnorePointer(
                              child: Opacity(
                                opacity: t,
                                child: Text(
                                  'Tools',
                                  style: TextStyle(
                                    fontSize: size,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Search bar — compact spacing
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
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

                    // Grid — compact top/bottom padding
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          childAspectRatio: isWide ? 1.05 : 1.10,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final t = _filteredItems.elementAt(i);
                            return _ToolOutlineTile(
                              label: t.label,
                              icon: t.icon,
                              semanticLabel: '${t.label} tool',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).push(
                                  NoTransitionPageRoute(builder: (_) => t.page),
                                );
                              },
                            );
                          },
                          childCount: _filteredItems.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom nav — identical padding/sizing/placement to Home
              Container(
                color: Colors.transparent,
                child: _BottomNav(index: 2, userName: widget.userName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- Widgets --------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final outlineColor = Colors.black.withOpacity(dark ? 0.7 : 1.0);

    return SizedBox(
      height: 46, // slightly shorter to pull content up
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search tools…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: (dark ? Colors.black : Colors.white).withOpacity(0.50),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );
  }
}

/// Outline-only, tactile tile with hover/focus glow and press depth + haptics on tap.
class _ToolOutlineTile extends StatefulWidget {
  const _ToolOutlineTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  State<_ToolOutlineTile> createState() => _ToolOutlineTileState();
}

class _ToolOutlineTileState extends State<_ToolOutlineTile> {
  bool _hovering = false;
  bool _pressed = false;
  bool _focused = false;

  double get _scale => _pressed ? 0.985 : 1.0;

  @override
  Widget build(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    final outlineBase = Colors.black.withOpacity(dark ? 0.7 : 1.0);
    final outlineColor = _focused
        ? outlineBase.withOpacity(0.95)
        : (_hovering ? outlineBase.withOpacity(0.9) : outlineBase);

    final width = MediaQuery.of(context).size.width;
    final iconSize = width > 820 ? 40.0 : 34.0;
    final fontSize = width > 820 ? 15.5 : 14.5;

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: widget.semanticLabel ?? widget.label,
        child: Tooltip(
          message: widget.label,
          waitDuration: const Duration(milliseconds: 400),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: outlineColor,
                      width: _focused ? 1.6 : (_hovering ? 1.3 : 1.0),
                    ),
                  ),
                  shadows: _pressed
                      ? const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]
                      : (_hovering || _focused
                          ? const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]
                          : const []),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTapDown: (_) {
                      setState(() => _pressed = true);
                      HapticFeedback.selectionClick();
                    },
                    onTapCancel: () => setState(() => _pressed = false),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTap: widget.onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 110),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.icon, size: iconSize, color: const Color(0xFF0D7C66)),
                              const SizedBox(height: 10),
                              Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: fontSize,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------- Data --------------------

class _ToolItem {
  final String label;
  final IconData icon;
  final Widget page;
  const _ToolItem(this.label, this.icon, this.page);
}

final _items = <_ToolItem>[
  const _ToolItem('Vision Board', Icons.dashboard_customize_rounded, VisionBoardPage()),
  const _ToolItem('Habit Tracker', Icons.checklist_rtl_rounded, HabitTrackerPage()),
  const _ToolItem('Sleep Tracker', Icons.bedtime_rounded, SleepTrackerPage()),
  const _ToolItem('Meditation', Icons.self_improvement_rounded, MeditationPage()),
  const _ToolItem('Tips', Icons.tips_and_updates_rounded, TipsPage()),
  const _ToolItem('Resources', Icons.library_books_rounded, ResourcesPage()),
  const _ToolItem('Exercises', Icons.fitness_center_rounded, ExercisesPage()),
  const _ToolItem('AI Chatbot', Icons.forum_rounded, AIChatbotPage()),
  const _ToolItem('Stress Busters', Icons.videogame_asset_rounded, StressBustersPage()),
  const _ToolItem('Affirmations', Icons.auto_awesome_rounded, AffirmationsPage()),
];

// -------------------- Bottom Nav (identical to Home) --------------------

class _BottomNav extends StatelessWidget {
  final int index; // 0=home, 1=journal, 2=tools
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

    // Match Home: Padding(bottom: 8, top: 6) + Row(spaceEvenly)
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: c(0)),
            onPressed: index == 0
                ? null
                : () => Navigator.pushReplacement(
                      context,
                      NoTransitionPageRoute(builder: (_) => HomePage(userName: userName)),
                    ),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: c(1)),
            onPressed: index == 1
                ? null
                : () => Navigator.pushReplacement(
                      context,
                      NoTransitionPageRoute(builder: (_) => JournalPage(userName: userName)),
                    ),
          ),
          IconButton(
            icon: Icon(Icons.dashboard, color: c(2)),
            onPressed: () {}, // already on Tools
          ),
        ],
      ),
    );
  }
}
