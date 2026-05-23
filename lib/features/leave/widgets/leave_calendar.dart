import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/leave_request_model.dart';

class LeaveCalendar extends StatefulWidget {
  final List<dynamic> holidays;
  final List<dynamic> leaves;
  final DateTime focusedDay;
  final Function(DateTime) onMonthChanged;
  final DateTime? rangeStart; // Added
  final DateTime? rangeEnd;   // Added

  const LeaveCalendar({
    super.key,
    required this.holidays,
    required this.leaves,
    required this.focusedDay,
    required this.onMonthChanged,
    this.rangeStart,
    this.rangeEnd,
  });

  @override
  State<LeaveCalendar> createState() => _LeaveCalendarState();
}

class _LeaveCalendarState extends State<LeaveCalendar> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;
  }

  @override
  void didUpdateWidget(covariant LeaveCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedDay != oldWidget.focusedDay) {
       setState(() => _focusedDay = widget.focusedDay);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final holiday = widget.holidays.where((h) {
      final dt = DateTime.parse(h.date);
      return isSameDay(dt, day);
    }).toList();
    
    // Can also add leaves here if needed to show on calendar
    final leave = widget.leaves.where((l) {
        if (l is! LeaveRequest) return false;
        final start = l.startDate;
        final end = l.endDate;
        return day.isAfter(start.subtract(const Duration(days: 1))) && day.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    return [...holiday, ...leave];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.transparent : Colors.grey[200]!;

    return Container(
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Custom Header
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                  });
                   widget.onMonthChanged(_focusedDay);
                },
              ),
               TextButton(
                onPressed: () {
                  setState(() => _focusedDay = DateTime.now());
                  widget.onMonthChanged(_focusedDay);
                },
                child: Text("Today", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF5B60F6))),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                  });
                  widget.onMonthChanged(_focusedDay);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            headerVisible: false, // Using custom header
            daysOfWeekHeight: 40, // Ensure enough height for headers
            startingDayOfWeek: StartingDayOfWeek.sunday,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              weekendStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            
            // Event Loader
            eventLoader: _getEventsForDay,
            
            rangeStartDay: widget.rangeStart,
            rangeEndDay: widget.rangeEnd,
            rangeSelectionMode: RangeSelectionMode.enforced,

            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: GoogleFonts.poppins(fontSize: 14, color: textColor),
              weekendTextStyle: GoogleFonts.poppins(fontSize: 14, color: textColor),
              todayDecoration: const BoxDecoration(
                color: Colors.transparent, 
                shape: BoxShape.circle,
              ),
              todayTextStyle: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF5B60F6), fontWeight: FontWeight.bold),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF5B60F6),
                shape: BoxShape.circle,
              ),
              // Range Styles
              rangeStartDecoration: BoxDecoration(
                color: const Color(0xFF5B60F6), // Start circle
                shape: BoxShape.circle,
              ),
              rangeEndDecoration: BoxDecoration(
                color: const Color(0xFF5B60F6), // End circle
                shape: BoxShape.circle,
              ),
              rangeHighlightColor: const Color(0xFF5B60F6).withOpacity(0.2), // The trace between
              
              markerSize: 0, 
            ),
            
            // Custom Builders for Events
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                
                // Priority: Holiday > Leave
                // Check if there is a holiday
                final holiday = events.firstWhere((e) => e is! Map, orElse: () => null); // Holiday is Object, Leave is Map
                
                // Using a date check for styling specific events from the image if needed (e.g. Republic Day)
                // For valid holiday objects:
                if (holiday != null) {
                  return Positioned(
                    bottom: 5,
                    left: 0, 
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), 
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }

                
                return null;
              },
            ),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              widget.onMonthChanged(_focusedDay);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
        ],
      ),
    );
  }
}
