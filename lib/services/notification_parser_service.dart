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
    // 样本1: "你向{merchant}付款{amount}元" (这个实际上是text, title为空)
    // 样本2: "你有一笔{amount}元的支出..." (这个是text, title为"交易提醒")
    final expenseRegExp1 = RegExp(r'你向(.+)付款([\d.]+)元');
    final expenseMatch1 = expenseRegExp1.firstMatch(text);
    if (expenseMatch1 != null) {
      return ParsedTransaction(
        amount: double.tryParse(expenseMatch1.group(2) ?? '0') ?? 0,
        merchant: expenseMatch1.group(1) ?? '未知商家',
        type: TransactionType.expense,
        source: 'alipay',
      );
    }
    
    final expenseRegExp2 = RegExp(r'你有一笔([\d.]+)元的支出');
    final expenseMatch2 = expenseRegExp2.firstMatch(text);
    if (expenseMatch2 != null) {
      return ParsedTransaction(
        amount: double.tryParse(expenseMatch2.group(1) ?? '0') ?? 0,
        type: TransactionType.expense,
        source: 'alipay',
      );
    }

    // 样本3: "支付宝成功收款{amount}元。"
    final incomeRegExp = RegExp(r'成功收款([\d.]+)元');
    final incomeMatch = incomeRegExp.firstMatch(text);
    if (incomeMatch != null) {
      return ParsedTransaction(
        amount: double.tryParse(incomeMatch.group(1) ?? '0') ?? 0,
        type: TransactionType.income,
        source: 'alipay',
        merchant: '对方', // 支付宝收款通知通常不带付款方
      );
    }

    return null;
  }

  ParsedTransaction? _parseWeChatNotification(String title, String text) {
    // 支付凭证类
    if (title == '微信支付凭证') {
      final certRegExp = RegExp(r'付款金额：￥([\d.]+)');
      final certMatch = certRegExp.firstMatch(text);
      if (certMatch != null) {
        return ParsedTransaction(
          amount: double.tryParse(certMatch.group(1) ?? '0') ?? 0,
          type: TransactionType.expense,
          source: 'wechat',
          merchant: '未知商家', // 凭证类通知通常需要看详情才知道商家
        );
      }
    }

    // "向{merchant}成功付款{amount}元"
    final paymentRegExp = RegExp(r'向(.+)成功付款([\d.]+)元');
    final paymentMatch = paymentRegExp.firstMatch(text);
    if (paymentMatch != null) {
      return ParsedTransaction(
        amount: double.tryParse(paymentMatch.group(2) ?? '0') ?? 0,
        merchant: paymentMatch.group(1) ?? '未知商家',
        type: TransactionType.expense,
        source: 'wechat',
      );
    }

    // "微信支付收款{amount}元"
    final incomeRegExp = RegExp(r'收款([\d.]+)元');
    final incomeMatch = incomeRegExp.firstMatch(text);
    if (incomeMatch != null) {
      return ParsedTransaction(
        amount: double.tryParse(incomeMatch.group(1) ?? '0') ?? 0,
        merchant: title, // 收款通知的标题通常是付款方
        type: TransactionType.income,
        source: 'wechat',
      );
    }

    return null;
  }
} 