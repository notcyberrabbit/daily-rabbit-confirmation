import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'error_logger.dart';
import 'notification_logger.dart';
import 'storage_service.dart';

/// Notification types with unique IDs.
enum NotificationType {
  morning(1),
  evening(2);

  const NotificationType(this.id);
  final int id;
}

/// Manages local notifications for daily reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  NotificationService._();

  static const String _channelId = 'daily_rabbit_reminders';
  static const String _channelName = 'Daily Reminders';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StorageService _storage = StorageService();

  bool _initialized = false;

  /// Initialize notifications and request permissions.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      tz_data.initializeTimeZones();
      String tzName = 'UTC';
      try {
        tzName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      NotificationLogger().log('Initialized, timezone: $tzName');

      const android = AndroidInitializationSettings('ic_notification');
      const initSettings = InitializationSettings(android: android);

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createChannel();
      _initialized = true;
      return true;
    } catch (e, st) {
      ErrorLogger.log('NotificationService.initialize', e, st);
      return false;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      NotificationLogger().log('Notification tapped, payload: ${response.payload}');
    }
  }

  Future<void> _createChannel() async {
    if (!Platform.isAndroid) return;
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e, st) {
      ErrorLogger.log('NotificationService.requestPermission', e, st);
      return false;
    }
  }

  /// Check if notification permission is granted.
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Schedule daily notification at given time (HH:mm).
  Future<void> scheduleDailyNotification(NotificationType type, String timeHHmm) async {
    if (!Platform.isAndroid) return;
    try {
      try {
        await cancelNotification(type.id);
      } catch (_) {
        // Ignore cancel errors (e.g. Missing type parameter in release)
      }

      final parts = timeHHmm.split(':');
      final hour = int.tryParse(parts.first) ?? 9;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final (title, body) = switch (type) {
        NotificationType.morning => (
            'Daily Rabbit',
            'GM! Check your daily affirmation 🐰',
          ),
        NotificationType.evening => (
            'Daily Rabbit',
            'Time to review today\'s tasks 📝',
          ),
      };

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: 'ic_notification',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );

      await _plugin.zonedSchedule(
        type.id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: type.name,
      );
      NotificationLogger().log('${type.name} scheduled for $timeHHmm (next: ${scheduled.toIso8601String()})');
    } catch (e, st) {
      ErrorLogger.log('NotificationService.scheduleDailyNotification', e, st);
      NotificationLogger().log('Schedule FAILED: $e');
      rethrow;
    }
  }

  /// Cancel scheduled notification.
  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
      final type = id == NotificationType.morning.id ? 'morning' : 'evening';
      NotificationLogger().log('$type notification cancelled');
    } catch (e, st) {
      ErrorLogger.log('NotificationService.cancelNotification', e, st);
    }
  }

  /// Cancel all reminder notifications.
  Future<void> cancelAllReminders() async {
    await cancelNotification(NotificationType.morning.id);
    await cancelNotification(NotificationType.evening.id);
  }

  /// Show immediate notification.
  Future<void> showNotification(String title, String body) async {
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: 'ic_notification',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      await _plugin.show(0, title, body, details);
      NotificationLogger().log('Test notification sent');
    } catch (e, st) {
      ErrorLogger.log('NotificationService.showNotification', e, st);
      NotificationLogger().log('Test notification FAILED: $e');
    }
  }

  /// Apply notification settings from storage.
  Future<void> applySettings() async {
    await _storage.init();
    final enabled = await _storage.getNotificationsEnabled();
    if (!enabled) {
      await cancelAllReminders();
      NotificationLogger().log('Notifications disabled, all cancelled');
      return;
    }
    NotificationLogger().log('Applying notification settings');

    // Request exact alarm permission (Android 14+)
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    if (await _storage.getMorningNotificationEnabled()) {
      final time = await _storage.getMorningNotificationTime();
      await scheduleDailyNotification(NotificationType.morning, time);
    } else {
      await cancelNotification(NotificationType.morning.id);
    }

    if (await _storage.getEveningNotificationEnabled()) {
      final time = await _storage.getEveningNotificationTime();
      await scheduleDailyNotification(NotificationType.evening, time);
    } else {
      await cancelNotification(NotificationType.evening.id);
    }
  }
}
