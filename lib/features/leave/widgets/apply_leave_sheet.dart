import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/leave/widgets/custom_date_picker_dialog.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';

class ApplyLeaveSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const ApplyLeaveSheet({super.key, this.onSuccess});

  static void show(BuildContext context, {VoidCallback? onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApplyLeaveSheet(onSuccess: onSuccess),
    );
  }

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedRuleId;
  bool _isCustomType = false;
  final _customTypeController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeaveProvider>();
      if (provider.myLeaveBalances.isEmpty) {
        provider.fetchMyLeaveBalancesAndPolicies().then((_) {
          if (mounted && provider.myLeaveBalances.isNotEmpty) {
            setState(() {
              _selectedRuleId = provider.myLeaveBalances.first['rule_id']?.toString();
            });
          }
        });
      } else {
        setState(() {
          _selectedRuleId = provider.myLeaveBalances.first['rule_id']?.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int get _calculatedDays {
    if (_startDate == null || _endDate == null) return 0;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff > 0 ? diff : 0;
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomDatePickerDialog(
        initialDate: initialDate,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 2),
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          if (_startDate != null && picked.isBefore(_startDate!)) {
            context.showToast('End date cannot be before start date', isWarning: true);
            return;
          }
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Could not access files.', isError: true);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      context.showToast('Please select both start and end dates.', isWarning: true);
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      context.showToast('Please provide a reason for the leave.', isWarning: true);
      return;
    }

    final provider = context.read<LeaveProvider>();

    String leaveType = '';
    int? ruleId;
    Map<String, dynamic>? selectedBalance;

    if (_isCustomType) {
      leaveType = _customTypeController.text.trim();
      if (leaveType.isEmpty) {
        context.showToast('Please specify the leave type.', isWarning: true);
        return;
      }
    } else {
      final matches = provider.myLeaveBalances.where(
        (b) => b['rule_id']?.toString() == _selectedRuleId,
      );
      if (matches.isNotEmpty) {
        selectedBalance = matches.first;
      }
      // Send rule_id as leave_type (like Attendance-Web) so backend resolves rule_id directly:
      leaveType = _selectedRuleId ?? selectedBalance?['leave_type']?.toString() ?? 'Casual Leave';
      ruleId = int.tryParse(_selectedRuleId ?? '');
    }

    // Check if attachment is required per policy (matching Attendance-Web)
    if (!_isCustomType && selectedBalance != null) {
      final requiresDoc = selectedBalance['requires_doc'] == 1 ||
          selectedBalance['requires_doc'] == true ||
          selectedBalance['requires_doc'] == '1';
      if (requiresDoc && _selectedFiles.isEmpty) {
        final typeName = selectedBalance['leave_type']?.toString() ?? 'this leave type';
        context.showToast('An attachment is required for $typeName as per leave policy.', isWarning: true);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final requestData = <String, dynamic>{
        'leave_type': leaveType,
        if (ruleId != null) 'rule_id': ruleId,
        'start_date': dateFormat.format(_startDate!),
        'end_date': dateFormat.format(_endDate!),
        'reason': _reasonController.text.trim(),
        if (_selectedFiles.isNotEmpty) 'attachments': _selectedFiles,
      };

      await provider.submitLeaveRequest(requestData);

      if (mounted) {
        Navigator.pop(context);
        context.showToast('Leave request submitted successfully.', isSuccess: true);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
        context.showToast(cleanMsg.isNotEmpty ? cleanMsg : 'Failed to apply for leave.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LeaveProvider>();
    final balances = provider.myLeaveBalances;

    final dateFormat = DateFormat('MMM dd, yyyy');

    final selectedBalance = !_isCustomType && _selectedRuleId != null
        ? balances.firstWhere(
            (b) => b['rule_id']?.toString() == _selectedRuleId,
            orElse: () => {},
          )
        : null;

    final requiresDoc = selectedBalance != null &&
        (selectedBalance['requires_doc'] == 1 ||
            selectedBalance['requires_doc'] == true ||
            selectedBalance['requires_doc'] == '1');

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = (screenHeight - bottomInset) * 0.90;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutQuad,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxSheetHeight,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Apply for Leave',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Custom Leave Type Dropdown
                        AppCustomDropdown<String>(
                          labelText: 'Leave Type',
                          hintText: 'Select leave type',
                          prefixIcon: Icons.beach_access_rounded,
                          initialValue: _isCustomType
                              ? 'other'
                              : (_selectedRuleId ?? (balances.isNotEmpty ? balances.first['rule_id']?.toString() : null)),
                          items: [
                            ...balances.map((bal) {
                              final ruleId = bal['rule_id']?.toString() ?? '';
                              final name = bal['leave_type']?.toString() ?? 'Leave';
                              final avail = bal['available']?.toString() ?? '0';
                              final policyName = bal['policy_name']?.toString();
                              final reqDoc = bal['requires_doc'] == 1 || bal['requires_doc'] == true || bal['requires_doc'] == '1';

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

                              final numAvail = double.tryParse(avail) ?? 0;
                              final badgeColor = numAvail > 0
                                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                  : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7));
                              final badgeTextColor = numAvail > 0
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                  : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309));

                              return AppDropdownItem<String>(
                                value: ruleId,
                                label: name,
                                subtitle: [
                                  if (policyName != null && policyName.isNotEmpty) policyName,
                                  if (reqDoc) 'Doc Required',
                                ].join(' • '),
                                icon: icon,
                                badge: '$avail days left',
                                badgeColor: badgeColor,
                                badgeTextColor: badgeTextColor,
                              );
                            }),
                            if (balances.isEmpty) ...[
                              const AppDropdownItem<String>(
                                value: 'casual',
                                label: 'Casual Leave',
                                icon: Icons.beach_access_rounded,
                              ),
                              const AppDropdownItem<String>(
                                value: 'sick',
                                label: 'Sick Leave',
                                icon: Icons.local_hospital_outlined,
                              ),
                            ],
                            AppDropdownItem<String>(
                              value: 'other',
                              label: 'Other (Custom)',
                              subtitle: 'Specify a custom leave reason',
                              icon: Icons.edit_note_rounded,
                              badge: 'Custom',
                              badgeColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              badgeTextColor: const Color(0xFF6366F1),
                              isCustomAction: true,
                            ),
                          ],
                          onChanged: (val) {
                            if (val == 'other') {
                              setState(() {
                                _isCustomType = true;
                                _selectedRuleId = null;
                              });
                            } else {
                              setState(() {
                                _isCustomType = false;
                                _selectedRuleId = val;
                              });
                            }
                          },
                        ),

                      if (_isCustomType) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customTypeController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom leave type',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Dates Pickers
                      Row(
                        children: [
                          // Start Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _pickDate(true),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _startDate != null ? dateFormat.format(_startDate!) : 'Select date',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal,
                                              color: _startDate != null
                                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                  : Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // End Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _pickDate(false),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _endDate != null ? dateFormat.format(_endDate!) : 'Select date',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: _endDate != null ? FontWeight.w600 : FontWeight.normal,
                                              color: _endDate != null
                                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                  : Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Duration Banner
                      if (_startDate != null && _endDate != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              Text(
                                'Total Duration: $_calculatedDays Day${_calculatedDays > 1 ? 's' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Reason Textarea
                      Text(
                        'Reason',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Why do you need leave?',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        style: GoogleFonts.inter(fontSize: 13),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Reason is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // Attachments Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Attachments',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                              if (requiresDoc) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Required',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Max 5MB (JPG, PNG, PDF)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Upload Area Button
                      InkWell(
                        onTap: _pickFiles,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_upload_outlined,
                                  color: Color(0xFF6366F1),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload documents',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Images and PDFs allowed',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Selected Files List
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...List.generate(_selectedFiles.length, (idx) {
                          final file = _selectedFiles[idx];
                          final sizeKb = (file.size / 1024).toStringAsFixed(1);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161B22) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 18,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$sizeKb KB',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _selectedFiles.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Submit Request',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
