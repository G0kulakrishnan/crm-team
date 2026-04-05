import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/call_log_service.dart';

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CallLogService _callLogService = CallLogService();
  List<Map<String, dynamic>> _callLogs = [];
  bool _loading = true;
  bool _syncing = false;
  String? _lastSyncText;
  final Set<int> _selectedIndices = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final ts = await widget.apiService.getLastSyncTime();
    if (ts != null && mounted) {
      setState(() {
        _lastSyncText = _formatTimeAgo(ts);
      });
    }
  }

  Future<void> _loadCallLogs() async {
    setState(() => _loading = true);
    try {
      final hasPerms = await CallLogService.hasPermissions();
      if (!hasPerms) {
        final granted = await CallLogService.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone permission is required to read call logs')),
            );
          }
          setState(() => _loading = false);
          return;
        }
      }
      final logs = await _callLogService.getAllRecentCallLogs(days: 7);
      if (mounted) {
        setState(() {
          _callLogs = logs;
          _loading = false;
          _selectedIndices.clear();
          _selectAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading call logs: $e')),
        );
      }
    }
  }

  Future<void> _syncSelected() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select call logs to sync')),
      );
      return;
    }

    setState(() => _syncing = true);
    try {
      final logsToSync = _selectedIndices.map((i) => _callLogs[i]).toList();
      final count = await widget.apiService.syncCallLogs(logsToSync);
      await _callLogService.updateLastFetchTime();
      await _loadLastSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count call log${count != 1 ? 's' : ''} synced to CRM'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        setState(() {
          _selectedIndices.clear();
          _selectAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncAll() async {
    setState(() => _syncing = true);
    try {
      final count = await widget.apiService.syncCallLogs(_callLogs);
      await _callLogService.updateLastFetchTime();
      await _loadLastSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count call log${count != 1 ? 's' : ''} synced to CRM'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedIndices.addAll(List.generate(_callLogs.length, (i) => i));
      } else {
        _selectedIndices.clear();
      }
    });
  }

  String _formatTimeAgo(int timestamp) {
    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    final minutes = diff ~/ 60000;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    final days = hours ~/ 24;
    return '${days}d ago';
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '-';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final today = _callLogs.where((l) {
      final ts = l['createdAt'] as int? ?? 0;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    final outgoing = today.where((l) => l['direction'] == 'Outgoing').length;
    final incoming = today.where((l) => l['direction'] == 'Incoming').length;
    final missed = today.where((l) => l['direction'] == 'Missed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('T2G CRM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            Text(
              widget.apiService.staffName ?? '',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          if (_lastSyncText != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  'Synced $_lastSyncText',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: _loading ? null : _loadCallLogs,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.apiService.staffEmail ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(widget.apiService.baseUrl ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Disconnect', style: TextStyle(color: Colors.red, fontSize: 13))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _statCard("Today's Calls", '${today.length}', const Color(0xFF6366F1)),
                const SizedBox(width: 8),
                _statCard('Outgoing', '$outgoing', const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _statCard('Incoming', '$incoming', const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                _statCard('Missed', '$missed', const Color(0xFFEF4444)),
              ],
            ),
          ),

          // Sync bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _callLogs.isNotEmpty ? _toggleSelectAll : null,
                  child: Row(
                    children: [
                      Icon(
                        _selectAll ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 20,
                        color: _selectAll ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedIndices.isEmpty ? 'Select All' : '${_selectedIndices.length} selected',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_selectedIndices.isNotEmpty)
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: _syncing ? null : _syncSelected,
                      icon: _syncing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: Text('Sync ${_selectedIndices.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: _syncing || _callLogs.isEmpty ? null : _syncAll,
                      icon: _syncing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('Sync All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Call log list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
                : _callLogs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_missed, size: 48, color: Color(0xFFCBD5E1)),
                            SizedBox(height: 12),
                            Text('No call logs found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                            Text('Recent calls will appear here', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCallLogs,
                        color: const Color(0xFF16A34A),
                        child: ListView.builder(
                          itemCount: _callLogs.length,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemBuilder: (context, index) {
                            final log = _callLogs[index];
                            final isSelected = _selectedIndices.contains(index);
                            return _callLogCard(log, index, isSelected);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 0.3), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _callLogCard(Map<String, dynamic> log, int index, bool isSelected) {
    final direction = log['direction'] as String? ?? 'Incoming';
    final phone = log['phone'] as String? ?? '';
    final name = log['contactName'] as String? ?? '';
    final duration = log['duration'] as int? ?? 0;
    final ts = log['createdAt'] as int? ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final timeStr = DateFormat('dd MMM, hh:mm a').format(dt);

    Color dirColor;
    IconData dirIcon;
    switch (direction) {
      case 'Outgoing':
        dirColor = const Color(0xFF2563EB);
        dirIcon = Icons.call_made;
        break;
      case 'Missed':
        dirColor = const Color(0xFFEF4444);
        dirIcon = Icons.call_missed;
        break;
      default:
        dirColor = const Color(0xFF16A34A);
        dirIcon = Icons.call_received;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
          _selectAll = _selectedIndices.length == _callLogs.length;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF16A34A).withAlpha(77) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Checkbox
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 10),
            // Direction icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dirColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(dirIcon, size: 18, color: dirColor),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : phone,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(direction, style: TextStyle(fontSize: 11, color: dirColor, fontWeight: FontWeight.w500)),
                      if (name.isNotEmpty) ...[
                        const Text(' \u2022 ', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                        Flexible(
                          child: Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Duration & time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatDuration(duration), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(timeStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('This will remove your CRM connection. You can reconnect anytime.', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.apiService.clearConfig();
              widget.onLogout();
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
