import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift_model.dart';
import '../../utils/week_off_policy_helper.dart';

class AddShiftDialog extends StatefulWidget {
  final Shift? existingShift;
  final Function(Shift) onSubmit;
  
  const AddShiftDialog({super.key, this.existingShift, required this.onSubmit});

  @override
  State<AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<AddShiftDialog> {
  final _nameCtrl = TextEditingController();
  final _graceCtrl = TextEditingController(text: "0");
  final _otThresholdCtrl = TextEditingController(text: "8.0");
  final _correctionDeadlineCtrl = TextEditingController(text: "2");
  
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isOvertimeEnabled = false;
  
  // Validation Rules
  bool _checkInGps = false;
  bool _checkInSelfie = false;
  bool _checkOutGps = false;
  bool _checkOutSelfie = false;

  // Policy rules variables
  List<String> _workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  List<WeekOffRule> _weekOffRules = [];
  List<HalfDayRule> _halfDayRules = [];
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingShift != null) {
      final s = widget.existingShift!;
      _nameCtrl.text = s.name;
      _graceCtrl.text = s.gracePeriodMins.toString();
      _isOvertimeEnabled = s.isOvertimeEnabled;
      _otThresholdCtrl.text = s.overtimeThresholdHours.toString();
      _startTime = _parseTime(s.startTime);
      _endTime = _parseTime(s.endTime);
      
      // Load Rules
      _checkInGps = s.entryGeofence;
      _checkInSelfie = s.entrySelfie;
      _checkOutGps = s.exitGeofence;
      _checkOutSelfie = s.exitSelfie;
      _correctionDeadlineCtrl.text = s.correctionDeadline.toString();

      final parsed = WeekOffPolicyHelper.parsePolicy(
        s.policyRules['week_off_policy'] ?? s.policyRules['week_off'] ?? [],
      );
      _workingDays = List<String>.from(parsed.workingDays);
      _weekOffRules = List<WeekOffRule>.from(parsed.weekOffRules);
      _halfDayRules = List<HalfDayRule>.from(parsed.halfDayRules);
    } else {
      // Defaults
       _checkInGps = true;
       _checkInSelfie = true;
       _checkOutGps = false; 
       _checkOutSelfie = false;
       _correctionDeadlineCtrl.text = "2";
       _workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
       _weekOffRules = [];
       _halfDayRules = [];
    }
  }

  TimeOfDay _parseTime(String t) {
      try {
        final parts = t.split(":");
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        return const TimeOfDay(hour: 9, minute: 0);
      }
  }
   
  String _fmtTime(TimeOfDay t) {
     final h = t.hour.toString().padLeft(2, '0');
     final m = t.minute.toString().padLeft(2, '0');
     return "$h:$m";
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context, 
      initialTime: isStart ? _startTime : _endTime
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shift Name is required")));
      return;
    }
    
    final weekOffPolicyJson = WeekOffPolicyHelper.buildPolicy(
      workingDays: _workingDays,
      weekOffRules: _weekOffRules,
      halfDayRules: _halfDayRules,
    );

    // Construct Policy Rules
    final rules = {
      'shift_timing': {
        'start_time': _fmtTime(_startTime),
        'end_time': _fmtTime(_endTime),
      },
      'grace_period': {
        'minutes': int.tryParse(_graceCtrl.text) ?? 0,
      },
      'overtime': {
        'enabled': _isOvertimeEnabled,
        'threshold': double.tryParse(_otThresholdCtrl.text) ?? 8.0,
        'buffer': widget.existingShift?.policyRules['overtime']?['buffer'] ?? 0.5,
      },
      'entry_requirements': {
        'geofence': _checkInGps,
        'selfie': _checkInSelfie,
      },
      'exit_requirements': {
        'geofence': _checkOutGps,
        'selfie': _checkOutSelfie,
      },
      'correction_deadline': int.tryParse(_correctionDeadlineCtrl.text) ?? 2,
      'week_off_policy': weekOffPolicyJson,
    };

    final s = Shift(
      id: widget.existingShift?.id,
      name: _nameCtrl.text,
      startTime: _fmtTime(_startTime),
      endTime: _fmtTime(_endTime),
      gracePeriodMins: int.tryParse(_graceCtrl.text) ?? 0,
      isOvertimeEnabled: _isOvertimeEnabled,
      overtimeThresholdHours: double.tryParse(_otThresholdCtrl.text) ?? 8.0,
      policyRules: rules,
    );
    widget.onSubmit(s);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic Colors
    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final inputColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF4A5568) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final hintColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;

    final isMobile = MediaQuery.of(context).size.width < 600;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      padding: EdgeInsets.only(
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        top: 12,
        bottom: (isMobile ? 16 : 24) + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                widget.existingShift == null ? 'Create New Shift' : 'Edit Shift',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.grey[600], size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          SizedBox(height: isMobile ? 16 : 24),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shift Name
                  _buildLabel('Shift Name', labelColor),
                  _buildTextField(
                    controller: _nameCtrl, 
                    hint: 'e.g. Morning Shift A', 
                    fillColor: inputColor, 
                    borderColor: borderColor,
                    textColor: textColor,
                    hintColor: hintColor,
                  ),
                  const SizedBox(height: 16),

                  // Start / End Time
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Start Time', labelColor),
                            _buildTimeBox(context, _fmtTime(_startTime), () => _pickTime(true), inputColor, borderColor, textColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('End Time', labelColor),
                            _buildTimeBox(context, _fmtTime(_endTime), () => _pickTime(false), inputColor, borderColor, textColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Working Days
                  _buildWorkingDaysConfig(labelColor, textColor, isDark),
                  const SizedBox(height: 20),

                  // Show Advanced Settings button
                  _buildAdvancedSettingsToggle(textColor, borderColor, isDark),
                  const SizedBox(height: 16),

                  if (_showAdvancedSettings) ...[
                    // Grace Period & Correction Deadline Row (moved here, matching advanced config from React)
                    _buildGraceAndDeadlineRow(labelColor, textColor, hintColor, inputColor, borderColor),
                    const SizedBox(height: 20),

                    // Overtime Section
                    _buildOvertimeConfig(textColor, labelColor, inputColor, borderColor, isDark),
                    const SizedBox(height: 20),

                    // Alternate Days Off Configuration
                    _buildAlternateDaysConfig(labelColor, textColor, isDark),
                    const SizedBox(height: 20),

                    // Half Days Configuration
                    _buildHalfDaysConfig(context, labelColor, textColor, isDark),
                    const SizedBox(height: 20),

                    // Attendance Validation Section
                    _buildAttendanceValidationConfig(textColor, labelColor, inputColor, borderColor, isDark),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF374151) : Colors.grey[200],
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), // Indigo button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Save Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingDaysConfig(Color labelColor, Color textColor, bool isDark) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Working Days', labelColor),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            final isSelected = _workingDays.contains(day);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _workingDays.remove(day);
                    // Clean up rule if disabling working day
                    _weekOffRules.removeWhere((r) => r.day == day);
                    _halfDayRules.removeWhere((r) => r.day == day);
                  } else {
                    _workingDays.add(day);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF4A5568) : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Text(
                  day,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : textColor,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettingsToggle(Color textColor, Color borderColor, bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          color: isDark ? const Color(0xFF1F2937) : Colors.grey[50],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 16, color: textColor),
            const SizedBox(width: 8),
            Text(
              _showAdvancedSettings ? 'Hide Advanced Settings' : 'Show Advanced Settings',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _showAdvancedSettings ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraceAndDeadlineRow(Color labelColor, Color textColor, Color hintColor, Color inputColor, Color borderColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Grace Period', labelColor),
              _buildTextField(
                controller: _graceCtrl, 
                hint: '0', 
                suffix: 'mins',
                fillColor: inputColor, 
                borderColor: borderColor,
                textColor: textColor,
                hintColor: hintColor,
                isNumeric: true
              ),
              const SizedBox(height: 4),
              Text(
                'Allowed lateness buffer.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Corr. Deadline', labelColor),
              _buildTextField(
                controller: _correctionDeadlineCtrl, 
                hint: '2', 
                suffix: 'days',
                fillColor: inputColor, 
                borderColor: borderColor,
                textColor: textColor,
                hintColor: hintColor,
                isNumeric: true
              ),
              const SizedBox(height: 4),
              Text(
                'Days to correct missed punches.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOvertimeConfig(Color textColor, Color labelColor, Color inputColor, Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overtime Calculation',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enable automatic OT tracking',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            Switch(
              value: _isOvertimeEnabled,
              onChanged: (v) => setState(() => _isOvertimeEnabled = v),
              activeTrackColor: const Color(0xFF6366F1), // Indigo
              activeThumbColor: Colors.white,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              inactiveThumbColor: isDark ? Colors.grey[400] : Colors.white,
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
          ],
        ),
        if (_isOvertimeEnabled) ...[
          const SizedBox(height: 12),
          _buildLabel('Minimum Hours for OT', labelColor),
          _buildTextField(
            controller: _otThresholdCtrl, 
            hint: '8', 
            suffix: 'Hr',
            fillColor: inputColor, 
            borderColor: borderColor,
            textColor: textColor,
            isNumeric: true
          ),
        ],
      ],
    );
  }

  Widget _buildAlternateDaysConfig(Color labelColor, Color textColor, bool isDark) {
    final nonWorkingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        .where((day) => !_workingDays.contains(day))
        .toList();

    if (nonWorkingDays.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Alternate Full Days Off',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...nonWorkingDays.map((day) {
          final rule = _weekOffRules.firstWhere((r) => r.day == day, orElse: () => WeekOffRule(day: day, weeks: []));
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    day,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(5, (index) {
                      final weekNum = index + 1;
                      final isOff = rule.weeks.contains(weekNum);
                      final suffix = weekNum == 1 ? 'st' : weekNum == 2 ? 'nd' : weekNum == 3 ? 'rd' : 'th';
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            final idx = _weekOffRules.indexWhere((r) => r.day == day);
                            if (idx >= 0) {
                              final w = List<int>.from(_weekOffRules[idx].weeks);
                              if (w.contains(weekNum)) {
                                w.remove(weekNum);
                              } else {
                                w.add(weekNum);
                              }
                              if (w.isEmpty) {
                                _weekOffRules.removeAt(idx);
                              } else {
                                _weekOffRules[idx] = WeekOffRule(day: day, weeks: w);
                              }
                            } else {
                              _weekOffRules.add(WeekOffRule(day: day, weeks: [weekNum]));
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOff
                                ? Colors.amber.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOff
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : (isDark ? const Color(0xFF4A5568) : const Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Text(
                            '$weekNum$suffix',
                            style: GoogleFonts.poppins(
                              color: isOff ? Colors.amber[700] : textColor,
                              fontSize: 11,
                              fontWeight: isOff ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHalfDaysConfig(BuildContext context, Color labelColor, Color textColor, bool isDark) {
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final inputColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF4A5568) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Half Days',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...allDays.map((day) {
          final ruleIdx = _halfDayRules.indexWhere((r) => r.day == day);
          final rule = ruleIdx >= 0 ? _halfDayRules[ruleIdx] : HalfDayRule(day: day, weeks: []);
          final hasHalfDays = rule.weeks.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        day,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(5, (index) {
                          final weekNum = index + 1;
                          final isHalf = rule.weeks.contains(weekNum);
                          final suffix = weekNum == 1 ? 'st' : weekNum == 2 ? 'nd' : weekNum == 3 ? 'rd' : 'th';

                          return InkWell(
                            onTap: () {
                              setState(() {
                                final idx = _halfDayRules.indexWhere((r) => r.day == day);
                                if (idx >= 0) {
                                  final w = List<int>.from(_halfDayRules[idx].weeks);
                                  if (w.contains(weekNum)) {
                                    w.remove(weekNum);
                                  } else {
                                    w.add(weekNum);
                                  }
                                  if (w.isEmpty) {
                                    _halfDayRules.removeAt(idx);
                                  } else {
                                    _halfDayRules[idx] = HalfDayRule(
                                      day: day,
                                      weeks: w,
                                      timing: _halfDayRules[idx].timing ?? {
                                        'start_time': _fmtTime(_startTime),
                                        'end_time': '13:00', // default half day end
                                      },
                                    );
                                  }
                                } else {
                                  _halfDayRules.add(HalfDayRule(
                                    day: day,
                                    weeks: [weekNum],
                                    timing: {
                                      'start_time': _fmtTime(_startTime),
                                      'end_time': '13:00',
                                    },
                                  ));
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: isHalf
                                    ? Colors.blue.withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isHalf
                                      ? Colors.blue.withValues(alpha: 0.5)
                                      : (isDark ? const Color(0xFF4A5568) : const Color(0xFFE5E7EB)),
                                ),
                              ),
                              child: Text(
                                '$weekNum$suffix',
                                style: GoogleFonts.poppins(
                                  color: isHalf ? Colors.blue[700] : textColor,
                                  fontSize: 11,
                                  fontWeight: isHalf ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
                if (hasHalfDays) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Half Day Start', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                const SizedBox(height: 4),
                                _buildTimeBox(
                                  context,
                                  rule.timing?['start_time'] ?? _fmtTime(_startTime),
                                  () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _parseTime(rule.timing?['start_time'] ?? _fmtTime(_startTime)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        final idx = _halfDayRules.indexWhere((r) => r.day == day);
                                        if (idx >= 0) {
                                          final t = Map<String, String>.from(_halfDayRules[idx].timing ?? {});
                                          t['start_time'] = _fmtTime(picked);
                                          _halfDayRules[idx] = HalfDayRule(day: day, weeks: _halfDayRules[idx].weeks, timing: t);
                                        }
                                      });
                                    }
                                  },
                                  inputColor,
                                  borderColor,
                                  textColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Half Day End', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                const SizedBox(height: 4),
                                _buildTimeBox(
                                  context,
                                  rule.timing?['end_time'] ?? '13:00',
                                  () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _parseTime(rule.timing?['end_time'] ?? '13:00'),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        final idx = _halfDayRules.indexWhere((r) => r.day == day);
                                        if (idx >= 0) {
                                          final t = Map<String, String>.from(_halfDayRules[idx].timing ?? {});
                                          t['end_time'] = _fmtTime(picked);
                                          _halfDayRules[idx] = HalfDayRule(day: day, weeks: _halfDayRules[idx].weeks, timing: t);
                                        }
                                      });
                                    }
                                  },
                                  inputColor,
                                  borderColor,
                                  textColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttendanceValidationConfig(Color textColor, Color labelColor, Color inputColor, Color borderColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
        color: inputColor, 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.indigo[200] : const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'Attendance Validation',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHECK-IN', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    _buildCheckbox('GPS Required', _checkInGps, (v) => setState(() => _checkInGps = v!), textColor, isDark),
                    const SizedBox(height: 8),
                    _buildCheckbox('Selfie Required', _checkInSelfie, (v) => setState(() => _checkInSelfie = v!), textColor, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHECK-OUT', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    _buildCheckbox('GPS Required', _checkOutGps, (v) => setState(() => _checkOutGps = v!), textColor, isDark),
                    const SizedBox(height: 8),
                    _buildCheckbox('Selfie Required', _checkOutSelfie, (v) => setState(() => _checkOutSelfie = v!), textColor, isDark),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _buildTimeBox(BuildContext context, String value, VoidCallback onTap, Color fillColor, Color borderColor, Color textColor) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: GoogleFonts.poppins(color: textColor, fontSize: 14)),
            Icon(Icons.access_time, size: 18, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hint, 
    String? suffix,
    required Color fillColor,
    required Color borderColor,
    required Color textColor,
    Color? hintColor,
    bool isNumeric = false
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.poppins(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: hintColor ?? Colors.grey[500], fontSize: 14),
        suffixText: suffix,
        suffixStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1))),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged, Color textColor, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 20, height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
            side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            checkColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(color: textColor, fontSize: 13)),
      ],
    );
  }
}
