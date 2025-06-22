import '../models/transaction_data.dart';

class NotificationParserService {
  static const List<String> _supportedApps = [
    'com.eg.android.AlipayGphone', // 支付宝
    'com.tencent.mm', // 微信
  ];

  ParsedTransaction? parse(Map<dynamic, dynamic> notificationData) {
    final String? packageName = notificationData['source']?.toString();
    final String? title = notificationData['title']?.toString();
    final String? text = notificationData['text']?.toString();

    if (packageName == null || text == null || !_supportedApps.contains(packageName)) {
      return null;
    }

    if (packageName.contains('AlipayGphone')) {
      return _parseAlipayNotification(text);
    } else if (packageName.contains('tencent.mm')) {
      return _parseWeChatNotification(title ?? '', text);
    }

    return null;
  }

  ParsedTransaction? _parseAlipayNotification(String text) {
    // 样本: "你有一笔0.01元的支出，点击领取1个支付宝积分。"
    final expRegExp = RegExp(r'你有一笔([\d.]+)元的支出');
    final expMatch = expRegExp.firstMatch(text);
    if (expMatch != null) {
      final amount = double.tryParse(expMatch.group(1) ?? '0') ?? 0;
      return ParsedTransaction(
        amount: amount,
        type: TransactionType.expense,
        source: 'alipay',
        // 商户信息从这个样本中无法获取
      );
    }

    // 可在此处添加更多支付宝的解析规则

    return null;
  }

  ParsedTransaction? _parseWeChatNotification(String title, String text) {
    // 样本1 (忽略): "[转账]已被接收"
    if (text.contains('[转账]已被接收')) {
      return null;
    }
    
    // 样本2 (收入, 但无金额): "[转账]请收款"
    // TODO: 微信的金额通常在更复杂的通知或下一个通知里，暂时无法处理

    // 常见的支付成功通知
    // "向肯德基成功付款0.01元"
    final paymentRegExp = RegExp(r'向(.+)成功付款([\d.]+)元');
    final paymentMatch = paymentRegExp.firstMatch(text);
    if (paymentMatch != null) {
      final merchant = paymentMatch.group(1) ?? '未知商家';
      final amount = double.tryParse(paymentMatch.group(2) ?? '0') ?? 0;
      return ParsedTransaction(
        amount: amount,
        merchant: merchant,
        type: TransactionType.expense,
        source: 'wechat',
      );
    }

    // 常见的收款成功通知
    // "微信支付收款0.01元"
    final incomeRegExp = RegExp(r'收款([\d.]+)元');
    final incomeMatch = incomeRegExp.firstMatch(text);
    if (incomeMatch != null) {
      final amount = double.tryParse(incomeMatch.group(1) ?? '0') ?? 0;
      return ParsedTransaction(
        amount: amount,
        merchant: title, // 收款通知的标题通常是付款方
        type: TransactionType.income,
        source: 'wechat',
      );
    }

    return null;
  }
} 