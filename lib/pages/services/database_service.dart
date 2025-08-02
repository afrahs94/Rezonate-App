// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';

// class DatabaseService {
//   static Database? _db;
//   static final DatabaseService instance = DatabaseService._constructor();

//   final String _signUpTable = "sign_up";
//   final String _id = "id";
//   final String _username = "username";
//   final String _email = "email";
//   final String _password = "password";
//   final String _firstName = "first_name";
//   final String _lastName = "last_name";
//   final String _gender = "gender";
//   final String _dob = "dob";
//   final String _createdAt = "created_at";

//   DatabaseService._constructor();

//   Future<Database> get database async {
//     if (_db != null) return _db!;
//     _db = await _initDatabase();
//     return _db!;
//   }

//   Future<Database> _initDatabase() async {
//     final path = join(await getDatabasesPath(), 'master_db.db');
//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: (db, version) {
//         return db.execute('''
//           CREATE TABLE $_signUpTable (
//             $_id INTEGER PRIMARY KEY AUTOINCREMENT,
//             $_username TEXT UNIQUE NOT NULL,
//             $_email TEXT UNIQUE NOT NULL,
//             $_password TEXT NOT NULL,
//             $_firstName TEXT NOT NULL,
//             $_lastName TEXT,
//             $_gender TEXT,
//             $_dob TEXT,
//             $_createdAt TEXT NOT NULL
//           )
//         ''');
//       },
//     );
//   }

//   Future<int> insertUser(Map<String, dynamic> user) async {
//     final db = await database;
//     return await db.insert(_signUpTable, user);
//   }

//   Future<Map<String, dynamic>?> getUserByUsernameOrEmail(String username, String email) async {
//     final db = await database;
//     final result = await db.query(
//       _signUpTable,
//       where: '$_username = ? OR $_email = ?',
//       whereArgs: [username, email],
//       limit: 1,
//     );
//     if (result.isNotEmpty) {
//       return result.first;
//     }
//     return null;
//   }
// }




// database_service.dart

// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';

// class DatabaseService {
//   // Singleton boilerplate
//   DatabaseService._privateConstructor();
//   static final DatabaseService instance = DatabaseService._privateConstructor();
//   static Database? _db;

//   // DB & table info
//   static const _dbName    = 'master_db.db';
//   static const _dbVersion = 1;
//   static const _signUpTable = 'sign_up';

//   // Column names
//   static const _colId        = 'id';
//   static const _colUsername  = 'username';
//   static const _colEmail     = 'email';
//   static const _colPassword  = 'password';
//   static const _colFirstName = 'first_name';
//   static const _colLastName  = 'last_name';
//   static const _colGender    = 'gender';
//   static const _colDob       = 'dob';
//   static const _colCreatedAt = 'created_at';

//   Future<Database> get database async {
//     if (_db != null) return _db!;
//     _db = await _initDatabase();
//     return _db!;
//   }

//   Future<Database> _initDatabase() async {
//     final path = join(await getDatabasesPath(), _dbName);
//     return await openDatabase(
//       path,
//       version: _dbVersion,
//       onCreate: _onCreate,
//     );
//   }

//   Future<void> _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE $_signUpTable (
//         $_colId        INTEGER PRIMARY KEY AUTOINCREMENT,
//         $_colUsername  TEXT UNIQUE NOT NULL,
//         $_colEmail     TEXT UNIQUE NOT NULL,
//         $_colPassword  TEXT NOT NULL,
//         $_colFirstName TEXT NOT NULL,
//         $_colLastName  TEXT,
//         $_colGender    TEXT,
//         $_colDob       TEXT,
//         $_colCreatedAt TEXT NOT NULL
//       )
//     ''');
//   }

//   /// Insert a new user record
//   Future<int> insertUser(Map<String, dynamic> user) async {
//     final db = await database;
//     return db.insert(_signUpTable, user);
//   }

//   /// Lookup by username OR email
//   Future<Map<String, dynamic>?> getUserByUsernameOrEmail(
//     String username,
//     String email,
//   ) async {
//     final db = await database;
//     final result = await db.query(
//       _signUpTable,
//       where: '$_colUsername = ? OR $_colEmail = ?',
//       whereArgs: [username, email],
//       limit: 1,
//     );
//     return result.isNotEmpty ? result.first : null;
//   }

//   /// Close the database when you’re done
//   Future<void> close() async {
//     final db = await database;
//     await db.close();
//     _db = null;
//   }
// }



// lib/pages/services/database_service.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseService {
  // Singleton boilerplate
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();
  static Database? _db;

  // DB & table info
  static const _dbName      = 'master_db.db';
  static const _dbVersion   = 1;
  static const _signUpTable = 'sign_up';

  // Column names
  static const _colId        = 'id';
  static const _colUsername  = 'username';
  static const _colEmail     = 'email';
  static const _colPassword  = 'password';
  static const _colFirstName = 'first_name';
  static const _colLastName  = 'last_name';
  static const _colGender    = 'gender';
  static const _colDob       = 'dob';
  static const _colCreatedAt = 'created_at';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_signUpTable (
        $_colId        INTEGER PRIMARY KEY AUTOINCREMENT,
        $_colUsername  TEXT UNIQUE NOT NULL,
        $_colEmail     TEXT UNIQUE NOT NULL,
        $_colPassword  TEXT NOT NULL,
        $_colFirstName TEXT NOT NULL,
        $_colLastName  TEXT,
        $_colGender    TEXT,
        $_colDob       TEXT,
        $_colCreatedAt TEXT NOT NULL
      )
    ''');
  }

  /// Insert a new user record
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return db.insert(_signUpTable, user);
  }

  /// Lookup by username OR email
  Future<Map<String, dynamic>?> getUserByUsernameOrEmail(
    String username,
    String email,
  ) async {
    final db = await database;
    final result = await db.query(
      _signUpTable,
      where: '$_colUsername = ? OR $_colEmail = ?',
      whereArgs: [username, email],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Authenticate a user by username/email + plain‐text password.
  ///
  /// Returns the full user record (with first_name, etc.) if the password
  /// matches, or null otherwise.
  Future<Map<String, dynamic>?> authenticateUser(
      String userOrEmail, String plainPassword) async {
    final db = await database;

    // 1) find the record by username or email
    final res = await db.query(
      _signUpTable,
      where: '$_colUsername = ? OR $_colEmail = ?',
      whereArgs: [userOrEmail, userOrEmail],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final user = res.first;

    // 2) hash the incoming password the same way we did on sign‐up
    final hash = sha256.convert(utf8.encode(plainPassword)).toString();

    // 3) compare
    if (user[_colPassword] == hash) {
      return user;
    }
    return null;
  }

  /// Close the database when you’re done
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
