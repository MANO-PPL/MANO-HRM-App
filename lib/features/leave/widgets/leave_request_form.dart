import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/features/leave/widgets/custom_date_picker_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const LeaveRequestForm({super.key, required this.onSuccess});

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  
  int? _selectedRuleId;
  String? _selectedLeaveTypeName;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LeaveProvider>().fetchMyLeaveBalancesAndPolicies();
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart 
        ? (_startDate ?? DateTime.now()) 
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomDatePickerDialog(
        initialDate: initialDate,
        firstDate: DateTime(2025),
        lastDate: DateTime(2030),
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Could not access files. Please check permissions.', isError: true);
      }
    }
  }

  IconData _getFileIcon(String? ext) {
    if (ext == null) return Icons.insert_drive_file_outlined;
    final e = ext.toLowerCase();
    if (e == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(e)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRuleId == null && (_selectedLeaveTypeName == null || _selectedLeaveTypeName!.isEmpty)) {
      context.showToast('Please select a leave type.', isWarning: true);
      return;
    }
    if (_startDate == null || _endDate == null) {
      context.showToast('Please select start and end dates.', isWarning: true);
      return;
    }

    try {
      final requestData = {
        'leave_type': (_selectedRuleId ?? _selectedLeaveTypeName)?.toString(),
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'reason': _reasonController.text.trim(),
        if (_selectedFiles.isNotEmpty) 'attachments': _selectedFiles,
      };

      await context.read<LeaveProvider>().submitLeaveRequest(requestData);
      if (mounted) {
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
        context.showToast(cleanMsg.isNotEmpty ? cleanMsg : 'Failed to submit leave request.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = context.watch<LeaveProvider>().isLoadingMyLeaves;
    final sheetColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final fieldColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? const Color(0xFFC9D1D9) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = (screenHeight - bottomInset) * 0.90;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutQuad,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Apply for Leave',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Leave Type Dropdown (Dynamic from policy)
                Builder(builder: (context) {
                  final provider = context.watch<LeaveProvider>();
                  final policies = provider.myLeavePolicies;
                  final balances = provider.myLeaveBalances;
                  final isLoading = provider.isLoadingBalances;

                  // Collect all rules from all policies
                  final List<Map<String, dynamic>> allRules = [];
                  for (final policy in policies) {
                    final rules = (policy['rules'] as List<dynamic>?) ?? [];
                    for (final rule in rules) {
                      final ruleMap = Map<String, dynamic>.from(rule as Map);
                      // Find matching balance
                      final bal = balances.firstWhere(
                        (b) => b['rule_id']?.toString() == ruleMap['rule_id']?.toString(),
                        orElse: () => {},
                      );
                      ruleMap['balance_available'] = bal['available'] ?? bal['allocated'];
                      allRules.add(ruleMap);
                    }
                  }

                  if (isLoading) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ));
                  }

                  final dropdownItems = allRules.map((rule) {
                    final name = rule['name']?.toString() ?? '';
                    final avail = rule['balance_available'];
                    final subtitle = avail != null ? '$avail days left' : null;
                    final ruleId = rule['rule_id'] is int
                        ? rule['rule_id'] as int
                        : int.tryParse(rule['rule_id']?.toString() ?? '') ?? 0;

                    IconData icon = Icons.event_available_rounded;
                    final nameLower = name.toLowerCase();
                    if (nameLower.contains('sick') || nameLower.contains('medical')) {
                      icon = Icons.local_hospital_outlined;
                    } else if (nameLower.contains('casual')) {
                      icon = Icons.beach_access_rounded;
                    } else if (nameLower.contains('privilege') || nameLower.contains('earned') || nameLower.contains('annual')) {
                      icon = Icons.verified_user_outlined;
                    } else if (nameLower.contains('unpaid') || nameLower.contains('loss')) {
                      icon = Icons.money_off_csred_rounded;
                    }

                    return AppDropdownItem<int>(
                      value: ruleId,
                      label: name,
                      subtitle: subtitle,
                      icon: icon,
                      badge: subtitle,
                    );
                  }).toList();

                  return AppCustomDropdown<int>(
                    labelText: 'Leave Type',
                    hintText: 'Select a leave type',
                    prefixIcon: Icons.category_outlined,
                    initialValue: _selectedRuleId,
                    items: dropdownItems,
                    validator: (val) => val == null ? 'Select a leave type' : null,
                    onChanged: (val) {
                      setState(() {
                        _selectedRuleId = val;
                        _selectedLeaveTypeName = allRules.firstWhere(
                          (r) => (r['rule_id'] is int ? r['rule_id'] : int.tryParse(r['rule_id']?.toString() ?? '')) == val,
                          orElse: () => {},
                        )['name']?.toString();
                      });
                    },
                  );
                }),
                const SizedBox(height: 16),

                // Date Selection Cards Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: fieldColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _startDate != null 
                                  ? const Color(0xFF5B60F6).withValues(alpha: 0.5) 
                                  : borderColor,
                              width: _startDate != null ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'START DATE',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: _startDate != null ? const Color(0xFF5B60F6) : textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _startDate == null 
                                          ? 'Select' 
                                          : DateFormat('MMM dd, yyyy').format(_startDate!),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: fieldColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _endDate != null 
                                  ? const Color(0xFF5B60F6).withValues(alpha: 0.5) 
                                  : borderColor,
                              width: _endDate != null ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'END DATE',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    size: 16,
                                    color: _endDate != null ? const Color(0xFF5B60F6) : textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _endDate == null 
                                          ? 'Select' 
                                          : DateFormat('MMM dd, yyyy').format(_endDate!),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: _endDate != null ? FontWeight.w600 : FontWeight.normal,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Requested Duration Preview
                if (_startDate != null && _endDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B60F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF5B60F6).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Requested Duration:',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF5B60F6),
                          ),
                        ),
                        Text(
                          '${_endDate!.difference(_startDate!).inDays + 1} Days',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5B60F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Reason Field
                TextFormField(
                  controller: _reasonController,
                  decoration: _inputDecoration(isDark, 'Reason', Icons.edit_note_rounded),
                  maxLines: 3,
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  style: GoogleFonts.poppins(color: textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Attachment Selector
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DottedBorderContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 28,
                              color: const Color(0xFF5B60F6),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload Supporting Documents',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'PDF, JPG, PNG, WEBP (Max 5MB)',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Render attached files list
                if (_selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B60F6).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF5B60F6).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFileIcon(file.extension),
                              size: 16,
                              color: const Color(0xFF5B60F6),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                file.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _selectedFiles.removeAt(index)),
                              child: const Icon(
                                Icons.cancel_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit Request',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String label, IconData icon) {
    final fieldColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF5B60F6), width: 1.5),
      ),
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.poppins(color: textMuted, fontSize: 13),
    );
  }
}

// Helper for Dotted Border
class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  const DottedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedPainter(color: Colors.grey.withValues(alpha: 0.4)),
      child: child,
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  _DottedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    
    double dashWidth = 6, dashSpace = 4, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      canvas.drawLine(Offset(size.width, startY), Offset(size.width, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// commit-marker: 2026-02-20T09:15:00+05:30

// [mod:2026-02-20T11:30:00+05:30]

// [upd:2026-05-05T17:00:00+05:30]

// [rev:2026-08-25T15:30:00+05:30]
