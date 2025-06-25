import 'transaction_data.dart';

class Transaction {
  final int? id;
  final double amount;
  final String merchant;
  final TransactionType type;
  final int categoryId; // 指向 categories 表的外键
  final String source; // 'alipay' or 'wechat'
  final DateTime timestamp;
  final String? remarks;

  Transaction({
    this.id,
    required this.amount,
    required this.merchant,
    required this.type,
    required this.categoryId,
    required this.source,
    required this.timestamp,
    this.remarks,
  });

  // 用于将数据库的 map 转换为对象
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      merchant: map['merchant'],
      type: TransactionType.values[map['type']],
      categoryId: map['category_id'],
      source: map['source'],
      timestamp: DateTime.parse(map['timestamp']),
      remarks: map['remarks'],
    );
  }

  // 用于将对象转换为 map 以便存入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'type': type.index,
      'category_id': categoryId,
      'source': source,
      'timestamp': timestamp.toIso8601String(),
      'remarks': remarks,
    };
  }
} 