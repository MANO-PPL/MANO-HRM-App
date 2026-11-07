import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// CreatePackageDialog - Dialog for creating or editing salary packages
/// Replicates CreatePackageModal.jsx & PackageFormPanel.jsx
class CreatePackageDialog extends StatefulWidget {
  final PayrollService payrollService;
  final SalaryPackage? initialPackage;
  final ValueChanged<SalaryPackage> onPackageSaved;
  final bool isBottomSheet;

  const CreatePackageDialog({
    super.key,
    required this.payrollService,
    this.initialPackage,
    required this.onPackageSaved,
    this.isBottomSheet = false,
  });

  static Future<void> show(
    BuildContext context, {
    required PayrollService payrollService,
    SalaryPackage? initialPackage,
    required ValueChanged<SalaryPackage> onPackageSaved,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CreatePackageDialog(
          payrollService: payrollService,
          initialPackage: initialPackage,
          onPackageSaved: onPackageSaved,
          isBottomSheet: true,
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (context) => CreatePackageDialog(
        payrollService: payrollService,
        initialPackage: initialPackage,
        onPackageSaved: onPackageSaved,
        isBottomSheet: false,
      ),
    );
  }

  @override
  State<CreatePackageDialog> createState() => _CreatePackageDialogState();
}

class _CreatePackageDialogState extends State<CreatePackageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _grossController;
  late TextEditingController _otRateController;
  bool _otEnabled = true;
  bool _lopEnabled = true;
  late String _lopBasis;
  late String _lopDayBasis;
  late double _halfDayMultiplier;
  bool _isSaving = false;

  late List<SalaryComponent> _components;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPackage;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _grossController = TextEditingController(text: p != null ? p.monthlyGross.toStringAsFixed(0) : '50000');
    _otRateController = TextEditingController(text: p != null ? p.overtimeRate.toStringAsFixed(0) : '150');
    _otEnabled = p?.overtimeEnabled ?? true;
    _lopEnabled = p?.lopEnabled ?? true;
    _lopBasis = p?.lopBasis ?? 'gross';
    _lopDayBasis = p?.lopDayBasis ?? 'calendar_days';
    _halfDayMultiplier = p?.halfDayMultiplier ?? 0.5;

    if (p != null && p.components.isNotEmpty) {
      _components = List.from(p.components);
    } else {
      _components = [
        const SalaryComponent(name: 'Basic Pay', category: 'earning', calcType: 'fixed', value: 25000),
        const SalaryComponent(name: 'House Rent Allowance (HRA)', category: 'earning', calcType: 'fixed', value: 12500),
        const SalaryComponent(name: 'Special Allowance', category: 'earning', calcType: 'fixed', value: 12500),
        const SalaryComponent(name: 'Provident Fund (Employee)', category: 'deduction', calcType: 'fixed', value: 1800),
        const SalaryComponent(name: 'Professional Tax', category: 'deduction', calcType: 'fixed', value: 200),
        const SalaryComponent(name: 'Provident Fund (Employer)', category: 'employer_contribution', calcType: 'fixed', value: 1800),
      ];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _grossController.dispose();
    _otRateController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final gross = double.tryParse(_grossController.text) ?? 50000;
    final otRate = double.tryParse(_otRateController.text) ?? 150;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'grossSalary': gross,
      'gross_salary': gross,
      'overtimeEnabled': _otEnabled,
      'overtime_enabled': _otEnabled,
      'overtimeRate': otRate,
      'overtime_rate': otRate,
      'lopEnabled': _lopEnabled,
      'lop_enabled': _lopEnabled,
      'lopBasis': _lopBasis,
      'lop_basis': _lopBasis,
      'lopDayBasis': _lopDayBasis,
      'lop_day_basis': _lopDayBasis,
      'halfDayMultiplier': _halfDayMultiplier,
      'half_day_multiplier': _halfDayMultiplier,
      'lopFactorHalfDay': _halfDayMultiplier,
      'lop_factor_half_day': _halfDayMultiplier,
      'packages_rules': {
        'lop': {
          'enabled': _lopEnabled,
          'basis': _lopBasis,
          'day_divisor': _lopDayBasis,
          'day_basis': _lopDayBasis,
          'factor_present': 1.0,
          'factor_half_day': _halfDayMultiplier,
          'factor_absent': 0.0,
        },
        'ot': {
          'enabled': _otEnabled,
          'rate_basis': 'hourly',
          'hourly_rate': otRate,
          'multiplier': 1.5,
        },
      },
      'effectiveFrom': DateTime.now().toIso8601String().split('T')[0],
      'components': _components.map((c) => c.toJson()).toList(),
    };

