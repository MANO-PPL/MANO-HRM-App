import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Punch item model used internally within the timeline.
class TimelinePunch {
  final String id;
  String time; // 'HH:mm'
  String type; // 'in', 'out', 'normal'
  int pairIdx;

  TimelinePunch({
    required this.id,
    required this.time,
    required this.type,
    this.pairIdx = 0,
  });

  int get minutes {
    final parts = time.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return (h % 24) * 60 + (m % 60);
    }
    return 0;
  }
}

/// Rich 24-Hour Visual Attendance Correction Timeline
/// Directly mirroring `VisualCorrectionTimeline.jsx` from Attendance-Web.
class VisualCorrectionTimeline extends StatefulWidget {
  final List<Map<String, dynamic>> originalSessions;
  final List<Map<String, dynamic>> proposedSessions;
  final bool isDark;
  final bool editable;
  final Map<String, dynamic>? shift;
  final ValueChanged<List<Map<String, dynamic>>>? onSessionsChange;
  final VoidCallback? onAutoFillMissingOut;
  final VoidCallback? onResetToOriginal;

  const VisualCorrectionTimeline({
    super.key,
    required this.originalSessions,
    required this.proposedSessions,
    required this.isDark,
    this.editable = false,
    this.shift,
    this.onSessionsChange,
    this.onAutoFillMissingOut,
    this.onResetToOriginal,
  });

  @override
  State<VisualCorrectionTimeline> createState() => _VisualCorrectionTimelineState();
}

class _VisualCorrectionTimelineState extends State<VisualCorrectionTimeline> {
  final ScrollController _scrollController = ScrollController();
  List<TimelinePunch> _punches = [];
  final Set<String> _selectedPunchIds = {};
  String? _hoveredPunchId;
  String _selectedAddType = 'punch'; // 'punch' (Clock IN/OUT) or 'normal' (Checkpoint)
  Offset? _lastSessionBarTapOffset;

  // Timeline track dimensions
  static const double _timelineWidth = 860.0;
  static const int _totalMinutes = 24 * 60; // 1440

