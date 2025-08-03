// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:new_rezonate/pages/journal.dart';
import 'package:new_rezonate/pages/settings.dart';

enum ChartView { weekly, monthly, overall }

class TrackerEntry {
  String label;
  double value;
  TrackerEntry({required this.label, required this.value});
}

class HomePage extends StatefulWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TrackerEntry> entries = [TrackerEntry(label: 'Mental Health', value: 5)];
  ChartView selectedView = ChartView.weekly;
  final lineColors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.yellow];

  String get today => DateFormat('MMM d, yyyy').format(DateTime.now());
  String get monthLabel => DateFormat('MMMM yyyy').format(DateTime.now());
  DateTime get startOfWeek {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }
  DateTime get endOfWeek => startOfWeek.add(Duration(days: 6));

  void _editLabel(int index) async {
    final ctl = TextEditingController(text: entries[index].label);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'Enter label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) setState(() => entries[index].label = name);
  }

  void _addEntry() => setState(() => entries.add(TrackerEntry(label: 'New Entry', value: 5)));

  LineChartData _buildWeeklyData() => LineChartData(
        minY: 1, maxY: 10, gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                    int i = v.toInt();
                    return (i>=0 && i<days.length)
                        ? SideTitleWidget(axisSide: meta.axisSide, child: Text(days[i], style: TextStyle(fontSize:10, color:Colors.teal.shade900)))
                        : const SizedBox.shrink();
                  })),
        ),
        lineBarsData: entries.asMap().entries.map((e) {
          int idx = e.key;
          return LineChartBarData(
            spots: List.generate(7, (i) => FlSpot(i.toDouble(), e.value.value)),
            isCurved: true,
            barWidth: 3,
            color: lineColors[idx % lineColors.length],
            dotData: FlDotData(show: true),
          );
        }).toList(),
      );

  LineChartData _buildMonthlyData() => LineChartData(
        minY: 1, maxY: 10, gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    const weeks = ['Wk 1','Wk 2','Wk 3','Wk 4'];
                    int i = v.toInt();
                    return (i>=0 && i<weeks.length)
                        ? SideTitleWidget(axisSide: meta.axisSide, child: Text(weeks[i], style: TextStyle(fontSize:10, color:Colors.teal.shade900)))
                        : const SizedBox.shrink();
                  })),
        ),
        lineBarsData: entries.asMap().entries.map((e) {
          int idx = e.key;
          return LineChartBarData(
            spots: List.generate(4, (i) => FlSpot(i.toDouble(), e.value.value)),
            isCurved: true,
            barWidth: 3,
            color: lineColors[idx % lineColors.length],
            dotData: FlDotData(show: true),
          );
        }).toList(),
      );

  LineChartData _buildOverallData() => LineChartData(
        minY: 1, maxY: 10, gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: entries.asMap().entries.map((e) {
          int idx = e.key;
          return LineChartBarData(
            spots: [FlSpot(0, e.value.value), FlSpot(1, e.value.value)],
            isCurved: false,
            barWidth: 3,
            color: lineColors[idx % lineColors.length],
            dotData: FlDotData(show: true),
          );
        }).toList(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
            Color(0xFFE0FEFF),
            Color(0xFF68D8D6),
          ]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, ${widget.userName}',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                  const SizedBox(height: 4),
                  Text(today, style: TextStyle(fontSize: 16, color: Colors.teal.shade700)),
                ]),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Slider rows
                      ...entries.asMap().entries.map((e) {
                        int i = e.key;
                        var ent = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(children: [
                            Expanded(
                              child: Row(children: [
                                Expanded(
                                  child: Text(ent.label,
                                      style: TextStyle(fontSize: 16, color: Colors.teal.shade900)),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.teal.shade700),
                                  onPressed: () => _editLabel(i),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 12,
                                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                                  activeTrackColor: Colors.teal.shade700,
                                  inactiveTrackColor: Colors.teal.shade200,
                                ),
                                child: Slider(
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  value: ent.value,
                                  onChanged: (v) => setState(() => ent.value = v),
                                ),
                              ),
                            ),
                          ]),
                        );
                      }),

                      const SizedBox(height: 8),
                      Center(
                        child: IconButton(
                          iconSize: 40,
                          color: Colors.teal.shade700,
                          icon: Icon(Icons.add_circle_outline),
                          onPressed: _addEntry,
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Chart controls
                      Text(monthLabel,
                          style:
                              TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                      const SizedBox(height: 4),
                      Text('${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}',
                          style: TextStyle(fontSize: 14, color: Colors.teal.shade700)),
                      const SizedBox(height: 8),
                      Row(
                        children: ChartView.values.map((view) {
                          final label = view.toString().split('.').last.capitalize();
                          final sel = view == selectedView;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ElevatedButton(
                                onPressed: () => setState(() => selectedView = view),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: sel ? Colors.white : Colors.teal.shade700, backgroundColor: sel ? Colors.teal.shade700 : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(label),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),
                      // Chart
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: LineChart(selectedView == ChartView.weekly
                              ? _buildWeeklyData()
                              : selectedView == ChartView.monthly
                                  ? _buildMonthlyData()
                                  : _buildOverallData()),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
              ),

              // Fixed bottom nav
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(icon: Icons.home, isSelected: true, onTap: () {}),
                    _NavItem(
                        icon: Icons.public,
                        isSelected: false,
                        onTap: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => JournalPage(userName: widget.userName)));
                        }),
                    _NavItem(
                        icon: Icons.settings,
                        isSelected: false,
                        onTap: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SettingsPage(userName: widget.userName)));
                        }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: isSelected
            ? BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(16))
            : null,
        child: Icon(icon, size: 28, color: isSelected ? Colors.purple : Colors.grey.shade600),
      ),
    );
  }
}

// Helper for capitalizing chart-view labels
extension StringCasingExtension on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
