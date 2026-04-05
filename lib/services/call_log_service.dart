import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallLogService {
  static const String _lastFetchKey = 'last_call_fetch_time';

  /// Request required permissions
  static Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.phone,
      Permission.contacts,
    ].request();

    return statuses[Permission.phone]?.isGranted == true;
  }

  /// Check if permissions are granted
  static Future<bool> hasPermissions() async {
    return await Permission.phone.isGranted;
  }

  /// Get new call logs since last fetch
  Future<List<Map<String, dynamic>>> getNewCallLogs() async {
    final hasPerms = await hasPermissions();
    if (!hasPerms) return [];

    final prefs = await SharedPreferences.getInstance();
    final lastFetch = prefs.getInt(_lastFetchKey) ?? 0;

    // Query call logs from device
    final Iterable<CallLogEntry> entries = await CallLog.query(
      dateFrom: lastFetch > 0 ? lastFetch : null,
    );

    final logs = <Map<String, dynamic>>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final entry in entries) {
      // Skip entries older than last fetch
      if (lastFetch > 0 && (entry.timestamp ?? 0) <= lastFetch) continue;

      logs.add({
        'phone': entry.number ?? '',
        'contactName': entry.name ?? '',
        'direction': _mapCallType(entry.callType),
        'outcome': _mapOutcome(entry.callType, entry.duration),
        'duration': entry.duration ?? 0,
        'createdAt': entry.timestamp ?? now,
        'source': 'android',
      });
    }

    return logs;
  }

  /// Get all call logs (for initial display)
  Future<List<Map<String, dynamic>>> getAllRecentCallLogs({int days = 7}) async {
    final hasPerms = await hasPermissions();
    if (!hasPerms) return [];

    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    final Iterable<CallLogEntry> entries = await CallLog.query(
      dateFrom: from,
    );

    return entries.map((entry) {
      return <String, dynamic>{
        'phone': entry.number ?? '',
        'contactName': entry.name ?? '',
        'direction': _mapCallType(entry.callType),
        'outcome': _mapOutcome(entry.callType, entry.duration),
        'duration': entry.duration ?? 0,
        'createdAt': entry.timestamp ?? DateTime.now().millisecondsSinceEpoch,
        'source': 'android',
      };
    }).toList();
  }

  /// Save last fetch timestamp
  Future<void> updateLastFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Reset last fetch (for re-sync)
  Future<void> resetLastFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastFetchKey);
  }

  String _mapCallType(CallType? type) {
    switch (type) {
      case CallType.incoming:
      case CallType.answeredExternally:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.rejected:
        return 'Missed';
      default:
        return 'Incoming';
    }
  }

  String _mapOutcome(CallType? type, int? duration) {
    if (type == CallType.missed || type == CallType.rejected) {
      return 'No Answer';
    }
    if ((duration ?? 0) > 0) {
      return 'Connected';
    }
    return 'No Answer';
  }
}
