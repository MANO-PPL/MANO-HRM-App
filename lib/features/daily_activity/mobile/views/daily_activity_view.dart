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
import '../../widgets/event_meeting_dialog.dart';
import '../../widgets/task_edit_dialog.dart';
import '../../widgets/mini_calendar_widget.dart';
import '../../widgets/multi_day_timeline_widget.dart';

class MobileDailyActivityView extends StatefulWidget {
  const MobileDailyActivityView({super.key});

  @override
  State<MobileDailyActivityView> createState() =>
      _MobileDailyActivityViewState();
}

class _MobileDailyActivityViewState extends State<MobileDailyActivityView> {
  late DarService _darService;
  late HolidayService _holidayService;
  late AttendanceService _attendanceService;

  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _rangeEndDate;
  List<String> _dateStrip = [];

  bool _isLoading = false;
  List<DarItem> _dayItems = []; // Tasks & events for selected day
  Map<String, Map<String, dynamic>> _attendanceData =
      {}; // date -> {timeIn, timeOut, hasTimedIn}
  Map<String, String> _holidays = {}; // date -> holiday_name
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

    _syncDateStrip(_selectedDate);

    final auth = Provider.of<AuthService>(context, listen: false);
    _darService = DarService(auth.dio);
    _holidayService = HolidayService(auth.dio);
    _attendanceService = AttendanceService(auth.dio);

