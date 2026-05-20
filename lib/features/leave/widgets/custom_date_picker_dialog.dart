import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CustomDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<CustomDatePickerDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primaryColor = const Color(0xFF5B60F6);

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 340, // Constrain width for all modes
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.chevron_left, color: textColor),
                      onPressed: () => setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                      }),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.chevron_right, color: textColor),
                      onPressed: () => setState(() {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                      }),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Running CalendarContainer
            TableCalendar(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              headerVisible: false,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              rowHeight: 40, // More compact rows
              
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                weekendStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
              ),
              
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: GoogleFonts.poppins(color: textColor, fontSize: 13),
                weekendTextStyle: GoogleFonts.poppins(color: textColor, fontSize: 13),
                todayDecoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                selectedDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedDay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text("Select", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
