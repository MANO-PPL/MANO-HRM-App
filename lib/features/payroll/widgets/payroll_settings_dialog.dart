import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// PayrollSettingsDialog - Modal dialog replicating PayrollSettingsModal.jsx
/// Configures company-wide compensation and LOP deduction calculation rules.
class PayrollSettingsDialog extends StatefulWidget {
  final PayrollSettings initialSettings;
  final PayrollService payrollService;
  final ValueChanged<PayrollSettings> onSettingsSaved;
  final bool isBottomSheet;

  const PayrollSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.payrollService,
    required this.onSettingsSaved,
    this.isBottomSheet = false,
  });

  static Future<void> show(
    BuildContext context, {
    required PayrollSettings initialSettings,
    required PayrollService payrollService,
    required ValueChanged<PayrollSettings> onSettingsSaved,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PayrollSettingsDialog(
          initialSettings: initialSettings,
          payrollService: payrollService,
          onSettingsSaved: onSettingsSaved,
          isBottomSheet: true,
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (context) => PayrollSettingsDialog(
        initialSettings: initialSettings,
        payrollService: payrollService,
        onSettingsSaved: onSettingsSaved,
        isBottomSheet: false,
      ),
    );
  }

  @override
  State<PayrollSettingsDialog> createState() => _PayrollSettingsDialogState();
}

class _PayrollSettingsDialogState extends State<PayrollSettingsDialog> {
  late String _currency;
  late String _payrollFrequency;
  late String _roundingMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currency = widget.initialSettings.currency;
    _payrollFrequency = widget.initialSettings.payrollFrequency;
    _roundingMethod = widget.initialSettings.roundingMethod;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final newSettings = PayrollSettings(
      currency: _currency,
      payrollFrequency: _payrollFrequency,
      roundingMethod: _roundingMethod,
      roundingPrecision: 0,
      lopCalculationMethod: widget.initialSettings.lopCalculationMethod,
      lopFixedDaysValue: widget.initialSettings.lopFixedDaysValue,
      lopFactorPresent: widget.initialSettings.lopFactorPresent,
      lopFactorHalfDay: widget.initialSettings.lopFactorHalfDay,
      lopFactorAbsent: widget.initialSettings.lopFactorAbsent,
    );

    try {
      final saved = await widget.payrollService.updatePayrollSettings(newSettings.toJson());
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        widget.onSettingsSaved(saved);
        context.showToast('Payroll settings saved successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        context.showExceptionToast(e, fallback: 'Failed to save settings');
      }
    }
  }

  Widget _buildFormContent(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
              child: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Payroll & Compensation Settings',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Organization-wide compensation rules',
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
        const Divider(height: 24),

        // Form fields
        Expanded(
          child: ListView(
            children: [
              // Currency
              AppCustomDropdown<String>(
                labelText: 'Currency',
                hintText: 'Select currency',
                initialValue: _currency,
                isDense: true,
                prefixIcon: Icons.payments_outlined,
                items: const [
                  AppDropdownItem(value: 'INR', label: 'INR (₹) - Indian Rupee', icon: Icons.currency_rupee),
                  AppDropdownItem(value: 'USD', label: 'USD (\$) - US Dollar', icon: Icons.attach_money),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _currency = v);
                },
              ),
              const SizedBox(height: 14),

              // Payroll Frequency
              AppCustomDropdown<String>(
                labelText: 'Payroll Frequency',
                hintText: 'Select frequency',
                initialValue: _payrollFrequency,
                isDense: true,
                prefixIcon: Icons.calendar_today_outlined,
                items: const [
                  AppDropdownItem(value: 'monthly', label: 'Monthly Cycle', subtitle: 'Processed once per month', icon: Icons.calendar_month),
                  AppDropdownItem(value: 'biweekly', label: 'Bi-Weekly Cycle', subtitle: 'Every two weeks', icon: Icons.date_range),
                  AppDropdownItem(value: 'weekly', label: 'Weekly Cycle', subtitle: 'Every 7 days', icon: Icons.view_week),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _payrollFrequency = v);
                },
              ),
              const SizedBox(height: 14),

              // Rounding Method
              AppCustomDropdown<String>(
                labelText: 'Net Salary Rounding',
                hintText: 'Select rounding',
                initialValue: _roundingMethod,
                isDense: true,
                prefixIcon: Icons.rounded_corner,
                items: const [
                  AppDropdownItem(value: 'nearest', label: 'Nearest Whole Rupee', subtitle: 'Standard mathematical round', icon: Icons.all_inclusive),
                  AppDropdownItem(value: 'down', label: 'Round Down (Floor)', subtitle: 'Drop paisa completely', icon: Icons.south),
                  AppDropdownItem(value: 'up', label: 'Round Up (Ceil)', subtitle: 'Next whole rupee', icon: Icons.north),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _roundingMethod = v);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 24),

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
                _isSaving ? 'Saving...' : 'Save Settings',
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
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(child: _buildFormContent(context, isDark)),
              ],
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildFormContent(context, isDark),
        ),
      ),
    );
  }
}
