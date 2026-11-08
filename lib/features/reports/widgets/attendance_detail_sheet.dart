import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/features/reports/widgets/image_lightbox_dialog.dart';

class AttendanceDetailSheet extends StatelessWidget {
  final AttendanceMatrixEmployee employee;
  final AttendanceMatrixDayRecord record;

  const AttendanceDetailSheet({
    super.key,
    required this.employee,
    required this.record,
  });

  static void show(
    BuildContext context, {
    required AttendanceMatrixEmployee employee,
    required AttendanceMatrixDayRecord record,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AttendanceDetailSheet(
        employee: employee,
        record: record,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(record.date);
    } catch (_) {}

    final dateFormatted = parsedDate != null
        ? DateFormat('EEEE, d MMMM yyyy').format(parsedDate)
        : record.date;

    final statusColor = record.statusColor;
    final statusBgColor = statusColor.withValues(alpha: isDark ? 0.2 : 0.12);

    final rawStatus = record.status.toUpperCase();
    final displayStatus = (rawStatus.contains('LATE') && rawStatus.contains('OVERTIME'))
        ? 'Overtime'
        : record.status;

    final inImage = record.timeInImage ?? record.verificationImage;
    final outImage = record.timeOutImage;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 20, right: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Attendance Details",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey[500]),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile & Date Section
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            employee.name.isNotEmpty
                                ? employee.name
                                    .split(' ')
                                    .map((n) => n.isNotEmpty ? n[0] : '')
                                    .join('')
                                    .toUpperCase()
                                    .padRight(1, 'E')
                                    .substring(0, 1)
                                : 'E',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    employee.name,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${employee.designation} • ${employee.department} • ${employee.employeeId}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Date & Status Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 5),
                            Text(
                              dateFormatted,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          displayStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Punch Timings Grid (Clock In & Clock Out Cards)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clock In Card
                      Expanded(
                        child: _buildPunchCard(
                          context,
                          title: "CLOCK IN",
                          time: record.clockIn ?? '--:--',
                          location: record.inLocation,
                          image: inImage,
                          isDark: isDark,
                          accentColor: const Color(0xFF10B981),
                          icon: Icons.login_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Clock Out Card
                      Expanded(
                        child: _buildPunchCard(
                          context,
                          title: "CLOCK OUT",
                          time: record.clockOut ?? '--:--',
                          location: record.outLocation,
                          image: outImage,
                          isDark: isDark,
                          accentColor: const Color(0xFFEF4444),
                          icon: Icons.logout_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metrics Summary Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricCol(
                          "Work Hours",
                          record.workDuration ?? "0.0 hrs",
                          Icons.timer_outlined,
                          const Color(0xFF6366F1),
                          isDark,
                        ),
                        Container(width: 1, height: 32, color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        _buildMetricCol(
                          "Overtime",
                          "${record.overtimeHours.toStringAsFixed(1)} hrs",
                          Icons.more_time_rounded,
                          const Color(0xFF8B5CF6),
                          isDark,
                        ),
                        Container(width: 1, height: 32, color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        _buildMetricCol(
                          "Late",
                          record.isLate ? "${record.lateMinutes} mins" : "None",
                          Icons.warning_amber_rounded,
                          record.isLate ? const Color(0xFFF97316) : Colors.grey,
                          isDark,
                        ),
                      ],
                    ),
                  ),

                  // Reason / Notes Card (if present)
                  if (record.reason != null && record.reason!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Text(
                                "Remarks / Reason",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.reason!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchCard(
    BuildContext context, {
    required String title,
    required String time,
    required String? location,
    required String? image,
    required bool isDark,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: accentColor),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location != null && location.isNotEmpty ? location : "Office premises",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Selfie photo preview if available
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ImageLightboxDialog.show(context, imageUrl: image, title: "$title Photo"),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      image,
                      height: 70,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    Container(
                      height: 70,
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.25),
                      child: const Center(
                        child: Icon(Icons.zoom_in, color: Colors.white, size: 20),
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
  }

  Widget _buildMetricCol(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
