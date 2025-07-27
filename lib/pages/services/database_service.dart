import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instance = DatabaseService._constructor();

  final String _signUpTable = "sign_up";
  final String _id = "id";
  final String _username = "username";
  final String _email = "email";
  final String _password = "password";
  final String _firstName = "first_name";
  final String _lastName = "last_name";
  final String _gender = "gender";
  final String _dob = "dob";
  final String _createdAt = "created_at";

  DatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'master_db.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE $_signUpTable (
            $_id INTEGER PRIMARY KEY AUTOINCREMENT,
            $_username TEXT UNIQUE NOT NULL,
            $_email TEXT UNIQUE NOT NULL,
            $_password TEXT NOT NULL,
            $_firstName TEXT NOT NULL,
            $_lastName TEXT,
            $_gender TEXT,
            $_dob TEXT,
            $_createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert(_signUpTable, user);
  }

  Future<Map<String, dynamic>?> getUserByUsernameOrEmail(String username, String email) async {
    final db = await database;
    final result = await db.query(
      _signUpTable,
      where: '$_username = ? OR $_email = ?',
      whereArgs: [username, email],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}
