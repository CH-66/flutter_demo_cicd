import 'transaction_data.dart';

class Transaction {
  final int? id;
  final double amount;
  final String merchant;
  final TransactionType type;
  final String category; // 记账分类，如"餐饮"、"购物"等
  final String source; // 'alipay' or 'wechat'
  final DateTime timestamp;
  final String? remarks;

  Transaction({
    this.id,
    required this.amount,
    required this.merchant,
    required this.type,
    this.category = '未分类',
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
      category: map['category'],
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
      'category': category,
      'source': source,
      'timestamp': timestamp.toIso8601String(),
      'remarks': remarks,
    };
  }
} 