    _fetchInitialData();
  }

  void _syncDateStrip(String startDate, [String? endDate]) {
    final start = DateTime.parse(startDate);
    final end = endDate == null ? start : DateTime.parse(endDate);

    if (endDate == null) {
      _dateStrip = List.generate(15, (i) {
        final date = start.subtract(Duration(days: 7 - i));
        return DateFormat('yyyy-MM-dd').format(date);
      });
      return;
    }

    final days = end.difference(start).inDays + 1;
    _dateStrip = List.generate(days, (i) {
      final date = start.add(Duration(days: i));
      return DateFormat('yyyy-MM-dd').format(date);
    });
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _darService.getCategories();
      if (cats.isNotEmpty) {
        setState(() => _categories = cats);
      }

      await _fetchDayData();
      await _fetchMetadata();
    } catch (e) {
      if (mounted)
        context.showToast("Error loading initial data: ${_getErrorMessage(e)}", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fetch current day activities & events
  Future<void> _fetchDayData() async {
    final effectiveStart = _selectedDate;
    final effectiveEnd = _rangeEndDate ?? _selectedDate;

    final List<DarActivity> acts;
    if (_rangeEndDate == null) {
      acts = await _darService.getActivitiesForDate(effectiveStart);
    } else {
      acts = await _darService.getActivities(
        dateFrom: effectiveStart,
        dateTo: effectiveEnd,
      );
    }
    final evts = await _darService.getEvents(
      dateFrom: effectiveStart,
      dateTo: effectiveEnd,
    );

    final List<DarItem> merged = [];
    merged.addAll(acts.map((a) => DarItem.fromActivity(a)));
    merged.addAll(evts.map((e) => DarItem.fromEvent(e)));

    // Sort chronologically
    merged.sort((a, b) => a.startTime.compareTo(b.startTime));

    setState(() {
      _dayItems = merged;
    });
  }

  // Fetch holidays & attendance records for date strip range to show indicator badges
  Future<void> _fetchMetadata() async {
    if (_dateStrip.isEmpty) return;

    final fromDate = _dateStrip.first;
    final toDate = _dateStrip.last;

    final hols = await _holidayService.getHolidays();
    final atts = await _attendanceService.getMyRecords(
      fromDate: fromDate,
      toDate: toDate,
    );

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
      _holidays = mappedHols;
      _attendanceData = mappedAtts;
    });
  }

  void _onSelectDate(String date) {
    setState(() {
      _selectedDate = date;
      _rangeEndDate = null;
      _syncDateStrip(date);
      _isLoading = true;
    });
    Future.wait([_fetchDayData(), _fetchMetadata()]).then((_) {
      setState(() => _isLoading = false);
    });
  }

  void _onCalendarRange(String startDate, String? endDate) {
    setState(() {
      _selectedDate = startDate;
      _rangeEndDate = endDate;
      _syncDateStrip(startDate, endDate);
      _isLoading = true;
    });
    Future.wait([_fetchDayData(), _fetchMetadata()]).then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  bool get _isPastDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime.parse(_selectedDate);
    return sel.isBefore(today);
  }

  // Handle single task save / update / delete. If past date, requires full-day request.
  Future<void> _handleSaveTask(
    Map<String, dynamic> payload,
    DarItem? initialItem,
  ) async {
    if (_isPastDate) {
      // For past dates, we simulate applying the edit to the full-day task list and send correction request
      _showPastDateJustification((reason) async {
        setState(() => _isLoading = true);
        try {
          // Original list
          final original = _dayItems
              .where((t) => t.type == DarItemType.task)
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
          for (var item in _dayItems.where((t) => t.type == DarItemType.task)) {
            if (initialItem != null && item.id == initialItem.id) {
              // Edit item
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
            // New item
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
          _fetchDayData();
        } catch (e) {
          if (mounted)
            context.showToast("Failed to submit request: ${_getErrorMessage(e)}", isError: true);
        } finally {
          setState(() => _isLoading = false);
        }
      });
    } else {
      // Current / future date - direct API call
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
        _fetchDayData();
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
          final original = _dayItems
              .where((t) => t.type == DarItemType.task)
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
          final proposed = _dayItems
              .where((t) => t.type == DarItemType.task && t.id != task.id)
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
          _fetchDayData();
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
          _fetchDayData();
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

  void _openEventMeetingEditor({
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
                      ? "Event updated successfully!"
                      : "Event scheduled successfully!",
                  isSuccess: true,
                );
              _fetchDayData();
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
                          "Event deleted successfully!",
                          isSuccess: true,
                        );
                      _fetchDayData();
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
          isBottomSheet: true,
        );
      },
    );
  }

  void _showQuickAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Create Entry",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                title: Text(
                  "Log Task",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  "Add a work task for the selected day",
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openTaskEditor();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                title: Text(
                  "Schedule Meeting",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  "Calendar block for workshops, company breaks, etc.",
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openEventMeetingEditor(type: 'EVENT');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRangeCalendarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: isDark
                    ? Border.all(color: const Color(0xFF30363D), width: 1)
                    : null,
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Date Range',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[900],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MiniCalendarWidget(
                      selectedDate: _selectedDate,
                      rangeEndDate: _rangeEndDate,
                      onRangeSelect: (start, end) {
                        _onCalendarRange(start, end);
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _rangeEndDate == null
                                ? null
                                : () {
                                    _onCalendarRange(_selectedDate, null);
                                    setModalState(() {});
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Clear Range',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Done',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onEditItemFromTimeline(DarItem item) {
    if (item.type == DarItemType.task) {
      _openTaskEditor(initialItem: item);
      return;
    }

    _openEventMeetingEditor(
      initialItem: item,
      type: item.type == DarItemType.event ? 'EVENT' : 'MEETING',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayPunch = _attendanceData[_selectedDate];
    final hasTimedIn = todayPunch != null && todayPunch['hasTimedIn'] == true;

    final holidayName = _holidays[_selectedDate];
    final isHoliday = holidayName != null;
    final isPast = DateTime.parse(_selectedDate).isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
    final isAbsent = isPast && !isHoliday && !hasTimedIn;

    final taskCount = _dayItems.where((t) => t.type == DarItemType.task).length;
    final meetingCount = _dayItems
        .where((t) => t.type == DarItemType.meeting)
        .length;
    final eventCount = _dayItems
        .where((t) => t.type == DarItemType.event)
        .length;
    final daysToShow = _rangeEndDate == null
        ? 1
        : DateTime.parse(
                _rangeEndDate!,
              ).difference(DateTime.parse(_selectedDate)).inDays +
              1;
    final timelineHeight = 40.0 + (daysToShow * 78.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Quick add action selector FAB
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddOptions,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rangeEndDate != null
                          ? "${DateFormat('d MMM').format(DateTime.parse(_selectedDate))} - ${DateFormat('d MMM yyyy').format(DateTime.parse(_rangeEndDate!))}"
                          : DateFormat(
                              'MMMM yyyy',
                            ).format(DateTime.parse(_selectedDate)),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _openRangeCalendarPicker,
                  icon: const Icon(
                    Icons.calendar_month,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                  tooltip: 'Select Date Range',
                ),
              ],
            ),
          ),

          if (_rangeEndDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 14,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('d MMM').format(DateTime.parse(_selectedDate))} - ${DateFormat('d MMM yyyy').format(DateTime.parse(_rangeEndDate!))}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _onCalendarRange(_selectedDate, null),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Horizontal swipable Date-strip
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _dateStrip.length,
              itemBuilder: (context, idx) {
                final dateStr = _dateStrip[idx];
                final parsed = DateTime.parse(dateStr);
                final isSelected = dateStr == _selectedDate;
                final isToday =
                    dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

                final dayAtt = _attendanceData[dateStr];
                final dayHols = _holidays[dateStr];
                final isDayHoliday = dayHols != null;
                final isDayPast = parsed.isBefore(
                  DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
                );
                final isDayAbsent =
                    isDayPast &&
                    !isDayHoliday &&
                    (dayAtt == null || dayAtt['hasTimedIn'] != true);

                Color textColor = isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300]! : Colors.grey[700]!);

                Color badgeCol = Colors.transparent;
                if (isDayHoliday) {
                  badgeCol = const Color(0xFF10B981);
                } else if (isDayAbsent) {
                  badgeCol = Colors.redAccent;
                } else if (dayAtt != null && dayAtt['hasTimedIn'] == true) {
                  badgeCol = const Color(0xFF6366F1);
                }

                return GestureDetector(
                  onTap: () => _onSelectDate(dateStr),
                  child: Container(
                    width: 40,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (isToday
                                ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                                : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.4),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat(
                            'E',
                          ).format(parsed).toUpperCase().substring(0, 2),
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white60 : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          parsed.day.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Indicator dot
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: badgeCol,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DailyActivityDaySnapshotCard(
              date: _selectedDate,
              items: _dayItems,
              attendance: _attendanceData[_selectedDate],
              holidayName: _holidays[_selectedDate],
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 8),

          // Main body content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick activity summary
                  SizedBox(
                    height: timelineHeight,
                    child: _isLoading && _dayItems.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : MultiDayTimelineWidget(
                            tasks: _dayItems,
                            startDate: _selectedDate,
                            daysToShow: daysToShow,
                            holidays: _holidays,
                            attendanceData: _attendanceData,
                            onEditTask: _onEditItemFromTimeline,
                            onDateTap: _onSelectDate,
                            propStartHour: 0,
                            propEndHour: 24,
                          ),
                  ),
                  const SizedBox(height: 8),

                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey[400]!,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Loading day summary...",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.checklist,
                                  size: 12,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$taskCount Tasks  •  $meetingCount Meetings  •  $eventCount Events",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    // Special Banners (Holidays, Absent days)
                    if (isHoliday)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.celebration,
                              color: Color(0xFF10B981),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "HOLIDAY",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    holidayName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[200]
                                          : Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isAbsent)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.red.withValues(alpha: 0.12)
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "ABSENT STATUS",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "No work sessions clocked on this date.",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[750],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
