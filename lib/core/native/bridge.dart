import 'package:flutter/services.dart';

/// Purpose-built native bridge (Android host implements both methods).
/// Keeping persistence + notifications here means zero plugin dependencies.
abstract final class NativeBridge {
  static const MethodChannel _ch = MethodChannel('habit_now/platform');

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int atMs,
    List<int> weekdays = const <int>[],
  }) async {
    try {
      await _ch.invokeMethod<void>('scheduleReminder', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'at': atMs,
        'weekdays': weekdays,
      });
    } on PlatformException {
      // Notifications are a nice-to-have; the app works without them.
    } on MissingPluginException {
      // Desktop/dev runs.
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      await _ch.invokeMethod<void>('cancelReminder', <String, dynamic>{
        'id': id,
      });
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
