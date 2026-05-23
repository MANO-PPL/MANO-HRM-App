import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/leave_provider.dart';
import 'custom_date_picker_dialog.dart';
import '../../../shared/widgets/toast_helper.dart';

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const LeaveRequestForm({super.key, required this.onSuccess});

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  List<PlatformFile> _selectedFiles = [];

  final List<String> _leaveTypes = [
    'Casual Leave',
    'Sick Leave',
    'Privilege Leave', 
    'Emergency Leave',
    'Unpaid Leave'
  ];

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
          // Reset end date if it's before start date
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
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      context.showToast('Please select start and end dates.', isWarning: true);
      return;
    }

    try {
      final requestData = {
        'leave_type': _selectedLeaveType,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'reason': _reasonController.text.trim(),
        if (_selectedFiles.isNotEmpty) 'attachments': _selectedFiles,
      };

      await context.read<LeaveProvider>().submitLeaveRequest(requestData);
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
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
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Apply for Leave',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Leave Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedLeaveType,
              decoration: _inputDecoration(isDark, 'Leave Type', Icons.category_outlined),
              items: _leaveTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedLeaveType = val),
              validator: (val) => val == null ? 'Required' : null,
              dropdownColor: sheetColor,
              style: TextStyle(color: textPrimary),
            ),
            const SizedBox(height: 16),

            // Date Selection
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: _inputDecoration(isDark, 'Start Date', Icons.calendar_today),
                      child: Text(
                        _startDate == null ? 'Select' : DateFormat('MMM dd, yyyy').format(_startDate!),
                        style: TextStyle(color: textPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    child: InputDecorator(
                      decoration: _inputDecoration(isDark, 'End Date', Icons.event),
                      child: Text(
                        _endDate == null ? 'Select' : DateFormat('MMM dd, yyyy').format(_endDate!),
                        style: TextStyle(color: textPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason
            TextFormField(
              controller: _reasonController,
              decoration: _inputDecoration(isDark, 'Reason', Icons.edit_note),
              maxLines: 3,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              style: TextStyle(color: textPrimary),
            ),
            const SizedBox(height: 16),

            // Attachments
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(12),
                      color: fieldColor,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Attach Documents (Optional)',
                            style: TextStyle(
                              color: textMuted,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                file.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => setState(() => _selectedFiles.removeAt(index)),
                              child: const Icon(Icons.close, size: 14, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
              ],
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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: textMuted),
    );
  }
}
