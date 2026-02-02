import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/todo.dart';
import '../models/later_list.dart';
import '../models/later_list_todo.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'todue.db';
  static const int _dbVersion = 2; // Bumped for later_lists tables

  static DatabaseService get instance => databaseService;

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        timezone TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_rollover_date TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Todos table
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY,
        text TEXT NOT NULL,
        assigned_date TEXT NOT NULL,
        instance_date TEXT NOT NULL,
        position INTEGER NOT NULL,
        recurring_todo_id INTEGER,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        is_rolled_over INTEGER NOT NULL DEFAULT 0,
        is_virtual INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Pending changes table (for offline queue)
    await db.execute('''
      CREATE TABLE pending_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indices
    await db.execute('CREATE INDEX idx_todos_assigned_date ON todos (assigned_date)');
    await db.execute('CREATE INDEX idx_todos_instance_date ON todos (instance_date)');
    await db.execute('CREATE INDEX idx_todos_recurring_id ON todos (recurring_todo_id)');

    // Later lists table
    await db.execute('''
      CREATE TABLE later_lists (
        id INTEGER PRIMARY KEY,
        list_name TEXT NOT NULL
      )
    ''');

    // Later list todos table
    await db.execute('''
      CREATE TABLE later_list_todos (
        id INTEGER PRIMARY KEY,
        list_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        position INTEGER NOT NULL,
        FOREIGN KEY (list_id) REFERENCES later_lists (id) ON DELETE CASCADE
      )
    ''');

    // Create indices for later lists
    await db.execute('CREATE INDEX idx_later_list_todos_list_id ON later_list_todos (list_id)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here if needed
    if (oldVersion < 2) {
      // Add later_lists tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS later_lists (
          id INTEGER PRIMARY KEY,
          list_name TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS later_list_todos (
          id INTEGER PRIMARY KEY,
          list_id INTEGER NOT NULL,
          text TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          completed_at TEXT,
          position INTEGER NOT NULL,
          FOREIGN KEY (list_id) REFERENCES later_lists (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_later_list_todos_list_id ON later_list_todos (list_id)');
    }
  }

  // User operations

  Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'id': user.id,
        'email': user.email,
        'timezone': user.timezone,
        'created_at': user.createdAt.toIso8601String(),
        'last_rollover_date': user.lastRolloverDate?.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);

    if (maps.isEmpty) return null;

    final map = maps.first;
    return User(
      id: map['id'] as int,
      email: map['email'] as String,
      timezone: map['timezone'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastRolloverDate: map['last_rollover_date'] != null
          ? DateTime.parse(map['last_rollover_date'] as String)
          : null,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<void> clearUser() async {
    final db = await database;
    await db.delete('users');
  }

  // Todo operations

  Future<void> saveTodo(Todo todo) async {
    final db = await database;
    await db.insert(
      'todos',
      {
        'id': todo.id,
        'text': todo.text,
        'assigned_date': todo.assignedDate,
        'instance_date': todo.instanceDate,
        'position': todo.position,
        'recurring_todo_id': todo.recurringTodoId,
        'is_completed': todo.isCompleted ? 1 : 0,
        'completed_at': todo.completedAt?.toIso8601String(),
        'is_rolled_over': todo.isRolledOver ? 1 : 0,
        'is_virtual': todo.isVirtual ? 1 : 0,
        'created_at': todo.createdAt?.toIso8601String(),
        'updated_at': todo.updatedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTodos(List<Todo> todos) async {
    final db = await database;
    final batch = db.batch();

    for (final todo in todos) {
      batch.insert(
        'todos',
        {
          'id': todo.id,
          'text': todo.text,
          'assigned_date': todo.assignedDate,
          'instance_date': todo.instanceDate,
          'position': todo.position,
          'recurring_todo_id': todo.recurringTodoId,
          'is_completed': todo.isCompleted ? 1 : 0,
          'completed_at': todo.completedAt?.toIso8601String(),
          'is_rolled_over': todo.isRolledOver ? 1 : 0,
          'is_virtual': todo.isVirtual ? 1 : 0,
          'created_at': todo.createdAt?.toIso8601String(),
          'updated_at': todo.updatedAt?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Todo>> getTodosForDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'assigned_date = ? AND is_virtual = 0',
      whereArgs: [date],
      orderBy: 'position ASC',
    );

    return maps.map((map) => _todoFromMap(map)).toList();
  }

  Future<List<Todo>> getTodosForDateRange(String startDate, String endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      where: 'assigned_date >= ? AND assigned_date <= ? AND is_virtual = 0',
      whereArgs: [startDate, endDate],
      orderBy: 'assigned_date ASC, position ASC',
    );

    return maps.map((map) => _todoFromMap(map)).toList();
  }

  Future<List<Todo>> getTodos({required String date}) {
    return getTodosForDate(date);
  }

  Future<void> deleteTodo(int id) async {
    final db = await database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTodos() async {
    final db = await database;
    await db.delete('todos');
  }

  // Helper methods

  Future<void> saveTodosForDate(String date, List<Todo> todos) async {
    final db = await database;
    // Delete existing todos for this date before inserting fresh data
    // This prevents stale data from accumulating when IDs change
    await db.delete('todos', where: 'assigned_date = ?', whereArgs: [date]);
    await saveTodos(todos);
  }

  Todo _todoFromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as int?,
      text: map['text'] as String,
      assignedDate: map['assigned_date'] as String,
      instanceDate: map['instance_date'] as String,
      position: map['position'] as int,
      recurringTodoId: map['recurring_todo_id'] as int?,
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      isRolledOver: (map['is_rolled_over'] as int) == 1,
      isVirtual: (map['is_virtual'] as int) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Later Lists operations

  Future<void> saveLaterList(LaterList list) async {
    final db = await database;
    await db.insert(
      'later_lists',
      {
        'id': list.id,
        'list_name': list.listName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveLaterLists(List<LaterList> lists) async {
    final db = await database;
    final batch = db.batch();
    for (final list in lists) {
      batch.insert(
        'later_lists',
        {
          'id': list.id,
          'list_name': list.listName,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<LaterList>> getLaterLists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'later_lists',
      orderBy: 'list_name ASC',
    );
    return maps.map((map) => LaterList(
      id: map['id'] as int,
      listName: map['list_name'] as String,
    )).toList();
  }

  Future<void> deleteLaterList(int id) async {
    final db = await database;
    await db.delete('later_lists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearLaterLists() async {
    final db = await database;
    await db.delete('later_lists');
  }

  // Later List Todos operations

  Future<void> saveLaterListTodo(LaterListTodo todo, int listId) async {
    final db = await database;
    await db.insert(
      'later_list_todos',
      {
        'id': todo.id,
        'list_id': listId,
        'text': todo.text,
        'is_completed': todo.isCompleted ? 1 : 0,
        'completed_at': todo.completedAt?.toIso8601String(),
        'position': todo.position,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveLaterListTodos(List<LaterListTodo> todos, int listId) async {
    final db = await database;
    final batch = db.batch();
    for (final todo in todos) {
      batch.insert(
        'later_list_todos',
        {
          'id': todo.id,
          'list_id': listId,
          'text': todo.text,
          'is_completed': todo.isCompleted ? 1 : 0,
          'completed_at': todo.completedAt?.toIso8601String(),
          'position': todo.position,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<LaterListTodo>> getLaterListTodos(int listId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'later_list_todos',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'position ASC',
    );
    return maps.map((map) => LaterListTodo(
      id: map['id'] as int,
      text: map['text'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      position: map['position'] as int,
    )).toList();
  }

  Future<void> deleteLaterListTodo(int id) async {
    final db = await database;
    await db.delete('later_list_todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearLaterListTodos(int listId) async {
    final db = await database;
    await db.delete('later_list_todos', where: 'list_id = ?', whereArgs: [listId]);
  }

  /// Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('todos');
    await db.delete('pending_changes');
    await db.delete('later_lists');
    await db.delete('later_list_todos');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

// Singleton instance
final databaseService = DatabaseService();
