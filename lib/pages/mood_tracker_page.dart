import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/database_helper.dart';
import 'package:new_rezonate/models/model_entry.dart';
import 'package:table_calendar/table_calendar.dart';

class MoodTrackerPage extends StatefulWidget {
  const MoodTrackerPage({super.key});

  @override
  State<MoodTrackerPage> createState() => _MoodTrackerPageState();
}

class _MoodTrackerPageState extends State<MoodTrackerPage> {
  String? selectedMood;
  DateTime today = DateTime.now();
  Map<DateTime, String> moodHistory = {};
  bool isLoading = true;

  final List<Map<String, dynamic>> moods = [
    {"emoji": "😄", "label": "rad", "color": Colors.teal},
    {"emoji": "😊", "label": "good", "color": Colors.lightGreen},
    {"emoji": "😐", "label": "meh", "color": Colors.blue},
    {"emoji": "😕", "label": "bad", "color": Colors.orange},
    {"emoji": "😵", "label": "awful", "color": Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final moodMap = await DatabaseHelper.instance.getMoodMap();
      setState(() {
        moodHistory = moodMap.cast<DateTime, String>();
        // Set today's mood if exists
        final todayKey = DateTime(today.year, today.month, today.day);
        selectedMood = moodHistory[todayKey];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load mood history: $e')),
      );
    }
  }

  Future<void> _selectMood(String label) async {
    final selectedDate = DateTime(today.year, today.month, today.day);
    
    try {
      await DatabaseHelper.instance.insertOrUpdateMood(
        MoodEntry(mood: label, date: selectedDate.toIso8601String()),
      );

      setState(() {
        selectedMood = label;
        moodHistory[selectedDate] = label;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mood "$label" saved for ${DateFormat('MMM d').format(selectedDate)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save mood: $e')),
      );
    }
  }

  Color? _getMoodColor(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final mood = moodHistory[dateKey];
    if (mood == null) return null;
    return moods.firstWhere((m) => m['label'] == mood)['color'];
  }

  Widget _buildMoodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: moods.map((mood) {
        final isSelected = selectedMood == mood['label'];
        return Column(
          children: [
            GestureDetector(
              onTap: () => _selectMood(mood['label']),
              child: CircleAvatar(
                radius: 35,
                backgroundColor: isSelected 
                  ? mood['color'].withOpacity(0.3) 
                  : Colors.grey[200],
                child: Text(
                  mood['emoji'],
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mood['label'],
              style: TextStyle(
                fontSize: 14,
                color: mood['color'],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: today,
      calendarStyle: const CalendarStyle(outsideDaysVisible: false),
      selectedDayPredicate: (day) => isSameDay(day, today),
      onDaySelected: (selected, focused) {
        setState(() {
          today = selected;
          // Update selected mood when changing days
          final selectedDate = DateTime(selected.year, selected.month, selected.day);
          selectedMood = moodHistory[selectedDate];
        });
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final color = _getMoodColor(day);
          if (color != null) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: color.withOpacity(0.6),
              ),
              child: Center(
                child: Text('${day.day}', style: const TextStyle(color: Colors.white)),
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('EEEE, MMM d, h:mm a').format(today);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCCCFF),
        title: const Text('Mood Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _loadInitialData();
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'HOW ARE YOU?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Today, $now',
                    style: const TextStyle(fontSize: 16, color: Colors.teal),
                  ),
                  const SizedBox(height: 30),
                  _buildMoodSelector(),
                  const SizedBox(height: 40),
                  Expanded(child: _buildCalendar()),
                ],
              ),
            ),
    );
  }
}