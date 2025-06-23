import '../../models/transaction_data.dart';
import 'notification_parser.dart';

/// Parses WeChat notifications with title "微信支付凭证"
class WeChatExpenseParserV1 implements NotificationParser {
  @override
  ParsedTransaction? parse(String packageName, String title, String text) {
    if (title != '微信支付凭证') return null;

    final regex = RegExp(r'付款金额：￥([\d.]+)');
    final match = regex.firstMatch(text);

    if (match != null) {
      // This type of notification doesn't contain the merchant name in the text.
      return ParsedTransaction(
        amount: double.tryParse(match.group(1) ?? '0') ?? 0,
        type: TransactionType.expense,
        source: packageName,
      );
    }
    return null;
  }
}

/// Parses WeChat notifications like: "向{merchant}成功付款{amount}元"
class WeChatExpenseParserV2 implements NotificationParser {
  @override
  ParsedTransaction? parse(String packageName, String title, String text) {
    final regex = RegExp(r'向(.+)成功付款([\d.]+)元');
    final match = regex.firstMatch(text);

    if (match != null) {
      return ParsedTransaction(
        amount: double.tryParse(match.group(2) ?? '0') ?? 0,
        merchant: match.group(1)?.trim() ?? '未知商家',
        type: TransactionType.expense,
        source: packageName,
      );
    }
    return null;
  }
}

/// Parses WeChat notifications like: "微信支付收款{amount}元"
class WeChatIncomeParserV1 implements NotificationParser {
  @override
  ParsedTransaction? parse(String packageName, String title, String text) {
    // For income, the title is often the payer's nickname.
    final regex = RegExp(r'收款([\d.]+)元');
    final match = regex.firstMatch(text);

    if (match != null) {
      return ParsedTransaction(
        amount: double.tryParse(match.group(1) ?? '0') ?? 0,
        merchant: title.isNotEmpty ? title : '对方', // Use title as merchant if available
        type: TransactionType.income,
        source: packageName,
      );
    }
    return null;
  }
} 