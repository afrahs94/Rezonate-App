// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:new_rezonate/pages/journal.dart';
// import 'package:new_rezonate/pages/settings.dart';

// enum ChartView { weekly, monthly, overall }

// class TrackerEntry {
//   String label;
//   double value; // 0..10
//   TrackerEntry({required this.label, required this.value});
// }

// class HomePage extends StatefulWidget {
//   final String userName;
//   const HomePage({super.key, required this.userName});

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   // Brand colors
//   static const _tealDark = Color(0xFF0D7C66);
//   static const _mint = Color(0xFFBDE8CA);
//   static const _lilac = Color(0xFFD7C3F1);

//   // Data
//   List<TrackerEntry> entries = [TrackerEntry(label: 'Edit', value: 6)];
//   int? selectedTracker; // null => View all
//   ChartView selectedView = ChartView.weekly;

//   String get today => DateFormat('MMM d, yyyy').format(DateTime.now());

//   // --- Editing / Adding ---
//   void _editLabel(int index) async {
//     final ctl = TextEditingController(text: entries[index].label);
//     final name = await showDialog<String>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Edit tracker name'),
//         content: TextField(
//           controller: ctl,
//           decoration: const InputDecoration(hintText: 'Tracker name'),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//           ElevatedButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Save')),
//         ],
//       ),
//     );
//     if (name != null && name.isNotEmpty) {
//       setState(() => entries[index].label = name);
//     }
//   }

//   void _addEntry() async {
//     final ctl = TextEditingController();
//     final name = await showDialog<String>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Add tracker'),
//         content: TextField(
//           controller: ctl,
//           decoration: const InputDecoration(hintText: 'Tracker name'),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//           ElevatedButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Add')),
//         ],
//       ),
//     );
//     if (name != null && name.isNotEmpty) {
//       setState(() {
//         // ➕ Always append to bottom
//         entries.add(TrackerEntry(label: name, value: 5));
//         // keep current selection; user can switch in dropdown or reorder
//       });
//     }
//   }

//   // --- Chart Builder ---
//   Widget _buildChart() {
//     if (selectedTracker == null) {
//       // View all: one bar per tracker
//       return _AllTrackersBarChart(entries: entries);
//     }

//     final idx = selectedTracker!.clamp(0, entries.length - 1);
//     switch (selectedView) {
//       case ChartView.weekly:
//         return _WeeklyBarChart(value: entries[idx].value);
//       case ChartView.monthly:
//         return _WeeklyBarChart(
//           value: entries[idx].value,
//           labels: const ['Wk1', 'Wk2', 'Wk3', 'Wk4', 'Wk5', ''],
//           bars: 5,
//         );
//       case ChartView.overall:
//         return _WeeklyBarChart(
//           value: entries[idx].value,
//           labels: const ['Q1', 'Q2', 'Q3', 'Q4', '', ''],
//           bars: 4,
//         );
//     }
//   }

//   // --- Reorder handler for “View all” list ---
//   void _onReorder(int oldIndex, int newIndex) {
//     setState(() {
//       if (newIndex > oldIndex) newIndex -= 1;
//       final item = entries.removeAt(oldIndex);
//       entries.insert(newIndex, item);

//       // If a specific tracker was selected, keep pointing at same tracker by label match
//       if (selectedTracker != null) {
//         // try to preserve selection by old item reference (no-op here; selection only used when not null)
//         selectedTracker = selectedTracker; // nothing special needed
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // guard selection if list shrinks
//     if (selectedTracker != null && entries.isNotEmpty) {
//       selectedTracker = selectedTracker!.clamp(0, entries.length - 1);
//     }

//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [_lilac, _mint],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               const SizedBox(height: 6),

