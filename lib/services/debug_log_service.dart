import 'dart:async';

/// A singleton service for managing in-memory debug logs.
/// This ensures a single, consistent log store across the entire app.
class DebugLogService {
  // Private constructor for the singleton
  DebugLogService._privateConstructor();

  // The single instance
  static final DebugLogService _instance = DebugLogService._privateConstructor();

  // Factory constructor to return the single instance
  factory DebugLogService() {
    return _instance;
  }

  final List<Map<String, dynamic>> _logs = [];

  /// Adds a new log entry to the top of the list.
  Future<void> addLog(Map<String, dynamic> log) async {
    _logs.insert(0, {'timestamp': DateTime.now(), ...log});
  }

  /// Returns a copy of all current logs.
  List<Map<String, dynamic>> getLogs() {
    return List.from(_logs);
  }

  /// Clears all logs from memory.
  void clearLogs() {
    _logs.clear();
  }
} 