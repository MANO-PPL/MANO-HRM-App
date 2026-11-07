import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// AssignPackageDialog - Dialog matching AssignPackageModal.jsx
/// Assigns a salary package to a selected employee.
class AssignPackageDialog extends StatefulWidget {
  final EmployeePackageAssignment employee;
  final List<SalaryPackage> packages;
  final PayrollService payrollService;
  final VoidCallback onAssigned;

  const AssignPackageDialog({
    super.key,
    required this.employee,
    required this.packages,
    required this.payrollService,
    required this.onAssigned,
  });

  static Future<void> show(
    BuildContext context, {
    required EmployeePackageAssignment employee,
    required List<SalaryPackage> packages,
    required PayrollService payrollService,
    required VoidCallback onAssigned,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AssignPackageDialog(
        employee: employee,
        packages: packages,
        payrollService: payrollService,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AssignPackageDialog> createState() => _AssignPackageDialogState();
}

class _AssignPackageDialogState extends State<AssignPackageDialog> {
  int? _selectedPackageId;
  DateTime _effectiveFrom = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.packages.isNotEmpty) {
      _selectedPackageId = widget.employee.packageId ?? int.tryParse(widget.packages.first.id);
    }
  }

  Future<void> _handleAssign() async {
    if (_selectedPackageId == null) {
      context.showToast('Please select a salary package to assign.', isWarning: true);
      return;
    }

    setState(() => _isSaving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_effectiveFrom);

    try {
      await widget.payrollService.assignPackageToEmployee(
        widget.employee.employeeId,
        _selectedPackageId!,
        dateStr,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        widget.onAssigned();
        context.showToast(
          'Package assigned to ${widget.employee.name} successfully!',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        context.showExceptionToast(e, fallback: 'Failed to assign package');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
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
                    child: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Assign Salary Package',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.employee.name,
                          style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
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

              // Employee Info Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF4F46E5),
                      child: Text(
                        widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : 'E',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.employee.name,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.employee.designation} • ${widget.employee.department} • ${widget.employee.code}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Package Dropdown
              AppCustomDropdown<int>(
                labelText: 'Select Salary Package *',
                hintText: 'Select salary package',
                initialValue: _selectedPackageId,
                isDense: true,
                prefixIcon: Icons.layers_outlined,
                items: widget.packages.map((p) {
                  final pId = int.tryParse(p.id) ?? 0;
                  return AppDropdownItem<int>(
                    value: pId,
                    label: p.name,
                    subtitle: '₹${p.monthlyGross.toStringAsFixed(0)}/mo',
                    badge: 'CTC ₹${p.annualCtc.toStringAsFixed(0)}',
                    icon: Icons.card_giftcard,
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPackageId = v);
                },
              ),
              const SizedBox(height: 14),

              // Effective Date
              Text('Effective From Date', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _effectiveFrom,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _effectiveFrom = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMMM yyyy').format(_effectiveFrom), style: GoogleFonts.inter(fontSize: 12)),
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                    onPressed: _isSaving ? null : _handleAssign,
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
                      _isSaving ? 'Assigning...' : 'Assign Package',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
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
