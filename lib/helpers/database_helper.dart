import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/password_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'password_manager.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建用户表
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        master_password TEXT NOT NULL,
        salt TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 创建密码条目表
    await db.execute('''
      CREATE TABLE password_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        website TEXT,
        note TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  // 用户相关操作
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUser(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getFirstUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> hasUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query('users');
    return result.isNotEmpty;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // 密码条目相关操作
  Future<int> insertPasswordEntry(PasswordEntry entry) async {
    final db = await database;
    return await db.insert('password_entries', entry.toMap());
  }

  Future<List<PasswordEntry>> getPasswordEntries(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'password_entries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return PasswordEntry.fromMap(maps[i]);
    });
  }

  Future<PasswordEntry?> getPasswordEntry(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'password_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return PasswordEntry.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updatePasswordEntry(PasswordEntry entry) async {
    final db = await database;
    return await db.update(
      'password_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deletePasswordEntry(int id) async {
    final db = await database;
    return await db.delete(
      'password_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 备份相关
  Future<List<Map<String, dynamic>>> exportPasswordEntries(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'password_entries',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps;
  }

  Future<void> clearPasswordEntries(int userId) async {
    final db = await database;
    await db.delete(
      'password_entries',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
