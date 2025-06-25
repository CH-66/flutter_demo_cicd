import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../models/transaction_data.dart';

class TransactionService {
  static Database? _database;
  static const String _transactionsTableName = 'transactions';
  static const String _categoriesTableName = 'categories';
  static const int _dbVersion = 2;

  // --- Database Initialization ---
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
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_categoriesTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon_code_point INTEGER NOT NULL,
        color_value INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_transactionsTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        type INTEGER NOT NULL,
        source TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        remarks TEXT,
        category_id INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES $_categoriesTableName (id)
      )
    ''');
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        // 1. Create categories table
        await txn.execute('''
          CREATE TABLE $_categoriesTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            icon_code_point INTEGER NOT NULL,
            color_value INTEGER NOT NULL
          )
        ''');

        // 2. Insert default categories and get the 'Uncategorized' ID
        final uncategorizedId = await _insertDefaultCategories(txn);

        // 3. Migrate old string-based categories
        final List<Map<String, dynamic>> oldCategories = await txn.query(
          _transactionsTableName,
          columns: ['category'],
          distinct: true,
        );

        for (final oldCategory in oldCategories) {
          final categoryName = oldCategory['category'] as String?;
          if (categoryName != null && categoryName.isNotEmpty) {
            // Avoid inserting duplicates if they are already in default set
            await txn.insert(
              _categoriesTableName,
              {
                'name': categoryName,
                'icon_code_point': Icons.label_outline.codePoint,
                'color_value': Colors.grey.value,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }

        // 4. Create new transactions table with the correct schema
        await txn.execute('''
          CREATE TABLE transactions_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            merchant TEXT NOT NULL,
            type INTEGER NOT NULL,
            source TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            remarks TEXT,
            category_id INTEGER NOT NULL,
            FOREIGN KEY (category_id) REFERENCES $_categoriesTableName (id)
          )
        ''');

        // 5. Copy data from old table to new table, mapping category strings to IDs
        await txn.rawInsert('''
          INSERT INTO transactions_new (id, amount, merchant, type, source, timestamp, remarks, category_id)
          SELECT
            t.id, t.amount, t.merchant, t.type, t.source, t.timestamp, t.remarks,
            COALESCE(c.id, ?)
          FROM $_transactionsTableName t
          LEFT JOIN $_categoriesTableName c ON t.category = c.name
        ''', [uncategorizedId]);
        
        // 6. Drop old table
        await txn.execute('DROP TABLE $_transactionsTableName');

        // 7. Rename new table
        await txn.execute('ALTER TABLE transactions_new RENAME TO $_transactionsTableName');
      });
    }
  }

  Future<int> _insertDefaultCategories(database) async {
    final defaults = [
      Category(name: '未分类', iconCodePoint: Icons.label_outline.codePoint, colorValue: Colors.grey.value),
      Category(name: '餐饮', iconCodePoint: Icons.restaurant.codePoint, colorValue: Colors.orange.value),
      Category(name: '购物', iconCodePoint: Icons.shopping_cart.codePoint, colorValue: Colors.blue.value),
      Category(name: '交通', iconCodePoint: Icons.directions_car.codePoint, colorValue: Colors.green.value),
      Category(name: '娱乐', iconCodePoint: Icons.local_play.codePoint, colorValue: Colors.purple.value),
      Category(name: '居家', iconCodePoint: Icons.home.codePoint, colorValue: Colors.brown.value),
    ];
    int uncategorizedId = -1;
    for (final category in defaults) {
      final id = await database.insert(_categoriesTableName, category.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      if (category.name == '未分类') {
         // If inserted, id is the new id. If ignored, we need to find it.
        if (id != 0) {
            uncategorizedId = id;
        } else {
            final existing = await database.query(_categoriesTableName, where: 'name = ?', whereArgs: [category.name]);
            uncategorizedId = existing.first['id'] as int;
        }
      }
    }
    return uncategorizedId;
  }
  
  // --- Category CRUD ---
  Future<int> addCategory(Category category) async {
    final db = await database;
    return await db.insert(_categoriesTableName, category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_categoriesTableName, orderBy: 'id');
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      _categoriesTableName,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Find 'Uncategorized' category ID
      final List<Map<String, dynamic>> uncategorizedMaps = await txn.query(
        _categoriesTableName,
        where: 'name = ?',
        whereArgs: ['未分类'],
        limit: 1,
      );
      if (uncategorizedMaps.isEmpty) {
        // This should not happen in a normal scenario
        throw Exception("Could not find 'Uncategorized' category.");
      }
      final uncategorizedId = uncategorizedMaps.first['id'] as int;

      if (id == uncategorizedId) {
        // Prevent deleting the 'Uncategorized' category
        throw Exception("Cannot delete the default 'Uncategorized' category.");
      }

      // Re-assign transactions to 'Uncategorized'
      await txn.update(
        _transactionsTableName,
        {'category_id': uncategorizedId},
        where: 'category_id = ?',
        whereArgs: [id],
      );

      // Delete the category
      return await txn.delete(
        _categoriesTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // --- Transaction Methods ---
  Future<List<model.Transaction>> getRecentTransactions({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _transactionsTableName,
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
      'SELECT SUM(amount) as total FROM $_transactionsTableName WHERE type = ? AND timestamp >= ?',
      [TransactionType.expense.index, startOfMonth]
    );
    final totalIncomeResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM $_transactionsTableName WHERE type = ? AND timestamp >= ?',
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
      _transactionsTableName,
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
      _transactionsTableName,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<model.Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_transactionsTableName);

    return List.generate(maps.length, (i) {
      return model.Transaction.fromMap(maps[i]);
    });
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.update(
      _transactionsTableName,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      _transactionsTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 