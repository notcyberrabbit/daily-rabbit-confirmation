import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/affirmation.dart';
import 'error_logger.dart';
import 'storage_service.dart';

/// Loads affirmations from JSON and provides random pick with repeat avoidance.
class AffirmationService {
  final StorageService _storage = StorageService();
  List<Affirmation> _all = [];
  String? _lastId;
  final Random _random = Random();

  List<Affirmation> get all => List.unmodifiable(_all);

  /// Load from assets/affirmations.json and apply favorites from storage.
  Future<void> load() async {
    try {
      final str = await rootBundle.loadString('assets/affirmations.json');
      final list = jsonDecode(str) as List<dynamic>;
      _all = list
          .map((e) => Affirmation.fromJson(e as Map<String, dynamic>))
          .toList();

      final favoriteIds = await _storage.getFavoriteIds();
      for (final a in _all) {
        a.isFavorite = favoriteIds.contains(a.id);
      }
    } catch (e, st) {
      ErrorLogger.log('AffirmationService.load', e, st);
      _all = [];
    }
  }

  /// Get a random affirmation, avoiding immediate repeat of the last one.
  Affirmation? getRandomAffirmation({bool favoritesOnly = false}) {
    if (_all.isEmpty) return null;
    List<Affirmation> pool = favoritesOnly
        ? _all.where((a) => a.isFavorite).toList()
        : List.from(_all);
    if (pool.isEmpty) pool = List.from(_all);
    if (pool.length == 1) {
      _lastId = pool.first.id;
      return pool.first;
    }
    // Prefer not repeating last
    pool.removeWhere((a) => a.id == _lastId);
    if (pool.isEmpty) pool = List.from(_all);
    final chosen = pool[_random.nextInt(pool.length)];
    _lastId = chosen.id;
    return chosen;
  }

  /// Toggle favorite and persist.
  Future<void> toggleFavorite(Affirmation a) async {
    final idx = _all.indexWhere((x) => x.id == a.id);
    if (idx < 0) return;
    _all[idx].isFavorite = !_all[idx].isFavorite;
    final ids = _all.where((x) => x.isFavorite).map((x) => x.id).toList();
    await _storage.setFavoriteIds(ids);
  }

  List<Affirmation> get favorites =>
      _all.where((a) => a.isFavorite).toList();
}
