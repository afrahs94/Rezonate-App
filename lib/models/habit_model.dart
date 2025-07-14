// models/habit_model.dart
class Habit {
  final int? id;
  final String title;
  final int colorValue;
  final String createdAt;

  Habit({
    this.id,
    required this.title,
    required this.colorValue,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'colorValue': colorValue,
      'createdAt': createdAt,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      title: map['title'],
      colorValue: map['colorValue'],
      createdAt: map['createdAt'],
    );
  }
}

class HabitCompletion {
  final int? id;
  final int habitId;
  final String date;
  final bool isCompleted;

  HabitCompletion({
    this.id,
    required this.habitId,
    required this.date,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    return HabitCompletion(
      id: map['id'],
      habitId: map['habitId'],
      date: map['date'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}