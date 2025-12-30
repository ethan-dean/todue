import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/todo.dart';
import '../models/recurring_todo.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'todue.db';
  static const int _dbVersion = 1;

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
        last_login TEXT,
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
        updated_at TEXT,
        FOREIGN KEY (recurring_todo_id) REFERENCES recurring_todos (id)
      )
    ''');

    // Recurring todos table
    await db.execute('''
      CREATE TABLE recurring_todos (
        id INTEGER PRIMARY KEY,
        text TEXT NOT NULL,
        recurrence_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        default_position INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Skip recurring table
    await db.execute('''
      CREATE TABLE skip_recurring (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recurring_todo_id INTEGER NOT NULL,
        skip_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (recurring_todo_id) REFERENCES recurring_todos (id),
        UNIQUE (recurring_todo_id, skip_date)
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
    await db.execute('CREATE INDEX idx_skip_recurring_date ON skip_recurring (recurring_todo_id, skip_date)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here if needed
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
        'last_login': user.lastLogin?.toIso8601String(),
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
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'] as String)
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

  Future<void> deleteTodo(int id) async {
    final db = await database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTodos() async {
    final db = await database;
    await db.delete('todos');
  }

  // Recurring todo operations

  Future<void> saveRecurringTodo(RecurringTodo recurringTodo) async {
    final db = await database;
    await db.insert(
      'recurring_todos',
      {
        'id': recurringTodo.id,
        'text': recurringTodo.text,
        'recurrence_type': recurringTodo.recurrenceType.name,
        'start_date': recurringTodo.startDate,
        'end_date': recurringTodo.endDate,
        'default_position': recurringTodo.defaultPosition,
        'created_at': recurringTodo.createdAt.toIso8601String(),
        'updated_at': recurringTodo.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RecurringTodo>> getRecurringTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('recurring_todos');

    return maps.map((map) => _recurringTodoFromMap(map)).toList();
  }

  Future<void> deleteRecurringTodo(int id) async {
    final db = await database;
    await db.delete('recurring_todos', where: 'id = ?', whereArgs: [id]);
  }

  // Helper methods

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

  RecurringTodo _recurringTodoFromMap(Map<String, dynamic> map) {
    return RecurringTodo(
      id: map['id'] as int,
      text: map['text'] as String,
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == map['recurrence_type'],
      ),
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      defaultPosition: map['default_position'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('todos');
    await db.delete('recurring_todos');
    await db.delete('skip_recurring');
    await db.delete('pending_changes');
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
