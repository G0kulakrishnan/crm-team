import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/api_service.dart';

class LeadFormScreen extends StatefulWidget {
  final ApiService apiService;
  final Lead? lead;

  const LeadFormScreen({
    super.key,
    required this.apiService,
    this.lead,
  });

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _sourceCtrl;
  late TextEditingController _stageCtrl;
  late TextEditingController _requirementCtrl;
  late TextEditingController _assignCtrl;
  late TextEditingController _followupCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _productCatCtrl;

  bool _saving = false;

  // Default options
  static const List<String> _defaultSources = [
    'Website',
    'Phone',
    'Email',
    'Referral',
    'Social Media',
    'Event',
    'Other',
  ];

  static const List<String> _defaultStages = [
    'Lead',
    'Negotiation',
    'Quotation Created',
    'Quotation Sent',
    'Invoice Created',
    'Invoice Sent',
    'Won',
    'Lost',
  ];

  static const List<String> _defaultRequirements = [
    'Budget',
    'Timeline',
    'Specification',
    'Demo',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.lead?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.lead?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.lead?.email ?? '');
    _sourceCtrl = TextEditingController(text: widget.lead?.source ?? '');
    _stageCtrl = TextEditingController(text: widget.lead?.stage ?? '');
    _requirementCtrl =
        TextEditingController(text: widget.lead?.requirement ?? '');
    _assignCtrl = TextEditingController(text: widget.lead?.assign ?? '');
    _followupCtrl = TextEditingController(text: widget.lead?.followup ?? '');
    _notesCtrl = TextEditingController(text: widget.lead?.notes ?? '');
    _companyNameCtrl =
        TextEditingController(text: widget.lead?.companyName ?? '');
    _productCatCtrl =
        TextEditingController(text: widget.lead?.productCat ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _sourceCtrl.dispose();
    _stageCtrl.dispose();
    _requirementCtrl.dispose();
    _assignCtrl.dispose();
    _followupCtrl.dispose();
    _notesCtrl.dispose();
    _companyNameCtrl.dispose();
    _productCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLead() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (widget.lead == null) {
        // Create new lead
        await widget.apiService.createLead(
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          source: _sourceCtrl.text,
          stage: _stageCtrl.text,
          requirement: _requirementCtrl.text,
          assign: _assignCtrl.text,
          followup: _followupCtrl.text,
          notes: _notesCtrl.text,
          companyName: _companyNameCtrl.text,
          productCat: _productCatCtrl.text,
        );
      } else {
        // Update existing lead
        await widget.apiService.updateLead(
          leadId: widget.lead!.id,
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          source: _sourceCtrl.text,
          stage: _stageCtrl.text,
          requirement: _requirementCtrl.text,
          assign: _assignCtrl.text,
          followup: _followupCtrl.text,
          notes: _notesCtrl.text,
          companyName: _companyNameCtrl.text,
          productCat: _productCatCtrl.text,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lead == null ? 'New Lead' : 'Edit Lead',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name field
          _buildTextField(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'Enter lead name',
            icon: Icons.person_outline,
            required: true,
          ),

          const SizedBox(height: 12),

          // Phone and Email
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _phoneCtrl,
                  label: 'Phone',
                  hint: 'Enter phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'Enter email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Company Name
          _buildTextField(
            controller: _companyNameCtrl,
            label: 'Company Name',
            hint: 'Enter company name',
            icon: Icons.business_outlined,
          ),

          const SizedBox(height: 12),

          // Source and Stage
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  controller: _sourceCtrl,
                  label: 'Source',
                  items: _defaultSources,
                  icon: Icons.source_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  controller: _stageCtrl,
                  label: 'Stage',
                  items: _defaultStages,
                  icon: Icons.flag_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Requirement and Assign
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  controller: _requirementCtrl,
                  label: 'Requirement',
                  items: _defaultRequirements,
                  icon: Icons.thermostat_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _assignCtrl,
                  label: 'Assign To',
                  hint: 'Assign to team member',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Follow-up and Product Category
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _followupCtrl,
                  label: 'Follow-up',
                  hint: 'Follow-up date/time',
                  icon: Icons.alarm,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _productCatCtrl,
                  label: 'Product Category',
                  hint: 'Enter product category',
                  icon: Icons.category_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Notes
          _buildTextField(
            controller: _notesCtrl,
            label: 'Notes',
            hint: 'Add notes about this lead',
            icon: Icons.note_outlined,
            minLines: 3,
            maxLines: 6,
          ),

          const SizedBox(height: 24),

          // Save button
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveLead,
            icon: _saving ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ) : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Lead'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF16A34A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required TextEditingController controller,
    required String label,
    required List<String> items,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF16A34A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              controller.text = val;
            }
          },
        ),
      ],
    );
  }
}
