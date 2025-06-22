import '../../models/transaction_data.dart';
import 'notification_parser.dart';

/// Parses Alipay notifications like: "你向{merchant}付款{amount}元"
class AlipayExpenseParserV1 implements NotificationParser {
  @override
  ParsedTransaction? parse(String title, String text) {
    final regex = RegExp(r'你向(.+)付款([\d.]+)元');
    final match = regex.firstMatch(text);

    if (match != null) {
      return ParsedTransaction(
        amount: double.tryParse(match.group(2) ?? '0') ?? 0,
        merchant: match.group(1)?.trim() ?? '未知商家',
        type: TransactionType.expense,
        source: 'alipay',
      );
    }
    return null;
  }
}

/// Parses Alipay notifications like: "你有一笔{amount}元的支出..."
class AlipayExpenseParserV2 implements NotificationParser {
  @override
  ParsedTransaction? parse(String title, String text) {
    final regex = RegExp(r'你有一笔([\d.]+)元的支出');
    final match = regex.firstMatch(text);

    if (match != null) {
      // This type of notification doesn't contain the merchant name.
      return ParsedTransaction(
        amount: double.tryParse(match.group(1) ?? '0') ?? 0,
        type: TransactionType.expense,
        source: 'alipay',
      );
    }
    return null;
  }
}

/// Parses Alipay notifications like: "支付宝成功收款{amount}元。"
class AlipayIncomeParserV1 implements NotificationParser {
  @override
  ParsedTransaction? parse(String title, String text) {
    final regex = RegExp(r'成功收款([\d.]+)元');
    final match = regex.firstMatch(text);

    if (match != null) {
      // Alipay income notifications usually don't specify the payer.
      return ParsedTransaction(
        amount: double.tryParse(match.group(1) ?? '0') ?? 0,
        merchant: '对方',
        type: TransactionType.income,
        source: 'alipay',
      );
    }
    return null;
  }
}

class AlipayExpenseParserV3 implements NotificationParser {
  @override
  ParsedTransaction? parse(String title, String text) {
    final reg = RegExp(r'你有一笔([\d.]+)元的支出');
    final match = reg.firstMatch(text);
    if (match != null) {
      final amount = double.tryParse(match.group(1)!);
      if (amount != null) {
        return ParsedTransaction(
          amount: amount,
          merchant: '支付宝',
          type: TransactionType.expense,
          source: 'Alipay',
        );
      }
    }
    return null;
  }
} 