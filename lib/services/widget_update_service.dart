import 'dart:io';

import 'package:flutter/services.dart';

/// Notifies Android home screen widget to refresh when app data changes.
class WidgetUpdateService {
  static const _channel = MethodChannel('com.dailyrabbit.daily_rabbit_confirmation/widget');

  /// Call when affirmation or tasks change to refresh the widget.
  static Future<void> notifyWidgetUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (_) {}
  }
}
