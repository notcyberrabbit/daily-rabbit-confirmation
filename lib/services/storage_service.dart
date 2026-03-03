import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme.dart';

/// Persists user preferences and streak via SharedPreferences.
/// Keys are namespaced to avoid clashes.
class StorageService {
  static const _keyName = 'daily_rabbit_name';
  static const _keyTheme = 'daily_rabbit_theme';
  static const _keyHaptic = 'daily_rabbit_haptic';
  static const _keyFavorites = 'daily_rabbit_favorites';
  static const _keyFilterFavoritesOnly = 'daily_rabbit_filter_favorites';
  static const _keyCurrentStreak = 'daily_rabbit_current_streak';
  static const _keyLastCheckIn = 'daily_rabbit_last_check_in';
  static const _keyLongestStreak = 'daily_rabbit_longest_streak';
  static const _keyAffirmationsViewed = 'daily_rabbit_affirmations_viewed';
  static const _keyMiniplayTotalCarrots = 'daily_rabbit_miniplay_total_carrots';
  static const _keyMiniplayLastSessionTs = 'daily_rabbit_miniplay_last_session_ts';
  static const _keyMiniplayTapsRemaining = 'daily_rabbit_miniplay_taps_remaining';
  static const _keyTasks = 'daily_rabbit_tasks';
  static const _keyTasksFilter = 'daily_rabbit_tasks_filter';
  static const _keyTaskLastResetDate = 'daily_rabbit_task_last_reset';
  static const _keyTaskStreak = 'daily_rabbit_task_streak';
  static const _keyTaskDailyLog = 'daily_rabbit_task_daily_log';
  static const _keyTaskAutoReset = 'daily_rabbit_task_auto_reset';
  static const _keyWalletConnectTopic = 'daily_rabbit_wc_topic';
  static const _keyWidgetAffirmation = 'daily_rabbit_widget_affirmation';
  static const _keyNotificationsEnabled = 'daily_rabbit_notifications_enabled';
  static const _keyMorningEnabled = 'daily_rabbit_morning_enabled';
  static const _keyMorningTime = 'daily_rabbit_morning_time';
  static const _keyEveningEnabled = 'daily_rabbit_evening_enabled';
  static const _keyEveningTime = 'daily_rabbit_evening_time';
  static const _keyStartScreen = 'daily_rabbit_start_screen';
  static const _keyShowOnChainAnalytics = 'daily_rabbit_show_on_chain_analytics';

  /// Miniplay: session duration (8 hours).
  static const int miniplaySessionHours = 8;
  static const int miniplayTapsPerSession = 100;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _p async {
    await init();
    return _prefs!;
  }

  /// User display name.
  Future<String> getName() async {
    return (await _p).getString(_keyName) ?? 'Friend';
  }

  Future<void> setName(String name) async {
    await (await _p).setString(_keyName, name);
  }

  /// Theme id index (0–3) or name.
  Future<ThemeId> getTheme() async {
    final raw = (await _p).getInt(_keyTheme);
    if (raw == null || raw < 0 || raw >= ThemeId.values.length) {
      return ThemeId.midnightBlue;
    }
    return ThemeId.values[raw];
  }

  Future<void> setTheme(ThemeId theme) async {
    await (await _p).setInt(_keyTheme, theme.index);
  }

  /// Haptic feedback enabled.
  Future<bool> getHapticEnabled() async {
    return (await _p).getBool(_keyHaptic) ?? true;
  }

  Future<void> setHapticEnabled(bool value) async {
    await (await _p).setBool(_keyHaptic, value);
  }

  /// Favorite affirmation ids (list of strings).
  Future<List<String>> getFavoriteIds() async {
    final list = (await _p).getStringList(_keyFavorites);
    return list ?? [];
  }

  Future<void> setFavoriteIds(List<String> ids) async {
    await (await _p).setStringList(_keyFavorites, ids);
  }

  Future<bool> getFilterFavoritesOnly() async {
    return (await _p).getBool(_keyFilterFavoritesOnly) ?? false;
  }

  Future<void> setFilterFavoritesOnly(bool value) async {
    await (await _p).setBool(_keyFilterFavoritesOnly, value);
  }

  /// Streak data.
  Future<int> getCurrentStreak() async {
    return (await _p).getInt(_keyCurrentStreak) ?? 0;
  }

  Future<void> setCurrentStreak(int value) async {
    await (await _p).setInt(_keyCurrentStreak, value);
  }

