import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrlKey = 'crm_base_url';
  static const String _ownerIdKey = 'crm_owner_id';
  static const String _staffEmailKey = 'crm_staff_email';
  static const String _staffNameKey = 'crm_staff_name';
  static const String _lastSyncKey = 'crm_last_sync';

  String? _baseUrl;
  String? _ownerId;
  String? _staffEmail;
  String? _staffName;

  String? get baseUrl => _baseUrl;
  String? get ownerId => _ownerId;
  String? get staffEmail => _staffEmail;
  String? get staffName => _staffName;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey);
    _ownerId = prefs.getString(_ownerIdKey);
    _staffEmail = prefs.getString(_staffEmailKey);
    _staffName = prefs.getString(_staffNameKey);
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String ownerId,
    required String staffEmail,
    required String staffName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _ownerId = ownerId;
    _staffEmail = staffEmail;
    _staffName = staffName;
    await prefs.setString(_baseUrlKey, _baseUrl!);
    await prefs.setString(_ownerIdKey, _ownerId!);
    await prefs.setString(_staffEmailKey, _staffEmail!);
    await prefs.setString(_staffNameKey, _staffName!);
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_ownerIdKey);
    await prefs.remove(_staffEmailKey);
    await prefs.remove(_staffNameKey);
    await prefs.remove(_lastSyncKey);
    _baseUrl = null;
    _ownerId = null;
    _staffEmail = null;
    _staffName = null;
  }

  bool get isConfigured => _baseUrl != null && _ownerId != null && _staffEmail != null;

  /// Verify connection by fetching team members and finding this user
  Future<Map<String, dynamic>> verifyConnection(String baseUrl, String email) async {
    final url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/data?module=teams&ownerId=_discover_&email=${Uri.encodeComponent(email)}'),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data;
      }
    }

    // Try alternative: fetch with any ownerId to verify URL is reachable
    final testResponse = await http.get(
      Uri.parse('$url/api/call-logs?ownerId=test'),
    ).timeout(const Duration(seconds: 10));

    if (testResponse.statusCode == 400 || testResponse.statusCode == 200) {
      // API is reachable
      return {'reachable': true};
    }

    throw Exception('Could not connect to CRM. Check the URL.');
  }

  /// Sync call logs to CRM (batch upload)
  Future<int> syncCallLogs(List<Map<String, dynamic>> logs) async {
    if (!isConfigured || logs.isEmpty) return 0;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/call-logs'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'ownerId': _ownerId,
        'batch': logs.map((log) {
          final entry = Map<String, dynamic>.from(log);
          entry['staffEmail'] = _staffEmail;
          entry['staffName'] = _staffName;
          return entry;
        }).toList(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      // Save last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      return data['created'] ?? 0;
    } else {
      throw Exception('Sync failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get last sync timestamp
  Future<int?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncKey);
  }

  /// Save last sync time
  Future<void> setLastSyncTime(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, timestamp);
  }
}
