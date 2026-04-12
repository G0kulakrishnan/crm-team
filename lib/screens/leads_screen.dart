import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/lead_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/stage_badge.dart';
import 'lead_form_screen.dart';
import 'lead_detail_screen.dart';

class LeadsScreen extends StatefulWidget {
  final ApiService apiService;

  const LeadsScreen({super.key, required this.apiService});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  List<Lead> _allLeads = [];
  List<Lead> _filteredLeads = [];
  bool _loading = true;
  String? _error;
  String _filterStage = '';
  String _filterSource = '';
  String _filterAssign = '';
  String _searchQuery = '';

  Set<String> _stages = {};
  Set<String> _sources = {};
  Set<String> _assignees = {};

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    try {
      setState(() => _loading = true);
      final data = await widget.apiService.fetchLeads();
      final leads = data.map((item) => Lead.fromJson(item)).toList();

      // Extract unique values for filters
      final stages = <String>{};
      final sources = <String>{};
      final assignees = <String>{};

      for (var lead in leads) {
        if (lead.stage.isNotEmpty) stages.add(lead.stage);
        if (lead.source.isNotEmpty) sources.add(lead.source);
        if (lead.assign.isNotEmpty) assignees.add(lead.assign);
      }

      setState(() {
        _allLeads = leads;
        _stages = stages;
        _sources = sources;
        _assignees = assignees;
        _error = null;
        _loading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    List<Lead> filtered = _allLeads;

    if (_filterStage.isNotEmpty) {
      filtered = filtered.where((l) => l.stage == _filterStage).toList();
    }

    if (_filterSource.isNotEmpty) {
      filtered = filtered.where((l) => l.source == _filterSource).toList();
    }

    if (_filterAssign.isNotEmpty) {
      filtered = filtered.where((l) => l.assign == _filterAssign).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((l) =>
              l.name.toLowerCase().contains(query) ||
              l.phone.contains(query) ||
              l.email.toLowerCase().contains(query))
          .toList();
    }

    setState(() => _filteredLeads = filtered);
  }

  int _getStatsCount(bool Function(Lead) predicate) {
    return _allLeads.where(predicate).length;
  }

  int _getLeadsToday() {
    final today = DateTime.now();
    return _getStatsCount((l) =>
        l.createdDate != null &&
        l.createdDate!.year == today.year &&
        l.createdDate!.month == today.month &&
        l.createdDate!.day == today.day);
  }

  int _getLeadsThisWeek() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _getStatsCount((l) =>
        l.createdDate != null &&
        l.createdDate!.isAfter(weekAgo) &&
        l.createdDate!.isBefore(now.add(const Duration(days: 1))));
  }

  int _getLeadsThisMonth() {
    final now = DateTime.now();
    return _getStatsCount((l) =>
        l.createdDate != null &&
        l.createdDate!.year == now.year &&
        l.createdDate!.month == now.month);
  }

  int _getFollowupsDue() {
    return _getStatsCount((l) => l.followup.isNotEmpty);
  }

  Future<void> _editLead(Lead lead) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(
          apiService: widget.apiService,
          lead: lead,
        ),
      ),
    );

    if (result == true) {
      await _loadLeads();
    }
  }

  Future<void> _deleteLead(Lead lead) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete "${lead.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiService.deleteLead(leadId: lead.id);
                await _loadLeads();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Leads',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadLeads,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => LeadFormScreen(apiService: widget.apiService),
                ),
              );
              if (result == true) {
                await _loadLeads();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadLeads,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeads,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Stats cards
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.1,
                        children: [
                          StatsCard(
                            label: 'Total Leads',
                            count: _allLeads.length,
                            icon: Icons.contacts_outlined,
                            color: const Color(0xFF3B82F6),
                          ),
                          StatsCard(
                            label: 'Today',
                            count: _getLeadsToday(),
                            icon: Icons.calendar_today,
                            color: const Color(0xFF10B981),
                          ),
                          StatsCard(
                            label: 'This Week',
                            count: _getLeadsThisWeek(),
                            icon: Icons.date_range_outlined,
                            color: const Color(0xFFF59E0B),
                          ),
                          StatsCard(
                            label: 'Follow-ups Due',
                            count: _getFollowupsDue(),
                            icon: Icons.alarm_outlined,
                            color: const Color(0xFFEF4444),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Filters
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search bar
                            TextField(
                              onChanged: (val) {
                                setState(() => _searchQuery = val);
                                _applyFilters();
                              },
                              decoration: InputDecoration(
                                hintText: 'Search by name, phone, email...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Filter dropdowns
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFilterDropdown(
                                    label: 'Stage',
                                    value: _filterStage,
                                    items: _stages.toList(),
                                    onChanged: (val) {
                                      setState(() => _filterStage = val ?? '');
                                      _applyFilters();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildFilterDropdown(
                                    label: 'Source',
                                    value: _filterSource,
                                    items: _sources.toList(),
                                    onChanged: (val) {
                                      setState(() => _filterSource = val ?? '');
                                      _applyFilters();
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (_filterStage.isNotEmpty ||
                                _filterSource.isNotEmpty ||
                                _searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _filterStage = '';
                                    _filterSource = '';
                                    _filterAssign = '';
                                    _searchQuery = '';
                                  });
                                  _applyFilters();
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear Filters'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Leads list
                      if (_filteredLeads.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No leads found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_filteredLeads.length, (i) {
                          final lead = _filteredLeads[i];
                          return LeadCard(
                            lead: lead,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(
                                  apiService: widget.apiService,
                                  lead: lead,
                                ),
                              ),
                            ),
                            onEdit: () => _editLead(lead),
                            onDelete: () => _deleteLead(lead),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text('All $label'),
        ),
        ...items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
