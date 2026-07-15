import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

class ErrorLogger {
  static const String _logKey = 'app_error_logs';
  static const int _maxLogs = 100;

  static Future<void> logError(dynamic error, {String type = 'general', Map<String, dynamic>? extraInfo}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> logs = await getErrors();

      final newLog = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'message': error?.toString() ?? 'Unknown Error',
        'url': extraInfo?['url'] ?? 'unknown',
        if (extraInfo != null) ...extraInfo,
      };

      logs.insert(0, newLog);

      if (logs.length > _maxLogs) {
        logs.removeRange(_maxLogs, logs.length);
      }

      final List<String> encodedLogs = logs.map((l) => jsonEncode(l)).toList();
      await prefs.setStringList(_logKey, encodedLogs);
    } catch (e) {
      debugPrint('Failed to save log to shared_preferences: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? raw = prefs.getStringList(_logKey);
      if (raw == null) return [];
      
      return raw.map((item) {
        try {
          return jsonDecode(item) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      }).where((item) => item.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Failed to read logs from shared_preferences: $e');
      return [];
    }
  }

  static Future<void> clearErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logKey);
    } catch (e) {
      debugPrint('Failed to clear logs from shared_preferences: $e');
    }
  }

  static Future<void> exportErrors(BuildContext context) async {
    try {
      final List<Map<String, dynamic>> logs = await getErrors();
      if (logs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No diagnostic logs available to export.')),
          );
        }
        return;
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(logs);

      // Use platform-specific directory:
      // Android → public Downloads folder (visible in Files app)
      // iOS     → app Documents directory (accessible via Files app when UIFileSharingEnabled)
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getDownloadsDirectory() ?? await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find storage directory.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final String dateStr = DateTime.now().toIso8601String().split('T').first;
      final String filePath = '${dir.path}/mano_app_errors_$dateStr.json';

      final File file = File(filePath);
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads (${logs.length} entries)'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () => OpenFilex.open(filePath),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
