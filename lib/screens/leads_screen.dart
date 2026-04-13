import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../services/api_service.dart';
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
  String _searchQuery = '';

  Set<String> _stages = {};
  Set<String> _sources = {};

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

      final stages = <String>{};
      final sources = <String>{};
      for (var lead in leads) {
        if (lead.stage.isNotEmpty) stages.add(lead.stage);
        if (lead.source.isNotEmpty) sources.add(lead.source);
      }

      setState(() {
        _allLeads = leads;
        _stages = stages;
        _sources = sources;
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

  int _getLeadsToday() {
    final today = DateTime.now();
    return _allLeads
        .where((l) =>
            l.createdDate != null &&
            l.createdDate!.year == today.year &&
            l.createdDate!.month == today.month &&
            l.createdDate!.day == today.day)
        .length;
  }

  int _getLeadsThisWeek() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _allLeads
        .where((l) =>
            l.createdDate != null &&
            l.createdDate!.isAfter(weekAgo) &&
            l.createdDate!.isBefore(now.add(const Duration(days: 1))))
        .length;
  }

  int _getLeadsThisMonth() {
    final now = DateTime.now();
    return _allLeads
        .where((l) =>
            l.createdDate != null &&
            l.createdDate!.year == now.year &&
            l.createdDate!.month == now.month)
        .length;
  }

  void _openFilterSheet() {
    String tempSearch = _searchQuery;
    String tempStage = _filterStage;
    String tempSource = _filterSource;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Filter Leads',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempSearch = '';
                            tempStage = '';
                            tempSource = '';
                          });
                        },
                        child: const Text('Clear All',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setSheetState(() => tempSearch = val),
                    controller: TextEditingController(text: tempSearch),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone, email...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tempStage.isEmpty ? null : tempStage,
                    decoration: InputDecoration(
                      labelText: 'Stage',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All Stages')),
                      ..._stages.map((s) =>
                          DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: (val) =>
                        setSheetState(() => tempStage = val ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tempSource.isEmpty ? null : tempSource,
                    decoration: InputDecoration(
                      labelText: 'Source',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All Sources')),
                      ..._sources.map((s) =>
                          DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: (val) =>
                        setSheetState(() => tempSource = val ?? ''),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = tempSearch;
                          _filterStage = tempStage;
                          _filterSource = tempSource;
                        });
                        _applyFilters();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiService.deleteLead(leadId: lead.id);
                await _loadLeads();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lead deleted')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter =
        _filterStage.isNotEmpty || _filterSource.isNotEmpty || _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Green gradient header ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Title row
                    Row(
                      children: [
                        const Text('Leads',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: Colors.white, size: 20),
                          onPressed: _loadLeads,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.filter_list,
                                  color: Colors.white, size: 22),
                              onPressed: _openFilterSheet,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (hasActiveFilter)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.white, size: 22),
                          onPressed: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadFormScreen(
                                    apiService: widget.apiService),
                              ),
                            );
                            if (result == true) await _loadLeads();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Stats row
                    Row(
                      children: [
                        _headerStat('Total', _allLeads.length),
                        const SizedBox(width: 8),
                        _headerStat('Today', _getLeadsToday()),
                        const SizedBox(width: 8),
                        _headerStat('This week', _getLeadsThisWeek()),
                        const SizedBox(width: 8),
                        _headerStat('This month', _getLeadsThisMonth()),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF16A34A)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text('Error: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadLeads,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredLeads.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('No leads found',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadLeads,
                            color: const Color(0xFF16A34A),
                            child: ListView.separated(
                              itemCount: _filteredLeads.length,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                              separatorBuilder: (_, __) => Divider(
                                  height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                final lead = _filteredLeads[index];
                                return _LeadTile(
                                  lead: lead,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LeadDetailScreen(
                                        apiService: widget.apiService,
                                        lead: lead,
                                      ),
                                    ),
                                  ).then((_) => _loadLeads()),
                                  onEdit: () async {
                                    final result =
                                        await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LeadFormScreen(
                                          apiService: widget.apiService,
                                          lead: lead,
                                        ),
                                      ),
                                    );
                                    if (result == true) await _loadLeads();
                                  },
                                  onDelete: () => _deleteLead(lead),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact lead tile matching reference design ──
class _LeadTile extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LeadTile({
    required this.lead,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat("MMM dd 'at' hh:mma").format(date).toLowerCase();
  }

  void _callLead() async {
    if (lead.hasPhone) {
      final uri = Uri.parse('tel:${lead.phone}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF334155),
              child: Text(
                _getInitials(lead.name),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    lead.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Badges row
                  Row(
                    children: [
                      if (lead.stage.isNotEmpty) _stageBadge(lead.stage),
                      if (lead.requirement.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _requirementBadge(lead.requirement),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Source + date line
                  Text(
                    'via ${lead.source}${lead.createdDate != null ? ' on ${_formatDate(lead.createdDate)}' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Call button
            if (lead.hasPhone)
              GestureDetector(
                onTap: _callLead,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.phone,
                      size: 18, color: Color(0xFF64748B)),
                ),
              ),
            // Menu
            PopupMenuButton(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: Color(0xFF94A3B8)),
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: onEdit,
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  onTap: onDelete,
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageBadge(String stage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1),
      ),
      child: Text(
        stage.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            letterSpacing: 0.3),
      ),
    );
  }

  Widget _requirementBadge(String requirement) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        requirement.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3),
      ),
    );
  }
}
