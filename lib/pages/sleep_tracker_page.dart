// sleep_tracker_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SleepTrackerPage extends StatefulWidget {
  const SleepTrackerPage({super.key});

  @override
  State<SleepTrackerPage> createState() => _SleepTrackerPageState();
}

class _SleepTrackerPageState extends State<SleepTrackerPage> {
  final List<double> sleepData = [7.5, 5.0, 6.5, 8.2, 5.3, 6.0, 7.8];
  final DateTime lastAwake = DateTime.now().subtract(const Duration(hours: 8, minutes: 16));

  @override
  Widget build(BuildContext context) {
    String lastAwakeTime = DateFormat('hh:mm a').format(lastAwake);
    String totalSleep = '8 h 16 m';

    return Scaffold(
      backgroundColor: const Color(0xFFD2EABD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD2EABD),
        title: const Text('Sleep Tracker'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoCard('Last Awake at', lastAwakeTime),
                _infoCard('Total Sleep', totalSleep),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Sleep Statistic',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text('${value.toInt() + 10}'),
                        reservedSize: 20,
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    sleepData.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: sleepData[i],
                          color: Colors.white,
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
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
        color: const Color(0xFFCCE5A2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
