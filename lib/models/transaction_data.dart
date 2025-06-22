enum TransactionType { expense, income, unknown }

class ParsedTransaction {
  final double amount;
  final String merchant;
  final TransactionType type;
  final String source; // 'alipay' or 'wechat'

  ParsedTransaction({
    required this.amount,
    this.merchant = '未知商家',
    this.type = TransactionType.unknown,
    required this.source,
  });

  @override
  String toString() {
    return 'ParsedTransaction(amount: $amount, merchant: $merchant, type: $type, source: $source)';
  }
} 