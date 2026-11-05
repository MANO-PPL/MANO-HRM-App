import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/attendance/core/attendance_record.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/policy_engine/core/shift_model.dart';
import 'package:flutter_application/features/holidays/core/holiday_model.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';

/// Helper model summarizing today's attendance sessions dynamically
class TodaySessionSummary {
  final DateTime? firstIn;
  final DateTime? lastOut;
  final Duration totalDuration;
  final bool hasActiveSession;
  final String status;
  final bool isLate;

  const TodaySessionSummary({
    this.firstIn,
    this.lastOut,
    required this.totalDuration,
    required this.hasActiveSession,
    required this.status,
    required this.isLate,
  });

  factory TodaySessionSummary.fromRecords(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return const TodaySessionSummary(
        firstIn: null,
        lastOut: null,
        totalDuration: Duration.zero,
        hasActiveSession: false,
        status: 'No Session Today',
        isLate: false,
      );
    }

    DateTime? earliestIn;
    DateTime? latestOut;
    Duration duration = Duration.zero;
    bool hasActive = false;
    bool isLate = false;

    for (final r in records) {
      if (r.lateMinutes > 0 || r.status.toUpperCase() == 'LATE') {
        isLate = true;
      }
      if (r.timeIn != null) {
        final parsedIn = DateTime.tryParse(r.timeIn!)?.toLocal();
        if (parsedIn != null) {
          if (earliestIn == null || parsedIn.isBefore(earliestIn)) {
            earliestIn = parsedIn;
          }
          if (r.timeOut != null) {
            final parsedOut = DateTime.tryParse(r.timeOut!)?.toLocal();
            if (parsedOut != null) {
              if (latestOut == null || parsedOut.isAfter(latestOut)) {
                latestOut = parsedOut;
              }
              if (parsedOut.isAfter(parsedIn)) {
                duration += parsedOut.difference(parsedIn);
              }
            }
          } else {
            hasActive = true;
            duration += DateTime.now().difference(parsedIn);
          }
        }
      }
    }

    String statusLabel;
    if (hasActive) {
      statusLabel = isLate ? 'Late Active' : 'Active Session';
    } else if (latestOut != null) {
      statusLabel = isLate ? 'LATE' : 'PRESENT';
    } else {
      statusLabel = records.first.status;
    }