//               // Header (smaller)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 18.0),
//                 child: Column(
//                   children: [
//                     const SizedBox(height: 4),
//                     const Text('Z', style: TextStyle(fontSize: 36, color: _tealDark, height: 0.9)),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Hello, ${widget.userName.isEmpty ? "User" : widget.userName}',
//                       style: const TextStyle(fontSize: 26, color: _tealDark, fontWeight: FontWeight.w500),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 2),
//                     Text(today, style: TextStyle(color: _tealDark.withOpacity(.75), fontSize: 12)),
//                     const SizedBox(height: 14),

//                     // Streak pill (smaller)
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(.7),
//                         borderRadius: BorderRadius.circular(14),
//                         boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 6, offset: const Offset(0, 3))],
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: const [
//                           Icon(Icons.local_fire_department, color: Colors.deepPurple, size: 18),
//                           SizedBox(width: 6),
//                           Text('3-Day Streak', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 12),

//               // Scrollable Content
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.symmetric(horizontal: 18),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Trackers area:
//                       if (selectedTracker == null)
//                         // VIEW ALL: show reorderable list of capsules
//                         ReorderableListView.builder(
//                           key: const PageStorageKey('reorderable-trackers'),
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           onReorder: _onReorder,
//                           padding: EdgeInsets.zero,
//                           itemCount: entries.length,
//                           itemBuilder: (context, i) {
//                             final e = entries[i];
//                             return _ReorderableCapsule(
//                               key: ValueKey('${e.label}-$i'),
//                               index: i,
//                               child: _HabitCapsule(
//                                 label: e.label,
//                                 value: e.value,
//                                 onChanged: (v) => setState(() => entries[i].value = v),
//                                 onEdit: () => _editLabel(i),
//                               ),
//                             );
//                           },
//                         )
//                       else
//                         // SINGLE: just one capsule for the selected tracker
//                         _HabitCapsule(
//                           label: entries[selectedTracker!].label,
//                           value: entries[selectedTracker!].value,
//                           onChanged: (v) => setState(() => entries[selectedTracker!].value = v),
//                           onEdit: () => _editLabel(selectedTracker!),
//                         ),

//                       // Plus button (smaller) — adds tracker to bottom
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: Padding(
//                           padding: const EdgeInsets.only(top: 8.0, right: 2),
//                           child: GestureDetector(
//                             onTap: _addEntry,
//                             child: Container(
//                               width: 30,
//                               height: 30,
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(15),
//                                 border: Border.all(color: _tealDark, width: 2),
//                               ),
//                               child: const Icon(Icons.add, color: _tealDark, size: 18),
//                             ),
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 10),

//                       // Tabs (Weekly | Monthly | Overall)
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           _TabChip(
//                             label: 'Weekly',
//                             selected: selectedView == ChartView.weekly,
//                             onTap: () => setState(() => selectedView = ChartView.weekly),
//                           ),
//                           const SizedBox(width: 16),
//                           _TabChip(
//                             label: 'Monthly',
//                             selected: selectedView == ChartView.monthly,
//                             onTap: () => setState(() => selectedView = ChartView.monthly),
//                           ),
//                           const SizedBox(width: 16),
//                           _TabChip(
//                             label: 'Overall',
//                             selected: selectedView == ChartView.overall,
//                             onTap: () => setState(() => selectedView = ChartView.overall),
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 8),

//                       // Chart card
//                       Container(
//                         height: 240,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(.55),
//                           borderRadius: BorderRadius.circular(14),
//                           boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8, offset: const Offset(0, 3))],
//                         ),
//                         padding: const EdgeInsets.all(12),
//                         child: _buildChart(),
//                       ),

//                       const SizedBox(height: 10),

//                       // Dropdown UNDER the chart: choose tracker or View all
//                       if (entries.isNotEmpty)
//                         Container(
//                           height: 44,
//                           padding: const EdgeInsets.symmetric(horizontal: 14),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(.85),
//                             borderRadius: BorderRadius.circular(22),
//                             boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 6, offset: const Offset(0, 3))],
//                           ),
//                           child: DropdownButtonHideUnderline(
//                             child: DropdownButton<Object>(
//                               isExpanded: true,
//                               value: selectedTracker ?? 'all',
//                               icon: const Icon(Icons.keyboard_arrow_down, color: _tealDark),
//                               items: [
//                                 for (int i = 0; i < entries.length; i++)
//                                   DropdownMenuItem<Object>(
//                                     value: i,
//                                     child: Text(entries[i].label,
//                                         overflow: TextOverflow.ellipsis,
//                                         style: const TextStyle(color: _tealDark)),
//                                   ),
//                                 const DropdownMenuItem<Object>(
//                                   value: 'all',
//                                   child: Text('View all', style: TextStyle(color: _tealDark, fontWeight: FontWeight.w600)),
//                                 ),
//                               ],
//                               onChanged: (val) {
//                                 setState(() {
//                                   if (val == 'all') {
//                                     selectedTracker = null;
//                                   } else {
//                                     selectedTracker = val as int;
//                                   }
//                                 });
//                               },
//                             ),
//                           ),
//                         ),

//                       const SizedBox(height: 16),
//                     ],
//                   ),
//                 ),
//               ),

//               // Bottom Nav (smaller)
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
//                 child: Container(
//                   height: 56,
//                   decoration: BoxDecoration(
//                     color: _tealDark,
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 10, offset: const Offset(0, 6))],
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _BottomIcon(icon: Icons.home, selected: true, onTap: () {}),
//                       _BottomIcon(
//                         icon: Icons.menu_book_rounded,
//                         selected: false,
//                         onTap: () => Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(builder: (_) => JournalPage(userName: widget.userName)),
//                         ),
//                       ),
//                       _BottomIcon(
//                         icon: Icons.settings,
//                         selected: false,
//                         onTap: () => Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(builder: (_) => SettingsPage(userName: widget.userName)),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Draggable wrapper with a subtle drag handle
// class _ReorderableCapsule extends StatelessWidget {
//   final Widget child;
//   final int index;
//   const _ReorderableCapsule({required Key key, required this.child, required this.index})
//       : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       key: key,
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Expanded(child: child),
//           const SizedBox(width: 8),
//           ReorderableDragStartListener(
//             index: index,
//             child: const Icon(Icons.drag_handle, color: Colors.black45),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Habit capsule shows tracker and slider
// class _HabitCapsule extends StatelessWidget {
//   static const _tealDark = Color(0xFF0D7C66);
//   final String label;
//   final double value;
//   final ValueChanged<double> onChanged;
//   final VoidCallback onEdit;

