import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../models/dar_models.dart';
import '../../services/dar_service.dart';
import '../../../holidays/services/holiday_service.dart';
import '../../../attendance/services/attendance_service.dart';
import '../../widgets/day_snapshot_card.dart';
import '../../widgets/multi_day_timeline_widget.dart';
import '../../widgets/mini_calendar_widget.dart';
import '../../widgets/event_meeting_dialog.dart';
import '../../widgets/task_edit_dialog.dart';

class TabletDailyActivityView extends StatefulWidget {
  final bool isLandscape;

  const TabletDailyActivityView({super.key, required this.isLandscape});

  @override
  State<TabletDailyActivityView> createState() =>
      _TabletDailyActivityViewState();
}

class _TabletDailyActivityViewState extends State<TabletDailyActivityView> {
  late DarService _darService;
  late HolidayService _holidayService;
  late AttendanceService _attendanceService;

  // Calendar-driven date selection
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _rangeEndDate; // null = single day; non-null = end of range
  String _focusedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Legacy field kept for MultiDayTimelineWidget — driven by calendar selection
  late String _startDate;

  bool _isLoading = false;
  List<DarItem> _tasks = [];
  Map<String, Map<String, dynamic>> _attendanceData = {};
  Map<String, String> _holidays = {};
  List<String> _categories = [
    'General',
    'Development',
    'Design',
    'Meeting',
    'Testing',
  ];

