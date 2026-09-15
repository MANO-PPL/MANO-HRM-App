import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/daily_activity/core/dar_models.dart';

class TaskEditDialog extends StatefulWidget {
  final DarItem? initialData;
  final String initialDate; // YYYY-MM-DD
  final List<String> categories;
  final Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;
  final bool isBottomSheet;
  final String? initialTimeIn; // Optional initial clocked session start

  const TaskEditDialog({
    super.key,
    this.initialData,
    required this.initialDate,
    required this.categories,
    required this.onSave,
    this.onDelete,
    this.isBottomSheet = false,
    this.initialTimeIn,
  });

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  late String _dateStr;
  late String _startTime;
  late String _endTime;
  late String _selectedCategory;
  late bool _isEdit;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.initialData != null;
    
    _titleController.text = _isEdit ? widget.initialData!.title : '';
    _descController.text = _isEdit ? widget.initialData!.description : '';
    _dateStr = _isEdit ? widget.initialData!.date : widget.initialDate;
    
    if (_isEdit) {
      _startTime = widget.initialData!.startTime;
      _endTime = widget.initialData!.endTime;
    } else {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_dateStr == todayStr) {
        final now = DateTime.now();
        final nowStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        if (widget.initialTimeIn != null) {
          _startTime = widget.initialTimeIn!;
          if (_startTime.compareTo(nowStr) > 0) {
            _startTime = nowStr;
          }
          final candidateEnd = _addOneHour(widget.initialTimeIn!);
          if (candidateEnd.compareTo(nowStr) > 0) {
            _endTime = nowStr;
          } else {
            _endTime = candidateEnd;
          }
        } else {
          _endTime = nowStr;
          final oneHourAgo = now.subtract(const Duration(hours: 1));
          _startTime = "${oneHourAgo.hour.toString().padLeft(2, '0')}:${oneHourAgo.minute.toString().padLeft(2, '0')}";
        }
      } else {
        if (widget.initialTimeIn != null) {
          _startTime = widget.initialTimeIn!;
          _endTime = _addOneHour(widget.initialTimeIn!);
        } else {
          _startTime = _getRoundedTime(0);
          _endTime = _getRoundedTime(60);
        }
      }
    }
    
    final initialCat = _isEdit ? widget.initialData!.category : '';
    _selectedCategory = widget.categories.contains(initialCat)
        ? initialCat
        : (widget.categories.isNotEmpty ? widget.categories.first : 'General');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _addOneHour(String timeStr) {
    final parts = timeStr.split(':');
    final h = (int.tryParse(parts[0]) ?? 9) + 1;
    final m = parts.length > 1 ? parts[1] : '00';
    return "${(h % 24).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  String _getRoundedTime(int addMinutes) {
    final now = DateTime.now().add(Duration(minutes: addMinutes));
    int min = now.minute;
    int hour = now.hour;

    if (min < 30) {
      min = 30;
    } else {
      min = 0;
      hour = (hour + 1) % 24;
    }

    return "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";
  }

  Future<void> _selectDate() async {
    if (_isEdit) return;
    final parsed = DateTime.parse(_dateStr);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateStr = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _adjustTime({required bool isStart, required bool increment}) {
    final timeStr = isStart ? _startTime : _endTime;
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    
    final dateTime = DateTime(2026, 1, 1, hour, minute);
    final adjusted = increment 
        ? dateTime.add(const Duration(minutes: 30)) 
        : dateTime.subtract(const Duration(minutes: 30));
        
    final formatted = "${adjusted.hour.toString().padLeft(2, '0')}:${adjusted.minute.toString().padLeft(2, '0')}";
    setState(() {
      if (isStart) {
        _startTime = formatted;
      } else {
        _endTime = formatted;
      }
    });
  }

  Future<void> _selectTime(bool isStart) async {
    final timeStr = isStart ? _startTime : _endTime;
    final parts = timeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        final formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime.compareTo(_endTime) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time.")),
      );
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String status = 'COMPLETED';
    if (_dateStr.compareTo(todayStr) > 0) {
      status = 'PLANNED';
    } else if (_dateStr == todayStr) {
      final now = DateTime.now();
      final nowStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      if (_endTime.compareTo(nowStr) > 0) {
        status = 'PLANNED';
      }
      if (widget.initialTimeIn != null && widget.initialTimeIn!.isNotEmpty && _startTime.compareTo(widget.initialTimeIn!) < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Task start time cannot precede check-in time (${widget.initialTimeIn}).")),
        );
        return;
      }
    }

    widget.onSave({
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'start_time': _startTime,
      'end_time': _endTime,
      'activity_date': _dateStr,
      'activity_type': _selectedCategory,
      'status': status,
    });
    Navigator.of(context).pop();
  }

  Widget _buildFormContent(BuildContext context, bool isDark, String formattedDate) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dividerColor = Theme.of(context).dividerColor;
    final fillColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEdit ? "Edit Task" : "New Task",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Title input
          TextFormField(
            controller: _titleController,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
            decoration: InputDecoration(
              hintText: 'Task Title',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dividerColor)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 20),

          // Category selector
          Row(
            children: [
              const Icon(Icons.category_outlined, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dividerColor),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.grey[800]),
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Beautiful Time Card Picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              children: [
                // Date Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: primaryColor, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          "Date",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D1117) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                // Start Time Adjustment Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          "Start Time",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                          onPressed: () => _adjustTime(isStart: true, increment: false),
                        ),
                        InkWell(
                          onTap: () => _selectTime(true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0D1117) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: dividerColor),
                            ),
                            child: Text(
                              _startTime,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
                          onPressed: () => _adjustTime(isStart: true, increment: true),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // End Time Adjustment Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          "End Time",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                          onPressed: () => _adjustTime(isStart: false, increment: false),
                        ),
                        InkWell(
                          onTap: () => _selectTime(false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0D1117) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: dividerColor),
                            ),
                            child: Text(
                              _endTime,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
                          onPressed: () => _adjustTime(isStart: false, increment: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Description input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notes, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Add description / details...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: dividerColor),
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isEdit && widget.onDelete != null)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDelete!();
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Task',
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      _isEdit ? "Update" : "Save",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.parse(_dateStr));
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;

    if (widget.isBottomSheet) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: dividerColor, width: 1),
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: _buildFormContent(context, isDark, formattedDate),
        ),
      );
    }

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dividerColor, width: 1),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _buildFormContent(context, isDark, formattedDate),
        ),
      ),
    );
  }
}

// [mod:2026-03-18T14:00:00+05:30]
