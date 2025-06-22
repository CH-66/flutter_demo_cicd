import '../models/transaction_data.dart';
import 'notification_parsers/alipay_parsers.dart';
import 'notification_parsers/fallback_parsers.dart';
import 'notification_parsers/notification_parser.dart';
import 'notification_parsers/wechat_parsers.dart';

class NotificationParserService {
  static const String alipayPackage = 'com.eg.android.AlipayGphone';
  static const String wechatPackage = 'com.tencent.mm';

  final Map<String, List<NotificationParser>> _parsers;

  NotificationParserService() : _parsers = {
    alipayPackage: [
      AlipayExpenseParserV1(),
      AlipayExpenseParserV2(),
      AlipayIncomeParserV1(),
      AlipayFallbackParser(),
    ],
    wechatPackage: [
      WeChatExpenseParserV1(),
      WeChatExpenseParserV2(),
      WeChatIncomeParserV1(),
      WeChatFallbackParser(),
    ],
  };

  ParsedTransaction? parse(Map<dynamic, dynamic> notificationData) {
    final String? packageName = notificationData['source']?.toString();
    final String? title = notificationData['title']?.toString();
    final String? text = notificationData['text']?.toString();

    if (packageName == null || text == null) {
      return null;
    }

    final parsersForApp = _parsers[packageName];
    if (parsersForApp == null) {
      return null;
    }

    for (final parser in parsersForApp) {
      final result = parser.parse(title ?? '', text);
      if (result != null) {
        return result;
      }
    }

    return null;
  }
} 