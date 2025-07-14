import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_rezonate/database_helper.dart';
import 'package:new_rezonate/models/habit_model.dart';
import 'package:table_calendar/table_calendar.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late DatabaseHelper _dbHelper;
  List<Habit> _habits = [];
  Map<int, Map<String, bool>> _completions = {};

  final List<String> _defaultHabitTitles = [
    "Read a Book",
    "Learn Something New",
    "Morning 15 min Workout",
    "Daily Breathing Meditation",
    "Walk 30 minutes",
  ];

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
    _initializeHabits();
  }

  Future<void> _initializeHabits() async {
    final existingHabits = await _dbHelper.getAllHabits();
    if (existingHabits.isEmpty) {
      for (int i = 0; i < _defaultHabitTitles.length; i++) {
        await _dbHelper.insertHabit(
          Habit(
            title: _defaultHabitTitles[i],
            colorValue: Colors.primaries[i % Colors.primaries.length].value,
            createdAt: _formatDate(DateTime.now()),
          ),
        );
      }
    }
    await _loadHabits();
  }

  List<DateTime> _getCurrentWeekDates() {
    final start = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _loadHabits() async {
    final habits = await _dbHelper.getAllHabits();
    final completionsMap = <int, Map<String, bool>>{};

    for (var habit in habits) {
      final weekDates = _getCurrentWeekDates();
      final completions = await _dbHelper.getCompletionsForHabitOnDates(
        habit.id!,
        weekDates.map(_formatDate).toList(),
      );
      completionsMap[habit.id!] = completions;
    }

    setState(() {
      _habits = habits;
      _completions = completionsMap;
    });
  }

  Future<void> _toggleCompletion(Habit habit, DateTime date) async {
    final dateStr = _formatDate(date);
    final current = _completions[habit.id!]?[dateStr] ?? false;

    final completion = HabitCompletion(
      habitId: habit.id!,
      date: dateStr,
      isCompleted: !current,
    );

    await _dbHelper.insertOrUpdateCompletion(completion);
    _loadHabits();
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete "${_habits[index].title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _dbHelper.deleteHabit(_habits[index].id!);
              _loadHabits();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getCurrentWeekDates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
        backgroundColor: const Color(0xFFCCCCFF),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadHabits();
            },
            calendarFormat: CalendarFormat.week,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _habits.length,
              itemBuilder: (context, index) {
                final habit = _habits[index];
                final completions = _completions[habit.id!] ?? {};
                final completedCount = weekDates
                    .where((d) => completions[_formatDate(d)] ?? false)
                    .length;
                final percent = (completedCount / 7 * 100).round();

                return GestureDetector(
                  onLongPress: () => _showDeleteDialog(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(habit.colorValue).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$percent% • ${habit.title}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: weekDates.map((date) {
                            final dateStr = _formatDate(date);
                            final isCompleted = completions[dateStr] ?? false;
                            final isToday = isSameDay(date, _selectedDay);

                            return GestureDetector(
                              onTap: () => _toggleCompletion(habit, date),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isToday
                                      ? Color(habit.colorValue).withOpacity(0.5)
                                      : Colors.transparent,
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isCompleted
                                      ? Color(habit.colorValue)
                                      : Colors.grey,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