  String _getErrorMessage(dynamic e) {
    if (e is DioException) {
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data.containsKey('message')) {
            return data['message'].toString();
          }
          if (data.containsKey('error')) {
            return data['error'].toString();
          }
        }
        return data.toString();
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  @override
  void initState() {
    super.initState();

    // Default timeline: today at center of a 7-day window
    final d = DateTime.now().subtract(const Duration(days: 3));
    _startDate = DateFormat('yyyy-MM-dd').format(d);

    final auth = Provider.of<AuthService>(context, listen: false);
    _darService = DarService(auth.dio);
    _holidayService = HolidayService(auth.dio);
    _attendanceService = AttendanceService(auth.dio);

    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch categories
      final cats = await _darService.getCategories();

      // 2. Fetch timeline tasks & attendance & holidays
      await _fetchTimelineData();

      setState(() {
        if (cats.isNotEmpty) _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        context.showToast("Error loading initial data: ${_getErrorMessage(e)}", isError: true);
    }
  }

  Future<void> _fetchTimelineData() async {
    // Determine effective date range from calendar selection
    final effectiveStart = _selectedDate;
    final effectiveEnd = _rangeEndDate ?? _selectedDate;

    // Add buffer days around the range for the visual timeline
    final startDt = DateTime.parse(
      effectiveStart,
    ).subtract(const Duration(days: 1));
    final endDt = DateTime.parse(effectiveEnd).add(const Duration(days: 1));
    final dateFrom = DateFormat('yyyy-MM-dd').format(startDt);
    final dateTo = DateFormat('yyyy-MM-dd').format(endDt);

    // Keep _startDate aligned so timeline starts at the selected date
    _startDate = effectiveStart;

    final acts = await _darService.getActivities(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final evts = await _darService.getEvents(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final hols = await _holidayService.getHolidays();
    final atts = await _attendanceService.getMyRecords(
      fromDate: dateFrom,
      toDate: dateTo,
    );

    final List<DarItem> merged = [];
    merged.addAll(acts.map((a) => DarItem.fromActivity(a)));
    merged.addAll(evts.map((e) => DarItem.fromEvent(e)));

    final Map<String, String> mappedHols = {};
    for (var h in hols) {
      mappedHols[h.date] = h.name;
    }

    final Map<String, Map<String, dynamic>> mappedAtts = {};
    for (var a in atts) {
      if (a.timeIn != null) {
        final parsedTimeIn = DateTime.parse(a.timeIn!);
        final key = DateFormat('yyyy-MM-dd').format(parsedTimeIn);
        final String tIn = DateFormat('HH:mm').format(parsedTimeIn);
        String? tOut;
        if (a.timeOut != null) {
          tOut = DateFormat('HH:mm').format(DateTime.parse(a.timeOut!));
        }
        mappedAtts[key] = {'hasTimedIn': true, 'timeIn': tIn, 'timeOut': tOut};
      }
    }

    setState(() {
      _tasks = merged;
      _holidays = mappedHols;
      _attendanceData = mappedAtts;
    });
  }

  /// Called by MiniCalendarWidget whenever the user taps a date or completes a range.
  void _onCalendarRange(String startDate, String? endDate) {
    setState(() {
      _selectedDate = startDate;
      _rangeEndDate = endDate;
      _focusedDate = startDate;
      // Align timeline start to the selected date
      _startDate = startDate;
    });
    _fetchTimelineData();
  }

  void _focusDay(String date) {
    setState(() {
      _focusedDate = date;
      if (_rangeEndDate == null) {
        _selectedDate = date;
        _startDate = date;
      }
    });
  }

  void _changeDateRange(int offsetDays) {
    setState(() {
      final current = DateTime.parse(_startDate);
      _startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(current.add(Duration(days: offsetDays)));
      _selectedDate = _startDate;
      _rangeEndDate = null;
    });
    _fetchTimelineData();
  }

  bool get _isPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime.parse(_selectedDate);
    return sel.isBefore(today);
  }

  String? _getInitialTimeIn() {
    final todayPunch = _attendanceData[_selectedDate];
    if (todayPunch != null && todayPunch['hasTimedIn'] == true) {
      return todayPunch['timeIn'];
    }
    return null;
  }

  void _openTaskEditor({DarItem? initialItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return TaskEditDialog(
          initialData: initialItem,
          initialDate: _selectedDate,
          categories: _categories,
          initialTimeIn: _getInitialTimeIn(),
          onSave: (payload) => _handleSaveTask(payload, initialItem),
          onDelete: initialItem == null
              ? null
              : () => _handleDeleteTask(initialItem),
          isBottomSheet: true,
        );
      },
    );
  }

  Future<void> _handleSaveTask(
    Map<String, dynamic> payload,
    DarItem? initialItem,
  ) async {
    if (_isPastDate) {
      _showPastDateJustification((reason) async {
        setState(() => _isLoading = true);
        try {
          // Original list
          final original = _tasks
              .where((t) => t.date == _selectedDate && t.type == DarItemType.task)
              .map(
                (t) => {
                  'title': t.title,
                  'description': t.description,
                  'start_time': t.startTime,
                  'end_time': t.endTime,
                  'activity_type': t.category,
                  'status': t.status,
                },
              )
              .toList();

          // Proposed list after applying change
          final List<Map<String, dynamic>> proposed = [];
          bool appliedEdit = false;
          
          for (var item in _tasks.where((t) => t.date == _selectedDate && t.type == DarItemType.task)) {
            if (initialItem != null && item.id == initialItem.id) {
              proposed.add({
                'title': payload['title'],
                'description': payload['description'],
                'start_time': payload['start_time'],
                'end_time': payload['end_time'],
                'activity_type': payload['activity_type'],
                'status': 'COMPLETED',
              });
              appliedEdit = true;
            } else {
              proposed.add({
                'title': item.title,
                'description': item.description,
                'start_time': item.startTime,
                'end_time': item.endTime,
                'activity_type': item.category,
                'status': item.status,
              });
            }
          }

          if (!appliedEdit) {
            proposed.add({
              'title': payload['title'],
              'description': payload['description'],
              'start_time': payload['start_time'],
              'end_time': payload['end_time'],
              'activity_type': payload['activity_type'],
              'status': 'COMPLETED',
            });
          }

          await _darService.submitRequest(
            date: _selectedDate,
            reason: reason,
            originalData: original,
            proposedData: proposed,
          );

          if (mounted)
            context.showToast(
              "Past date correction request submitted successfully!",
              isSuccess: true,
            );
          _fetchTimelineData();
        } catch (e) {
          if (mounted)
            context.showToast("Failed to submit request: ${_getErrorMessage(e)}", isError: true);
        } finally {
          setState(() => _isLoading = false);
        }
      });
    } else {
      // Today or future date: direct API call
      setState(() => _isLoading = true);
      try {
        final isEdit = initialItem != null;
        final id = isEdit
            ? int.tryParse(initialItem.id.replaceFirst('act-', ''))
            : null;

        final act = DarActivity(
          activityId: id,
          title: payload['title'],
          description: payload['description'],
          startTime: payload['start_time'],
          endTime: payload['end_time'],
          activityDate: payload['activity_date'],
          activityType: payload['activity_type'],
          status: 'COMPLETED',
        );

        await _darService.saveActivity(act);
        if (mounted)
          context.showToast(
            isEdit
                ? "Task updated successfully!"
                : "Task created successfully!",
            isSuccess: true,
          );
        _fetchTimelineData();
      } catch (e) {
        if (mounted)
          context.showToast("Failed to save task: ${_getErrorMessage(e)}", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDeleteTask(DarItem task) async {
    if (_isPastDate) {
      _showPastDateJustification((reason) async {
        setState(() => _isLoading = true);
        try {
          // Original list
          final original = _tasks
              .where((t) => t.date == _selectedDate && t.type == DarItemType.task)
              .map(
                (t) => {
                  'title': t.title,
                  'description': t.description,
                  'start_time': t.startTime,
                  'end_time': t.endTime,
                  'activity_type': t.category,
                  'status': t.status,
                },
              )
              .toList();

          // Proposed list after removing task
          final proposed = _tasks
              .where((t) => t.date == _selectedDate && t.type == DarItemType.task && t.id != task.id)
              .map(
                (t) => {
                  'title': t.title,
                  'description': t.description,
                  'start_time': t.startTime,
                  'end_time': t.endTime,
                  'activity_type': t.category,
                  'status': t.status,
                },
              )
              .toList();

          await _darService.submitRequest(
            date: _selectedDate,
            reason: reason,
            originalData: original,
            proposedData: proposed,
          );

          if (mounted)
            context.showToast(
              "Past date deletion request submitted successfully!",
              isSuccess: true,
            );
          _fetchTimelineData();
        } catch (e) {
          if (mounted)
            context.showToast(
              "Failed to submit deletion request: ${_getErrorMessage(e)}",
              isError: true,
            );
        } finally {
          setState(() => _isLoading = false);
        }
      });
    } else {
      setState(() => _isLoading = true);
      try {
        final id = int.tryParse(task.id.replaceFirst('act-', ''));
        if (id != null) {
          await _darService.deleteActivity(id);
          if (mounted)
            context.showToast("Task deleted successfully!", isSuccess: true);
          _fetchTimelineData();
        }
      } catch (e) {
        if (mounted)
          context.showToast("Failed to delete task: ${_getErrorMessage(e)}", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPastDateJustification(Function(String reason) onSubmit) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Justification Reason Required",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You are modifying activities on a past date. Please enter a justification for your corrections.",
                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: "Enter justification reason here...",
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  if (mounted)
                    context.showToast(
                      "Please provide a reason.",
                      isWarning: true,
                    );
                  return;
                }
                Navigator.of(ctx).pop();
                onSubmit(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: Text(
                "Submit",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Create or edit a Meeting / Event
  void _openEventMeetingDialog({
    DarItem? initialItem,
    String type = 'MEETING',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return EventMeetingDialog(
          initialData: initialItem,
          initialDate: _selectedDate,
          type: type,
          isBottomSheet: true,
          onSave: (payload) async {
            setState(() => _isLoading = true);
            try {
              final isEdit = initialItem != null;
              final id = isEdit
                  ? int.tryParse(initialItem.id.replaceFirst('evt-', ''))
                  : null;

              final evt = DarEvent(
                eventId: id,
                title: payload['title'],
                description: payload['description'],
                startTime: payload['start_time'],
                endTime: payload['end_time'],
                eventDate: payload['event_date'],
                type: payload['type'],
                location: payload['location'],
              );

              await _darService.saveEvent(evt);
              if (mounted)
                context.showToast(
                  isEdit
                      ? "Event updated successfully"
                      : "Event created successfully",
                  isSuccess: true,
                );
              _fetchTimelineData();
            } catch (e) {
              if (mounted)
                context.showToast("Failed to save event: ${_getErrorMessage(e)}", isError: true);
            } finally {
              setState(() => _isLoading = false);
            }
          },
          onDelete: initialItem == null
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    final id = int.tryParse(
                      initialItem.id.replaceFirst('evt-', ''),
                    );
                    if (id != null) {
                      await _darService.deleteEvent(id);
                      if (mounted)
                        context.showToast(
                          "Event deleted successfully",
                          isSuccess: true,
                        );
                      _fetchTimelineData();
                    }
                  } catch (e) {
                    if (mounted)
                      context.showToast(
                        "Failed to delete event: ${_getErrorMessage(e)}",
                        isError: true,
                      );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
        );
      },
    );
  }

  void _onEditItemFromTimeline(DarItem item) {
    _focusDay(item.date);
    if (item.type == DarItemType.task) {
      _openTaskEditor(initialItem: item);
    } else {
      // Open dialog
      _openEventMeetingDialog(
        initialItem: item,
        type: item.type == DarItemType.event ? 'EVENT' : 'MEETING',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Area: Timeline Header + Timeline Container (70% width)
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row header with prev/next navigation


                  // Horizontal Stack Timeline scrollable area
                  Expanded(
                    child: _isLoading && _tasks.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : Builder(
                            builder: (context) {
                              final daysToShow = _rangeEndDate != null
                                  ? DateTime.parse(_rangeEndDate!)
                                            .difference(
                                              DateTime.parse(_selectedDate),
                                            )
                                            .inDays +
                                        1
                                  : 1;
                              return MultiDayTimelineWidget(
                                tasks: _tasks,
                                startDate: _startDate,
                                daysToShow: daysToShow.clamp(1, 14),
                                holidays: _holidays,
                                attendanceData: _attendanceData,
                                onEditTask: _onEditItemFromTimeline,
                                onDateTap: _focusDay,
                                propStartHour: 0,
                                propEndHour: 24,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          ),

          // Right Area: MiniCalendar + Task Creation Panel (30% width)
          SizedBox(
            width: 270,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MiniCalendarWidget(
                        selectedDate: _selectedDate,
                        rangeEndDate: _rangeEndDate,
                        onRangeSelect: _onCalendarRange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  DailyActivityDaySnapshotCard(
                    date: _focusedDate,
                    items: _tasks,
                    attendance: _attendanceData[_focusedDate],
                    holidayName: _holidays[_focusedDate],
                    isDark: isDark,
                    emptyMessage:
                        'Tap a date on the timeline to inspect its tasks and punches.',
                  ),
                  const SizedBox(height: 10),

                  // Selection Date / Range Banner
                  Text(
                    _rangeEndDate != null
                        ? '${DateFormat('EEE, d MMM').format(DateTime.parse(_selectedDate))} → ${DateFormat('EEE, d MMM yyyy').format(DateTime.parse(_rangeEndDate!))}'
                        : DateFormat(
                            'EEEE, MMM d, yyyy',
                          ).format(DateTime.parse(_selectedDate)),
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 10),

                  // Quick Action Buttons (Add Meeting / Event)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openTaskEditor(),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: Text(
                          "Log Task",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: const Color(0xFF10B981).withValues(alpha: 0.5),
                          ),
                          foregroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openEventMeetingDialog(type: 'EVENT'),
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: Text(
                          "Schedule Meeting",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                          ),
                          foregroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