//   const _HabitCapsule({
//     required this.label,
//     required this.value,
//     required this.onChanged,
//     required this.onEdit,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 62,
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(.7),
//         borderRadius: BorderRadius.circular(31),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8, offset: const Offset(0, 6))],
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 14),
//       child: Row(
//         children: [
//           Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _tealDark)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Stack(
//               alignment: Alignment.centerLeft,
//               children: [
//                 // inactive track
//                 Container(
//                   height: 14,
//                   decoration: BoxDecoration(color: const Color(0xFFBFDCDC), borderRadius: BorderRadius.circular(7)),
//                 ),
//                 // active track
//                 LayoutBuilder(
//                   builder: (_, c) {
//                     final pct = (value.clamp(0, 10) / 10.0);
//                     return Container(
//                       height: 14,
//                       width: c.maxWidth * pct,
//                       decoration: BoxDecoration(color: _tealDark, borderRadius: BorderRadius.circular(7)),
//                     );
//                   },
//                 ),
//                 // Slider overlay
//                 SliderTheme(
//                   data: SliderTheme.of(context).copyWith(
//                     trackHeight: 0,
//                     thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
//                     overlayShape: SliderComponentShape.noOverlay,
//                     activeTrackColor: Colors.transparent,
//                     inactiveTrackColor: Colors.transparent,
//                     thumbColor: Colors.white,
//                   ),
//                   child: Slider(
//                     min: 0,
//                     max: 10,
//                     divisions: 10,
//                     value: value,
//                     onChanged: onChanged,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: _tealDark, size: 20)),
//         ],
//       ),
//     );
//   }
// }

