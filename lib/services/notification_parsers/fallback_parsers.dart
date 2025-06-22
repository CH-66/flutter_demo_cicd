import '../../../models/transaction_data.dart';
import 'notification_parser.dart';

/// 一个备用的、基于关键字的支付宝解析器，作为最后手段。
class AlipayFallbackParser implements NotificationParser {
  @override
  ParsedTransaction? parse(String title, String text) {
    try {
      // 类型判断：简单地通过关键字判断
      final type = (text.contains('支出') || text.contains('支付') || text.contains('付款'))
          ? TransactionType.expense
          : (text.contains('收入') || text.contains('收款'))
              ? TransactionType.income
              : null;
      
      if (type == null) return null;

      // 金额提取：移除所有非数字和非小数点的字符
      final amountString = text.replaceAll(RegExp(r'[^0-9.]'), '');
      if (amountString.isEmpty) return null;
      
      final amount = double.tryParse(amountString);
      if (amount == null || amount == 0.0) return null;

      // 由于是模糊匹配，我们无法获取精确的商户名，使用一个通用名称
      final merchant = (type == TransactionType.expense) ? '支付宝支出' : '支付宝收款';

      return ParsedTransaction(
        amount: amount,
        merchant: merchant,
        type: type,
        source: 'Alipay (Fallback)', // 明确标注为备用解析
      );
    } catch (e) {
      return null;
    }
  }
}

/// 一个备用的、基于关键字的微信解析器，作为最后手段。
class WeChatFallbackParser implements NotificationParser {
  @override
  ParsedTransaction? parse(String title, String text) {
     try {
      // 类型判断
      final type = (text.contains('支出') || text.contains('支付') || text.contains('付款'))
          ? TransactionType.expense
          : (text.contains('收入') || text.contains('收款'))
              ? TransactionType.income
              : null;
      
      if (type == null) return null;

      // 金额提取：找到'¥'符号后进行截取
      final
      moneyIndex = text.indexOf('¥');
      if (moneyIndex == -1) return null;

      final amountString = text.substring(moneyIndex + 1);
       if (amountString.isEmpty) return null;

      final amount = double.tryParse(amountString);
      if (amount == null || amount == 0.0) return null;
      
      // 使用通用商户名
      final merchant = (type == TransactionType.expense) ? '微信支付' : '微信收款';

      return ParsedTransaction(
        amount: amount,
        merchant: merchant,
        type: type,
        source: 'WeChat (Fallback)', // 明确标注为备用解析
      );
    } catch (e) {
      return null;
    }
  }
} 