    try {
      SalaryPackage saved;
      if (widget.initialPackage != null) {
        final id = int.tryParse(widget.initialPackage!.id) ?? 1;
        saved = await widget.payrollService.updatePackage(id, payload);
      } else {
        saved = await widget.payrollService.createPackage(payload);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        widget.onPackageSaved(saved);
        context.showToast('Package "${saved.name}" saved successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        context.showExceptionToast(e, fallback: 'Failed to save package');
      }
    }
  }

  void _showComponentDialog({SalaryComponent? initialComponent, int? editIndex}) {
    final isEditingComponent = initialComponent != null;
    final nameCtrl = TextEditingController(text: initialComponent?.name ?? '');
    final valCtrl = TextEditingController(
      text: initialComponent != null ? initialComponent.value.toStringAsFixed(0) : '1000',
    );
    String category = initialComponent?.category ?? 'earning';

    final isMobile = MediaQuery.of(context).size.width < 600;

    Widget buildDialog(BuildContext ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          final content = Material(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: isMobile
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(14),
            elevation: isMobile ? 16 : 0,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 420,
                maxHeight: isMobile ? MediaQuery.of(ctx).size.height * 0.85 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: isMobile ? 12 : 20,
                  bottom: isMobile ? MediaQuery.of(ctx).viewInsets.bottom + 20 : 20,
                ),
                child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile)
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isEditingComponent ? Icons.edit_note : Icons.add_circle_outline,
                            size: 20,
                            color: const Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditingComponent ? 'Edit Salary Component' : 'Add Salary Component',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Component Name (e.g. Conveyance, PF, Gratuity)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCustomDropdown<String>(
                    labelText: 'Category',
                    hintText: 'Select category',
                    initialValue: category,
                    isDense: true,
                    prefixIcon: Icons.category_outlined,
                    items: const [
                      AppDropdownItem(
                        value: 'earning',
                        label: 'Earning (+) / Addition',
                        icon: Icons.add_circle_outline,
                        iconColor: Color(0xFF10B981),
                      ),
                      AppDropdownItem(
                        value: 'deduction',
                        label: 'Deduction (-) / Withholding',
                        icon: Icons.remove_circle_outline,
                        iconColor: Color(0xFFF43F5E),
                      ),
                      AppDropdownItem(
                        value: 'employer_contribution',
                        label: 'Employer Cost / Contribution',
                        icon: Icons.business_outlined,
                        iconColor: Color(0xFF3B82F6),
                      ),
                      AppDropdownItem(
                        value: 'benefit',
                        label: 'Benefit / Perk',
                        icon: Icons.card_giftcard_outlined,
                        iconColor: Color(0xFF8B5CF6),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monthly Value (₹)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (nameCtrl.text.trim().isNotEmpty) {
                            final val = double.tryParse(valCtrl.text) ?? 0;
                            setState(() {
                              final updatedComp = SalaryComponent(
                                id: initialComponent?.id,
                                packageId: initialComponent?.packageId,
                                name: nameCtrl.text.trim(),
                                category: category,
                                calcType: initialComponent?.calcType ?? 'fixed',
                                value: val,
                                sortOrder: initialComponent?.sortOrder ?? (editIndex ?? _components.length),
                              );
                              if (editIndex != null && editIndex >= 0 && editIndex < _components.length) {
                                _components[editIndex] = updatedComp;
                              } else {
                                _components.add(updatedComp);
                              }
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(isEditingComponent ? 'Save Changes' : 'Add Component'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

          if (isMobile) {
            return content;
          }
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: content,
          );
        },
      );
    }

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: buildDialog,
      );
    } else {
      showDialog(
        context: context,
        builder: buildDialog,
      );
    }
  }

  Widget _buildMultiplierCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required Widget valueWidget,
    required bool isDark,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          valueWidget,
        ],
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, bool isDark, bool isEditing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEditing ? 'Edit Salary Package' : 'Create Salary Package',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Define gross compensation and statutory breakdown',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Form Content
                Expanded(
                  child: ListView(
                    children: [
                      // Package Name
                      Text('Package Name *', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _nameController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Package name is required' : null,
                        decoration: InputDecoration(
                          hintText: 'e.g. Senior Tech Lead - Tier 1',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text('Description', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Role or grade scope summary...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Monthly Gross
                      Text('Monthly Gross Salary (₹) *', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _grossController,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || double.tryParse(v) == null) ? 'Valid gross salary required' : null,
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Overtime & LOP rules
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Overtime Eligible', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              value: _otEnabled,
                              onChanged: (v) => setState(() => _otEnabled = v),
                            ),
                          ),
                          if (_otEnabled) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _otRateController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Rate / hr (₹)',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Loss of Pay (LOP) Applicable', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text('Deduct absent days according to package divisor rules', style: GoogleFonts.inter(fontSize: 10.5)),
                        value: _lopEnabled,
                        onChanged: (v) => setState(() => _lopEnabled = v),
                      ),
                      if (_lopEnabled) ...[
                        const SizedBox(height: 8),

                        // Deduction Basis & Divisor Method Row (Loss of Pay divisor configured per package)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 480;
                            final basisDropdown = AppCustomDropdown<String>(
                              labelText: 'Deduction Basis',
                              hintText: 'Select basis',
                              initialValue: _lopBasis,
                              isDense: true,
                              prefixIcon: Icons.account_balance_wallet_outlined,
                              items: const [
                                AppDropdownItem(value: 'gross', label: 'Gross Contractual Salary', subtitle: 'Standard gross pay', icon: Icons.account_balance_wallet_outlined),
                                AppDropdownItem(value: 'basic', label: 'Basic Salary Only', subtitle: 'Basic component only', icon: Icons.payments_outlined),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _lopBasis = v);
                              },
                            );

                            final divisorDropdown = AppCustomDropdown<String>(
                              labelText: 'Loss of Pay (LOP) Divisor Method',
                              hintText: 'Select divisor method',
                              initialValue: _lopDayBasis,
                              isDense: true,
                              prefixIcon: Icons.calculate_outlined,
                              items: const [
                                AppDropdownItem(value: 'calendar_days', label: 'Actual Calendar Days (28-31)', subtitle: 'Exact days in specific month', icon: Icons.calendar_month),
                                AppDropdownItem(value: 'fixed_30', label: 'Fixed 30 Days Standard Basis', subtitle: 'Standard commercial 30-day divisor', icon: Icons.calendar_today),
                                AppDropdownItem(value: 'fixed_26', label: 'Fixed 26 Working Days', subtitle: 'Standard 6-day week divisor', icon: Icons.date_range),
                                AppDropdownItem(value: 'working_days', label: 'Scheduled Working Days', subtitle: 'Excludes weekly offs & holidays', icon: Icons.work_outline),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _lopDayBasis = v);
                              },
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: basisDropdown),
                                  const SizedBox(width: 10),
                                  Expanded(child: divisorDropdown),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                basisDropdown,
                                const SizedBox(height: 10),
                                divisorDropdown,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Attendance Pay Multipliers Section Header (matching Attendance-Web CreatePackageModal.jsx)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance Pay Multipliers',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Multiplier applied to daily salary for each status',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Multiplier Cards: Present (1.0x), Half Day (Configurable), Absent (0.0x)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 520;

                            final cardPresent = _buildMultiplierCard(
                              title: 'Present / Late',
                              badgeText: '100% Pay',
                              badgeColor: const Color(0xFF10B981),
                              badgeBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                              valueWidget: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  '1.0x (Standard)',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                              isDark: isDark,
                            );

                            final cardHalfDay = _buildMultiplierCard(
                              title: 'Half Day',
                              badgeText: '${(_halfDayMultiplier * 100).toStringAsFixed(0)}% Pay',
                              badgeColor: const Color(0xFFD97706),
                              badgeBg: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
                              valueWidget: AppCustomDropdown<double>(
                                labelText: '',
                                hintText: 'Rate',
                                initialValue: _halfDayMultiplier,
                                isDense: true,
                                items: const [
                                  AppDropdownItem(value: 0.5, label: '0.50x (50% pay)'),
                                  AppDropdownItem(value: 0.4, label: '0.40x (40% pay)'),
                                  AppDropdownItem(value: 0.6, label: '0.60x (60% pay)'),
                                  AppDropdownItem(value: 0.75, label: '0.75x (75% pay)'),
                                  AppDropdownItem(value: 0.33, label: '0.33x (33% pay)'),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _halfDayMultiplier = v);
                                },
                              ),
                              isDark: isDark,
                              isHighlighted: true,
                            );

                            final cardAbsent = _buildMultiplierCard(
                              title: 'Absent',
                              badgeText: '0% Pay',
                              badgeColor: const Color(0xFFE11D48),
                              badgeBg: isDark ? const Color(0xFF881337).withValues(alpha: 0.4) : const Color(0xFFFFF1F2),
                              valueWidget: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  '0.0x (Full LOP)',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48)),
                                ),
                              ),
                              isDark: isDark,
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cardPresent),
                                  const SizedBox(width: 8),
                                  Expanded(child: cardHalfDay),
                                  const SizedBox(width: 8),
                                  Expanded(child: cardAbsent),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                cardPresent,
                                const SizedBox(height: 8),
                                cardHalfDay,
                                const SizedBox(height: 8),
                                cardAbsent,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Components Builder Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Salary Components Breakdown', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(
                                '${_components.length} components • Tap or click edit to modify',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => _showComponentDialog(),
                            icon: const Icon(Icons.add, size: 14),
                            label: Text('Add Component', style: GoogleFonts.inter(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Components List
                      ...List.generate(_components.length, (idx) {
                        final comp = _components[idx];
                        final isEarning = comp.isEarning;
                        final isEmployerCost = comp.isEmployerContribution;
                        final isBenefit = comp.isBenefit;
                        final isDeduction = comp.isDeduction;

                        final categoryLabel = isEarning
                            ? 'Earning (+) • Monthly Fixed'
                            : isEmployerCost
                                ? 'Employer Cost (CTC) • Monthly Fixed'
                                : isBenefit
                                    ? 'Benefit (Perk) • Monthly Fixed'
                                    : 'Deduction (-) • Monthly Fixed';

                        final categoryColor = isEarning
                            ? const Color(0xFF10B981)
                            : isEmployerCost
                                ? const Color(0xFF3B82F6)
                                : isBenefit
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFFF43F5E);

                        final prefix = isEarning
                            ? '+'
                            : isDeduction
                                ? '-'
                                : isEmployerCost
                                    ? 'CTC '
                                    : 'Perk ';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showComponentDialog(initialComponent: comp, editIndex: idx),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comp.name,
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          categoryLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: categoryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$prefix₹${comp.value.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: categoryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF4F46E5),
                                    ),
                                    tooltip: 'Edit Component',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showComponentDialog(
                                      initialComponent: comp,
                                      editIndex: idx,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                    tooltip: 'Remove Component',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() => _components.removeAt(idx));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        _isSaving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Create Package'),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.initialPackage != null;

    if (widget.isBottomSheet) {
      return Material(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        elevation: 16,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(child: _buildFormContent(context, isDark, isEditing)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: _buildFormContent(context, isDark, isEditing),
          ),
        ),
      ),
    );
  }
}