// /// Tab text with underline when selected
// class _TabChip extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;
//   const _TabChip({required this.label, required this.selected, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     const _tealDark = Color(0xFF0D7C66);
//     return InkWell(
//       borderRadius: BorderRadius.circular(8),
//       onTap: onTap,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2),
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 16,
//             color: selected ? _tealDark : Colors.black87,
//             fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
//             decoration: selected ? TextDecoration.underline : TextDecoration.none,
//             decorationColor: _tealDark,
//             decorationThickness: 2,
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Weekly-like bar chart for one tracker (same value across labels)
// class _WeeklyBarChart extends StatelessWidget {
//   final double value;
//   final List<String> labels;
//   final int bars;

//   const _WeeklyBarChart({
//     required this.value,
//     this.labels = const ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'],
//     this.bars = 7,
//   });

//   @override
//   Widget build(BuildContext context) {
//     const _tealDark = Color(0xFF0D7C66);
//     final clamped = value.clamp(0, 10);

//     return BarChart(
//       BarChartData(
//         maxY: 10,
//         minY: 0,
//         gridData: FlGridData(show: false),
//         borderData: FlBorderData(show: false),
//         titlesData: FlTitlesData(
//           leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           bottomTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               getTitlesWidget: (v, meta) {
//                 final i = v.toInt();
//                 if (i < 0 || i >= labels.length) return const SizedBox.shrink();
//                 return SideTitleWidget(axisSide: meta.axisSide, child: Text(labels[i], style: const TextStyle(fontSize: 11)));
//               },
//               reservedSize: 24,
//               interval: 1,
//             ),
//           ),
//         ),
//         barGroups: List.generate(bars, (i) {
//           return BarChartGroupData(
//             x: i,
//             barRods: [
//               BarChartRodData(
//                 toY: clamped.toDouble(),
//                 width: 14,
//                 borderRadius: BorderRadius.circular(6),
//                 color: _tealDark,
//               ),
//             ],
//           );
//         }),
//       ),
//     );
//   }
// }

// /// “View all” chart — one bar per tracker, labels are tracker names
// class _AllTrackersBarChart extends StatelessWidget {
//   final List<TrackerEntry> entries;
//   const _AllTrackersBarChart({required this.entries});

//   @override
//   Widget build(BuildContext context) {
//     const _tealDark = Color(0xFF0D7C66);
//     final labels = entries.map((e) => e.label).toList();
//     return BarChart(
//       BarChartData(
//         maxY: 10,
//         minY: 0,
//         gridData: FlGridData(show: false),
//         borderData: FlBorderData(show: false),
//         titlesData: FlTitlesData(
//           leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//           bottomTitles: AxisTitles(
//             sideTitles: SideTitles(
//               showTitles: true,
//               getTitlesWidget: (v, meta) {
//                 final i = v.toInt();
//                 if (i < 0 || i >= labels.length) return const SizedBox.shrink();
//                 return SideTitleWidget(
//                   axisSide: meta.axisSide,
//                   child: Text(labels[i], style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
//                 );
//               },
//               reservedSize: 28,
//               interval: 1,
//             ),
//           ),
//         ),
//         barGroups: List.generate(entries.length, (i) {
//           final val = entries[i].value.clamp(0, 10);
//           return BarChartGroupData(
//             x: i,
//             barRods: [
//               BarChartRodData(
//                 toY: val.toDouble(),
//                 width: 14,
//                 borderRadius: BorderRadius.circular(6),
//                 color: _tealDark,
//               ),
//             ],
//           );
//         }),
//       ),
//     );
//   }
// }

