import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// RunPayrollSheet - Modal Bottom Sheet replicating RunPayrollDrawer.jsx
/// Dedicated solely to configuring and calculating a new payroll run.
class RunPayrollSheet extends StatefulWidget {
  final PayrollService payrollService;
  final List<EmployeePackageAssignment> employees;
  final ValueChanged<PayrollRun> onRunCreated;

  const RunPayrollSheet({
    super.key,
    required this.payrollService,
    required this.employees,
    required this.onRunCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required PayrollService payrollService,
    required List<EmployeePackageAssignment> employees,
    required ValueChanged<PayrollRun> onRunCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: RunPayrollSheet(
          payrollService: payrollService,
          employees: employees,
          onRunCreated: onRunCreated,
        ),
      ),
    );
  }

  @override
  State<RunPayrollSheet> createState() => _RunPayrollSheetState();
}

class _RunPayrollSheetState extends State<RunPayrollSheet> {
  String _runType = 'batch'; // 'batch' | 'individual'
  String _periodPreset = 'current_month';
  DateTime _periodStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _periodEnd = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  final TextEditingController _titleController = TextEditingController();
  int? _selectedEmployeeId;
  String _empSearch = '';
  bool _isCalculating = false;
  int _calculationStep = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset('current_month');
    if (widget.employees.isNotEmpty) {
      _selectedEmployeeId = widget.employees.first.employeeId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    setState(() {
      _periodPreset = preset;
      final now = DateTime.now();
      if (preset == 'current_month') {
        _periodStart = DateTime(now.year, now.month, 1);
        _periodEnd = DateTime(now.year, now.month + 1, 0);
        _titleController.text = '${DateFormat('MMMM yyyy').format(now)} Payroll';
      } else if (preset == 'prev_month') {
        final prev = DateTime(now.year, now.month - 1, 1);
        _periodStart = prev;
        _periodEnd = DateTime(now.year, now.month, 0);
        _titleController.text = '${DateFormat('MMMM yyyy').format(prev)} Payroll';
      } else if (preset == 'last_30') {
        _periodEnd = now;
        _periodStart = now.subtract(const Duration(days: 30));
        _titleController.text = 'Past 30 Days Payroll';
      }
    });
  }

  Future<void> _handleCreateRun() async {
    if (_periodStart.isAfter(_periodEnd)) {
      context.showToast('Period start cannot be after period end date.', isWarning: true);
      return;
    }

    if (_runType == 'individual' && _selectedEmployeeId == null) {
      context.showToast('Please select an employee for the off-cycle run.', isWarning: true);
      return;
    }

    setState(() {
      _isCalculating = true;
      _calculationStep = 1;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _calculationStep = 2);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _calculationStep = 3);
    await Future.delayed(const Duration(milliseconds: 500));

    final payload = <String, dynamic>{
      'run_type': _runType,
      'period_start': DateFormat('yyyy-MM-dd').format(_periodStart),
      'period_end': DateFormat('yyyy-MM-dd').format(_periodEnd),
      'batch_name': _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : '${DateFormat('MMMM yyyy').format(_periodStart)} Payroll',
    };

    if (_runType == 'individual' && _selectedEmployeeId != null) {
      payload['employee_id'] = _selectedEmployeeId;
    }

    try {
      final newRun = await widget.payrollService.triggerPayrollRun(payload);
      if (mounted) {
        setState(() => _isCalculating = false);
        if (newRun != null) {
          Navigator.pop(context);
          widget.onRunCreated(newRun);
          context.showToast(
            'Payroll run "${newRun.batchName ?? 'Batch'}" generated as Draft!',
            isSuccess: true,
          );
        } else {
          context.showToast(
            'Failed to generate payroll run. Please check backend connection.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalculating = false);
        context.showExceptionToast(e, fallback: 'Failed to trigger payroll run');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredEmps = widget.employees.where((e) {
      if (_empSearch.isEmpty) return true;
      final q = _empSearch.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.code.toLowerCase().contains(q) ||
          e.department.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF4F46E5), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Run Payroll',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Configure cycle parameters and calculate draft payslips',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                // 1. Run Scope Selector
                Text(
                  'RUN SCOPE',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildScopeOption(
                        title: 'All Active Staff',
                        subtitle: 'Full monthly cycle',
                        icon: Icons.people_outline,
                        isSelected: _runType == 'batch',
                        onTap: () => setState(() => _runType = 'batch'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildScopeOption(
                        title: 'Individual Off-Cycle',
                        subtitle: 'Single employee run',
                        icon: Icons.person_outline,
                        isSelected: _runType == 'individual',
                        onTap: () => setState(() => _runType = 'individual'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // If Individual: Employee selector
                if (_runType == 'individual') ...[
                  Text(
                    'SELECT EMPLOYEE',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setState(() => _empSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Search employee name or department...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filteredEmps.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final emp = filteredEmps[idx];
                        final isSel = _selectedEmployeeId == emp.employeeId;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              emp.name,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? const Color(0xFF4F46E5) : null,
                              ),
                            ),
                            subtitle: Text(
                              '${emp.department} • ${emp.code}',
                              style: GoogleFonts.inter(fontSize: 10.5),
                            ),
                            trailing: isSel
                                ? const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5))
                                : null,
                            onTap: () => setState(() => _selectedEmployeeId = emp.employeeId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // 2. Pay Period Presets
                Text(
                  'PAY PERIOD PRESET',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip('current_month', 'Current Month'),
                    _buildPresetChip('prev_month', 'Previous Month'),
                    _buildPresetChip('last_30', 'Past 30 Days'),
                    _buildPresetChip('custom', 'Custom Range'),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Date Range Pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period Start',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _periodStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _periodStart = picked;
                                  _periodPreset = 'custom';
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(_periodStart),
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4F46E5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period End',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _periodEnd,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _periodEnd = picked;
                                  _periodPreset = 'custom';
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(_periodEnd),
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4F46E5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4. Batch Name / Title
                Text(
                  'BATCH TITLE',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. October 2026 Payroll',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Calculation Progress Feedback
                if (_isCalculating) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _calculationStep == 1
                                  ? 'Evaluating biometric and attendance logs...'
                                  : _calculationStep == 2
                                      ? 'Calculating statutory deductions & LOP...'
                                      : 'Finalizing draft payroll batch...',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isCalculating ? null : _handleCreateRun,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _isCalculating
                        ? const SizedBox.shrink()
                        : const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(
                      _isCalculating ? 'Calculating Run...' : 'Calculate & Generate Run',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF161B22) : Colors.white),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF4F46E5) : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSel = _periodPreset == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) => _applyPreset(key),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
        color: isSel ? Colors.white : (isDark ? const Color(0xFFC9D1D9) : const Color(0xFF4B5563)),
      ),
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(
        color: isSel
            ? const Color(0xFF4F46E5)
            : (isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB)),
      ),
    );
  }
}
