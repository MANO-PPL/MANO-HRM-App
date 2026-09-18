import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/leave/core/leave_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// Modal dialog allowing administrators to adjust an employee's allocated, carried forward,
/// and used leave balance days. Directly mirrors `AdjustBalanceDrawer.jsx` from Attendance-Web.
class AdjustBalanceDialog extends StatefulWidget {
  final int balanceId;
  final String employeeName;
  final String leaveType;
  final double initialAllocated;
  final double initialCarriedForward;
  final double initialUsed;
  final LeaveService leaveService;
  final VoidCallback onSaved;

  const AdjustBalanceDialog({
    super.key,
    required this.balanceId,
    required this.employeeName,
    required this.leaveType,
    required this.initialAllocated,
    this.initialCarriedForward = 0,
    this.initialUsed = 0,
    required this.leaveService,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required int balanceId,
    required String employeeName,
    required String leaveType,
    required double initialAllocated,
    double initialCarriedForward = 0,
    double initialUsed = 0,
    required LeaveService leaveService,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdjustBalanceDialog(
        balanceId: balanceId,
        employeeName: employeeName,
        leaveType: leaveType,
        initialAllocated: initialAllocated,
        initialCarriedForward: initialCarriedForward,
        initialUsed: initialUsed,
        leaveService: leaveService,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AdjustBalanceDialog> createState() => _AdjustBalanceDialogState();
}

class _AdjustBalanceDialogState extends State<AdjustBalanceDialog> {
  late final TextEditingController _allocatedController;
  late final TextEditingController _carriedForwardController;
  late final TextEditingController _usedController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _allocatedController = TextEditingController(
      text: widget.initialAllocated % 1 == 0
          ? widget.initialAllocated.toInt().toString()
          : widget.initialAllocated.toString(),
    );
    _carriedForwardController = TextEditingController(
      text: widget.initialCarriedForward % 1 == 0
          ? widget.initialCarriedForward.toInt().toString()
          : widget.initialCarriedForward.toString(),
    );
    _usedController = TextEditingController(
      text: widget.initialUsed % 1 == 0
          ? widget.initialUsed.toInt().toString()
          : widget.initialUsed.toString(),
    );
  }

  @override
  void dispose() {
    _allocatedController.dispose();
    _carriedForwardController.dispose();
    _usedController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final allocated = double.tryParse(_allocatedController.text.trim());
    final carriedForward = double.tryParse(_carriedForwardController.text.trim()) ?? 0;
    final used = double.tryParse(_usedController.text.trim()) ?? 0;

    if (allocated == null || allocated < 0) {
      context.showToast('Please enter a valid non-negative allocated quota', isWarning: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await widget.leaveService.updateLeaveBalance(
        widget.balanceId,
        allocated: allocated,
        carriedForward: carriedForward,
        used: used,
      );

      if (!mounted) return;

      if (success) {
        context.showToast('Leave balance updated successfully', isSuccess: true);
        widget.onSaved();
        Navigator.of(context).pop();
      } else {
        context.showToast('Failed to update leave balance', isError: true);
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Error: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF6366F1), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Balance',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          '${widget.employeeName} · ${widget.leaveType}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: subtitleColor,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Allocated Quota Field
              _buildNumericInput(
                label: 'Allocated Quota (Days)',
                controller: _allocatedController,
                isDark: isDark,
                borderColor: borderColor,
                helperText: 'Annual base allocation per policy',
              ),
              const SizedBox(height: 12),

              // Carried Forward Field
              _buildNumericInput(
                label: 'Carried Forward (Days)',
                controller: _carriedForwardController,
                isDark: isDark,
                borderColor: borderColor,
                helperText: 'Days carried over from previous year',
              ),
              const SizedBox(height: 12),

              // Used Days Field
              _buildNumericInput(
                label: 'Used / Consumed (Days)',
                controller: _usedController,
                isDark: isDark,
                borderColor: borderColor,
                helperText: 'Total leaves already utilized',
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Save Balance',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  Widget _buildNumericInput({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    required Color borderColor,
    required String helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            Text(
              helperText,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            filled: true,
            fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