// class _BottomIcon extends StatelessWidget {
//   final IconData icon;
//   final bool selected;
//   final VoidCallback onTap;
//   const _BottomIcon({required this.icon, required this.selected, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       onPressed: onTap,
//       icon: Icon(icon, color: Colors.white.withOpacity(selected ? 1 : .75), size: 24),
//     );
//   }
// }

// lib/pages/home.dart
// lib/pages/home.dart
// lib/pages/home.dart
// lib/pages/home.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:new_rezonate/main.dart' as app;
import 'journal.dart';
import 'settings.dart';

class Tracker {
  Tracker({required this.id, required this.label, required this.color, this.value = 5});
  final String id;
  String label;
  Color color;
  double value;
}

enum ChartView { weekly, monthly, overall }

class HomePage extends StatefulWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _rnd = Random();
  final List<Tracker> _trackers = [
    Tracker(id: 't0', label: 'Edit', color: const Color(0xFF147C72), value: 6),
  ];

  final Set<String> _selectedForChart = {}; // tracker ids to show
  ChartView _view = ChartView.weekly;

  // naive local “days with any log” to compute streak
  final Set<DateTime> _loggedDays = {};

  int get _streak {
    int s = 0;
    DateTime d = DateTime.now();
    bool has(DateTime x) =>
        _loggedDays.contains(DateTime(x.year, x.month, x.day));
    while (has(d)) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  void _onValueChanged() {
    final now = DateTime.now();
    _loggedDays.add(DateTime(now.year, now.month, now.day));
    setState(() {});
  }

  LinearGradient _bg(BuildContext context) {
    final dark = app.ThemeControllerScope.of(context).isDark;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFFBDA9DB), Color(0xFF3E8F84)]
          : const [Color(0xFFD9C9F0), Color(0xFFBFE9CE)],
    );
  }

  void _addTracker() {
    final id = 't${DateTime.now().microsecondsSinceEpoch}';
    final color = Colors.primaries[_rnd.nextInt(Colors.primaries.length)]
        .shade700;
    setState(() {
      _trackers.add(Tracker(id: id, label: 'Tracker', color: color, value: 5));
    });
  }

  Future<void> _openMultiSelect() async {
    final chosen = Set<String>.from(_selectedForChart);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final dark = app.ThemeControllerScope.of(context).isDark;
        return Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF123A36) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  height: 4,
                  width: 44,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(20))),
              const Text('Select trackers to view',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._trackers.map((t) => CheckboxListTile(
                    value: chosen.contains(t.id),
                    onChanged: (v) {
                      if (v == true) {
                        chosen.add(t.id);
                      } else {
                        chosen.remove(t.id);
                      }
                      setState(() {});
                    },
                    title: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: t.color, shape: BoxShape.circle),
                        ),
                        Text(t.label),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedForChart
                        ..clear()
                        ..addAll(chosen));
                      Navigator.pop(context);
                    },
                    child: const Text('Apply')),
              )
            ],
          ),
        );
      },
    );
  }

  LineChartData _chartData() {
    final sel = _trackers.where((t) => _selectedForChart.contains(t.id)).toList();

    List<double> xPoints;
    switch (_view) {
      case ChartView.weekly:
        xPoints = List.generate(7, (i) => i.toDouble());
        break;
      case ChartView.monthly:
        xPoints = List.generate(4, (i) => i.toDouble());
        break;
      case ChartView.overall:
        xPoints = [0, 1, 2, 3];
        break;
    }

    final bars = sel.map((t) {
      final spots = xPoints
          .map((x) => FlSpot(x, (t.value + _rnd.nextDouble() - 0.5).clamp(1, 10)))
          .toList();
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: t.color,
        barWidth: 3,
        dotData: FlDotData(show: false),
      );
    }).toList();

    return LineChartData(
      minY: 1,
      maxY: 10,
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              reservedSize: 28,
              getTitlesWidget: (v, meta) =>
                  SideTitleWidget(axisSide: meta.axisSide, child: Text(v.toInt().toString()))),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, meta) {
              String label = '';
              if (_view == ChartView.weekly) {
                const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (v.toInt() >= 0 && v.toInt() < d.length) label = d[v.toInt()];
              } else if (_view == ChartView.monthly) {
                const w = ['W1', 'W2', 'W3', 'W4'];
                if (v.toInt() >= 0 && v.toInt() < w.length) label = w[v.toInt()];
              } else {
                label = 'P${v.toInt() + 1}';
              }
              return SideTitleWidget(axisSide: meta.axisSide, child: Text(label));
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: bars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: _bg(context)),
        child: SafeArea(
          child: Column(
            children: [
              // Z logo + hello
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Image.asset(
                  'assets/logo_z.png',
                  height: 22,
                  errorBuilder: (_, __, ___) => Icon(Icons.flash_on, size: 22, color: green.withOpacity(.7)),
                ),
              ),
              const SizedBox(height: 6),
              Text('Hello, ${widget.userName.toLowerCase()}',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text('${_monthName(now.month)} ${now.day}, ${now.year}',
                  style: TextStyle(color: Colors.black.withOpacity(.6))),

              const SizedBox(height: 12),
              // Streak pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.85),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text('$_streak-Day Streak',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Trackers header with + inside
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  children: [
                    const Text('Trackers',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    InkWell(
                      onTap: _addTracker,
                      child: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.9),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.add, color: green),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 8),
              // Reorderable trackers list
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ReorderableListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _trackers.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final t = _trackers.removeAt(oldIndex);
                            _trackers.insert(newIndex, t);
                          });
                        },
                        itemBuilder: (context, i) {
                          final t = _trackers[i];
                          return Container(
                            key: ValueKey(t.id),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.9),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 6)
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 12, color: t.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller:
                                        TextEditingController(text: t.label),
                                    onChanged: (v) => t.label = v,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 10,
                                      thumbShape:
                                          const RoundSliderThumbShape(enabledThumbRadius: 10),
                                    ),
                                    child: Slider(
                                      value: t.value,
                                      min: 1,
                                      max: 10,
                                      divisions: 9,
                                      activeColor: t.color,
                                      onChanged: (v) {
                                        setState(() => t.value = v);
                                        _onValueChanged();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.drag_indicator),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Centered view selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ChartView.values.map((v) {
                          final sel = v == _view;
                          String lbl = switch (v) {
                            ChartView.weekly => 'Weekly',
                            ChartView.monthly => 'Monthly',
                            ChartView.overall => 'Overall',
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextButton(
                              onPressed: () => setState(() => _view = v),
                              child: Text(
                                lbl,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: sel ? TextDecoration.underline : null,
                                  color: sel ? green : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Chart card
                      Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6)
                          ],
                        ),
                        child: _selectedForChart.isEmpty
                            ? const Center(
                                child: Text('Select trackers to view',
                                    style: TextStyle(fontSize: 16)))
                            : LineChart(_chartData()),
                      ),

                      // Multi-select dropdown trigger
                      Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6)
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.filter_list),
                          title: const Text('Select trackers to view'),
                          trailing: const Icon(Icons.expand_more),
                          onTap: _openMultiSelect,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Transparent bottom nav
              const _BottomNav(index: 0,),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int m) =>
      const [
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
      ][m - 1];
}

class _BottomNav extends StatelessWidget {
  final int index;
  const _BottomNav({required this.index});

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF0D7C66);
    Color c(int i) => i == index ? green : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: Icon(Icons.home, color: c(0)),
              onPressed: () {}),
          IconButton(icon: Icon(Icons.menu_book, color: c(1)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JournalPage(userName: '')))),
          IconButton(icon: Icon(Icons.settings, color: c(2)),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsPage(userName: '')))),
        ],
      ),
    );
  }
}
