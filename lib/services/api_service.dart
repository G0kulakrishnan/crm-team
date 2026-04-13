import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrlKey = 'crm_base_url';
  static const String _ownerIdKey = 'crm_owner_id';
  static const String _staffEmailKey = 'crm_staff_email';
  static const String _staffNameKey = 'crm_staff_name';
  static const String _staffRoleKey = 'crm_staff_role';
  static const String _lastSyncKey = 'crm_last_sync';

  static const String crmUrl = 'https://dev.t2gcrm.in';

  String? _baseUrl;
  String? _ownerId;
  String? _staffEmail;
  String? _staffName;
  String? _staffRole;
  String? get baseUrl => _baseUrl;
  String? get ownerId => _ownerId;
  String? get staffEmail => _staffEmail;
  String? get staffName => _staffName;
  String? get staffRole => _staffRole;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey);
    _ownerId = prefs.getString(_ownerIdKey);
    _staffEmail = prefs.getString(_staffEmailKey);
    _staffName = prefs.getString(_staffNameKey);
    _staffRole = prefs.getString(_staffRoleKey);
  }

  Future<void> _saveConfig({
    required String baseUrl,
    required String ownerId,
    required String staffEmail,
    required String staffName,
    required String staffRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = baseUrl;
    _ownerId = ownerId;
    _staffEmail = staffEmail;
    _staffName = staffName;
    _staffRole = staffRole;
    await prefs.setString(_baseUrlKey, baseUrl);
    await prefs.setString(_ownerIdKey, ownerId);
    await prefs.setString(_staffEmailKey, staffEmail);
    await prefs.setString(_staffNameKey, staffName);
    await prefs.setString(_staffRoleKey, staffRole);
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_ownerIdKey);
    await prefs.remove(_staffEmailKey);
    await prefs.remove(_staffNameKey);
    await prefs.remove(_staffRoleKey);
    await prefs.remove(_lastSyncKey);
    _baseUrl = null;
    _ownerId = null;
    _staffEmail = null;
    _staffName = null;
    _staffRole = null;
  }

  bool get isConfigured => _baseUrl != null && _ownerId != null && _staffEmail != null;

  /// Login with email + password via CRM auth API.
  /// Returns user info including ownerUserId, name, role.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = crmUrl;

    // Step 1: Authenticate via /api/auth?action=login
    final loginResponse = await http.post(
      Uri.parse('$url/api/auth'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'login',
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    final loginData = json.decode(loginResponse.body);

    if (loginResponse.statusCode != 200 || loginData['success'] != true) {
      throw Exception(loginData['error'] ?? 'Login failed');
    }

    // Extract info from login response
    String ownerUserId = loginData['ownerUserId'] ?? '';
    String name = '';
    String role = loginData['role'] ?? '';

    // If ownerUserId is available from login, use it
    if (ownerUserId.isNotEmpty) {
      // For team members, login already returns ownerUserId
      // Get the team member name
      if (loginData['isTeamMember'] == true) {
        // Fetch name from roles endpoint
        final rolesResponse = await http.post(
          Uri.parse('$url/api/auth'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'roles',
            'email': email.trim().toLowerCase(),
          }),
        ).timeout(const Duration(seconds: 10));

        final rolesData = json.decode(rolesResponse.body);
        if (rolesData['success'] == true) {
          name = rolesData['name'] ?? '';
          ownerUserId = rolesData['ownerUserId'] ?? ownerUserId;
          role = rolesData['role'] ?? role;
        }
      }
    } else {
      // Fallback: use roles endpoint to discover
      final rolesResponse = await http.post(
        Uri.parse('$url/api/auth'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'roles',
          'email': email.trim().toLowerCase(),
        }),
      ).timeout(const Duration(seconds: 10));

      final rolesData = json.decode(rolesResponse.body);
      if (rolesResponse.statusCode == 200 && rolesData['success'] == true) {
        ownerUserId = rolesData['ownerUserId'] ?? '';
        name = rolesData['name'] ?? '';
        role = rolesData['role'] ?? '';
      }
    }

    if (ownerUserId.isEmpty) {
      throw Exception('Could not determine your business. Contact your admin.');
    }

    // Save config
    await _saveConfig(
      baseUrl: url,
      ownerId: ownerUserId,
      staffEmail: email.trim().toLowerCase(),
      staffName: name.isNotEmpty ? name : email.trim(),
      staffRole: role,
    );

    return {
      'ownerUserId': ownerUserId,
      'name': name,
      'role': role,
      'isTeamMember': loginData['isTeamMember'] ?? false,
    };
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

  /// Check-in: POST /api/attendance with action='checkin'
  Future<Map<String, dynamic>> checkIn({
    required double lat,
    required double lng,
    required String address,
  }) async {
    if (!isConfigured) throw Exception('Not configured');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'checkin',
        'ownerId': _ownerId,
        'staffEmail': _staffEmail,
        'staffName': _staffName,
        'lat': lat,
        'lng': lng,
        'address': address,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Check-in failed');
    }
  }

  /// Check-out: POST /api/attendance with action='checkout'
  Future<Map<String, dynamic>> checkOut({
    required double lat,
    required double lng,
    required String address,
  }) async {
    if (!isConfigured) throw Exception('Not configured');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'checkout',
        'ownerId': _ownerId,
        'staffEmail': _staffEmail,
        'staffName': _staffName,
        'lat': lat,
        'lng': lng,
        'address': address,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Check-out failed');
    }
  }

  /// Get attendance records
  Future<List<Map<String, dynamic>>> getAttendance({String? date}) async {
    if (!isConfigured) throw Exception('Not configured');

    final queryParams = <String, String>{
      'ownerId': _ownerId!,
      'staffEmail': _staffEmail!,
    };
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$_baseUrl/api/attendance').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } else {
      throw Exception(data['error'] ?? 'Failed to fetch attendance');
    }
  }

  /// Fetch leads for current business
  Future<List<Map<String, dynamic>>> fetchLeads() async {
    if (!isConfigured) throw Exception('Not configured');

    final queryParams = <String, String>{
      'module': 'leads',
      'ownerId': _ownerId!,
    };

    final uri = Uri.parse('$_baseUrl/api/data').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } else {
      throw Exception(data['error'] ?? 'Failed to fetch leads');
    }
  }

  /// Create a new lead
  Future<Map<String, dynamic>> createLead({
    required String name,
    required String phone,
    required String email,
    required String source,
    required String stage,
    String requirement = '',
    String assign = '',
    String followup = '',
    String notes = '',
    String companyName = '',
    String productCat = '',
    Map<String, dynamic> custom = const {},
  }) async {
    if (!isConfigured) throw Exception('Not configured');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/data'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'module': 'leads',
        'ownerId': _ownerId,
        'actorId': _ownerId,
        'userName': _staffEmail,
        'name': name,
        'phone': phone,
        'email': email,
        'source': source,
        'stage': stage,
        'requirement': requirement,
        'assign': assign,
        'followup': followup,
        'notes': notes,
        'companyName': companyName,
        'productCat': productCat,
        'custom': custom,
        'createdDate': DateTime.now().toIso8601String(),
        'staffEmail': _staffEmail,
        'staffName': _staffName,
        'logText': 'Lead created from mobile app',
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to create lead');
    }
  }

  /// Update an existing lead
  Future<Map<String, dynamic>> updateLead({
    required String leadId,
    required String name,
    required String phone,
    required String email,
    required String source,
    required String stage,
    String requirement = '',
    String assign = '',
    String followup = '',
    String notes = '',
    String companyName = '',
    String productCat = '',
    Map<String, dynamic> custom = const {},
  }) async {
    if (!isConfigured) throw Exception('Not configured');

    final response = await http.patch(
      Uri.parse('$_baseUrl/api/data'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'module': 'leads',
        'ownerId': _ownerId,
        'actorId': _ownerId,
        'userName': _staffEmail,
        'id': leadId,
        'name': name,
        'phone': phone,
        'email': email,
        'source': source,
        'stage': stage,
        'requirement': requirement,
        'assign': assign,
        'followup': followup,
        'notes': notes,
        'companyName': companyName,
        'productCat': productCat,
        'custom': custom,
        'logText': 'Lead updated from mobile app',
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to update lead');
    }
  }

  /// Delete a lead
  Future<bool> deleteLead({required String leadId}) async {
    if (!isConfigured) throw Exception('Not configured');

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/data'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'module': 'leads',
        'ownerId': _ownerId,
        'actorId': _ownerId,
        'userName': _staffEmail,
        'id': leadId,
        'logText': 'Lead deleted from mobile app',
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return true;
    } else {
      throw Exception(data['error'] ?? 'Failed to delete lead');
    }
  }
}
