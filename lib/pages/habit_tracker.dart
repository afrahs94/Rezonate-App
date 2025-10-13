// lib/pages/habit_tracker.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});
  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

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
    await _logDocFor(day).set(
      {habitId: value, '_ts': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

  Future<void> _editHabit(BuildContext context, String id, String name, Color color) async {
    final nameCtrl = TextEditingController(text: name);
    Color picked = color;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              await _habitsCol.doc(id).update({'name': newName, 'color': picked.value});
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
    final hues = [Colors.amber, Colors.teal, Colors.indigo, Colors.pink, Colors.orange, Colors.cyan];
    return hues[rnd.nextInt(hues.length)];
  }

  // ===== EXACT Tools page gradient (multi-stop) =====
  static const LinearGradient kToolsBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFDFBFF), // near-white
      Color(0xFFEAD7FF), // lavender
      Color(0xFFC7DDEA), // misty blue
      Color(0xFF57C4B3), // teal
    ],
    stops: [0.00, 0.32, 0.66, 1.00],
  );

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 34,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.black26, borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text('Filter trackers on calendar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: docs.map((h) {
                          final id = h.id;
                          final name = (h['name'] as String?) ?? 'Habit';
                          final color = Color((h['color'] as int?) ?? Colors.amber.value);
                          final selected = local.contains(id);
                          return FilterChip(
                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                            avatar: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            label: Text(name, style: const TextStyle(fontSize: 13)),
                            selected: selected,
                            onSelected: (val) {
                              setLocal(() {
                                if (val) {
                                  local.add(id);
                                } else {
                                  local.remove(id);
                                }
                              });
                            },
                            shape: const StadiumBorder(),
                            selectedColor: Colors.white,
                            checkmarkColor: Colors.black,
                            backgroundColor: Colors.white.withOpacity(0.55),
                            side: BorderSide(color: Colors.black.withOpacity(0.08)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setLocal((local..clear()..addAll(docs.map((d) => d.id))) as VoidCallback),
                            child: const Text('Select all'),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => setLocal((local..clear()) as VoidCallback),
                            child: const Text('Clear all'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                if (local.length == docs.length) {
                                  _visibleHabitIds.clear();
                                } else {
                                  _visibleHabitIds
                                    ..clear()
                                    ..addAll(local);
                                }
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
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
          // Keep the title strong and not smaller.
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 28),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _createHabit(context)),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: kToolsBackgroundGradient)),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Month header "October 2025"
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _MonthHeader(
                      focusedDay: _focusedDay,
                      onPrev: () => setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                      }),
                      onNext: () => setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                      }),
                    ),
                  ),
                ),

                // Compact "Filters" button
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.filter_list_rounded, size: 16),
                        label: const Text('Filters', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: Colors.black.withOpacity(0.12)),
                          shape: const StadiumBorder(),
                          backgroundColor: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                ),

                // Weekdays row (today highlighted)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        final isToday = i == todayIndex;
                        return Text(
                          _dowShort(i),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isToday ? const Color(0xFF0D7C66) : Colors.black87,
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // Calendar with colored markers + filters applied
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
                        habitColor[d.id] = Color((d['color'] as int?) ?? Colors.amber.value);
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
                                final passesFilter =
                                    _visibleHabitIds.isEmpty || _visibleHabitIds.contains(key);
                                if (passesFilter && value == true && habitColor.containsKey(key)) {
                                  colors.add(habitColor[key]!);
                                }
                              });
                              if (colors.isNotEmpty) {
                                markers[doc.id] = colors;
                              }
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                            child: TableCalendar(
                              firstDay: DateTime.utc(2010, 1, 1),
                              lastDay: DateTime.utc(2040, 12, 31),
                              focusedDay: _focusedDay,
                              headerVisible: false,
                              daysOfWeekVisible: false,
                              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                              onDaySelected: (sel, foc) {
                                setState(() {
                                  _selectedDay = DateTime(sel.year, sel.month, sel.day);
                                  _focusedDay = foc;
                                });
                              },
                              onPageChanged: (f) => setState(() => _focusedDay = f),
                              startingDayOfWeek: StartingDayOfWeek.sunday,

                              // Make the calendar less squished: taller rows
                              daysOfWeekHeight: 22,
                              rowHeight: 78,

                              calendarStyle: const CalendarStyle(
                                cellPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                outsideDaysVisible: false,
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, _) => _DayCell(
                                  day: day,
                                  dotColors: markers[_docId(day)] ?? const [],
                                ),
                                todayBuilder: (context, day, _) {
                                  // Use darker shade of base surface for today
                                  final base = Theme.of(context).colorScheme.surface.withOpacity(0.80);
                                  return _DayCell(
                                    day: day,
                                    isToday: true,
                                    overrideBackground: _darken(base, .12),
                                    dotColors: markers[_docId(day)] ?? const [],
                                  );
                                },
                                selectedBuilder: (context, day, _) => _DayCell(
                                  day: day,
                                  isSelected: true,
                                  dotColors: markers[_docId(day)] ?? const [],
                                ),
                              ),
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
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(_selectedDay),
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                      stream: _habitsCol.orderBy('createdAt', descending: false).snapshots(),
                      builder: (context, snapshotHabits) {
                        if (!snapshotHabits.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final docs = snapshotHabits.data!.docs;
                        if (docs.isEmpty) return _EmptyState(onAdd: () => _createHabit(context));

                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _logDocFor(_selectedDay).snapshots(),
                          builder: (context, snapshotLog) {
                            final log = snapshotLog.data?.data() ?? <String, dynamic>{};
                            return Column(
                              children: List.generate(docs.length, (i) {
                                final h = docs[i];
                                final id = h.id;
                                final name = (h['name'] as String?) ?? 'Habit';
                                final color = Color((h['color'] as int?) ?? Colors.amber.value);
                                final logged = (log[id] as bool?) ?? false;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _HabitCard(
                                    name: name,
                                    color: color,
                                    logged: logged,
                                    onToggle: (val) => _toggleHabit(id, _selectedDay, val),
                                    onMenuSelected: (value) async {
                                      if (value == 'edit') {
                                        await _editHabit(context, id, name, color);
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

                const SliverFillRemaining(hasScrollBody: false, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Small UI parts =====================

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.focusedDay, required this.onPrev, required this.onNext});
  final DateTime focusedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 22), onPressed: onPrev),
        const SizedBox(width: 6),
        Text(
          DateFormat('MMMM yyyy').format(focusedDay), // "October 2025"
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        const SizedBox(width: 6),
        IconButton(icon: const Icon(Icons.chevron_right_rounded, color: Colors.black, size: 22), onPressed: onNext),
      ],
    );
  }
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
    final number = Text(
      '${day.day}',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );

    final dots = Wrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      children: dotColors
          .map((c) => Container(
                width: 5.5,
                height: 5.5,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ))
          .toList(),
    );

    final baseColor = Theme.of(context).colorScheme.surface.withOpacity(0.80);
    final bgColor = overrideBackground ??
        (isSelected ? const Color(0xFFF0F0F2) : baseColor);

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? Colors.black12 : Colors.transparent,
          width: isSelected ? 1.2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            number,
            const SizedBox(height: 3),
            if (dotColors.isNotEmpty) dots,
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.name,
    required this.color,
    required this.logged,
    required this.onToggle,
    required this.onMenuSelected,
  });

  final String name;
  final Color color;
  final bool logged;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface.withOpacity(0.60);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 7, offset: const Offset(0, 3))],
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 1),
                Text(
                  logged ? 'Logged' : 'Not logged',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: onMenuSelected,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              child: const Padding(
                padding: EdgeInsets.only(right: 4.0),
                child: Icon(Icons.more_vert_rounded, color: Colors.black87, size: 20),
              ),
            ),
            Checkbox(
              value: logged,
              onChanged: (v) => onToggle(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
              side: const BorderSide(width: 1),
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
          const Text('No habits yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
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
            .map((c) => GestureDetector(
                  onTap: () => setState(() => _selected = c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selected == c ? Theme.of(context).colorScheme.primary : Colors.black26,
                        width: _selected == c ? 2.2 : 1,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Select')),
      ],
    );
  }
}
