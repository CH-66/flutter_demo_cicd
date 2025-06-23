import '../../models/transaction_data.dart';
import 'notification_parser.dart';

/// A fallback parser for Alipay notifications that couldn't be parsed by more specific rules.
/// It attempts a very generic pattern match.
class AlipayFallbackParser implements NotificationParser {
  @override
  ParsedTransaction? parse(String packageName, String title, String text) {
    // This regex is very generic, looking for any mention of "付款" (payment)
    // and a number. This is a last-ditch effort.
    final regex = RegExp(r'付款([\d.]+)元');
    final match = regex.firstMatch(text);

    if (match != null) {
      return ParsedTransaction(
        amount: double.tryParse(match.group(1) ?? '0') ?? 0,
        merchant: '未知(回退)',
        type: TransactionType.expense,
        source: packageName, // Use the original package name
      );
    }

    // Another generic attempt for income.
    final incomeRegex = RegExp(r'收款([\d.]+)元');
    final incomeMatch = incomeRegex.firstMatch(text);
    if (incomeMatch != null) {
      return ParsedTransaction(
        amount: double.tryParse(incomeMatch.group(1) ?? '0') ?? 0,
        merchant: '未知(回退)',
        type: TransactionType.income,
        source: packageName, // Use the original package name
      );
    }

    return null;
  }
}

/// A fallback parser for WeChat notifications.
class WeChatFallbackParser implements NotificationParser {
  @override
  ParsedTransaction? parse(String packageName, String title, String text) {
    // WeChat often uses "微信支付" as the title for payment notifications.
    if (title == '微信支付') {
      final regex = RegExp(r'收款([\d.]+)元');
      final match = regex.firstMatch(text);
      if (match != null) {
        return ParsedTransaction(
          amount: double.tryParse(match.group(1) ?? '0') ?? 0,
          merchant: '未知(回退)',
          type: TransactionType.income,
          source: packageName, // Use the original package name
        );
      }
    }
    return null;
  }
} 