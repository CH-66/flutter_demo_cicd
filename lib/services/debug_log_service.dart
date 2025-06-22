import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DebugLog {
  final int? id;
  final String source;
  final String? title;
  final String? text;
  final DateTime timestamp;

  DebugLog({
    this.id,
    required this.source,
    this.title,
    this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source,
      'title': title,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DebugLog.fromMap(Map<String, dynamic> map) {
    return DebugLog(
      id: map['id'],
      source: map['source'],
      title: map['title'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}


class DebugLogService {
  static Database? _database;
  static const String _tableName = 'debug_logs';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'debug_logs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            title TEXT,
            text TEXT,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> addLog(Map<dynamic, dynamic> notificationData) async {
    final db = await database;
    final log = DebugLog(
      source: notificationData['source']?.toString() ?? 'unknown',
      title: notificationData['title']?.toString(),
      text: notificationData['text']?.toString(),
      timestamp: DateTime.now(),
    );
    await db.insert(_tableName, log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DebugLog>> getAllLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName, orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return DebugLog.fromMap(maps[i]);
    });
  }
} 