import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/stage_badge.dart';
import 'lead_form_screen.dart';

class LeadDetailScreen extends StatelessWidget {
  final ApiService apiService;
  final Lead lead;

  const LeadDetailScreen({
    super.key,
    required this.apiService,
    required this.lead,
  });

  void _callLead() async {
    final uri = Uri.parse('tel:${lead.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _whatsappLead() async {
    final uri = Uri.parse('https://wa.me/${lead.waPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _emailLead() async {
    final uri = Uri.parse('mailto:${lead.email}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Lead Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => LeadFormScreen(
                    apiService: apiService,
                    lead: lead,
                  ),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lead.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (lead.companyName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(lead.companyName,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    StageBadge(stage: lead.stage),
                    if (lead.requirement.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withAlpha(12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lead.requirement.toUpperCase(),
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (lead.hasPhone)
                  _actionButton(Icons.phone, 'Call', Colors.green, _callLead),
                if (lead.hasPhone)
                  _actionButton(Icons.message, 'WhatsApp', const Color(0xFF25D366),
                      _whatsappLead),
                if (lead.hasEmail)
                  _actionButton(Icons.email_outlined, 'Email', Colors.blue,
                      _emailLead),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details
          _detailsCard([
            if (lead.phone.isNotEmpty)
              _detailRow(Icons.phone_outlined, 'Phone', lead.phone),
            if (lead.email.isNotEmpty)
              _detailRow(Icons.email_outlined, 'Email', lead.email),
            _detailRow(Icons.source_outlined, 'Source', lead.source),
            _detailRow(Icons.flag_outlined, 'Stage', lead.stage),
            if (lead.assign.isNotEmpty)
              _detailRow(Icons.person_outline, 'Assigned To', lead.assign),
            if (lead.followup.isNotEmpty)
              _detailRow(Icons.alarm, 'Follow-up', lead.followup),
            if (lead.requirement.isNotEmpty)
              _detailRow(Icons.thermostat_outlined, 'Requirement',
                  lead.requirement),
            if (lead.productCat.isNotEmpty)
              _detailRow(Icons.category_outlined, 'Product Category',
                  lead.productCat),
            if (lead.createdDate != null)
              _detailRow(Icons.calendar_today, 'Created',
                  DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdDate!)),
          ]),

          // Notes
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text(lead.notes,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
          ],

          // Custom fields
          if (lead.custom.isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailsCard(lead.custom.entries
                .where((e) => e.value.toString().isNotEmpty)
                .map((e) =>
                    _detailRow(Icons.edit_note, e.key, e.value.toString()))
                .toList()),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _detailsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    if (e.key > 0)
                      Divider(height: 1, color: Colors.grey.shade100),
                    e.value,
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
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
                await apiService.deleteLead(leadId: lead.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
