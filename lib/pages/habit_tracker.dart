// lib/pages/habit_tracker.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:new_rezonate/main.dart' as app;

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});
  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  /// If empty => show all
  final Set<String> _visibleHabitIds = {};

  String get _uid => _auth.currentUser!.uid;

  // ---------- Firestore ----------
  CollectionReference<Map<String, dynamic>> get _habitsCol =>
      _db.collection('users').doc(_uid).collection('habits');
  CollectionReference<Map<String, dynamic>> get _logsCol =>
      _db.collection('users').doc(_uid).collection('habitLogs');
  DocumentReference<Map<String, dynamic>> _logDocFor(DateTime d) =>
      _logsCol.doc(DateFormat('yyyy-MM-dd').format(d));

  // ---------- Helpers ----------
  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _docId(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _toggleHabit(String habitId, DateTime day, bool value) async {
    final today = DateTime.now();
    final isFuture = day.isAfter(DateTime(today.year, today.month, today.day));

    if (isFuture) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can’t log habits for future dates."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _logDocFor(day).set({
      habitId: value,
      '_ts': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _dowShort(int i) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return labels[i % 7];
  }

  Future<void> _createHabit(BuildContext context) async {
    final nameCtrl = TextEditingController();
    Color picked = _randomColor();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Color'),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    final c = await showDialog<Color>(
                      context: context,
                      builder: (_) => _ColorPickerDialog(initial: picked),
                    );
                    if (c != null) setState(() => picked = c);
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: picked,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await _habitsCol.add({
                'name': name,
                'color': picked.value,
                'createdAt': FieldValue.serverTimestamp(),
                'active': true,
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editHabit(
    BuildContext context,
    String id,
    String name,
    Color color,
  ) async {
    final nameCtrl = TextEditingController(text: name);
    Color picked = color;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Color'),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    final c = await showDialog<Color>(
                      context: context,
                      builder: (_) => _ColorPickerDialog(initial: picked),
                    );
                    if (c != null) setState(() => picked = c);
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: picked,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              await _habitsCol.doc(id).update({
                'name': newName,
                'color': picked.value,
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHabit(String id) async {
    await _habitsCol.doc(id).delete();
  }

  Color _randomColor() {
    final rnd = Random();
    final hues = [
      Colors.amber,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.orange,
      Colors.cyan,
    ];
    return hues[rnd.nextInt(hues.length)];
  }

  // ===== EXACT Tools page gradient (multi-stop) =====
  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFFFFFFF), Color(0xFFD7C3F1), Color(0xFF41B3A2)],
    );
  }

  // Slight darken utility for today's cell
  Color _darken(Color c, [double amount = .10]) {
    final hsl = HSLColor.fromColor(c);
    final darker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darker.toColor();
  }

  // Stream all logs for the focused month (by documentId range)
  Stream<QuerySnapshot<Map<String, dynamic>>> _monthLogsStream(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final startId = _docId(first);
    final endId = _docId(last);
    return _logsCol
        .orderBy(FieldPath.documentId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endId)
        .snapshots();
  }

  Future<void> _openFilters() async {
    final snap = await _habitsCol.orderBy('createdAt', descending: false).get();
    final docs = snap.docs;
    if (docs.isEmpty) return;

    final local = _visibleHabitIds.isEmpty
        ? docs.map((d) => d.id).toSet()
        : _visibleHabitIds.toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Filter trackers on calendar',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),

                    // Chips (scroll if many)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: docs.map((h) {
                            final id = h.id;
                            final name = (h['name'] as String?) ?? 'Habit';
                            final color = Color((h['color'] as int?) ?? Colors.amber.value);
                            final selected = local.contains(id);

                            return FilterChip(
                              avatar: CircleAvatar(backgroundColor: color, radius: 6),
                              label: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              selected: selected,
                              onSelected: (v) => setLocal(() {
                                v ? local.add(id) : local.remove(id);
                              }),
                              showCheckmark: true,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: (selected
                                    ? Colors.black.withOpacity(.15)
                                    : Colors.black12),
                              ),
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: Colors.white,
                              checkmarkColor: Colors.black87,
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0x1A000000)),
                    const SizedBox(height: 12),

                    // Footer actions
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setLocal(() {
                            local
                              ..clear()
                              ..addAll(docs.map((d) => d.id));
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0D7C66),
                          ),
                          child: const Text('Select all'),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => setLocal(() => local.clear()),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0D7C66),
                          ),
                          child: const Text('Clear all'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              if (local.length == docs.length) {
                                _visibleHabitIds.clear(); // empty => show all
                              } else {
                                _visibleHabitIds
                                  ..clear()
                                  ..addAll(local);
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Apply'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Index of *today* in our Sun..Sat header (Mon=1..Sun=7 in Dart)
    final todayIndex = DateTime.now().weekday % 7;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Habit Tracker',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 28,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () {
                setState(() {
                  final today = DateTime.now();
                  _focusedDay = today;
                  _selectedDay = DateTime(today.year, today.month, today.day);
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.6),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _bg(context)),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // >>> Combined line: Month/Year on LEFT + Filters button on RIGHT
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        // Left: month navigation + label
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                          onPressed: () => setState(() {
                            _focusedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month - 1,
                              1,
                            );
                          }),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMMM yyyy').format(_focusedDay),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                          onPressed: () => setState(() {
                            _focusedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month + 1,
                              1,
                            );
                          }),
                        ),

                        const Spacer(),

                        // Right: Filters button (unchanged)
                        OutlinedButton.icon(
                          onPressed: _openFilters,
                          icon: const Icon(Icons.filter_list_rounded, size: 16),
                          label: const Text(
                            'Filters',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            side: BorderSide(
                              color: Colors.black.withOpacity(0.12),
                            ),
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Weekdays row (today highlighted)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columnWidth = constraints.maxWidth / 7;
                        final todayIndex = DateTime.now().weekday % 7;
                        return Row(
                          children: List.generate(7, (i) {
                            final isToday = i == todayIndex;
                            return SizedBox(
                              width: columnWidth,
                              child: Center(
                                child: Text(
                                  _dowShort(i),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isToday
                                        ? const Color(0xFF0D7C66)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),

                // Calendar with squared cells
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _habitsCol.snapshots(),
                    builder: (context, habitsSnap) {
                      if (!habitsSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(22),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final habitColor = <String, Color>{};
                      for (final d in habitsSnap.data!.docs) {
                        habitColor[d.id] =
                            Color((d['color'] as int?) ?? Colors.amber.value);
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _monthLogsStream(_focusedDay),
                        builder: (context, logsSnap) {
                          final markers = <String, List<Color>>{};
                          if (logsSnap.hasData) {
                            for (final doc in logsSnap.data!.docs) {
                              final data = doc.data();
                              final colors = <Color>[];
                              data.forEach((key, value) {
                                if (key == '_ts') return;
                                final passesFilter = _visibleHabitIds.isEmpty ||
                                    _visibleHabitIds.contains(key);
                                if (passesFilter &&
                                    value == true &&
                                    habitColor.containsKey(key)) {
                                  colors.add(habitColor[key]!);
                                }
                              });
                              if (colors.isNotEmpty) {
                                markers[doc.id] = colors;
                              }
                            }
                          }

                          // >>> Square-cell sizing based on available width
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                            child: LayoutBuilder(
                              builder: (context, cons) {
                                // cell margin = 4 (see _DayCell), 7 columns => total gaps ~ 8*4 = 32
                                final cellSize = (cons.maxWidth - 32) / 7;
                                return TableCalendar(
                                  firstDay: DateTime.utc(2010, 1, 1),
                                  lastDay: DateTime.utc(2040, 12, 31),
                                  focusedDay: _focusedDay,
                                  headerVisible: false,
                                  daysOfWeekVisible: false,
                                  selectedDayPredicate: (d) =>
                                      isSameDay(d, _selectedDay),
                                  onDaySelected: (sel, foc) {
                                    setState(() {
                                      _selectedDay =
                                          DateTime(sel.year, sel.month, sel.day);
                                      _focusedDay = foc;
                                    });
                                  },
                                  onPageChanged: (f) =>
                                      setState(() => _focusedDay = f),
                                  startingDayOfWeek: StartingDayOfWeek.sunday,

                                  // Square: rowHeight ~= cell width
                                  rowHeight: cellSize,

                                  daysOfWeekHeight: 20,
                                  calendarStyle: const CalendarStyle(
                                    // reduced padding so cells can be square
                                    cellPadding:
                                        EdgeInsets.symmetric(horizontal: 2),
                                    outsideDaysVisible: false,
                                  ),
                                  calendarBuilders: CalendarBuilders(
                                    defaultBuilder: (context, day, _) => _DayCell(
                                      day: day,
                                      dotColors: markers[_docId(day)] ?? const [],
                                    ),
                                    todayBuilder: (context, day, _) {
                                      final base = Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withOpacity(0.80);
                                      return _DayCell(
                                        day: day,
                                        isToday: true,
                                        overrideBackground: _darken(base, .12),
                                        dotColors:
                                            markers[_docId(day)] ?? const [],
                                      );
                                    },
                                    selectedBuilder:
                                        (context, day, _) => _DayCell(
                                      day: day,
                                      isSelected: true,
                                      dotColors:
                                          markers[_docId(day)] ?? const [],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Habits header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Text(
                          'Habits',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.add_rounded,
                            color: Color.fromARGB(255, 0, 0, 0),
                            size: 28,
                          ),
                          onPressed: () => _createHabit(context),
                          tooltip: 'Add habit',
                        ),
                      ],
                    ),
                  ),
                ),

                // Smaller Habit list
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                  sliver: SliverToBoxAdapter(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _habitsCol
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snapshotHabits) {
                        if (!snapshotHabits.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final docs = snapshotHabits.data!.docs;
                        if (docs.isEmpty) {
                          return _EmptyState(onAdd: () => _createHabit(context));
                        }

                        return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _logDocFor(_selectedDay).snapshots(),
                          builder: (context, snapshotLog) {
                            final log =
                                snapshotLog.data?.data() ?? <String, dynamic>{};
                            return Column(
                              children: List.generate(docs.length, (i) {
                                final h = docs[i];
                                final id = h.id;
                                final name =
                                    (h['name'] as String?) ?? 'Habit';
                                final color = Color(
                                    (h['color'] as int?) ?? Colors.amber.value);
                                final logged = (log[id] as bool?) ?? false;
                                final isFuture =
                                    _selectedDay.isAfter(DateTime.now());

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _HabitCard(
                                    name: name,
                                    color: color,
                                    logged: logged,
                                    isFuture: isFuture,
                                    onToggle: (val) =>
                                        _toggleHabit(id, _selectedDay, val),
                                    onMenuSelected: (value) async {
                                      if (value == 'edit') {
                                        await _editHabit(
                                            context, id, name, color);
                                      } else if (value == 'delete') {
                                        await _deleteHabit(id);
                                      }
                                    },
                                  ),
                                );
                              }),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Small UI parts =====================

Widget _dotSized(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );

Widget _moreBadge(int n, {double fontSize = 10}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('+$n',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700)),
    );

Widget _buildMarkersSized(
  List<Color> colors, {
  int maxVisible = 4,
  double dot = 6,
  double spacing = 3,
  double top = 4,
}) {
  if (colors.isEmpty) return const SizedBox.shrink();
  maxVisible = maxVisible.clamp(2, 6);

  final children = <Widget>[];
  if (colors.length <= maxVisible) {
    children.addAll(colors.take(maxVisible).map((c) => _dotSized(c, dot)));
  } else {
    // (maxVisible - 1) dots + "+N"
    final overflow = colors.length - (maxVisible - 1);
    children.addAll(colors.take(maxVisible - 1).map((c) => _dotSized(c, dot)));
    children.add(_moreBadge(overflow, fontSize: dot + 4 /* ~10 */));
  }

  return Padding(
    padding: EdgeInsets.only(top: top),
    child: Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: children,
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.isSelected = false,
    this.isToday = false,
    this.dotColors = const [],
    this.overrideBackground,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final List<Color> dotColors;
  final Color? overrideBackground;

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surface.withOpacity(0.80);
    final bgColor =
        overrideBackground ?? (isSelected ? const Color(0xFFDADADA) : baseColor);

    // >>> Squared, calendar-like cell styling (tight radius, hairline grid)
    return Container(
      margin: const EdgeInsets.all(4), // tighter gaps so cells read as a grid
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6), // closer to a square
        border: Border.all(
          color: Colors.black.withOpacity(0.08), // subtle grid lines
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final compact = h < 52;

          final number = Text(
            '${day.day}',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          );

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                number,
                _buildMarkersSized(
                  dotColors,
                  maxVisible: compact ? 3 : 4,
                  dot: compact ? 5.0 : 6.0,
                  spacing: compact ? 2.0 : 3.0,
                  top: compact ? 2.0 : 4.0,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.name,
    required this.color,
    required this.logged,
    required this.isFuture,
    required this.onToggle,
    required this.onMenuSelected,
  });

  final String name;
  final Color color;
  final bool logged;
  final bool isFuture;

  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface.withOpacity(0.60);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: onMenuSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              child: const Padding(
                padding: EdgeInsets.only(right: 4.0),
                child: Icon(
                  Icons.more_vert_rounded,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ),
            Checkbox(
              value: logged,
              onChanged: isFuture ? null : (v) => onToggle(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              side: BorderSide(
                color: isFuture
                    ? Colors.grey.withOpacity(0.5)
                    : color,
                width: 1,
              ),
              fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) return color;
                return Colors.transparent;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'No habits yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first habit to start tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Habit', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});
  final Color initial;
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;
  final List<Color> _palette = const [
    Color(0xFFFFC107),
    Color(0xFF0D7C66),
    Color(0xFF3F51B5),
    Color(0xFFE91E63),
    Color(0xFFFF7043),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFF9C27B0),
    Color(0xFF795548),
    Color(0xFFFFD54F),
    Color(0xFF00796B),
    Color(0xFF303F9F),
    Color(0xFFD81B60),
    Color(0xFFFF8A65),
    Color(0xFF00ACC1),
    Color(0xFF7CB342),
    Color(0xFF8E24AA),
    Color(0xFF6D4C41),
    Color(0xFFFFEB3B),
    Color(0xFF009688),
    Color(0xFF5C6BC0),
    Color(0xFFF06292),
    Color(0xFFFFA726),
    Color.fromARGB(255, 0, 225, 255),
    Color.fromARGB(255, 135, 233, 22),
    Color.fromARGB(255, 201, 29, 231),
    Color.fromARGB(255, 0, 0, 0),
  ];
  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: _palette
            .map(
              (c) => GestureDetector(
                onTap: () => setState(() => _selected = c),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selected == c
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black26,
                      width: _selected == c ? 2.2 : 1,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
