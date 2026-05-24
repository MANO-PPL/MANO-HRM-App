import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../employees/models/employee_model.dart';
import './dar_admin_controller.dart';

/// Shared bottom-sheet that displays a chronological timeline for a given
/// employee. Call [DarAdminSheet.show] from any layout widget.
class DarAdminSheet {
  DarAdminSheet._();

  static void show(
    BuildContext context,
    Employee employee,
    DarAdminController ctrl,
  ) {
    final grouped = ctrl.getTimeline(employee);
    final dates = grouped.keys.toList()..sort();
    final initials = employee.userName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark
                ? Border.all(color: const Color(0xFF30363D))
                : null,
          ),
          child: Column(
            children: [
              // ── Drag handle ───────────────────────────────────────────
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // ── Employee header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF5B60F6),
                      child: Text(
                        initials,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  employee.userName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (employee.department?.isNotEmpty == true)
                                ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5B60F6)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    employee.department!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF5B60F6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            employee.designation ?? 'Employee',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Timeline body ─────────────────────────────────────────
              Expanded(
                child: Container(
                  color: isDark
                      ? const Color(0xFF0D1117)
                      : const Color(0xFFF8FAFC),
                  child: dates.isEmpty
                      ? _buildEmpty(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: dates.length,
                          itemBuilder: (_, idx) => _buildDateGroup(
                            dateKey: dates[idx],
                            items: grouped[dates[idx]]!,
                            ctrl: ctrl,
                            isDark: isDark,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No Activity Logged',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'No activities or meetings logged for this employee in the selected range.',
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDateGroup({
    required String dateKey,
    required List<dynamic> items,
    required DarAdminController ctrl,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date strip
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: Color(0xFF5B60F6)),
              const SizedBox(width: 6),
              Text(
                ctrl.formatDate(dateKey),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161B22)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? "entry" : "entries"}',
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),

        // Timeline spine + cards
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  color: isDark
                      ? const Color(0xFF30363D)
                      : Colors.grey[300],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: items.map((item) {
                      final theme = ctrl.categoryTheme(
                          item['category'] as String, isDark);
                      final isMeet = item['type'] == 'meeting';
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF161B22)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF30363D)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Icon(Icons.access_time_filled,
                                      size: 11, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ctrl.formatTime(item['startTime'] as String)} – ${ctrl.formatTime(item['endTime'] as String)}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey),
                                  ),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme['bg'],
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isMeet
                                        ? 'MEETING'
                                        : (item['category'] as String)
                                            .toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: theme['text'],
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            if ((item['description'] as String)
                                .isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item['description'] as String,
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
