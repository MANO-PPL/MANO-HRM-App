import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class PolicyFormDialog extends StatefulWidget {
  final Map<String, dynamic>? editingPolicy;
  final VoidCallback onSaved;

  const PolicyFormDialog({
    super.key,
    this.editingPolicy,
    required this.onSaved,
  });

  @override
  State<PolicyFormDialog> createState() => _PolicyFormDialogState();
}

class _PolicyFormDialogState extends State<PolicyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.editingPolicy?['name']?.toString() ?? '');
    _descCtrl = TextEditingController(text: widget.editingPolicy?['description']?.toString() ?? '');
    _isActive = widget.editingPolicy?['is_active'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<LeaveProvider>();

    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'is_active': _isActive,
      };

      if (widget.editingPolicy != null) {
        final lpId = widget.editingPolicy!['lp_id'] as int;
        await provider.leaveService.updateLeavePolicy(lpId, payload);
        if (mounted) context.showToast('Policy updated successfully', isSuccess: true);
      } else {
        await provider.leaveService.createLeavePolicy(payload);
        if (mounted) context.showToast('Policy created successfully', isSuccess: true);
      }

      await provider.fetchMyLeaveBalancesAndPolicies(forceRefresh: true);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        context.showToast(e.toString().replaceAll('Exception:', '').trim(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.editingPolicy != null;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Edit Leave Policy' : 'Create Leave Policy',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Policy Name
              Text('Policy Name *', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'e.g. Standard Entitlements',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a policy name' : null,
              ),
              const SizedBox(height: 12),

              // Description
              Text('Description', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Outline scope or details about eligibility for this policy...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Active toggle
              SwitchListTile(
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                title: Text('Active Policy', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text('Employees can be assigned to active policies', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey)),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeThumbColor: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEditing ? 'Save Changes' : 'Create Policy', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
