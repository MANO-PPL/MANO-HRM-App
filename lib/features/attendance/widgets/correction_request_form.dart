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
import 'package:flutter_application/features/attendance/core/attendance_record.dart';
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

class _SessionControllers {
  TextEditingController? _inHourController;
  TextEditingController? _inMinuteController;
  FocusNode? _inHourFocus;
  FocusNode? _inMinuteFocus;
  bool? _inIsPm;

  TextEditingController? _outHourController;
  TextEditingController? _outMinuteController;
  FocusNode? _outHourFocus;
  FocusNode? _outMinuteFocus;
  bool? _outIsPm;

  _SessionControllers({
    TextEditingController? inHourController,
    TextEditingController? inMinuteController,
    FocusNode? inHourFocus,
    FocusNode? inMinuteFocus,
    bool? inIsPm,
    TextEditingController? outHourController,
    TextEditingController? outMinuteController,
    FocusNode? outHourFocus,
    FocusNode? outMinuteFocus,
    bool? outIsPm,
  })  : _inHourController = inHourController,
        _inMinuteController = inMinuteController,
        _inHourFocus = inHourFocus,
        _inMinuteFocus = inMinuteFocus,
        _inIsPm = inIsPm ?? false,
        _outHourController = outHourController,
        _outMinuteController = outMinuteController,
        _outHourFocus = outHourFocus,
        _outMinuteFocus = outMinuteFocus,
        _outIsPm = outIsPm ?? true;

  TextEditingController get inHourController => _inHourController ??= TextEditingController();
  TextEditingController get inMinuteController => _inMinuteController ??= TextEditingController();
  FocusNode get inHourFocus => _inHourFocus ??= FocusNode();
  FocusNode get inMinuteFocus => _inMinuteFocus ??= FocusNode();

  bool get inIsPm => _inIsPm ?? false;
  set inIsPm(bool val) => _inIsPm = val;

  TextEditingController get outHourController => _outHourController ??= TextEditingController();
  TextEditingController get outMinuteController => _outMinuteController ??= TextEditingController();
  FocusNode get outHourFocus => _outHourFocus ??= FocusNode();
  FocusNode get outMinuteFocus => _outMinuteFocus ??= FocusNode();

  bool get outIsPm => _outIsPm ?? true;
  set outIsPm(bool val) => _outIsPm = val;

  bool _listenersAttached = false;

  void attachListeners({
    required VoidCallback onInHourSubmitted,
    required VoidCallback onInMinuteSubmitted,
    required VoidCallback onOutHourSubmitted,
    required VoidCallback onOutMinuteSubmitted,
  }) {
    if (_listenersAttached) return;
    _listenersAttached = true;

    inHourFocus.addListener(() {
      if (!inHourFocus.hasFocus) onInHourSubmitted();
    });
    inMinuteFocus.addListener(() {
      if (!inMinuteFocus.hasFocus) onInMinuteSubmitted();
    });
    outHourFocus.addListener(() {
      if (!outHourFocus.hasFocus) onOutHourSubmitted();
    });
    outMinuteFocus.addListener(() {
      if (!outMinuteFocus.hasFocus) onOutMinuteSubmitted();
    });
  }

  void dispose() {
    _inHourController?.dispose();
    _inMinuteController?.dispose();
    _inHourFocus?.dispose();
    _inMinuteFocus?.dispose();
    _outHourController?.dispose();
    _outMinuteController?.dispose();
    _outHourFocus?.dispose();
    _outMinuteFocus?.dispose();
  }
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

  // Existing records from backend for the selected date
  List<AttendanceRecord> _existingRecords = [];

  // Proposed Sessions (Inside Advanced)
  List<Map<String, TimeOfDay?>> _sessions = [];
  final List<_SessionControllers> _sessionControllers = [];

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
    for (final c in _sessionControllers) {
      c.dispose();
    }
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
          _existingRecords = validRecords;

