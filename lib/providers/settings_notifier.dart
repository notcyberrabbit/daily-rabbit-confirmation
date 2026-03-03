import 'package:flutter/foundation.dart';

import '../services/error_logger.dart';
import '../services/storage_service.dart';

/// Holds filter preference (All vs Favorites) and syncs with storage.
class SettingsNotifier extends ChangeNotifier {
  final StorageService _storage = StorageService();
  bool _favoritesOnly = false;

  bool get favoritesOnly => _favoritesOnly;

  Future<void> load() async {
    try {
      _favoritesOnly = await _storage.getFilterFavoritesOnly();
      notifyListeners();
    } catch (e, st) {
      ErrorLogger.log('SettingsNotifier.load', e, st);
    }
  }

  Future<void> setFavoritesOnly(bool value) async {
    if (_favoritesOnly == value) return;
    _favoritesOnly = value;
    await _storage.setFilterFavoritesOnly(value);
    notifyListeners();
  }
}
