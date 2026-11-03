import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart';
import 'package:flutter_application/features/attendance/core/attendance_service.dart';
import 'package:flutter_application/features/attendance/widgets/visual_correction_timeline.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class CorrectionRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onClose;
  final DateTime? initialDate;
  final CorrectionType? initialType;

  const CorrectionRequestForm({
    super.key,
    required this.onSuccess,
    this.onClose,
    this.initialDate,
    this.initialType,
  });

  @override
  State<CorrectionRequestForm> createState() => _CorrectionRequestFormState();
}

class _CorrectionRequestFormState extends State<CorrectionRequestForm> {
  late AttendanceService _service;
  bool _isLoading = false;
  bool _isLoadingRecords = false;

  // Simple Form State (Web Parity)
  late DateTime _requestDate;
  late DateTime _focusedDay;
  CorrectionType _type = CorrectionType.missedPunch;
  final TextEditingController _otherCategoryController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // Custom Inline Themed Picker Toggles
  bool _isCalendarOpen = false;
  bool _isCategoryOpen = false;

  // Advanced [Optional] Collapsible Accordion State
  bool _showAdvancedSettings = false;

  // Proposed Sessions (Inside Advanced)
  List<Map<String, dynamic>> _sessions = [];

  // Frozen snapshot for original_data
  List<Map<String, String>> _originalSessions = [];

