import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/daily_activity/core/dar_models.dart';

class EventMeetingDialog extends StatefulWidget {
  final DarItem? initialData;
  final String initialDate; // YYYY-MM-DD
  final String type; // 'MEETING' or 'EVENT'
  final Function(Map<String, dynamic> payload) onSave;
  final VoidCallback? onDelete;
  final bool isBottomSheet;

  const EventMeetingDialog({
    super.key,
    this.initialData,
    required this.initialDate,
    required this.type,
    required this.onSave,
    this.onDelete,
    this.isBottomSheet = false,
  });

  @override
  State<EventMeetingDialog> createState() => _EventMeetingDialogState();
}

class _EventMeetingDialogState extends State<EventMeetingDialog> {
  late String _selectedType; // 'MEETING' or 'EVENT'
  late bool _isEdit;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController(); // online link or physical location

  late String _dateStr; // YYYY-MM-DD
  late String _startTime; // HH:MM
  late String _endTime; // HH:MM
  late String _locationType; // 'online' or 'offline'

  @override
  void initState() {
    super.initState();
    _isEdit = widget.initialData != null;
    _selectedType = 'MEETING';

    _titleController.text = _isEdit ? widget.initialData!.title : '';
    _descController.text = _isEdit ? widget.initialData!.description : '';
    
    _dateStr = _isEdit ? widget.initialData!.date : widget.initialDate;
    _startTime = _isEdit ? widget.initialData!.startTime : _getRoundedTime(0);
    _endTime = _isEdit ? widget.initialData!.endTime : _getRoundedTime(60);

    if (_selectedType == 'MEETING') {
      final initialLoc = _isEdit ? widget.initialData!.location : '';
      _locationController.text = initialLoc;
      _locationType = (_isEdit && widget.initialData!.isOnline) ? 'online' : 'offline';
    } else {
      _locationController.text = _isEdit ? widget.initialData!.location : '';
      _locationType = 'offline';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Get rounded time (next 30 mins)
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
    if (_isEdit) return; // Cannot edit date of existing event per web client logic
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
    final hour = int.tryParse(parts[0]) ?? 10;
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
      hour: int.tryParse(parts[0]) ?? 10,
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
    
    // Time comparison validation
    if (_startTime.compareTo(_endTime) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time.")),
      );
      return;
    }

    final payload = {
      'type': _selectedType,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'start_time': _startTime,
      'end_time': _endTime,
      'event_date': _dateStr,
      'location': _selectedType == 'MEETING' ? _locationController.text.trim() : _locationController.text.trim(),
    };
    
    widget.onSave(payload);
    Navigator.of(context).pop();
  }

  Widget _buildFormContent(BuildContext context, bool isDark, String formattedDate) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dividerColor = Theme.of(context).dividerColor;
    
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEdit ? "Edit Meeting" : "Schedule Meeting",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Title input
          TextFormField(
            controller: _titleController,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
            decoration: InputDecoration(
              hintText: 'Add title',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[350]!)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2)),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
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

          // Meeting specific fields (location type toggle & link/address inputs)
          if (_selectedType == 'MEETING') ...[
            Row(
              children: [
                Icon(
                  _locationType == 'online' ? Icons.videocam_outlined : Icons.map_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => setState(() => _locationType = 'online'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _locationType == 'online'
                        ? const Color(0xFFEFF6FF)
                        : Colors.transparent,
                    foregroundColor: _locationType == 'online'
                        ? const Color(0xFF2563EB)
                        : Colors.grey,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: _locationType == 'online' ? const Color(0xFFBFDBFE) : Colors.grey[300]!,
                      ),
                    ),
                  ),
                  child: Text("Online Meeting", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _locationType = 'offline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _locationType == 'offline'
                        ? const Color(0xFFEFF6FF)
                        : Colors.transparent,
                    foregroundColor: _locationType == 'offline'
                        ? const Color(0xFF2563EB)
                        : Colors.grey,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: _locationType == 'offline' ? const Color(0xFFBFDBFE) : Colors.grey[300]!,
                      ),
                    ),
                  ),
                  child: Text("In-Person", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    style: GoogleFonts.poppins(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: _locationType == 'online'
                          ? 'Google Meet / Zoom link'
                          : 'Meeting Room name / Address',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                      ),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Description (common)
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
                    hintText: 'Add description',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Footer actions: Delete (if edit) & Save/Update
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
                  tooltip: 'Delete',
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
                      backgroundColor: const Color(0xFF3B82F6),
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
    final formattedDate = DateFormat('d MMMM yyyy').format(DateTime.parse(_dateStr));

    if (widget.isBottomSheet) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: isDark ? Border.all(color: const Color(0xFF30363D), width: 1) : null,
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
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _buildFormContent(context, isDark, formattedDate),
        ),
      ),
    );
  }
}

// [upd:2026-04-15T14:00:00+05:30]
