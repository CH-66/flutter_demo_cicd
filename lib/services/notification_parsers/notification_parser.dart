import '../../models/transaction_data.dart';

/// The basic interface for all notification parsers.
/// Each parser is responsible for attempting to extract transaction data
/// from a given notification's content.
abstract class NotificationParser {
  /// Attempts to parse the notification content.
  ///
  /// [packageName] The original package name of the app that sent the notification.
  /// [title] The title of the notification.
  /// [text] The main text content of the notification.
  ///
  /// Returns a [ParsedTransaction] if successful, otherwise `null`.
  ParsedTransaction? parse(String packageName, String title, String text);
} 