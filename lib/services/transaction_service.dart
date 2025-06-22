import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';
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
    final newTransaction = Transaction(
      amount: parsedData.amount,
      merchant: parsedData.merchant,
      type: parsedData.type,
      source: parsedData.source,
      timestamp: DateTime.now(),
    );
    await db.insert(_tableName, newTransaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
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
} 