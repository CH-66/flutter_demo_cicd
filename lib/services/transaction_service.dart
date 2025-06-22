import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as model;
import '../models/transaction_data.dart';

class TransactionService {
  static Database? _database;
  static const String _tableName = 'transactions';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'transactions.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            merchant TEXT NOT NULL,
            type INTEGER NOT NULL,
            category TEXT NOT NULL,
            source TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            remarks TEXT
          )
        ''');
      },
    );
  }

  Future<void> addTransactionFromParsedData(ParsedTransaction parsedData) async {
    final db = await database;
    final newTransaction = model.Transaction(
      amount: parsedData.amount,
      merchant: parsedData.merchant,
      type: parsedData.type,
      source: parsedData.source,
      timestamp: DateTime.now(),
    );
    await db.insert(_tableName, newTransaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<model.Transaction>> getRecentTransactions({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return model.Transaction.fromMap(maps[i]);
    });
  }

  Future<Map<String, double>> getMonthlySummary() async {
    final db = await database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final totalExpenseResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM $_tableName WHERE type = ? AND timestamp >= ?',
      [TransactionType.expense.index, startOfMonth]
    );
    final totalIncomeResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM $_tableName WHERE type = ? AND timestamp >= ?',
      [TransactionType.income.index, startOfMonth]
    );

    final totalExpense = (totalExpenseResult.first['total'] as double?) ?? 0.0;
    final totalIncome = (totalIncomeResult.first['total'] as double?) ?? 0.0;

    return {
      'expense': totalExpense,
      'income': totalIncome,
    };
  }

  Future<List<model.Transaction>> getFilteredTransactions({
    TransactionType? type,
    String? keyword,
    DateTime? month,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClauses.add('type = ?');
      whereArgs.add(type.index);
    }
    
    if (keyword != null && keyword.isNotEmpty) {
      whereClauses.add('merchant LIKE ?');
      whereArgs.add('%$keyword%');
    }

    if (month != null) {
      final startOfMonth = DateTime(month.year, month.month, 1).toIso8601String();
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();
      whereClauses.add('timestamp BETWEEN ? AND ?');
      whereArgs.add(startOfMonth);
      whereArgs.add(endOfMonth);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return model.Transaction.fromMap(maps[i]);
    });
  }

  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.insert(
      _tableName,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<model.Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);

    return List.generate(maps.length, (i) {
      return model.Transaction.fromMap(maps[i]);
    });
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.update(
      _tableName,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 