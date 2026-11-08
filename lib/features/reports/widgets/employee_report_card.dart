import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/features/reports/widgets/attendance_detail_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/widgets/pfp_viewer_dialog.dart';

class EmployeeReportCard extends StatefulWidget {
  final AttendanceMatrixEmployee employee;
  final List<String> dates;

  const EmployeeReportCard({
    super.key,
    required this.employee,
    required this.dates,
  });

  @override
  State<EmployeeReportCard> createState() => _EmployeeReportCardState();
}

class _EmployeeReportCardState extends State<EmployeeReportCard> {
  bool _isTimelineExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emp = widget.employee;

    final presentCount = emp.presentCount;
    final absentCount = emp.absentCount;
    final leaveCount = emp.leaveCount;
    final halfDayCount = emp.halfDayCount;
    final lateCount = emp.lateCount;
    final missedCount = emp.missedPunchCount;
    final otHours = emp.overtimeHours;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Name, Designation, Department ─────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    PfpViewerDialog.show(
                      context,
                      imageUrl: emp.avatarUrl,
                      name: emp.name,
                      subtitle: "${emp.employeeId} • ${emp.department}",
                      heroTag: 'report-card-pfp-${emp.userId}',
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: emp.avatarUrl!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, err) => Center(
                                child: Text(
                                  emp.name.isNotEmpty
                                      ? emp.name
                                          .split(' ')
                                          .map((n) => n.isNotEmpty ? n[0] : '')
                                          .join('')
                                          .toUpperCase()
                                          .padRight(1, 'E')
                                          .substring(0, 1)
                                      : 'E',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              emp.name.isNotEmpty
                                  ? emp.name
                                      .split(' ')
                                      .map((n) => n.isNotEmpty ? n[0] : '')
                                      .join('')
                                      .toUpperCase()
                                      .padRight(1, 'E')
                                      .substring(0, 1)
                                  : 'E',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              emp.name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "$presentCount Present",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "${emp.designation} • ${emp.department} • ${emp.employeeId}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Metrics Pills Row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricBadge("Present", "$presentCount", const Color(0xFF10B981), isDark),
                  const SizedBox(width: 8),
                  _buildMetricBadge("Absent", "$absentCount", const Color(0xFFEF4444), isDark),
                  const SizedBox(width: 8),
                  _buildMetricBadge("Late", "$lateCount", const Color(0xFFF97316), isDark),
                  const SizedBox(width: 8),
                  _buildMetricBadge("Missed", "$missedCount", const Color(0xFFF59E0B), isDark),
                  const SizedBox(width: 8),
                  _buildMetricBadge("Leaves", "$leaveCount", const Color(0xFF0284C7), isDark),
                  const SizedBox(width: 8),
                  _buildMetricBadge("Half Day", "$halfDayCount", const Color(0xFF6366F1), isDark),
                  const SizedBox(width: 8),
                  _buildMetricBadge("Overtime", "${otHours.toStringAsFixed(1)}h", const Color(0xFF8B5CF6), isDark),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Daily Attendance Timeline Header ───────────────────────────────
          InkWell(
            onTap: () => setState(() => _isTimelineExpanded = !_isTimelineExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    "Daily Attendance Log",
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isTimelineExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),

          // ── Daily Attendance Timeline List ──────────────────────────────────
          if (_isTimelineExpanded) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.dates.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, idx) {
                final dateStr = widget.dates[idx];
                final rec = emp.dailyRecords[dateStr] ??
                    AttendanceMatrixDayRecord(date: dateStr, status: '-');

                DateTime? dt;
                try {
                  dt = DateTime.parse(dateStr);
                } catch (_) {}

                final dateFormatted = dt != null ? DateFormat('d MMM (E)').format(dt) : dateStr;
                final isSunday = dt?.weekday == DateTime.sunday;
                final statusCol = rec.statusColor;

                return InkWell(
                  onTap: () => AttendanceDetailSheet.show(context, employee: emp, record: rec),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        // Date column
                        SizedBox(
                          width: 90,
                          child: Text(
                            dateFormatted,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isSunday
                                  ? const Color(0xFFE11D48)
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                        ),

                        // Status Chip
                        Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: statusCol.withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            rec.shortStatus,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: statusCol,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Clock in / out timings
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rec.clockIn != null ? "In: ${rec.clockIn}" : "-",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (rec.isLate)
                                    Text(
                                      "Late: ${rec.lateMinutes}m",
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF97316),
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    rec.clockOut != null ? "Out: ${rec.clockOut}" : "-",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (rec.workDuration != null && rec.workDuration != '-')
                                    Text(
                                      rec.workDuration!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
