import '../../models/transaction_data.dart';

/// Abstract base class for all notification parsers.
/// Each concrete implementation of this class represents a "strategy" for parsing
/// a specific notification format.
abstract class NotificationParser {
  /// Attempts to parse the notification content.
  ///
  /// Returns a [ParsedTransaction] if the format is recognized and parsed successfully,
  /// otherwise returns `null`.
  ParsedTransaction? parse(String title, String text);
} 