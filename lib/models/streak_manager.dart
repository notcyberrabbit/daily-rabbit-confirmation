import 'package:flutter/foundation.dart';

/// Tracks daily check-in streak for the user.
/// Persisted via [StorageService]; this model holds in-memory state.
class StreakManager extends ChangeNotifier {
  int _currentStreak = 0;
  DateTime? _lastCheckIn;
  int _longestStreak = 0;

  int get currentStreak => _currentStreak;
  DateTime? get lastCheckIn => _lastCheckIn;
  int get longestStreak => _longestStreak;

  /// Initialize from persisted values (e.g. from SharedPreferences).
  void load(int currentStreak, DateTime? lastCheckIn, int longestStreak) {
    _currentStreak = currentStreak;
    _lastCheckIn = lastCheckIn;
    _longestStreak = longestStreak;
    notifyListeners();
  }

  /// Call when user "checks in" (e.g. opens app or confirms for the day).
  /// Updates streak based on whether last check-in was yesterday.
  void checkIn() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastCheckIn == null) {
      _currentStreak = 1;
    } else {
      final last = DateTime(
        _lastCheckIn!.year,
        _lastCheckIn!.month,
        _lastCheckIn!.day,
      );
      final diff = today.difference(last).inDays;
      if (diff == 0) {
        // Already checked in today, no change
        return;
      } else if (diff == 1) {
        _currentStreak += 1;
      } else {
        _currentStreak = 1;
      }
    }

    _lastCheckIn = now;
    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }
    notifyListeners();
  }

  /// For testing or reset.
  void setValues({
    required int currentStreak,
    required DateTime? lastCheckIn,
    required int longestStreak,
  }) {
    _currentStreak = currentStreak;
    _lastCheckIn = lastCheckIn;
    _longestStreak = longestStreak;
    notifyListeners();
  }
}
