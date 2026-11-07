import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class PolicyRuleFormDialog extends StatefulWidget {
  final int selectedPolicyId;
  final String policyName;
  final Map<String, dynamic>? editingRule;
  final VoidCallback onSaved;

  const PolicyRuleFormDialog({
    super.key,
    required this.selectedPolicyId,
    required this.policyName,
    this.editingRule,
    required this.onSaved,
  });

  @override
  State<PolicyRuleFormDialog> createState() => _PolicyRuleFormDialogState();
}

class _PolicyRuleFormDialogState extends State<PolicyRuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _maxBalanceCtrl;
  late final TextEditingController _carryMaxCtrl;

  String _accrualType = 'No Accrual';
  bool _isPaid = true;
  bool _requiresDoc = false;
  bool _carryForward = false;
  bool _encashable = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.editingRule;
    _nameCtrl = TextEditingController(text: r?['name']?.toString() ?? '');
    _codeCtrl = TextEditingController(text: r?['code']?.toString() ?? '');
    _maxBalanceCtrl = TextEditingController(text: (r?['max_balance'] ?? 12).toString());
    _carryMaxCtrl = TextEditingController(text: (r?['carry_forward_max'] ?? 0).toString());

    final rawAccrual = r?['accural_type']?.toString().trim();
    if (rawAccrual != null && rawAccrual.isNotEmpty) {
      final lower = rawAccrual.toLowerCase();
      if (lower == 'comp_off' || lower == 'comp off' || lower == 'compoff') {
        _accrualType = 'comp_off';
      } else if (lower == 'monthly') {
        _accrualType = 'Monthly';
      } else if (lower == 'quarterly') {
        _accrualType = 'Quarterly';
      } else if (lower == 'yearly') {
        _accrualType = 'Yearly';
      } else if (lower == 'no accrual' || lower == 'no_accrual') {
        _accrualType = 'No Accrual';
      } else {
        _accrualType = rawAccrual;
      }
    } else {
      _accrualType = 'No Accrual';
    }
    _isPaid = r?['is_paid'] != false;
    _requiresDoc = r?['requires_doc'] == true;
    _carryForward = r?['carry_forward'] == true;
    _encashable = r?['encashable'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _maxBalanceCtrl.dispose();
    _carryMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<LeaveProvider>();

    try {
      final maxBal = double.tryParse(_maxBalanceCtrl.text.trim()) ?? 12.0;
      final carryMax = double.tryParse(_carryMaxCtrl.text.trim()) ?? 0.0;

      final payload = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'max_balance': maxBal,
        'accural_type': _accrualType,
        'accural_amount': _accrualType == 'Monthly'
            ? (maxBal / 12)
            : (_accrualType == 'Quarterly'
                ? (maxBal / 4)
                : (_accrualType == 'Yearly' ? maxBal : 0)),
        'is_paid': _isPaid,
        'requires_doc': _requiresDoc,
        'carry_forward': _carryForward,
        'carry_forward_max': _carryForward ? carryMax : 0,
        'encashable': _encashable,
      };

      if (widget.editingRule != null) {
        final ruleId = widget.editingRule!['rule_id'] as int;
        await provider.leaveService.updateLeavePolicyRule(widget.selectedPolicyId, ruleId, payload);
        if (mounted) context.showToast('Rule updated successfully', isSuccess: true);
      } else {
        await provider.leaveService.createLeavePolicyRule(widget.selectedPolicyId, payload);
        if (mounted) context.showToast('Rule added successfully', isSuccess: true);
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
    final isEditing = widget.editingRule != null;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                          child: const Icon(Icons.rule_folder_outlined, size: 18, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Entitlement Rule' : 'Add Entitlement Rule',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              widget.policyName,
                              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
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

                // Rule Name
                Text('Rule Name *', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. Annual Leave',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter rule name' : null,
                ),
                const SizedBox(height: 12),

                // Code & Days row
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Code *', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'e.g. AL',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Days Per Year *', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _maxBalanceCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: '12',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Accrual dropdown
                AppCustomDropdown<String>(
                  labelText: 'When is Leave Added? (Accrual Type)',
                  hintText: 'Select accrual type',
                  initialValue: _accrualType,
                  isDense: true,
                  prefixIcon: Icons.calendar_month_outlined,
                  items: _buildAccrualDropdownItems(),
                  onChanged: (v) {
                    if (v != null) setState(() => _accrualType = v);
                  },
                ),
                const SizedBox(height: 14),

                // Checkboxes
                CheckboxListTile(
                  value: _isPaid,
                  onChanged: (v) => setState(() => _isPaid = v ?? true),
                  title: Text('Paid Leave', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text('Eligible for salary payment while away', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF6366F1),
                ),
                CheckboxListTile(
                  value: _requiresDoc,
                  onChanged: (v) => setState(() => _requiresDoc = v ?? false),
                  title: Text('Require Document', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text('Must attach doctor note or document when applying', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF6366F1),
                ),
                CheckboxListTile(
                  value: _carryForward,
                  onChanged: (v) => setState(() => _carryForward = v ?? false),
                  title: Text('Carry Forward', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text('Unused days carry over to the next calendar year', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF6366F1),
                ),
                if (_carryForward) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: TextFormField(
                      controller: _carryMaxCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Max Carry Forward Days',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
                CheckboxListTile(
                  value: _encashable,
                  onChanged: (v) => setState(() => _encashable = v ?? false),
                  title: Text('Encashable', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text('Unused balance can be cashed out in payroll', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF6366F1),
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
                          : Text(isEditing ? 'Save Changes' : 'Add Rule', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AppDropdownItem<String>> _buildAccrualDropdownItems() {
    final standardItems = <AppDropdownItem<String>>[
      const AppDropdownItem(
        value: 'No Accrual',
        label: 'All at Once (Start of Year)',
        subtitle: 'Entire balance credited upfront (Lump Sum)',
        icon: Icons.calendar_today_outlined,
        iconColor: Color(0xFF6366F1),
      ),
      const AppDropdownItem(
        value: 'Monthly',
        label: 'Add Monthly',
        subtitle: 'Pro-rated accrual credited each month',
        icon: Icons.date_range_outlined,
        iconColor: Color(0xFF10B981),
      ),
      const AppDropdownItem(
        value: 'Quarterly',
        label: 'Add Quarterly',
        subtitle: 'Credited every 3 months',
        icon: Icons.calendar_view_month_outlined,
        iconColor: Color(0xFF3B82F6),
      ),
      const AppDropdownItem(
        value: 'Yearly',
        label: 'Add Yearly',
        subtitle: 'Credited once per calendar year',
        icon: Icons.event_repeat_outlined,
        iconColor: Color(0xFFF59E0B),
      ),
      const AppDropdownItem(
        value: 'comp_off',
        label: 'Compensatory Off (Comp Off)',
        subtitle: 'Credited when working on holidays or overtime',
        icon: Icons.badge_outlined,
        iconColor: Color(0xFF8B5CF6),
      ),
    ];

    final exists = standardItems.any((item) => item.value == _accrualType);
    if (!exists && _accrualType.isNotEmpty) {
      return [
        ...standardItems,
        AppDropdownItem(
          value: _accrualType,
          label: _accrualType,
          subtitle: 'Configured accrual type',
          icon: Icons.tune_outlined,
          iconColor: const Color(0xFF6366F1),
        ),
      ];
    }
    return standardItems;
  }
}
