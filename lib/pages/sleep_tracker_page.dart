import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SleepSession {
  final DateTime date;
  final double hours;

  SleepSession({required this.date, required this.hours});
}

class SleepTrackerPage extends StatefulWidget {
  const SleepTrackerPage({super.key});

  @override
  State<SleepTrackerPage> createState() => _SleepTrackerPageState();
}

class _SleepTrackerPageState extends State<SleepTrackerPage> {
  final Map<DateTime, SleepSession> _sleepDataByDate = {};

  DateTime selectedDate = DateTime.now();
  TimeOfDay? sleepStart;
  TimeOfDay? sleepEnd;

  @override
  void initState() {
    super.initState();
    _loadSleepData();
  }

  void _addSleepSession() {
    if (sleepStart == null || sleepEnd == null) return;

    final start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      sleepStart!.hour,
      sleepStart!.minute,
    );

    var end = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      sleepEnd!.hour,
      sleepEnd!.minute,
    );

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    final duration = end.difference(start).inMinutes / 60;
    final key = _dateOnly(selectedDate);

    setState(() {
      _sleepDataByDate[key] = SleepSession(date: key, hours: duration);
      sleepStart = null;
      sleepEnd = null;
    });

    _saveSleepData();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<DateTime> _getPast7Days() {
    final today = _dateOnly(DateTime.now());
    return List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
  }

  void _saveSleepData() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _sleepDataByDate.map(
      (k, v) => MapEntry(k.toIso8601String(), v.hours),
    );
    prefs.setString('sleepData', jsonEncode(encoded));
  }

  void _loadSleepData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sleepData');
    if (raw == null) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      _sleepDataByDate.clear();
      for (final entry in decoded.entries) {
        final date = DateTime.parse(entry.key);
        _sleepDataByDate[_dateOnly(date)] = SleepSession(
          date: _dateOnly(date),
          hours: (entry.value as num).toDouble(),
        );
      }
    });
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '--:--';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final past7Days = _getPast7Days();

    final lastEntry =
        _sleepDataByDate.values.isNotEmpty
            ? _sleepDataByDate.values.reduce(
              (a, b) => a.date.isAfter(b.date) ? a : b,
            )
            : null;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCFF),
        title: const Text('Sleep Tracker'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lastEntry != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCCCFF),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
              child: Text(
                'Selected Date: ${DateFormat.yMMMd().format(selectedDate)}',
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCCCFF),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    sleepStart = picked;
                  });
                }
              },
              child: Text('Sleep Start: ${_formatTimeOfDay(sleepStart)}'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCCCFF),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    sleepEnd = picked;
                  });
                }
              },
              child: Text('Wake Time: ${_formatTimeOfDay(sleepEnd)}'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCCCFF),
                foregroundColor: Colors.black,
              ),
              onPressed: _addSleepSession,
              child: const Text('Save'),
            ),
            const SizedBox(height: 30),
            const Text(
              'Sleep Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= past7Days.length) {
                            return const SizedBox.shrink();
                          }
                          final date = past7Days[index];
                          return Text(DateFormat('E').format(date));
                        },
                        reservedSize: 20,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),

                  barGroups: List.generate(past7Days.length, (i) {
                    final day = past7Days[i];
                    final sleep =
                        _sleepDataByDate[_dateOnly(day)]?.hours ?? 0.0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: sleep,
                          color: Colors.black,
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.43,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFCCCCFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
