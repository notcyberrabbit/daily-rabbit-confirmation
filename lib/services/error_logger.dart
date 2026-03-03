import 'package:flutter/foundation.dart';

/// In-memory error log with optional persistence.
/// Used for Error Logs screen: list, copy all, clear all.
class ErrorLogger {
  static final List<ErrorEntry> _entries = [];

  static List<ErrorEntry> get entries => List.unmodifiable(_entries);

  /// Log an error with optional stack trace.
  static void log(String source, Object error, [StackTrace? stackTrace]) {
    _entries.insert(
      0,
      ErrorEntry(
        source: source,
        message: error.toString(),
        stackTrace: stackTrace?.toString(),
        timestamp: DateTime.now(),
      ),
    );
    if (kDebugMode) {
      debugPrint('[$source] $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }

  /// Log an info/debug message (shows on Error logs screen and in console).
  static void info(String source, String message) {
    _entries.insert(
      0,
      ErrorEntry(
        source: source,
        message: message,
        stackTrace: null,
        timestamp: DateTime.now(),
      ),
    );
    if (kDebugMode) {
      debugPrint('[$source] $message');
    }
  }

  /// Export all as single string (for Copy all).
  static String exportAll() {
    final buffer = StringBuffer();
    for (final e in _entries) {
      buffer.writeln('--- ${e.timestamp.toIso8601String()} ---');
      buffer.writeln('[${e.source}] ${e.message}');
      if (e.stackTrace != null) buffer.writeln(e.stackTrace);
      buffer.writeln();
    }
    return buffer.toString();
  }

  static void clearAll() {
    _entries.clear();
  }
}

class ErrorEntry {
  final String source;
  final String message;
  final String? stackTrace;
  final DateTime timestamp;

  ErrorEntry({
    required this.source,
    required this.message,
    this.stackTrace,
    required this.timestamp,
  });
}