    return TodaySessionSummary(
      firstIn: earliestIn,
      lastOut: hasActive ? null : latestOut,
      totalDuration: duration,
      hasActiveSession: hasActive,
      status: statusLabel,
      isLate: isLate,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Format Helpers
// ─────────────────────────────────────────────────────────────────────────────

String formatTime12h(dynamic timeVal) {
  if (timeVal == null) return '--:--';
  final str = timeVal.toString().trim();
  if (str.isEmpty || str == '--:--' || str == '-') return '--:--';

  try {
    if (str.contains('T') || str.contains(' ')) {
      final dt = DateTime.tryParse(str)?.toLocal();
      if (dt != null) {
        return DateFormat('hh:mm a').format(dt);
      }
    }
    final parts = str.split(':');
    if (parts.length >= 2) {
      int hour = int.parse(parts[0]);
      final minute = parts[1].padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
    }
    return str;
  } catch (_) {
    return str;
  }
}

String formatDuration(Duration duration) {
  if (duration.inMinutes <= 0) return '0h';
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

List<String> getActiveWorkingDays(Shift? shift) {
  if (shift == null) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  final weekOff = shift.policyRules['week_off_policy'];
  if (weekOff is List) {
    final offDays = <String>{};
    for (final rule in weekOff) {
      if (rule is Map) {
        final type = rule['type']?.toString().toLowerCase();
        final freq = rule['frequency']?.toString().toLowerCase();
        final day = rule['day']?.toString();
        if (type == 'full' && (freq == 'every' || freq == null) && day != null) {
          offDays.add(day);
        }
      }
    }
    if (offDays.isNotEmpty) {
      const allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return allDays.where((d) => !offDays.contains(d)).toList();
    }
  }
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Blue Half-Rectangular Header (Web Dashboard Format)
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeWelcomeBanner extends StatelessWidget {
  final String userName;
  final String? department;
  final String? designation;
  final Shift? shift;
  final List<AttendanceRecord>? records;

  const EmployeeWelcomeBanner({
    super.key,
    required this.userName,
    this.department,
    this.designation,
    this.shift,
    this.records,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : (hour < 18 ? 'Good Afternoon' : 'Good Evening');
    final formattedDate = DateFormat('d MMMM yyyy').format(DateTime.now());

    final nameParts = userName.trim().split(' ');
    final firstName = nameParts.first.isNotEmpty ? nameParts.first : 'User';

    // Access attendance provider if shift or records not explicitly supplied
    AttendanceProvider? attProvider;
    try {
      attProvider = context.watch<AttendanceProvider>();
    } catch (_) {}

    final activeShift = shift ?? attProvider?.shiftPolicy;
    final activeRecords = records ?? attProvider?.records ?? [];

    final summary = TodaySessionSummary.fromRecords(activeRecords);
    final activeDays = getActiveWorkingDays(activeShift);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isStacked = constraints.maxWidth < 540;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF090A1A), const Color(0xFF05060A)]
                  : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF4F46E5)).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Subtle ambient glow background decorations
              Positioned(
                top: -50,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth < 400 ? 12 : 16,
                  10,
                  constraints.maxWidth < 400 ? 12 : 16,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Greeting & Date
                    Text(
                      '$greeting, $firstName!',
                      style: GoogleFonts.poppins(
                        fontSize: constraints.maxWidth < 400 ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          formattedDate,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.2,
                          ),
                        ),
                        if (designation != null || department != null) ...[
                          Text(
                            '  •  ',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              [designation, department].whereType<String>().join(' • '),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quick Action Buttons (Uniform height 30, horizontal single row)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildActionButton(
                            label: 'My Attendance',
                            icon: Icons.access_time_rounded,
                            isSolid: true,
                            onTap: () => navigateTo(PageType.myAttendance),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            label: 'Holiday List',
                            icon: Icons.calendar_today_outlined,
                            isSolid: false,
                            onTap: () => navigateToHolidaysAndLeave(tab: 'holidays'),
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            label: 'Apply Leave',
                            icon: Icons.coffee_outlined,
                            isSolid: false,
                            onTap: () => navigateToHolidaysAndLeave(tab: 'leaves'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Side-by-side or Stacked Glass Cards
                    if (isStacked)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTodayStatusCard(context, summary),
                          const SizedBox(height: 6),
                          _buildShiftDetailsCard(context, activeShift, activeDays, weekdays),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTodayStatusCard(context, summary)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildShiftDetailsCard(context, activeShift, activeDays, weekdays)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isSolid,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 30,
      child: Material(
        color: isSolid ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSolid ? Colors.white : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13.5,
                  color: isSolid ? const Color(0xFF4F46E5) : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: isSolid ? FontWeight.w700 : FontWeight.w600,
                    color: isSolid ? const Color(0xFF4F46E5) : Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatusCard(BuildContext context, TodaySessionSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Icon + Category Tag + Status Pill (Height: 20)
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.access_time_rounded, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "TODAY'S STATUS",
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.8,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                _buildStatusPill(summary.status),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // 2. Headline Title (Height: 18)
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                summary.hasActiveSession
                    ? 'Current Active Session'
                    : (summary.firstIn != null ? 'Daily Attendance Logged' : 'No Active Session Today'),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 3. Metrics Panel (Height: 44, 3 uniform columns with dividers)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'CHECK IN',
                    value: summary.firstIn != null ? DateFormat('hh:mm a').format(summary.firstIn!) : '--:--',
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
                Expanded(
                  child: _buildMetricItem(
                    label: 'CHECK OUT',
                    value: summary.lastOut != null ? DateFormat('hh:mm a').format(summary.lastOut!) : '--:--',
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
                Expanded(
                  child: _buildMetricItem(
                    label: 'DURATION',
                    value: formatDuration(summary.totalDuration),
                    valueColor: const Color(0xFF6EE7B7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDetailsCard(
    BuildContext context,
    Shift? shift,
    List<String> activeDays,
    List<String> allWeekdays,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Icon + Category Tag + Shift Badge (Height: 20)
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.calendar_month_outlined, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SHIFT DETAILS',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.8,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    shift != null ? 'Active' : 'Regular',
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // 2. Headline Title (Height: 18)
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                shift?.name.isNotEmpty == true ? shift!.name : 'Regular General Shift',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 3. Metrics Panel (Height: 44, 3 uniform columns with dividers)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'START TIME',
                    value: formatTime12h(shift?.startTime ?? '09:00'),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
                Expanded(
                  child: _buildMetricItem(
                    label: 'END TIME',
                    value: formatTime12h(shift?.endTime ?? '18:00'),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 11,
                        child: Text(
                          'WORK DAYS',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 0.4,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: allWeekdays.map((day) {
                              final isActive = activeDays.contains(day);
                              final label = day.length > 3 ? day.substring(0, 3) : day;
                              return Container(
                                margin: const EdgeInsets.only(right: 2.5),
                                padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.28)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.white.withValues(alpha: 0.4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.45),
                                    height: 1.1,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 11,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 0.4,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 16,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.firaCode(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color border;
    Color text;

    switch (status) {
      case 'Active':
      case 'Active Session':
        bg = const Color(0xFF10B981).withValues(alpha: 0.25);
        border = const Color(0xFF10B981).withValues(alpha: 0.6);
        text = const Color(0xFF6EE7B7);
        break;
      case 'Late Active':
        bg = const Color(0xFFF97316).withValues(alpha: 0.25);
        border = const Color(0xFFF97316).withValues(alpha: 0.6);
        text = const Color(0xFFFDBA74);
        break;
      case 'PRESENT':
      case 'LATE':
      case 'OVERTIME':
      case 'COMPLETED':
        bg = Colors.white.withValues(alpha: 0.22);
        border = Colors.white.withValues(alpha: 0.4);
        text = Colors.white;
        break;
      default:
        bg = Colors.white.withValues(alpha: 0.1);
        border = Colors.white.withValues(alpha: 0.2);
        text = Colors.white.withValues(alpha: 0.85);
    }

    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: text,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Missed Time Out Warning Banner
// ─────────────────────────────────────────────────────────────────────────────

class MissedPunchBanner extends StatelessWidget {
  final DateTime missedDate;
  final VoidCallback onFixNow;

  const MissedPunchBanner({
    super.key,
    required this.missedDate,
    required this.onFixNow,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM yyyy').format(missedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFFB45309).withValues(alpha: 0.5) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missed Time Out',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'You forgot to time out on $dateLabel. Please submit a correction request to fix your hours.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFFDE68A).withValues(alpha: 0.85) : const Color(0xFFB45309),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onFixNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Fix Now',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Employee Stat Card (Web 4-card style)
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String badgeText;
  final bool isCompact;

  const EmployeeStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.badgeText = 'This Month',
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 7 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 5 : 7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isCompact ? 7 : 9),
                ),
                child: Icon(icon, color: iconColor, size: isCompact ? 14 : 18),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 8.0 : 8.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 2 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 17 : 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Employee Recent Activity Card (Web style)
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeRecentActivityCard extends StatelessWidget {
  final List<AttendanceRecord> records;

  const EmployeeRecentActivityCard({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = TodaySessionSummary.fromRecords(records);

    final rows = [
      {
        'label': 'Checked In',
        'value': summary.firstIn != null ? DateFormat('hh:mm a').format(summary.firstIn!) : '--:--',
        'badge': summary.isLate ? 'LATE' : (summary.firstIn != null ? 'PRESENT' : null),
        'badgeColor': summary.isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
      },
      {
        'label': 'Checked Out',
        'value': summary.lastOut != null ? DateFormat('hh:mm a').format(summary.lastOut!) : '--:--',
        'badge': summary.lastOut != null ? 'COMPLETED' : null,
        'badgeColor': const Color(0xFF6366F1),
      },
      {
        'label': 'Total Work Hours',
        'value': formatDuration(summary.totalDuration),
        'badge': null,
        'badgeColor': Colors.transparent,
      },
      {
        'label': 'Status',
        'value': summary.status,
        'badge': null,
        'badgeColor': Colors.transparent,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((row) {
            final badge = row['badge'] as String?;
            final badgeColor = row['badgeColor'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF21262D).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D).withValues(alpha: 0.4) : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    row['value'] as String,
                    style: GoogleFonts.firaCode(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.poppins(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Employee Upcoming Holidays Card (Web style)
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeUpcomingHolidaysCard extends StatelessWidget {
  final List<Holiday> holidays;

  const EmployeeUpcomingHolidaysCard({
    super.key,
    required this.holidays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    'Upcoming Holidays',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => navigateToHolidaysAndLeave(tab: 'holidays'),
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right, size: 13, color: Color(0xFF6366F1)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (holidays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No Upcoming Holidays',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Enjoy your work!',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            ...holidays.take(3).map((holiday) {
              DateTime? date;
              try {
                date = DateTime.parse(holiday.date);
              } catch (_) {}

              final monthStr = date != null ? DateFormat('MMM').format(date).toUpperCase() : 'HOL';
              final dayStr = date != null ? DateFormat('dd').format(date) : '--';
              final dayOfWeek = date != null ? DateFormat('EEEE').format(date) : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D).withValues(alpha: 0.4) : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthStr,
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6366F1),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            dayStr,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holiday.name,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            [dayOfWeek, holiday.type].where((s) => s.isNotEmpty).join(' • '),
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Unified EmployeeHeaderStack (Used by Admin, HR & Employee Dashboards)
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeHeaderStack extends StatelessWidget {
  final String userName;
  final String? department;
  final String? designation;
  final Shift? shift;
  final List<AttendanceRecord>? records;

  const EmployeeHeaderStack({
    super.key,
    required this.userName,
    this.department,
    this.designation,
    this.shift,
    this.records,
  });

  @override
  Widget build(BuildContext context) {
    return EmployeeWelcomeBanner(
      userName: userName,
      department: department,
      designation: designation,
      shift: shift,
      records: records,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backward Compatibility Stubs
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceStatusCard extends StatelessWidget {
  const AttendanceStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class EmployeeQuickActions extends StatelessWidget {
  const EmployeeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class EmployeeInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  final Widget child;

  const EmployeeInfoCard({
    super.key,
    required this.title,
    required this.icon,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
