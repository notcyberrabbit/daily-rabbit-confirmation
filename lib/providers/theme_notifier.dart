import 'package:flutter/foundation.dart';

import '../models/app_theme.dart';
import '../services/error_logger.dart';
import '../services/storage_service.dart';

/// Holds current app theme and persists via [StorageService].
class ThemeNotifier extends ChangeNotifier {
  final StorageService _storage = StorageService();
  AppTheme _theme = AppTheme.midnightBlue;

  AppTheme get theme => _theme;

  /// Load theme from storage (call on startup).
  Future<void> load() async {
    try {
      final id = await _storage.getTheme();
      _theme = AppTheme.fromId(id);
      notifyListeners();
    } catch (e, st) {
      ErrorLogger.log('ThemeNotifier.load', e, st);
    }
  }

  Future<void> setTheme(AppTheme value) async {
    if (_theme.id == value.id) return;
    _theme = value;
    await _storage.setTheme(value.id);
    notifyListeners();
  }
}
