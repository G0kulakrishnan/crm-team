import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class AttendanceScreen extends StatefulWidget {
  final ApiService apiService;

  const AttendanceScreen({super.key, required this.apiService});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _todayRecord;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    try {
      final records = await widget.apiService.getAttendance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      Map<String, dynamic>? todayRec;
      for (final r in records) {
        if (r['date'] == today && r['checkOutTime'] == null) {
          todayRec = r;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _records = records;
          _todayRecord = todayRec;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _actionLoading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getAddressFromCoords(
        position.latitude,
        position.longitude,
      );

      await widget.apiService.checkIn(
        lat: position.latitude,
        lng: position.longitude,
        address: address,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked in successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        await _loadAttendance();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() => _actionLoading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getAddressFromCoords(
        position.latitude,
        position.longitude,
      );

      final result = await widget.apiService.checkOut(
        lat: position.latitude,
        lng: position.longitude,
        address: address,
      );

      if (mounted) {
        final hours = result['totalHours'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked out! Total: ${hours}h worked today'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
        await _loadAttendance();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-out failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _openMap(double? lat, double? lng) {
    if (lat == null || lng == null) return;
    final url = 'https://www.google.com/maps?q=$lat,$lng';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '-';
    return DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  String _formatElapsed(int checkInTime) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - checkInTime;
    final hours = elapsed ~/ (1000 * 60 * 60);
    final minutes = (elapsed ~/ (1000 * 60)) % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = _todayRecord != null;

    return _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
        : RefreshIndicator(
            onRefresh: _loadAttendance,
            color: const Color(0xFF16A34A),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCheckedIn
                          ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                          : [const Color(0xFF64748B), const Color(0xFF475569)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isCheckedIn ? Icons.check_circle_outline : Icons.access_time,
                        size: 48,
                        color: Colors.white.withAlpha(200),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isCheckedIn ? 'You are checked in' : 'Not checked in yet',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      if (isCheckedIn) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Since ${_formatTime(_todayRecord!['checkInTime'])} \u2022 ${_formatElapsed(_todayRecord!['checkInTime'])}',
                          style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
                        ),
                        if (_todayRecord!['checkInAddress'] != null && (_todayRecord!['checkInAddress'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.white.withAlpha(180)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _todayRecord!['checkInAddress'],
                                    style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(180)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _actionLoading ? null : (isCheckedIn ? _handleCheckOut : _handleCheckIn),
                          icon: _actionLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(isCheckedIn ? Icons.logout : Icons.login, size: 20),
                          label: Text(
                            _actionLoading
                                ? 'Getting location...'
                                : (isCheckedIn ? 'Check Out' : 'Check In'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCheckedIn ? const Color(0xFFEF4444) : Colors.white,
                            foregroundColor: isCheckedIn ? Colors.white : const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // History Header
                const Text(
                  'Recent Attendance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),

                // History List
                if (_records.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.event_busy, size: 40, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 8),
                        Text('No attendance records', style: TextStyle(color: Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                else
                  ...(_records.map((r) => _attendanceCard(r))),
              ],
            ),
          );
  }

  Widget _attendanceCard(Map<String, dynamic> record) {
    final date = record['date'] ?? '';
    final checkIn = record['checkInTime'] as int?;
    final checkOut = record['checkOutTime'] as int?;
    final totalHours = record['totalHours'];
    final checkInLat = record['checkInLat'] as num?;
    final checkInLng = record['checkInLng'] as num?;
    final checkOutLat = record['checkOutLat'] as num?;
    final checkOutLng = record['checkOutLng'] as num?;
    final checkInAddr = record['checkInAddress'] as String? ?? '';
    final checkOutAddr = record['checkOutAddress'] as String? ?? '';

    Color hoursColor = const Color(0xFF64748B);
    if (totalHours != null) {
      if (totalHours >= 8) {
        hoursColor = const Color(0xFF16A34A);
      } else if (totalHours >= 4) {
        hoursColor = const Color(0xFFF59E0B);
      } else {
        hoursColor = const Color(0xFFEF4444);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date row
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              const Spacer(),
              if (totalHours != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hoursColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${totalHours}h',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hoursColor),
                  ),
                )
              else if (checkOut == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Check-in row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('In: ${_formatTime(checkIn)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (checkInLat != null && checkInLng != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openMap(checkInLat.toDouble(), checkInLng.toDouble()),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 2),
                      Text(
                        checkInAddr.isNotEmpty ? (checkInAddr.length > 30 ? '${checkInAddr.substring(0, 30)}...' : checkInAddr) : 'View Map',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Check-out row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: checkOut != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                checkOut != null ? 'Out: ${_formatTime(checkOut)}' : 'Not checked out',
                style: TextStyle(fontSize: 12, color: checkOut != null ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
              if (checkOutLat != null && checkOutLng != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openMap(checkOutLat.toDouble(), checkOutLng.toDouble()),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 2),
                      Text(
                        checkOutAddr.isNotEmpty ? (checkOutAddr.length > 30 ? '${checkOutAddr.substring(0, 30)}...' : checkOutAddr) : 'View Map',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