  @override
  void initState() {
    super.initState();
    _initPunchesFromProposed();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScrollToActivity());
  }

  @override
  void didUpdateWidget(covariant VisualCorrectionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.proposedSessions != oldWidget.proposedSessions) {
      _initPunchesFromProposed();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initPunchesFromProposed() {
    final list = <TimelinePunch>[];
    for (int i = 0; i < widget.proposedSessions.length; i++) {
      final s = widget.proposedSessions[i];
      final inT = _cleanTimeStr(s['time_in']?.toString() ?? s['in']?.toString());
      final outT = _cleanTimeStr(s['time_out']?.toString() ?? s['out']?.toString());
      final isNormal = (s['punch_type']?.toString().toLowerCase() == 'normal');

      if (inT.isNotEmpty) {
        list.add(TimelinePunch(
          id: s['inPunchId']?.toString() ?? 'punch-$i-in',
          time: inT,
          type: isNormal ? 'normal' : 'in',
        ));
      }
      if (outT.isNotEmpty) {
        list.add(TimelinePunch(
          id: s['outPunchId']?.toString() ?? 'punch-$i-out',
          time: outT,
          type: 'out',
        ));
      }
    }
    _punches = _resequencePunches(list);
  }

  String _cleanTimeStr(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final clean = raw.trim();
    final timePart = clean.contains(' ')
        ? clean.split(' ')[1]
        : (clean.contains('T') ? clean.split('T')[1] : clean);
    final parts = timePart.split(':');
    if (parts.length >= 2) {
      final h = (int.tryParse(parts[0]) ?? 0).toString().padLeft(2, '0');
      final m = (int.tryParse(parts[1]) ?? 0).toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '';
  }

  int? _parseMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return (h % 24) * 60 + (m % 60);
    }
    return null;
  }

  String _minutesToTimeStr(int mins) {
    final clamped = max(0, min(1439, mins));
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  List<TimelinePunch> _resequencePunches(List<TimelinePunch> punchList) {
    final sorted = List<TimelinePunch>.from(punchList)
      ..sort((a, b) => a.minutes.compareTo(b.minutes));

    int boundaryIndex = 0;
    int currentPairIdx = 0;

    return sorted.map((p) {
      if (p.type == 'normal') {
        return TimelinePunch(
          id: p.id,
          time: p.time,
          type: 'normal',
          pairIdx: currentPairIdx,
        );
      }
      final assignedType = boundaryIndex % 2 == 0 ? 'in' : 'out';
      final assignedPair = boundaryIndex ~/ 2;
      if (assignedType == 'in') currentPairIdx = assignedPair;
      boundaryIndex++;

      return TimelinePunch(
        id: p.id,
        time: p.time,
        type: assignedType,
        pairIdx: assignedPair,
      );
    }).toList();
  }

  void _emitChanges() {
    _punches = _resequencePunches(_punches);
    final paired = <Map<String, dynamic>>[];
    String? curIn;
    String? curInPunchId;

    for (final p in _punches) {
      if (p.type == 'normal') {
        paired.add({
          'id': 'normal-${paired.length}',
          'time_in': p.time,
          'time_out': '',
          'punch_type': 'normal',
          'inPunchId': p.id,
        });
      } else if (p.type == 'in') {
        if (curIn != null) {
          paired.add({
            'id': 'sess-${paired.length}',
            'time_in': curIn,
            'time_out': '',
            'punch_type': 'regular',
            'inPunchId': curInPunchId,
          });
        }
        curIn = p.time;
        curInPunchId = p.id;
      } else if (p.type == 'out') {
        if (curIn != null) {
          paired.add({
            'id': 'sess-${paired.length}',
            'time_in': curIn,
            'time_out': p.time,
            'punch_type': 'regular',
            'inPunchId': curInPunchId,
            'outPunchId': p.id,
          });
          curIn = null;
          curInPunchId = null;
        } else {
          paired.add({
            'id': 'sess-${paired.length}',
            'time_in': '',
            'time_out': p.time,
            'punch_type': 'regular',
            'outPunchId': p.id,
          });
        }
      }
    }
    if (curIn != null) {
      paired.add({
        'id': 'sess-${paired.length}',
        'time_in': curIn,
        'time_out': '',
        'punch_type': 'regular',
        'inPunchId': curInPunchId,
      });
    }

    if (widget.onSessionsChange != null) {
      widget.onSessionsChange!(paired);
    }
  }

  void _autoScrollToActivity() {
    if (!_scrollController.hasClients) return;
    int focusMins = 540; // 09:00 AM default
    if (widget.shift != null && widget.shift!['start_time'] != null) {
      final sm = _parseMinutes(widget.shift!['start_time'].toString());
      if (sm != null) focusMins = sm;
    } else if (_punches.isNotEmpty) {
      focusMins = _punches.first.minutes;
    }

    final targetX = (focusMins / _totalMinutes) * _timelineWidth - 160;
    _scrollController.animateTo(
      max(0.0, targetX),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  bool _isInsideSession(int mins) {
    final boundary = _punches.where((p) => p.type != 'normal').toList();
    for (int i = 0; i < boundary.length - 1; i += 2) {
      final inP = boundary[i];
      final outP = boundary[i + 1];
      if (inP.type == 'in' && outP.type == 'out') {
        if (mins >= inP.minutes && mins <= outP.minutes) {
          return true;
        }
      }
    }
    return false;
  }

  void _addPunchAtMinutes(int rawMins, {String? type}) {
    if (!widget.editable) return;
    // Snap to 5 minutes
    final snappedMins = (rawMins / 5).round() * 5;
    final timeStr = _minutesToTimeStr(snappedMins);

    // If clicked inside an existing timein & timeout interval, automatically add a checkpoint!
    final bool inside = _isInsideSession(snappedMins);
    final punchType = type ?? (inside ? 'normal' : _selectedAddType);

    final newPunch = TimelinePunch(
      id: 'punch-new-${DateTime.now().millisecondsSinceEpoch}',
      time: timeStr,
      type: punchType == 'normal' ? 'normal' : 'in', // 'normal' remains checkpoint, 'in' is resequenced
    );

    setState(() {
      _punches.add(newPunch);
      _emitChanges();
    });
  }

  void _updatePunchTime(String id, String newTime) {
    if (!widget.editable) return;
    setState(() {
      final punch = _punches.firstWhere((p) => p.id == id);
      punch.time = newTime;
      _emitChanges();
    });
  }

  void _togglePunchType(String id) {
    if (!widget.editable) return;
    setState(() {
      final punch = _punches.firstWhere((p) => p.id == id);
      if (punch.type == 'in') {
        punch.type = 'out';
      } else if (punch.type == 'out') {
        punch.type = 'normal';
      } else {
        punch.type = 'in';
      }
      _emitChanges();
    });
  }

  void _stepPunchTime(String id, int deltaMinutes) {
    if (!widget.editable) return;
    setState(() {
      final punch = _punches.firstWhere((p) => p.id == id);
      final nextMins = max(0, min(1435, punch.minutes + deltaMinutes));
      punch.time = _minutesToTimeStr(nextMins);
      _emitChanges();
    });
  }

  Future<void> _pickPunchTime(String id) async {
    if (!widget.editable) return;
    final punch = _punches.firstWhere((p) => p.id == id);
    final initialTime = TimeOfDay(
      hour: punch.minutes ~/ 60,
      minute: punch.minutes % 60,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        punch.time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _emitChanges();
      });
    }
  }

  void _removePunch(String id) {
    if (!widget.editable) return;
    setState(() {
      _punches.removeWhere((p) => p.id == id);
      _selectedPunchIds.remove(id);
      _emitChanges();
    });
  }

  void _removeSelectedPunches() {
    if (!widget.editable || _selectedPunchIds.isEmpty) return;
    setState(() {
      _punches.removeWhere((p) => _selectedPunchIds.contains(p.id));
      _selectedPunchIds.clear();
      _emitChanges();
    });
  }

  double _calculateTotalHours(List<Map<String, dynamic>> sessions) {
    double total = 0;
    for (final s in sessions) {
      final inT = _parseMinutes(s['time_in']?.toString() ?? s['in']?.toString());
      final outT = _parseMinutes(s['time_out']?.toString() ?? s['out']?.toString());
      if (inT != null && outT != null && outT > inT) {
        total += (outT - inT) / 60.0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalProposedHours = _calculateProposedHoursFromPunches();
    final totalOriginalHours = _calculateTotalHours(widget.originalSessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Title, Badges & Quick Action Helpers
        _buildHeader(totalProposedHours, totalOriginalHours),

        const SizedBox(height: 12),

        // Legend Bar (Shift, Original, Proposed IN/OUT)
        _buildLegend(),

        const SizedBox(height: 14),

        // 24-Hour Continuous Timeline Canvas & Track
        _buildInteractiveTimelineTrack(),

        const SizedBox(height: 14),

        // Punch Breakdown & Direct Management Table
        _buildPunchBreakdownTable(totalProposedHours),
      ],
    );
  }

  double _calculateProposedHoursFromPunches() {
    double total = 0;
    final boundary = _punches.where((p) => p.type != 'normal').toList();
    for (int i = 0; i < boundary.length - 1; i += 2) {
      final inP = boundary[i];
      final outP = boundary[i + 1];
      if (inP.type == 'in' && outP.type == 'out' && outP.minutes > inP.minutes) {
        total += (outP.minutes - inP.minutes) / 60.0;
      }
    }
    return total;
  }

  Widget _buildHeader(double totalProposedHours, double totalOriginalHours) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
          ),
          child: const Icon(
            Icons.timeline_rounded,
            size: 16,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '24-Hour Punch Timeline',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Text(
                widget.editable
                    ? 'Tap on track to add punch, drag/step to adjust'
                    : 'Comparison of biometric punches vs proposed correction',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: widget.isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        if (totalProposedHours > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
            ),
            child: Text(
              '${totalProposedHours.toStringAsFixed(1)} hrs',
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _buildLegendItem(
          color: const Color(0xFF10B981),
          label: 'Clock IN',
          icon: Icons.login_rounded,
        ),
        _buildLegendItem(
          color: const Color(0xFFEF4444),
          label: 'Clock OUT',
          icon: Icons.logout_rounded,
        ),
        _buildLegendItem(
          color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          label: 'Original Biometric',
          isDashed: true,
        ),
        if (widget.shift != null)
          _buildLegendItem(
            color: const Color(0xFF6366F1),
            label: 'Shift (${widget.shift!['start_time']?.toString().substring(0, 5) ?? '09:00'} - ${widget.shift!['end_time']?.toString().substring(0, 5) ?? '18:00'})',
            isBand: true,
          ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    IconData? icon,
    bool isDashed = false,
    bool isBand = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBand)
          Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
          )
        else if (isDashed)
          Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color, width: 1),
            ),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveTimelineTrack() {
    final trackBg = widget.isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.editable) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'CLICK TO ADD:',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                _buildAddModeButton(
                  label: 'Clock IN / OUT',
                  icon: Icons.access_time_rounded,
                  color: const Color(0xFF6366F1),
                  isSelected: _selectedAddType == 'punch',
                  onTap: () => setState(() => _selectedAddType = 'punch'),
                ),
                _buildAddModeButton(
                  label: 'Checkpoint',
                  icon: Icons.location_on_rounded,
                  color: const Color(0xFFF59E0B),
                  isSelected: _selectedAddType == 'normal',
                  onTap: () => setState(() => _selectedAddType = 'normal'),
                ),
                Text(
                  '• Click inside session to add Checkpoint • Double-click to remove',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: _timelineWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hourly Time Scale & Tick Marks Header
                  _buildTimeScaleHeader(),

                  const SizedBox(height: 8),

                  // 2. Primary 24-Hour Track Container
                  GestureDetector(
                    onTapUp: (details) {
                      if (widget.editable) {
                        final localX = details.localPosition.dx.clamp(0.0, _timelineWidth);
                        final mins = (localX / _timelineWidth * _totalMinutes).round();
                        _addPunchAtMinutes(mins);
                      }
                    },
                    child: Container(
                  height: 64,
                  width: _timelineWidth,
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Base track horizontal rail
                      Positioned(
                        top: 28,
                        left: 0,
                        right: 0,
                        height: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // Shift Window Highlight Band
                      if (widget.shift != null) _buildShiftWindowBand(),

                      // Original Biometric Punches Ghost Blocks
                      ..._buildOriginalGhostBlocks(),

                      // Proposed Active Session Duration Blocks
                      ..._buildProposedSessionBars(),

                      // Proposed Punch Markers & Pins (IN, OUT, Normal)
                      ..._buildPunchPins(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Hourly major ticks visual line
              _buildTickLines(),
            ],
          ),
        ),
      ),
    ),
  ],
);
  }

  Widget _buildTimeScaleHeader() {
    // Show labels every 3 hours: 00:00, 03:00, 06:00, 09:00, 12:00, 15:00, 18:00, 21:00, 24:00
    final hours = [0, 3, 6, 9, 12, 15, 18, 21, 24];

    return SizedBox(
      height: 18,
      width: _timelineWidth,
      child: Stack(
        children: hours.map((h) {
          final double leftPos = (h / 24.0) * _timelineWidth;
          final isEdge = h == 24;

          return Positioned(
            left: isEdge ? leftPos - 32 : leftPos - 12,
            top: 0,
            child: Text(
              '${h.toString().padLeft(2, '0')}:00',
              style: GoogleFonts.robotoMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTickLines() {
    return SizedBox(
      height: 8,
      width: _timelineWidth,
      child: Stack(
        children: List.generate(25, (hour) {
          final double leftPos = (hour / 24.0) * _timelineWidth;
          final isMajor = hour % 3 == 0;

          return Positioned(
            left: leftPos,
            top: 0,
            child: Container(
              width: 1,
              height: isMajor ? 8 : 4,
              color: isMajor
                  ? (widget.isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                  : (widget.isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShiftWindowBand() {
    final shiftStart = _parseMinutes(widget.shift!['start_time']?.toString()) ?? 540;
    final shiftEnd = _parseMinutes(widget.shift!['end_time']?.toString()) ?? 1080;
    final left = (shiftStart / _totalMinutes) * _timelineWidth;
    final width = max(10.0, ((shiftEnd - shiftStart) / _totalMinutes) * _timelineWidth);

    return Positioned(
      left: left,
      top: 14,
      width: width,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Shift',
          style: GoogleFonts.poppins(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOriginalGhostBlocks() {
    final widgets = <Widget>[];

    for (final s in widget.originalSessions) {
      final inT = _parseMinutes(s['time_in']?.toString() ?? s['in']?.toString());
      final outT = _parseMinutes(s['time_out']?.toString() ?? s['out']?.toString());

      if (inT != null && outT != null && outT > inT) {
        final left = (inT / _totalMinutes) * _timelineWidth;
        final width = max(6.0, ((outT - inT) / _totalMinutes) * _timelineWidth);

        widgets.add(
          Positioned(
            left: left,
            top: 24,
            width: width,
            height: 14,
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFF94A3B8).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: widget.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  width: 1,
                ),
              ),
            ),
          ),
        );
      } else if (inT != null) {
        final left = (inT / _totalMinutes) * _timelineWidth;
        widgets.add(
          Positioned(
            left: left - 3,
            top: 26,
            width: 6,
            height: 10,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildProposedSessionBars() {
    final widgets = <Widget>[];
    final boundary = _punches.where((p) => p.type != 'normal').toList();

    for (int i = 0; i < boundary.length - 1; i += 2) {
      final inP = boundary[i];
      final outP = boundary[i + 1];

      if (inP.type == 'in' && outP.type == 'out' && outP.minutes > inP.minutes) {
        final left = (inP.minutes / _totalMinutes) * _timelineWidth;
        final width = max(14.0, ((outP.minutes - inP.minutes) / _totalMinutes) * _timelineWidth);
        final durationHours = (outP.minutes - inP.minutes) / 60.0;

        widgets.add(
          Positioned(
            left: left,
            top: 20,
            width: width,
            height: 22,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _lastSessionBarTapOffset = details.localPosition;
              },
              onTap: widget.editable
                  ? () {
                      final localX = _lastSessionBarTapOffset?.dx ?? (width / 2);
                      final clickXOnTimeline = left + localX;
                      final mins = (clickXOnTimeline / _timelineWidth * _totalMinutes).round();
                      _addPunchAtMinutes(mins, type: 'normal');
                    }
                  : null,
              onDoubleTap: widget.editable
                  ? () {
                      _removePunch(inP.id);
                      _removePunch(outP.id);
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: width > 35
                    ? Text(
                        '${durationHours.toStringAsFixed(1)}h',
                        style: GoogleFonts.robotoMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildPunchPins() {
    final widgets = <Widget>[];

    for (int i = 0; i < _punches.length; i++) {
      final p = _punches[i];
      final double leftPos = (p.minutes / _totalMinutes) * _timelineWidth;
      final isSelected = _selectedPunchIds.contains(p.id);
      final isHovered = _hoveredPunchId == p.id;
      final isIn = p.type == 'in';
      final isNormal = p.type == 'normal';

      final pinColor = isNormal
          ? const Color(0xFFF59E0B)
          : (isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444));

        widgets.add(
        Positioned(
          left: leftPos - 14,
          top: 8,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.editable) {
                // Single-click on pin: switch punch type (IN -> OUT -> Checkpoint -> IN)
                _togglePunchType(p.id);
              }
            },
            onDoubleTap: () {
              if (widget.editable) {
                // Double-click on pin: remove punch
                _removePunch(p.id);
              }
            },
            onHorizontalDragUpdate: widget.editable
                ? (details) {
                    final double newLeft = (leftPos + details.delta.dx).clamp(0.0, _timelineWidth);
                    final mins = (newLeft / _timelineWidth * _totalMinutes).round();
                    final snapped = (mins / 5).round() * 5;
                    setState(() {
                      p.time = _minutesToTimeStr(snapped);
                      _emitChanges();
                    });
                  }
                : null,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoveredPunchId = p.id),
              onExit: (_) => setState(() => _hoveredPunchId = null),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating pin badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: pinColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.white : pinColor,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: pinColor.withValues(alpha: isHovered ? 0.6 : 0.35),
                          blurRadius: isHovered ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isNormal ? 'CP' : (isIn ? 'IN' : 'OUT'),
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Pin stem
                  Container(
                    width: 2,
                    height: 12,
                    color: pinColor,
                  ),

                  // Dot on track
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: pinColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),

                  // Time label underneath
                  const SizedBox(height: 2),
                  Text(
                    p.time,
                    style: GoogleFonts.robotoMono(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildAddModeButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (widget.isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? color : (widget.isDark ? Colors.white60 : const Color(0xFF64748B))),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : (widget.isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchBreakdownTable(double totalProposedHours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Toolbar Header
        Row(
          children: [
            Expanded(
              child: Text(
                'PUNCH BREAKDOWN',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: widget.isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.editable) ...[
              if (_selectedPunchIds.isNotEmpty) ...[
                InkWell(
                  onTap: _removeSelectedPunches,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 3),
                        Text(
                          'Del (${_selectedPunchIds.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              InkWell(
                onTap: () {
                  int defaultMins = 540;
                  if (_punches.isNotEmpty) {
                    defaultMins = min(1380, _punches.last.minutes + 60);
                  }
                  _addPunchAtMinutes(defaultMins, type: 'punch');
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        'Add Punch',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  int defaultMins = 720;
                  if (_punches.isNotEmpty) {
                    defaultMins = min(1410, _punches.last.minutes + 30);
                  }
                  _addPunchAtMinutes(defaultMins, type: 'normal');
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_location_alt_rounded, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        'Add Checkpoint',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

          const SizedBox(height: 10),

          // Punch items list
          if (_punches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No correction punches specified. Tap on the timeline to add.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            )
          else
            ..._punches.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final isChecked = _selectedPunchIds.contains(p.id);
              final isIn = p.type == 'in';
              final isNormal = p.type == 'normal';

              final badgeBg = isNormal
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                  : (isIn
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12));

              final badgeColor = isNormal
                  ? const Color(0xFFF59E0B)
                  : (isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444));

              final label = isNormal ? 'Checkpoint' : (isIn ? 'Clock IN' : 'Clock OUT');

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 360;

                  final badgeWidget = Tooltip(
                    message: widget.editable ? 'Tap to switch type (IN / OUT / Checkpoint)' : label,
                    child: InkWell(
                      onTap: widget.editable ? () => _togglePunchType(p.id) : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final Widget timeWidget = widget.editable
                      ? DirectTimeInputField(
                          key: ValueKey('punch-field-${p.id}'),
                          initialTime: p.time,
                          isDark: widget.isDark,
                          onTimeChanged: (newTime) => _updatePunchTime(p.id, newTime),
                          onPickClock: () => _pickPunchTime(p.id),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Text(
                                p.time,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        );                  if (isCompact) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: widget.editable ? () => _removePunch(p.id) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                              : (widget.isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isChecked
                                ? const Color(0xFF6366F1)
                                : (widget.isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Checkbox, #idx, Badge, Delete
                            Row(
                              children: [
                                if (widget.editable) ...[
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: isChecked,
                                      activeColor: const Color(0xFF6366F1),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedPunchIds.add(p.id);
                                          } else {
                                            _selectedPunchIds.remove(p.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '#${idx + 1}',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                badgeWidget,
                                const Spacer(),
                                if (widget.editable)
                                  InkWell(
                                    onTap: () => _removePunch(p.id),
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Bottom row: Time adjustment
                            Row(
                              children: [
                                Text(
                                  'Time:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const Spacer(),
                                if (widget.editable) ...[
                                  InkWell(
                                    onTap: () => _stepPunchTime(p.id, -15),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.remove_circle_outline_rounded,
                                        size: 16,
                                        color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                timeWidget,
                                if (widget.editable) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _stepPunchTime(p.id, 15),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 16,
                                        color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Standard single row layout for >= 360px
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: widget.editable ? () => _removePunch(p.id) : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                            : (widget.isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isChecked
                              ? const Color(0xFF6366F1)
                              : (widget.isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (widget.editable) ...[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFF6366F1),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedPunchIds.add(p.id);
                                    } else {
                                      _selectedPunchIds.remove(p.id);
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '#${idx + 1}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          badgeWidget,
                          const Spacer(),
                          if (widget.editable) ...[
                            InkWell(
                              onTap: () => _stepPunchTime(p.id, -15),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 16,
                                  color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          timeWidget,
                          if (widget.editable) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _stepPunchTime(p.id, 15),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 16,
                                  color: widget.isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _removePunch(p.id),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
        ],
      );
  }
}

/// Direct Editable Time Input Field for Correction Timeline Punches
class DirectTimeInputField extends StatefulWidget {
  final String initialTime;
  final bool isDark;
  final ValueChanged<String> onTimeChanged;
  final VoidCallback onPickClock;

  const DirectTimeInputField({
    super.key,
    required this.initialTime,
    required this.isDark,
    required this.onTimeChanged,
    required this.onPickClock,
  });

  @override
  State<DirectTimeInputField> createState() => _DirectTimeInputFieldState();
}

class _DirectTimeInputFieldState extends State<DirectTimeInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String _lastCommitted = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTime);
    _lastCommitted = widget.initialTime;
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant DirectTimeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTime != oldWidget.initialTime && !_focusNode.hasFocus) {
      _controller.text = widget.initialTime;
      _lastCommitted = widget.initialTime;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final clean = _controller.text.trim();
    if (clean.isEmpty) {
      _controller.text = _lastCommitted;
      return;
    }

    int? h;
    int? m;

    if (clean.contains(':')) {
      final parts = clean.split(':');
      h = int.tryParse(parts[0]);
      m = int.tryParse(parts[1]);
    } else if (clean.length == 3) {
      h = int.tryParse(clean.substring(0, 1));
      m = int.tryParse(clean.substring(1));
    } else if (clean.length == 4) {
      h = int.tryParse(clean.substring(0, 2));
      m = int.tryParse(clean.substring(2));
    } else if (clean.length <= 2) {
      h = int.tryParse(clean);
      m = 0;
    }

    if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
      final formatted = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      _controller.text = formatted;
      if (formatted != _lastCommitted) {
        _lastCommitted = formatted;
        widget.onTimeChanged(formatted);
      }
    } else {
      _controller.text = _lastCommitted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      width: 78,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _focusNode.hasFocus
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
          width: _focusNode.hasFocus ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.onPickClock,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                LengthLimitingTextInputFormatter(5),
              ],
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'HH:mm',
              ),
              onSubmitted: (_) => _commit(),
            ),
          ),
        ],
      ),
    );
  }
}