          if (validRecords.isNotEmpty) {
            _sessions = validRecords.map((r) {
              TimeOfDay? inTime;
              TimeOfDay? outTime;
              if (r.timeIn != null) {
                inTime = TimeOfDay.fromDateTime(DateTime.parse(r.timeIn!));
              }
              if (r.timeOut != null) {
                outTime = TimeOfDay.fromDateTime(DateTime.parse(r.timeOut!));
              }
              return {'in': inTime, 'out': outTime};
            }).toList();

            _originalSessions = validRecords.map((r) {
              String tIn = '';
              String tOut = '';
              if (r.timeIn != null) {
                tIn = DateFormat('HH:mm').format(DateTime.parse(r.timeIn!));
              }
              if (r.timeOut != null) {
                tOut = DateFormat('HH:mm').format(DateTime.parse(r.timeOut!));
              }
              return {'time_in': tIn, 'time_out': tOut};
            }).toList();
          } else {
            _sessions = [];
            _originalSessions = [];
          }
          _syncSessionControllers();
        });
      }
    } catch (e) {
      debugPrint("Error fetching existing records for correction: $e");
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  void _syncSessionControllers() {
    while (_sessionControllers.length < _sessions.length) {
      final idx = _sessionControllers.length;
      final inT = _sessions[idx]['in'];
      final outT = _sessions[idx]['out'];

      int? inH = inT != null ? (inT.hourOfPeriod == 0 ? 12 : inT.hourOfPeriod) : null;
      int? inM = inT?.minute;
      bool inPm = inT != null ? inT.period == DayPeriod.pm : false;

      int? outH = outT != null ? (outT.hourOfPeriod == 0 ? 12 : outT.hourOfPeriod) : null;
      int? outM = outT?.minute;
      bool outPm = outT != null ? outT.period == DayPeriod.pm : true;

      final inHCtrl = TextEditingController(text: inH != null ? inH.toString().padLeft(2, '0') : '');
      final inMCtrl = TextEditingController(text: inM != null ? inM.toString().padLeft(2, '0') : '');
      final inHFocus = FocusNode();
      final inMFocus = FocusNode();

      final outHCtrl = TextEditingController(text: outH != null ? outH.toString().padLeft(2, '0') : '');
      final outMCtrl = TextEditingController(text: outM != null ? outM.toString().padLeft(2, '0') : '');
      final outHFocus = FocusNode();
      final outMFocus = FocusNode();

      _sessionControllers.add(_SessionControllers(
        inHourController: inHCtrl,
        inMinuteController: inMCtrl,
        inHourFocus: inHFocus,
        inMinuteFocus: inMFocus,
        inIsPm: inPm,
        outHourController: outHCtrl,
        outMinuteController: outMCtrl,
        outHourFocus: outHFocus,
        outMinuteFocus: outMFocus,
        outIsPm: outPm,
      ));
    }

    while (_sessionControllers.length > _sessions.length) {
      _sessionControllers.removeLast().dispose();
    }

    for (int i = 0; i < _sessions.length; i++) {
      final inT = _sessions[i]['in'];
      final outT = _sessions[i]['out'];
      final ctrl = _sessionControllers[i];

      final capturedIdx = i;
      ctrl.attachListeners(
        onInHourSubmitted: () => _handleHourSubmitted(capturedIdx, true),
        onInMinuteSubmitted: () => _handleMinuteSubmitted(capturedIdx, true),
        onOutHourSubmitted: () => _handleHourSubmitted(capturedIdx, false),
        onOutMinuteSubmitted: () => _handleMinuteSubmitted(capturedIdx, false),
      );

      if (inT != null) {
        final h = inT.hourOfPeriod == 0 ? 12 : inT.hourOfPeriod;
        final hStr = h.toString().padLeft(2, '0');
        final mStr = inT.minute.toString().padLeft(2, '0');
        if (!ctrl.inHourFocus.hasFocus && ctrl.inHourController.text != hStr) {
          ctrl.inHourController.text = hStr;
        }
        if (!ctrl.inMinuteFocus.hasFocus && ctrl.inMinuteController.text != mStr) {
          ctrl.inMinuteController.text = mStr;
        }
        ctrl.inIsPm = inT.period == DayPeriod.pm;
      } else {
        if (!ctrl.inHourFocus.hasFocus && ctrl.inHourController.text.isNotEmpty) {
          ctrl.inHourController.text = '';
        }
        if (!ctrl.inMinuteFocus.hasFocus && ctrl.inMinuteController.text.isNotEmpty) {
          ctrl.inMinuteController.text = '';
        }
      }

      if (outT != null) {
        final h = outT.hourOfPeriod == 0 ? 12 : outT.hourOfPeriod;
        final hStr = h.toString().padLeft(2, '0');
        final mStr = outT.minute.toString().padLeft(2, '0');
        if (!ctrl.outHourFocus.hasFocus && ctrl.outHourController.text != hStr) {
          ctrl.outHourController.text = hStr;
        }
        if (!ctrl.outMinuteFocus.hasFocus && ctrl.outMinuteController.text != mStr) {
          ctrl.outMinuteController.text = mStr;
        }
        ctrl.outIsPm = outT.period == DayPeriod.pm;
      } else {
        if (!ctrl.outHourFocus.hasFocus && ctrl.outHourController.text.isNotEmpty) {
          ctrl.outHourController.text = '';
        }
        if (!ctrl.outMinuteFocus.hasFocus && ctrl.outMinuteController.text.isNotEmpty) {
          ctrl.outMinuteController.text = '';
        }
      }
    }
  }

  TimeOfDay? _timeFromSlotInputs({
    required String hourStr,
    required String minuteStr,
    required bool isPm,
  }) {
    final h = int.tryParse(hourStr.trim());
    if (h == null || h < 1 || h > 12) return null;
    final m = int.tryParse(minuteStr.trim()) ?? 0;
    final validMin = (m < 0 || m > 59) ? 0 : m;
    final hour24 = (h % 12) + (isPm ? 12 : 0);
    return TimeOfDay(hour: hour24, minute: validMin);
  }

  void _updateSessionFromSlots(int idx, bool isTimeIn) {
    if (idx >= _sessions.length || idx >= _sessionControllers.length) return;
    final ctrl = _sessionControllers[idx];
    final hourStr = isTimeIn ? ctrl.inHourController.text : ctrl.outHourController.text;
    final minStr = isTimeIn ? ctrl.inMinuteController.text : ctrl.outMinuteController.text;
    final isPm = isTimeIn ? ctrl.inIsPm : ctrl.outIsPm;

    final newTime = _timeFromSlotInputs(
      hourStr: hourStr,
      minuteStr: minStr,
      isPm: isPm,
    );

    setState(() {
      if (isTimeIn) {
        _sessions[idx]['in'] = newTime;
      } else {
        _sessions[idx]['out'] = newTime;
      }
    });
  }

  void _formatHourField(TextEditingController ctrl) {
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return;
    final val = int.tryParse(raw);
    if (val != null) {
      if (val == 0 || val > 12) {
        ctrl.text = '12';
      } else {
        ctrl.text = val.toString().padLeft(2, '0');
      }
    }
  }

  void _formatMinuteField(TextEditingController ctrl) {
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return;
    final val = int.tryParse(raw);
    if (val != null) {
      if (val < 0) {
        ctrl.text = '00';
      } else if (val > 59) {
        ctrl.text = '59';
      } else {
        ctrl.text = val.toString().padLeft(2, '0');
      }
    }
  }

  void _handleHourChanged(int idx, bool isTimeIn, String val) {
    if (idx >= _sessionControllers.length || idx >= _sessions.length) return;
    final ctrlGroup = _sessionControllers[idx];
    final hourCtrl = isTimeIn ? ctrlGroup.inHourController : ctrlGroup.outHourController;
    final minFocus = isTimeIn ? ctrlGroup.inMinuteFocus : ctrlGroup.outMinuteFocus;

    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean != val) {
      hourCtrl.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }

    final parsed = int.tryParse(clean);
    if (parsed != null) {
      if (clean.length == 1 && parsed >= 2 && parsed <= 9) {
        final formatted = parsed.toString().padLeft(2, '0');
        hourCtrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        minFocus.requestFocus();
      } else if (clean.length >= 2) {
        int clamped = parsed;
        if (clamped == 0) clamped = 12;
        if (clamped > 12) clamped = 12;
        final formatted = clamped.toString().padLeft(2, '0');
        hourCtrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        minFocus.requestFocus();
      }
    }

    _updateSessionFromSlots(idx, isTimeIn);
  }

  void _handleMinuteChanged(int idx, bool isTimeIn, String val) {
    if (idx >= _sessionControllers.length || idx >= _sessions.length) return;
    final ctrlGroup = _sessionControllers[idx];
    final minCtrl = isTimeIn ? ctrlGroup.inMinuteController : ctrlGroup.outMinuteController;
    final minFocus = isTimeIn ? ctrlGroup.inMinuteFocus : ctrlGroup.outMinuteFocus;

    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean != val) {
      minCtrl.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }

    final parsed = int.tryParse(clean);
    if (parsed != null && clean.length >= 2) {
      int clamped = parsed;
      if (clamped > 59) clamped = 59;
      final formatted = clamped.toString().padLeft(2, '0');
      minCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      minFocus.unfocus();
    }

    _updateSessionFromSlots(idx, isTimeIn);
  }

  void _handleHourSubmitted(int idx, bool isTimeIn) {
    if (idx >= _sessionControllers.length) return;
    final ctrl = isTimeIn
        ? _sessionControllers[idx].inHourController
        : _sessionControllers[idx].outHourController;
    _formatHourField(ctrl);
    _updateSessionFromSlots(idx, isTimeIn);
  }

  void _handleMinuteSubmitted(int idx, bool isTimeIn) {
    if (idx >= _sessionControllers.length) return;
    final ctrl = isTimeIn
        ? _sessionControllers[idx].inMinuteController
        : _sessionControllers[idx].outMinuteController;
    _formatMinuteField(ctrl);
    _updateSessionFromSlots(idx, isTimeIn);
  }

  void _handlePeriodToggled(int idx, bool isTimeIn, bool newIsPm) {
    if (idx >= _sessionControllers.length || idx >= _sessions.length) return;
    setState(() {
      if (isTimeIn) {
        _sessionControllers[idx].inIsPm = newIsPm;
      } else {
        _sessionControllers[idx].outIsPm = newIsPm;
      }
      _updateSessionFromSlots(idx, isTimeIn);
    });
  }

  Future<void> _pickTime(bool isTimeIn, {required int sessionIndex}) async {
    if (sessionIndex >= _sessions.length) return;
    final initial = isTimeIn ? _sessions[sessionIndex]['in'] : _sessions[sessionIndex]['out'];

    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme(
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: const Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSurface: isDark ? Colors.white : const Color(0xFF1E293B),
              secondary: const Color(0xFF818CF8),
              onSecondary: Colors.white,
              error: const Color(0xFFEF4444),
              onError: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isTimeIn) {
          _sessions[sessionIndex]['in'] = picked;
        } else {
          _sessions[sessionIndex]['out'] = picked;
        }
        _syncSessionControllers();
      });
    }
  }

  double _calculateTotalProposedHours() {
    double total = 0;
    for (final s in _sessions) {
      final inT = s['in'];
      final outT = s['out'];
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
      final inT = s['in'];
      final outT = s['out'];

      return {
        'id': 'sess-$idx',
        'time_in': inT != null
            ? '${inT.hour.toString().padLeft(2, '0')}:${inT.minute.toString().padLeft(2, '0')}'
            : '',
        'time_out': outT != null
            ? '${outT.hour.toString().padLeft(2, '0')}:${outT.minute.toString().padLeft(2, '0')}'
            : '',
        'punch_type': 'regular',
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
        return {'in': inT, 'out': outT};
      }).toList();
      _syncSessionControllers();
    });
  }

  void _handleAutoFillMissingOut() {
    setState(() {
      if (_existingRecords.isNotEmpty) {
        for (final r in _existingRecords) {
          if (r.timeIn != null && (r.timeOut == null || r.timeOut!.isEmpty)) {
            final inDt = DateTime.parse(r.timeIn!);
            final outDt = inDt.add(const Duration(hours: 9));
            _sessions = [
              {
                'in': TimeOfDay.fromDateTime(inDt),
                'out': TimeOfDay.fromDateTime(outDt),
              }
            ];
            _syncSessionControllers();
            context.showToast(
              "Auto-filled missing clock out with standard 9-hour shift",
              isSuccess: true,
            );
            return;
          }
        }
      }

      _sessions = [
        {'in': const TimeOfDay(hour: 9, minute: 0), 'out': const TimeOfDay(hour: 18, minute: 0)}
      ];
      _syncSessionControllers();
      context.showToast(
        "Auto-filled shift hours (09:00 AM - 06:00 PM)",
        isSuccess: true,
      );
    });
  }

  void _handleResetCorrectionToOriginal() {
    setState(() {
      if (_existingRecords.isNotEmpty) {
        _sessions = _existingRecords.map((r) {
          TimeOfDay? inT;
          TimeOfDay? outT;
          if (r.timeIn != null) inT = TimeOfDay.fromDateTime(DateTime.parse(r.timeIn!));
          if (r.timeOut != null) outT = TimeOfDay.fromDateTime(DateTime.parse(r.timeOut!));
          return {'in': inT, 'out': outT};
        }).toList();
      } else {
        _sessions = [];
      }
      _syncSessionControllers();
      context.showToast(
        "Reset to original logged biometric punches",
        isSuccess: true,
      );
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
            _buildConfirmRow('Date', DateFormat('EEEE, MMM dd, yyyy').format(_requestDate), isDark),
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

    // Proposed sessions: only populated if user customized in Advanced
    final validSessions = _sessions.where((s) => s['in'] != null && s['out'] != null).toList();
    final correctionData = {
      'sessions': validSessions.map((s) => {
            'time_in':
                '${s['in']!.hour.toString().padLeft(2, '0')}:${s['in']!.minute.toString().padLeft(2, '0')}:00',
            'time_out':
                '${s['out']!.hour.toString().padLeft(2, '0')}:${s['out']!.minute.toString().padLeft(2, '0')}:00',
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
                              DateFormat('EEEE, MMMM dd, yyyy').format(_requestDate),
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
                      DateFormat('yyyy-MM-dd').format(_requestDate),
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
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
      padding: const EdgeInsets.all(6),
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
          _buildCategoryOptionItem(
            type: CorrectionType.missedPunch,
            title: 'Missed Punch',
            subtitle: 'Forgot to clock in or clock out',
            icon: Icons.timer_off_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 4),
          _buildCategoryOptionItem(
            type: CorrectionType.missedDay,
            title: 'Missed Day',
            subtitle: 'Full day attendance missing or off-site',
            icon: Icons.event_busy_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 4),
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
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

  /// Advanced Settings Collapsible Accordion
  /// Holds Custom Punch Timeline, Session Editors, Auto-Fill, and Existing Records.
  Widget _buildAdvancedSettingsAccordion(bool isDark, double totalProposedHours) {
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accordion Header Toggle
          InkWell(
            onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Advanced',
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
                      'Not Set (Optional)',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
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

          // Collapsible Advanced Body
          if (_showAdvancedSettings) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Bar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleAutoFillMissingOut,
                          icon: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF6366F1)),
                          label: Text(
                            'Auto-fill 9h Shift',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(color: Color(0xFF6366F1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_existingRecords.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleResetCorrectionToOriginal,
                            icon: const Icon(Icons.restore_rounded, size: 14, color: Color(0xFF64748B)),
                            label: Text(
                              'Reset Punches',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Interactive Visual 24-Hour Timeline
                  VisualCorrectionTimeline(
                    originalSessions: _originalSessions,
                    proposedSessions: _getProposedSessionsForTimeline(),
                    isDark: isDark,
                    editable: true,
                    onSessionsChange: _handleTimelineSessionsChanged,
                    onAutoFillMissingOut: _handleAutoFillMissingOut,
                    onResetToOriginal: _handleResetCorrectionToOriginal,
                  ),

                  const SizedBox(height: 14),

                  // Session Timings Editor
                  _buildProposedSessionsEditor(isDark, totalProposedHours),

                  const SizedBox(height: 14),

                  // Day's Logged Activity
                  _buildExistingActivityCard(isDark),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProposedSessionsEditor(bool isDark, double totalHours) {
    if (_sessionControllers.length != _sessions.length ||
        _sessionControllers.any((c) => c._inIsPm == null || c._inHourController == null)) {
      for (final c in _sessionControllers) {
        c.dispose();
      }
      _sessionControllers.clear();
      _syncSessionControllers();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('CUSTOM WORK TIMINGS'),
            if (totalHours > 0)
              Text(
                '${totalHours.toStringAsFixed(1)} hrs total',
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No custom sessions added. Standard attendance will apply.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

        ..._sessions.asMap().entries.map((entry) {
          final idx = entry.key;
          if (idx >= _sessionControllers.length) return const SizedBox.shrink();
          final ctrlGroup = _sessionControllers[idx];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTimingRow(
              sessionLabel: 'Session #${idx + 1}',
              ctrlGroup: ctrlGroup,
              sessionIndex: idx,
              onPickIn: () => _pickTime(true, sessionIndex: idx),
              onPickOut: () => _pickTime(false, sessionIndex: idx),
              onRemove: () {
                setState(() {
                  _sessions.removeAt(idx);
                  _syncSessionControllers();
                });
              },
              isDark: isDark,
            ),
          );
        }),

        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            setState(() {
              _sessions.add({
                'in': const TimeOfDay(hour: 9, minute: 0),
                'out': const TimeOfDay(hour: 18, minute: 0),
              });
              _syncSessionControllers();
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              ),
              color: const Color(0xFF6366F1).withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, size: 15, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  'Add Session Timing',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimingRow({
    required String sessionLabel,
    required _SessionControllers ctrlGroup,
    required int sessionIndex,
    VoidCallback? onPickIn,
    VoidCallback? onPickOut,
    VoidCallback? onRemove,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sessionLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideLayout = constraints.maxWidth >= 460;

              final inEditor = _buildTimeSlotEditor(
                typeLabel: 'IN',
                icon: Icons.login_rounded,
                iconColor: const Color(0xFF10B981),
                hourController: ctrlGroup.inHourController,
                minuteController: ctrlGroup.inMinuteController,
                hourFocus: ctrlGroup.inHourFocus,
                minuteFocus: ctrlGroup.inMinuteFocus,
                isPm: ctrlGroup.inIsPm,
                onPeriodChanged: (val) => _handlePeriodToggled(sessionIndex, true, val),
                onHourChanged: (val) => _handleHourChanged(sessionIndex, true, val),
                onMinuteChanged: (val) => _handleMinuteChanged(sessionIndex, true, val),
                onHourSubmitted: () => _handleHourSubmitted(sessionIndex, true),
                onMinuteSubmitted: () => _handleMinuteSubmitted(sessionIndex, true),
                isDark: isDark,
                onPickTime: onPickIn,
              );

              final outEditor = _buildTimeSlotEditor(
                typeLabel: 'OUT',
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFEF4444),
                hourController: ctrlGroup.outHourController,
                minuteController: ctrlGroup.outMinuteController,
                hourFocus: ctrlGroup.outHourFocus,
                minuteFocus: ctrlGroup.outMinuteFocus,
                isPm: ctrlGroup.outIsPm,
                onPeriodChanged: (val) => _handlePeriodToggled(sessionIndex, false, val),
                onHourChanged: (val) => _handleHourChanged(sessionIndex, false, val),
                onMinuteChanged: (val) => _handleMinuteChanged(sessionIndex, false, val),
                onHourSubmitted: () => _handleHourSubmitted(sessionIndex, false),
                onMinuteSubmitted: () => _handleMinuteSubmitted(sessionIndex, false),
                isDark: isDark,
                onPickTime: onPickOut,
              );

              if (isWideLayout) {
                return Row(
                  children: [
                    Expanded(child: inEditor),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
                    ),
                    Expanded(child: outEditor),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    inEditor,
                    const SizedBox(height: 6),
                    outEditor,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotEditor({
    required String typeLabel,
    required IconData icon,
    required Color iconColor,
    required TextEditingController hourController,
    required TextEditingController minuteController,
    required FocusNode hourFocus,
    required FocusNode minuteFocus,
    required bool isPm,
    required ValueChanged<bool> onPeriodChanged,
    required ValueChanged<String> onHourChanged,
    required ValueChanged<String> onMinuteChanged,
    required VoidCallback onHourSubmitted,
    required VoidCallback onMinuteSubmitted,
    required bool isDark,
    VoidCallback? onPickTime,
  }) {
    final hasFocus = hourFocus.hasFocus || minuteFocus.hasFocus;
    final borderColor = hasFocus
        ? const Color(0xFF6366F1)
        : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: hasFocus ? 1.5 : 1.0),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              typeLabel,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 6),
            // Hour
            SizedBox(
              width: 30,
              height: 26,
              child: TextField(
                controller: hourController,
                focusNode: hourFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                maxLength: 2,
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                  hintText: 'HH',
                  hintStyle: GoogleFonts.robotoMono(
                    fontSize: 10.5,
                    color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                  ),
                ),
                onChanged: onHourChanged,
                onSubmitted: (_) => onHourSubmitted(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                ':',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ),
            // Minute
            SizedBox(
              width: 30,
              height: 26,
              child: TextField(
                controller: minuteController,
                focusNode: minuteFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                maxLength: 2,
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                  hintText: 'MM',
                  hintStyle: GoogleFonts.robotoMono(
                    fontSize: 10.5,
                    color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                  ),
                ),
                onChanged: onMinuteChanged,
                onSubmitted: (_) => onMinuteSubmitted(),
              ),
            ),
            const SizedBox(width: 5),
            // AM / PM Segmented Toggle
            Container(
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onPeriodChanged(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: !isPm ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'AM',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: !isPm
                              ? Colors.white
                              : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onPeriodChanged(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isPm ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'PM',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isPm
                              ? Colors.white
                              : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onPickTime != null) ...[
              const SizedBox(width: 3),
              InkWell(
                onTap: onPickTime,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingActivityCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader("DAY'S LOGGED BIOMETRIC ACTIVITY"),
              const Spacer(),
              if (_isLoadingRecords)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_existingRecords.isEmpty)
            Text(
              'No biometric punches or attendance records found on this day.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            )
          else
            ..._existingRecords.map((r) {
              String tIn = '--:--';
              String tOut = '--:--';
              if (r.timeIn != null) {
                tIn = DateFormat('hh:mm a').format(DateTime.parse(r.timeIn!));
              }
              if (r.timeOut != null) {
                tOut = DateFormat('hh:mm a').format(DateTime.parse(r.timeOut!));
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'IN: $tIn',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10.5,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'OUT: $tOut',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10.5,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
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
