import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/password_entry.dart';
import '../models/category.dart';

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
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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

    // 创建分类表
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 创建密码条目表
    await db.execute('''
      CREATE TABLE password_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        category_id INTEGER,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        website TEXT,
        note TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 升级到版本2：添加分类表和密码条目的分类字段
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          icon TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      // 为密码条目表添加 category_id 字段
      await db.execute(
          'ALTER TABLE password_entries ADD COLUMN category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL');
    }
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

  Future<List<PasswordEntry>> getPasswordEntriesByCategory(
      int userId, int? categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (categoryId == null) {
      // 获取未分类的条目
      maps = await db.query(
        'password_entries',
        where: 'user_id = ? AND category_id IS NULL',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'password_entries',
        where: 'user_id = ? AND category_id = ?',
        whereArgs: [userId, categoryId],
        orderBy: 'created_at DESC',
      );
    }

    return List.generate(maps.length, (i) {
      return PasswordEntry.fromMap(maps[i]);
    });
  }

  /// 获取每个分类下的密码条目数量
  Future<Map<int?, int>> getPasswordCountByCategory(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT category_id, COUNT(*) as count 
      FROM password_entries 
      WHERE user_id = ? 
      GROUP BY category_id
    ''', [userId]);

    final Map<int?, int> countMap = {};
    for (final row in result) {
      final categoryId = row['category_id'] as int?;
      final count = row['count'] as int;
      countMap[categoryId] = count;
    }
    return countMap;
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

  // ==================== 分类相关操作 ====================

  /// 插入分类
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  /// 获取用户所有分类
  Future<List<Category>> getCategories(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  /// 获取单个分类
  Future<Category?> getCategory(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  /// 更新分类
  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// 将指定分类下的密码条目移到默认分类（category_id 设为 NULL）
  Future<int> moveCategoryEntriesToDefault(int categoryId) async {
    final db = await database;
    return await db.update(
      'password_entries',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  /// 删除分类
  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 导出分类
  Future<List<Map<String, dynamic>>> exportCategories(int userId) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// 清除用户所有分类
  Future<void> clearCategories(int userId) async {
    final db = await database;
    await db.delete(
      'categories',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
