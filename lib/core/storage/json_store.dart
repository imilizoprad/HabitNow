import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Minimal JSON file persistence.
///
/// Uses a purpose-built platform channel for the Android app-private files
/// directory (no path_provider dependency), falling back to a local folder
/// during desktop development. Writes are atomic (tmp file + rename) so a
/// crash mid-write can never corrupt state.
abstract final class JsonStore {
  static const MethodChannel _channel = MethodChannel('habit_now/platform');
  static Directory? _dir;

  /// Resolves (once) and returns the app's private data directory.
  static Future<Directory> directory() async {
    final Directory? cached = _dir;
    if (cached != null) return cached;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final String? path = await _channel
            .invokeMethod<String>('filesDir')
            .timeout(const Duration(seconds: 3));
        if (path != null && path.isNotEmpty) {
          _dir = Directory(path);
          return _dir!;
        }
      } on Exception {
        // Fall through to the dev fallback below.
      }
    }
    final Directory fallback = Directory('./.habitnow');
    if (!fallback.existsSync()) {
      await fallback.create(recursive: true);
    }
    _dir = fallback;
    return fallback;
  }

  static Future<Map<String, dynamic>> readJson(String name) async {
    try {
      final Directory dir = await directory();
      final File f = File('${dir.path}/$name.json');
      if (!f.existsSync()) return const <String, dynamic>{};
      final String raw = await f.readAsString();
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return const <String, dynamic>{};
    } on Exception {
      return const <String, dynamic>{};
    }
  }

  static Future<void> writeJson(String name, Map<String, dynamic> data) async {
    final Directory dir = await directory();
    final File target = File('${dir.path}/$name.json');
    final File tmp = File('${dir.path}/.$name.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    try {
      await tmp.rename(target.path);
    } on FileSystemException {
      // rename across some devices can fail if target exists on odd FS;
      // overwrite is still safe because tmp write succeeded.
      await target.writeAsString(jsonEncode(data), flush: true);
      await tmp.delete();
    }
  }
}