  Future<DateTime?> getLastCheckIn() async {
    final ms = (await _p).getInt(_keyLastCheckIn);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastCheckIn(DateTime? value) async {
    if (value == null) {
      await (await _p).remove(_keyLastCheckIn);
    } else {
      await (await _p).setInt(_keyLastCheckIn, value.millisecondsSinceEpoch);
    }
  }

  Future<int> getLongestStreak() async {
    return (await _p).getInt(_keyLongestStreak) ?? 0;
  }

  Future<void> setLongestStreak(int value) async {
    await (await _p).setInt(_keyLongestStreak, value);
  }

  /// Total number of affirmations viewed (incremented each time user sees one).
  Future<int> getAffirmationsViewed() async {
    return (await _p).getInt(_keyAffirmationsViewed) ?? 0;
  }

  Future<void> setAffirmationsViewed(int value) async {
    await (await _p).setInt(_keyAffirmationsViewed, value);
  }

  Future<void> incrementAffirmationsViewed() async {
    final n = await getAffirmationsViewed();
    await setAffirmationsViewed(n + 1);
  }

  /// Miniplay Tap the Rabbit: total carrots earned (lifetime).
  Future<int> getMiniplayTotalCarrots() async {
    return (await _p).getInt(_keyMiniplayTotalCarrots) ?? 0;
  }

  Future<void> setMiniplayTotalCarrots(int value) async {
    await (await _p).setInt(_keyMiniplayTotalCarrots, value);
  }

  /// Last session start timestamp (milliseconds since epoch).
  Future<int?> getMiniplayLastSessionTimestamp() async {
    return (await _p).getInt(_keyMiniplayLastSessionTs);
  }

  Future<void> setMiniplayLastSessionTimestamp(int? value) async {
    if (value == null) {
      await (await _p).remove(_keyMiniplayLastSessionTs);
    } else {
      await (await _p).setInt(_keyMiniplayLastSessionTs, value);
    }
  }

  /// Taps remaining in current session (0–100).
  Future<int> getMiniplayTapsRemaining() async {
    final v = (await _p).getInt(_keyMiniplayTapsRemaining);
    if (v == null || v < 0 || v > miniplayTapsPerSession) {
      return miniplayTapsPerSession;
    }
    return v;
  }

  Future<void> setMiniplayTapsRemaining(int value) async {
    await (await _p).setInt(_keyMiniplayTapsRemaining, value.clamp(0, miniplayTapsPerSession));
  }

  /// If more than [miniplaySessionHours] have passed since last session, reset taps to 100 and update last session ts. Returns current taps remaining.
  Future<int> getMiniplayTapsRemainingWithSessionReset() async {
    await init();
    final prefs = _prefs!;
    final now = DateTime.now();
    final lastMs = prefs.getInt(_keyMiniplayLastSessionTs);
    int tapsRemaining = prefs.getInt(_keyMiniplayTapsRemaining) ?? miniplayTapsPerSession;
    if (tapsRemaining < 0 || tapsRemaining > miniplayTapsPerSession) {
      tapsRemaining = miniplayTapsPerSession;
    }
    if (lastMs == null) {
      await setMiniplayLastSessionTimestamp(now.millisecondsSinceEpoch);
      await setMiniplayTapsRemaining(miniplayTapsPerSession);
      return miniplayTapsPerSession;
    }
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final elapsed = now.difference(last);
    if (elapsed.inHours >= miniplaySessionHours) {
      await setMiniplayLastSessionTimestamp(now.millisecondsSinceEpoch);
      await setMiniplayTapsRemaining(miniplayTapsPerSession);
      return miniplayTapsPerSession;
    }
    return tapsRemaining;
  }

  /// Minutes until next session (when taps will reset). Returns null if session already reset or no previous session.
  Future<int?> getMiniplayMinutesUntilNextSession() async {
    final lastMs = await getMiniplayLastSessionTimestamp();
    if (lastMs == null) return null;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final now = DateTime.now();
    final elapsed = now.difference(last);
    final sessionMinutes = miniplaySessionHours * 60;
    if (elapsed.inMinutes >= sessionMinutes) return null;
    return sessionMinutes - elapsed.inMinutes;
  }

  /// Daily tasks: JSON list of {id, text, completed}.
  Future<List<Map<String, dynamic>>> getTasks() async {
    final json = (await _p).getString(_keyTasks);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => e as Map<String, dynamic>)
          .map((m) => {
                'id': m['id'] as String? ?? '',
                'text': m['text'] as String? ?? '',
                'completed': m['completed'] as bool? ?? false,
                'priority': m['priority'] as String?,
                'linkedPackage': m['linkedPackage'] as String?,
                'linkedAppName': m['linkedAppName'] as String?,
                'linkedUrl': m['linkedUrl'] as String?,
                'createdAt': m['createdAt'] as int?,
                'estimatedMinutes': m['estimatedMinutes'] as int?,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setTasks(List<Map<String, dynamic>> tasks) async {
    await (await _p).setString(_keyTasks, jsonEncode(tasks));
  }

  /// Tasks filter: 'all' | 'active' | 'completed'.
  Future<String> getTasksFilter() async {
    return (await _p).getString(_keyTasksFilter) ?? 'all';
  }

  Future<void> setTasksFilter(String value) async {
    await (await _p).setString(_keyTasksFilter, value);
  }

  /// Task last reset date (YYYY-MM-DD). When we last cleared checkboxes.
  Future<String?> getTaskLastResetDate() async {
    return (await _p).getString(_keyTaskLastResetDate);
  }

  Future<void> setTaskLastResetDate(String? value) async {
    if (value == null || value.isEmpty) {
      await (await _p).remove(_keyTaskLastResetDate);
    } else {
      await (await _p).setString(_keyTaskLastResetDate, value);
    }
  }

  /// Task streak: consecutive days with all tasks completed.
  Future<int> getTaskStreak() async {
    return (await _p).getInt(_keyTaskStreak) ?? 0;
  }

  Future<void> setTaskStreak(int value) async {
    await (await _p).setInt(_keyTaskStreak, value);
  }

  /// Task daily log: list of {date, completedCount, totalCount, completedMinutes, totalMinutes}.
  Future<List<Map<String, dynamic>>> getTaskDailyLog() async {
    final json = (await _p).getString(_keyTaskDailyLog);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setTaskDailyLog(List<Map<String, dynamic>> log) async {
    await (await _p).setString(_keyTaskDailyLog, jsonEncode(log));
  }

  /// Auto reset at midnight: clear checkboxes when a new day starts.
  Future<bool> getTaskAutoReset() async =>
      (await _p).getBool(_keyTaskAutoReset) ?? true;

  Future<void> setTaskAutoReset(bool value) async =>
      (await _p).setBool(_keyTaskAutoReset, value);

  Future<void> appendTaskDayLog(Map<String, dynamic> entry) async {
    final log = await getTaskDailyLog();
    log.insert(0, entry);
    while (log.length > 90) {
      log.removeLast();
    }
    await setTaskDailyLog(log);
  }

  /// WalletConnect v2 session topic for restore.
  Future<String?> getWalletConnectTopic() async {
    return (await _p).getString(_keyWalletConnectTopic);
  }

  Future<void> setWalletConnectTopic(String? value) async {
    if (value == null || value.isEmpty) {
      await (await _p).remove(_keyWalletConnectTopic);
    } else {
      await (await _p).setString(_keyWalletConnectTopic, value);
    }
  }

  /// Current affirmation text for home screen widget.
  Future<void> setWidgetAffirmation(String text) async {
    await (await _p).setString(_keyWidgetAffirmation, text);
  }

  /// Notifications master switch.
  Future<bool> getNotificationsEnabled() async =>
      (await _p).getBool(_keyNotificationsEnabled) ?? false;

  Future<void> setNotificationsEnabled(bool value) async =>
      (await _p).setBool(_keyNotificationsEnabled, value);

  /// Morning reminder.
  Future<bool> getMorningNotificationEnabled() async =>
      (await _p).getBool(_keyMorningEnabled) ?? false;

  Future<void> setMorningNotificationEnabled(bool value) async =>
      (await _p).setBool(_keyMorningEnabled, value);

  Future<String> getMorningNotificationTime() async =>
      (await _p).getString(_keyMorningTime) ?? '09:00';

  Future<void> setMorningNotificationTime(String value) async =>
      (await _p).setString(_keyMorningTime, value);

  /// Evening reminder.
  Future<bool> getEveningNotificationEnabled() async =>
      (await _p).getBool(_keyEveningEnabled) ?? false;

  Future<void> setEveningNotificationEnabled(bool value) async =>
      (await _p).setBool(_keyEveningEnabled, value);

  Future<String> getEveningNotificationTime() async =>
      (await _p).getString(_keyEveningTime) ?? '20:00';

  Future<void> setEveningNotificationTime(String value) async =>
      (await _p).setString(_keyEveningTime, value);

  /// Start screen after splash: 'main' | 'task' | 'minigame' | 'defi' | 'profile'.
  Future<String> getStartScreen() async =>
      (await _p).getString(_keyStartScreen) ?? 'main';

  Future<void> setStartScreen(String value) async =>
      (await _p).setString(_keyStartScreen, value);

  /// Show on-chain analytics dashboard on Profile.
  Future<bool> getShowOnChainAnalytics() async =>
      (await _p).getBool(_keyShowOnChainAnalytics) ?? true;

  Future<void> setShowOnChainAnalytics(bool value) async =>
      (await _p).setBool(_keyShowOnChainAnalytics, value);
}
