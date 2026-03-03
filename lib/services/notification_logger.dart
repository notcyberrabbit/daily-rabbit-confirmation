import 'package:flutter/foundation.dart';

/// Logs notification events for debugging. Displayed on Debug Logs screen.
class NotificationLogger {
  static final NotificationLogger _instance = NotificationLogger._();
  factory NotificationLogger() => _instance;

  NotificationLogger._();

  static const int _maxEntries = 100;
  final List<String> _entries = [];
  final List<VoidCallback> _listeners = [];

  List<String> get entries => List.unmodifiable(_entries);

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final l in _listeners) {
      try {
        l();
      } catch (_) {}
    }
  }

  void log(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    _entries.insert(0, line);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    _notify();
  }

  void clear() {
    _entries.clear();
    _notify();
  }
}