  // Attachments
  final List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _requestDate = widget.initialDate ?? DateTime.now();
    _focusedDay = _requestDate;
    _type = widget.initialType ?? CorrectionType.missedPunch;
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AttendanceService(authService.dio);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExistingRecords(_requestDate);
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _otherCategoryController.dispose();
    super.dispose();
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

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age.inSeconds < 15) return lastKnown;
      }
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _fetchExistingRecords(DateTime date) async {
    setState(() => _isLoadingRecords = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final records = await _service.getMyRecords(
        fromDate: dateStr,
        toDate: dateStr,
        limit: 50,
      );

      final validRecords = records.where((r) => r.timeIn != null).toList();
      validRecords.sort((a, b) => a.timeIn!.compareTo(b.timeIn!));

      if (mounted) {
        setState(() {
          if (validRecords.isNotEmpty) {
            final sessionsList = <Map<String, dynamic>>[];
            final originalList = <Map<String, String>>[];

            for (final r in validRecords) {
              if (r.timeIn != null) {
                final inTime = TimeOfDay.fromDateTime(DateTime.parse(r.timeIn!));
                final outTime = r.timeOut != null
                    ? TimeOfDay.fromDateTime(DateTime.parse(r.timeOut!))
                    : null;
                sessionsList.add({
                  'in': inTime,
                  'out': outTime,
                  'punch_type': 'regular',
                });
                originalList.add({
                  'time_in': DateFormat('HH:mm').format(DateTime.parse(r.timeIn!)),
                  'time_out': r.timeOut != null
                      ? DateFormat('HH:mm').format(DateTime.parse(r.timeOut!))
                      : '',
                  'punch_type': 'regular',
                });
              }
              for (final cp in r.checkpoints) {
                if (cp.time != null && cp.time!.isNotEmpty) {
                  try {
                    final cpDt = DateTime.parse(cp.time!);
                    final cpTime = TimeOfDay.fromDateTime(cpDt);
                    sessionsList.add({
                      'in': cpTime,
                      'out': null,
                      'punch_type': 'normal',
                    });
                    originalList.add({
                      'time_in': DateFormat('HH:mm').format(cpDt),
                      'time_out': '',
                      'punch_type': 'normal',
                    });
                  } catch (_) {
                    if (cp.time!.contains(':')) {
                      final parts = cp.time!.split(':');
                      final cpTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                      sessionsList.add({
                        'in': cpTime,
                        'out': null,
                        'punch_type': 'normal',
                      });
                      originalList.add({
                        'time_in': '${cpTime.hour.toString().padLeft(2, '0')}:${cpTime.minute.toString().padLeft(2, '0')}',
                        'time_out': '',
                        'punch_type': 'normal',
                      });
                    }
                  }
                }
              }
            }

            _sessions = sessionsList;
            _originalSessions = originalList;
          } else {
            _sessions = [];
            _originalSessions = [];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching existing records for correction: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  double _calculateTotalProposedHours() {
    double total = 0;
    for (final s in _sessions) {
      if (s['punch_type'] == 'normal') continue;
      final inT = s['in'] as TimeOfDay?;
      final outT = s['out'] as TimeOfDay?;
      if (inT != null && outT != null) {
        final inMins = inT.hour * 60 + inT.minute;
        final outMins = outT.hour * 60 + outT.minute;
        if (outMins > inMins) {
          total += (outMins - inMins) / 60.0;
        }
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _getProposedSessionsForTimeline() {
    return _sessions.asMap().entries.map((entry) {
      final idx = entry.key;
      final s = entry.value;
      final inT = s['in'] as TimeOfDay?;
      final outT = s['out'] as TimeOfDay?;
      final pType = s['punch_type']?.toString() ?? 'regular';

      return {
        'id': 'sess-$idx',
        'time_in': inT != null
            ? '${inT.hour.toString().padLeft(2, '0')}:${inT.minute.toString().padLeft(2, '0')}'
            : '',
        'time_out': outT != null
            ? '${outT.hour.toString().padLeft(2, '0')}:${outT.minute.toString().padLeft(2, '0')}'
            : '',
        'punch_type': pType,
      };
    }).toList();
  }

  void _handleTimelineSessionsChanged(List<Map<String, dynamic>> updatedSessions) {
    setState(() {
      _sessions = updatedSessions.map((s) {
        TimeOfDay? inT;
        TimeOfDay? outT;
        final inStr = s['time_in']?.toString();
        final outStr = s['time_out']?.toString();
        if (inStr != null && inStr.contains(':')) {
          final parts = inStr.split(':');
          inT = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        if (outStr != null && outStr.contains(':')) {
          final parts = outStr.split(':');
          outT = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        return {
          'in': inT,
          'out': outT,
          'punch_type': s['punch_type']?.toString() ?? 'regular',
        };
      }).toList();
    });
  }

  Future<void> _handleConfirmAndSubmit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      context.showToast(
        "Please state a justification reason for this correction request.",
        isError: true,
      );
      return;
    }

    if (_type == CorrectionType.other && _otherCategoryController.text.trim().isEmpty) {
      context.showToast(
        "Please specify your custom other category.",
        isError: true,
      );
      return;
    }

    // Only validate sessions if user opened Advanced and has active sessions
    if (_showAdvancedSettings && _sessions.isNotEmpty) {
      for (var s in _sessions) {
        if (s['in'] == null || s['out'] == null) {
          context.showToast(
            "Please select both Time In and Time Out for each customized session in Advanced.",
            isError: true,
          );
          return;
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalHours = _calculateTotalProposedHours();

    // Category display label
    String catLabel = _getCategoryLabel(_type);
    if (_type == CorrectionType.other && _otherCategoryController.text.trim().isNotEmpty) {
      catLabel = 'Other: ${_otherCategoryController.text.trim()}';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Review Correction Request',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please review your correction submission details:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            _buildConfirmRow('Date', DateFormat('d MMMM yyyy').format(_requestDate), isDark),
            _buildConfirmRow('Category', catLabel, isDark),
            if (totalHours > 0)
              _buildConfirmRow('Custom Timings', '${totalHours.toStringAsFixed(1)} hrs', isDark)
            else
              _buildConfirmRow('Custom Timings', 'None (Standard / Remarks)', isDark),
            if (_selectedFiles.isNotEmpty)
              _buildConfirmRow('Attached Proof', '${_selectedFiles.length} file(s)', isDark),
            const SizedBox(height: 12),
            Text(
              'Stated Reason:',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$reason"',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Back to Edit',
              style: GoogleFonts.poppins(color: isDark ? Colors.white60 : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              'Confirm & Submit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeSubmit(reason);
    }
  }

  Widget _buildConfirmRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(CorrectionType type) {
    switch (type) {
      case CorrectionType.missedPunch:
        return 'Missed Punch';
      case CorrectionType.missedDay:
        return 'Missed Day';
      case CorrectionType.other:
        return 'Other Reason';
      default:
        return 'Missed Punch';
    }
  }

  IconData _getCategoryIcon(CorrectionType type) {
    switch (type) {
      case CorrectionType.missedPunch:
        return Icons.timer_off_outlined;
      case CorrectionType.missedDay:
        return Icons.event_busy_outlined;
      case CorrectionType.other:
      default:
        return Icons.edit_note_outlined;
    }
  }

  String _getCategorySubtitle(CorrectionType type) {
    switch (type) {
      case CorrectionType.missedPunch:
        return 'Forgot to clock in or clock out';
      case CorrectionType.missedDay:
        return 'Full day attendance missing';
      case CorrectionType.other:
      default:
        return 'Custom reason or exception';
    }
  }

  Future<void> _executeSubmit(String reason) async {
    // Determine category tag matching Web formatting
    String formattedReason = reason;
    if (_type == CorrectionType.other && _otherCategoryController.text.trim().isNotEmpty) {
      formattedReason = '[${_otherCategoryController.text.trim()}] $reason';
    } else {
      formattedReason = '[${_getCategoryLabel(_type)}] $reason';
    }

    // Proposed sessions: includes regular sessions and checkpoints
    final validSessions = _sessions.where((s) {
      final isCheckpoint = s['punch_type'] == 'normal';
      if (isCheckpoint) return s['in'] != null;
      return s['in'] != null && s['out'] != null;
    }).toList();

    final correctionData = {
      'sessions': validSessions.map((s) {
        final isCheckpoint = s['punch_type'] == 'normal';
        final inT = s['in'] as TimeOfDay?;
        final outT = s['out'] as TimeOfDay?;
        return {
          'time_in': inT != null
              ? '${inT.hour.toString().padLeft(2, '0')}:${inT.minute.toString().padLeft(2, '0')}:00'
              : '',
          'time_out': (!isCheckpoint && outT != null)
              ? '${outT.hour.toString().padLeft(2, '0')}:${outT.minute.toString().padLeft(2, '0')}:00'
              : '',
          'punch_type': isCheckpoint ? 'normal' : 'regular',
        };
      }).toList(),
    };

    setState(() => _isLoading = true);

    try {
      final position = await _getCurrentLocation();

      await _service.submitCorrectionRequest(
        requestDate: DateFormat('yyyy-MM-dd').format(_requestDate),
        correctionType: _type == CorrectionType.missedDay
            ? 'missed_day'
            : (_type == CorrectionType.missedPunch ? 'missed_punch' : 'other'),
        correctionMethod: 'add_session',
        reason: formattedReason,
        correctionData: correctionData,
        originalData: _originalSessions,
        latitude: position?.latitude,
        longitude: position?.longitude,
        attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        context.showToast(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalProposedHours = _calculateTotalProposedHours();

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: isWide
                  ? BorderRadius.circular(24)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle on mobile / portrait
                if (!isWide)
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_calendar_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Attendance Correction',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              DateFormat('d MMMM yyyy').format(_requestDate),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // Scrollable Form Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary Fields: Date & Category (Grid on wide, column on narrow)
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildDateSelector(isDark)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildCategorySelector(isDark)),
                            ],
                          )
                        else ...[
                          _buildDateSelector(isDark),
                          const SizedBox(height: 16),
                          _buildCategorySelector(isDark),
                        ],

                        // Conditional "Specify Other Category" field
                        if (_type == CorrectionType.other) ...[
                          const SizedBox(height: 14),
                          _buildOtherCategoryField(isDark),
                        ],

                        const SizedBox(height: 16),

                        // Simple Reason field with inline file attachment
                        _buildReasonSection(isDark),

                        // Attached files chips
                        if (_selectedFiles.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildAttachmentChips(isDark),
                        ],

                        const SizedBox(height: 20),

                        // Collapsible "Advanced [Optional]" Accordion
                        _buildAdvancedSettingsAccordion(isDark, totalProposedHours),

                        const SizedBox(height: 24),

                        // Submit Button
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Custom Themed Date Selector with Inline Calendar
  Widget _buildDateSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ADJUSTMENT DATE'),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            setState(() {
              _isCalendarOpen = !_isCalendarOpen;
              if (_isCalendarOpen) _isCategoryOpen = false;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCalendarOpen
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                width: _isCalendarOpen ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMMM yyyy').format(_requestDate),
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE').format(_requestDate),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isCalendarOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _isCalendarOpen
                        ? const Color(0xFF6366F1)
                        : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Custom Inline Themed Calendar
        if (_isCalendarOpen) _buildInlineThemedCalendar(isDark),
      ],
    );
  }

  Widget _buildInlineThemedCalendar(bool isDark) {
    final now = DateTime.now();
    final isNextMonthDisabled = _focusedDay.year == now.year && _focusedDay.month >= now.month;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Header & Navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: isNextMonthDisabled
                    ? (isDark ? Colors.white12 : const Color(0xFFCBD5E1))
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                onPressed: isNextMonthDisabled
                    ? null
                    : () {
                        setState(() {
                          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                        });
                      },
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  final today = DateTime.now();
                  setState(() {
                    _requestDate = today;
                    _focusedDay = today;
                    _isCalendarOpen = false;
                  });
                  _fetchExistingRecords(today);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Today',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 4),

          // Custom styled TableCalendar
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_requestDate, day),
            calendarFormat: CalendarFormat.month,
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.monday,
            rowHeight: 34,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.poppins(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: GoogleFonts.poppins(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: GoogleFonts.robotoMono(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              weekendTextStyle: GoogleFonts.robotoMono(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              disabledTextStyle: GoogleFonts.robotoMono(
                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                fontSize: 11.5,
              ),
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
              ),
              todayTextStyle: GoogleFonts.robotoMono(
                color: const Color(0xFF6366F1),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: GoogleFonts.robotoMono(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (selectedDay.isAfter(DateTime.now())) return;
              setState(() {
                _requestDate = selectedDay;
                _focusedDay = focusedDay;
                _isCalendarOpen = false;
              });
              _fetchExistingRecords(selectedDay);
            },
          ),
        ],
      ),
    );
  }

  /// Custom Themed Category Selector with Inline Expandable Options
  Widget _buildCategorySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CORRECTION CATEGORY'),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            setState(() {
              _isCategoryOpen = !_isCategoryOpen;
              if (_isCategoryOpen) _isCalendarOpen = false;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCategoryOpen
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                width: _isCategoryOpen ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getCategoryIcon(_type), size: 15, color: const Color(0xFF6366F1)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getCategoryLabel(_type),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getCategorySubtitle(_type),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _isCategoryOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _isCategoryOpen
                        ? const Color(0xFF6366F1)
                        : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Custom Inline Themed Options List
        if (_isCategoryOpen) _buildInlineThemedCategoryList(isDark),
      ],
    );
  }

  Widget _buildInlineThemedCategoryList(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCategoryOptionItem(
            type: CorrectionType.missedPunch,
            title: 'Missed Punch',
            subtitle: 'Forgot to clock in or clock out',
            icon: Icons.timer_off_outlined,
            isDark: isDark,
          ),
          _buildCategoryOptionItem(
            type: CorrectionType.missedDay,
            title: 'Missed Day',
            subtitle: 'Full day attendance missing or off-site',
            icon: Icons.event_busy_outlined,
            isDark: isDark,
          ),
          _buildCategoryOptionItem(
            type: CorrectionType.other,
            title: 'Other Reason',
            subtitle: 'Sensor glitch, travel, client visit, etc.',
            icon: Icons.edit_note_outlined,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryOptionItem({
    required CorrectionType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _type == type;

    return InkWell(
      onTap: () {
        setState(() {
          _type = type;
          _isCategoryOpen = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected
            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white10 : const Color(0xFFEEF2FF)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 17,
                color: Color(0xFF6366F1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherCategoryField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SPECIFY OTHER CATEGORY *'),
        const SizedBox(height: 6),
        TextField(
          controller: _otherCategoryController,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: 'e.g., Biometric sensor failure, Travel exception...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('REASON *'),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(
                      'Attach Proof',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: _reasonController,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Write your message or reason for adjustment...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
                child: Row(
                  children: [
                    Text(
                      'Provide clear details for manager approval',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      color: const Color(0xFF6366F1),
                      tooltip: 'Attach document or photo proof',
                      onPressed: _pickFile,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentChips(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedFiles.asMap().entries.map((entry) {
        final idx = entry.key;
        final file = entry.value;
        final sizeKb = (file.size / 1024).toStringAsFixed(1);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 14, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  '${file.name} ($sizeKb KB)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => setState(() => _selectedFiles.removeAt(idx)),
                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Advanced Settings Collapsible Section
  /// Holds Custom Punch Timeline, Session Editors, Auto-Fill, and Existing Records.
  Widget _buildAdvancedSettingsAccordion(bool isDark, double totalProposedHours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Accordion Header Toggle - Flat modern pill bar
        InkWell(
          onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Adjustment Timeline',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Optional',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (totalProposedHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${totalProposedHours.toStringAsFixed(1)}h',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  )
                else
                  Text(
                    'Not Set',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                    ),
                  ),
                if (_isLoadingRecords)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    ),
                  ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _showAdvancedSettings ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Unnested, direct timeline without nested card wrapper
        if (_showAdvancedSettings) ...[
          const SizedBox(height: 14),
          VisualCorrectionTimeline(
            originalSessions: _originalSessions,
            proposedSessions: _getProposedSessionsForTimeline(),
            isDark: isDark,
            editable: true,
            onSessionsChange: _handleTimelineSessionsChanged,
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleConfirmAndSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Correction Request',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: isDark ? Colors.white54 : const Color(0xFF64748B),
      ),
    );
  }
}
