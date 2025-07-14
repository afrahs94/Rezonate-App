import 'package:new_rezonate/models/model_entry.dart';
import 'package:new_rezonate/models/habit_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mood_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mood TEXT NOT NULL,
        date TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        color INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL,
        UNIQUE(habitId, date)
      )
    ''');
  }

  // MOOD FUNCTIONS
  Future<void> insertOrUpdateMood(MoodEntry entry) async {
    final db = await database;
    await db.insert(
      'mood_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getMoodMap() async {
    final db = await database;
    final result = await db.query('mood_entries');
    return {
      for (var row in result) row['date'] as String: row['mood'] as String
    };
  }

  // HABIT FUNCTIONS
  Future<int> insertHabit(Habit habit) async {
    final db = await database;
    return await db.insert('habits', habit.toMap());
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final result = await db.query('habits');
    return result.map((e) => Habit.fromMap(e)).toList();
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // COMPLETION FUNCTIONS
  Future<void> insertOrUpdateCompletion(HabitCompletion completion) async {
    final db = await database;
    await db.insert(
      'habit_completions',
      completion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, bool>> getCompletionsForHabitOnDates(int habitId, List<String> dates) async {
    final db = await database;
    final result = await db.query(
      'habit_completions',
      where: 'habitId = ? AND date IN (${List.filled(dates.length, '?').join(',')})',
      whereArgs: [habitId, ...dates],
    );

    final completions = <String, bool>{};
    for (var row in result) {
      completions[row['date'] as String] = (row['completed'] as int) == 1;
    }

    return completions;
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
