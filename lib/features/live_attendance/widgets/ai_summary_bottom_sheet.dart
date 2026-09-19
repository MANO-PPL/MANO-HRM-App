import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_application/features/attendance/core/live_attendance_item.dart';

/// Bottom sheet displaying AI-generated executive attendance insights, punctuality rates,
/// key observations, and attendance breakdown. Directly mirrors `AiSummaryModal.jsx` from Attendance-Web.
class AiSummaryBottomSheet extends StatefulWidget {
  final DateTime selectedDate;
  final List<LiveAttendanceItem> items;
  final Dio dio;

  const AiSummaryBottomSheet({
    super.key,
    required this.selectedDate,
    required this.items,
    required this.dio,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime selectedDate,
    required List<LiveAttendanceItem> items,
    required Dio dio,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => AiSummaryBottomSheet(
        selectedDate: selectedDate,
        items: items,
        dio: dio,
      ),
    );
  }

  @override
  State<AiSummaryBottomSheet> createState() => _AiSummaryBottomSheetState();
}

class _AiSummaryBottomSheetState extends State<AiSummaryBottomSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _aiData;

  int _presentRate = 0;
  int _lateRate = 0;

  @override
  void initState() {
    super.initState();
    _fetchAiSummary();
  }

  Future<void> _fetchAiSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final total = widget.items.length;

    int presentCount = 0;
    int lateCount = 0;
    final Map<String, Map<String, int>> deptStats = {};

    for (final item in widget.items) {
      final statusLower = item.statusLabel.toLowerCase();
      final isPresent = statusLower.contains('present') ||
          statusLower.contains('late') ||
          statusLower.contains('active');
      final isLate = item.isLate || statusLower.contains('late');

      if (isPresent) presentCount++;
      if (isLate) lateCount++;

      final dept = item.department;
      deptStats.putIfAbsent(dept, () => {'present': 0, 'absent': 0, 'late': 0});
      if (isPresent) deptStats[dept]!['present'] = (deptStats[dept]!['present'] ?? 0) + 1;
      if (isLate) deptStats[dept]!['late'] = (deptStats[dept]!['late'] ?? 0) + 1;
      if (statusLower.contains('absent')) {
        deptStats[dept]!['absent'] = (deptStats[dept]!['absent'] ?? 0) + 1;
      }
    }

    _presentRate = total > 0 ? ((presentCount / total) * 100).round() : 0;
    _lateRate = total > 0 ? ((lateCount / total) * 100).round() : 0;

    final analytics = {
      'present_rate': _presentRate,
      'late_rate': _lateRate,
      'avg_work_hours': 8.0,
      'department_breakdown': deptStats.entries.map((e) => {
        'department': e.key,
        'present': e.value['present'] ?? 0,
        'absent': e.value['absent'] ?? 0,
        'late': e.value['late'] ?? 0,
      }).toList(),
      'timeline_peaks': ['09:00', '17:00'],
    };

    final employees = widget.items.map((emp) {
      final rec = emp.record;
      String status = 'absent';
      final statusLower = emp.statusLabel.toLowerCase();
      if (statusLower.contains('active') || statusLower.contains('present')) {
        status = 'present';
      }
      if (statusLower.contains('late')) {
        status = 'late';
      }
      if (statusLower.contains('leave')) {
        status = 'on_leave';
      }

      return {
        'name': emp.name,
        'department': emp.department,
        'status': status,
        'check_in': rec?.timeIn,
        'check_out': rec?.timeOut,
      };
    }).toList();

    final payload = {
      'date': formattedDate,
      'total_employees': total,
      'employees': employees,
      'analytics': analytics,
    };

    try {
      final response = await widget.dio.post(
        '/attendance/ai-summary',
        data: payload,
      );

      if (mounted) {
        if (response.data != null && response.data is Map) {
          setState(() {
            _aiData = Map<String, dynamic>.from(response.data);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('AI Summary API error: $e');
    }

    // Fallback: Generate structured local AI intelligence summary
    if (mounted) {
      final highlights = <String>[];
      if (_presentRate >= 85) {
        highlights.add('High attendance rate across departments at $_presentRate%. Operations are fully staffed.');
      } else if (_presentRate < 60) {
        highlights.add('Attendance is currently below target at $_presentRate%. Review staffing levels and pending leave requests.');
      } else {
        highlights.add('Attendance is moderate at $_presentRate% with $_lateRate% late check-ins recorded.');
      }

      if (_lateRate > 20) {
        highlights.add('Punctuality notice: $_lateRate% of checked-in staff arrived past grace period.');
      } else {
        highlights.add('Punctuality is healthy: ${100 - _lateRate}% on-time arrival rate.');
      }

      final presentList = widget.items
          .where((i) => i.statusLabel.contains('Present') || i.statusLabel.contains('Active'))
          .map((i) => {'name': i.name, 'department': i.department, 'note': i.isLate ? 'Checked in late' : null})
          .toList();

      final absentList = widget.items
          .where((i) => i.statusLabel.contains('Absent'))
          .map((i) => {'name': i.name, 'department': i.department})
          .toList();

      setState(() {
        _aiData = {
          'summary': 'Daily attendance intelligence report for $formattedDate. Out of $total scheduled workforce members, $presentCount are active/present and ${total - presentCount} are absent or on leave. Overall attendance rate is $_presentRate% with a $_lateRate% late arrival frequency.',
          'analytics_insights': {
            'highlights': highlights,
          },
          'present_employees': presentList,
          'absent_employees': absentList,
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI Attendance Insights',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Generated for ${DateFormat('EEE, MMM dd, yyyy').format(widget.selectedDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: subtitleColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // Body Content
          Expanded(
            child: _isLoading
                ? _buildLoadingSkeleton(isDark)
                : _errorMessage != null
                    ? _buildErrorState(isDark)
                    : _buildAiContent(isDark, titleColor, subtitleColor, borderColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    final shimmerColor = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            Text(
              'Analysis Failed',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unable to process AI attendance insights.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAiSummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiContent(
    bool isDark,
    Color titleColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    final summary = _aiData?['summary']?.toString() ?? '';
    final rawInsights = _aiData?['analytics_insights'];
    final highlights = (rawInsights is Map && rawInsights['highlights'] is List)
        ? (rawInsights['highlights'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final presentEmployees = (_aiData?['present_employees'] as List<dynamic>?) ?? [];
    final absentEmployees = (_aiData?['absent_employees'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Metric Gauges
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Present Rate',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_presentRate%',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Late Rate',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_lateRate%',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Executive Summary Card
        if (summary.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.summarize_outlined, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      'Executive Summary',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Key Observations / Highlights
        if (highlights.isNotEmpty) ...[
          Text(
            'Key Observations',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 6),
          ...highlights.map((h) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      h,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Breakdown: Present
        if (presentEmployees.isNotEmpty) ...[
          Text(
            'Active / Present (${presentEmployees.length})',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presentEmployees.map((e) {
              final name = e['name']?.toString() ?? '';
              final dept = e['department']?.toString() ?? '';
              final note = e['note']?.toString();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    if (dept.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· $dept',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                    if (note != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          note,
                          style: GoogleFonts.inter(fontSize: 9, color: Colors.amber.shade700),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Breakdown: Absences
        if (absentEmployees.isNotEmpty) ...[
          Text(
            'Absences (${absentEmployees.length})',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: absentEmployees.map((e) {
              final name = e['name']?.toString() ?? '';
              final dept = e['department']?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    if (dept.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· $dept',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
