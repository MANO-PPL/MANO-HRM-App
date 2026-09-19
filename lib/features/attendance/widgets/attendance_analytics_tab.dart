import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/attendance/core/attendance_service.dart';
import 'package:flutter_application/features/attendance/core/attendance_record.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_common_widgets.dart';

class AttendanceAnalyticsTab extends StatefulWidget {
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AttendanceAnalyticsTab({
    super.key, 
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<AttendanceAnalyticsTab> createState() => _AttendanceAnalyticsTabState();
}

class _AttendanceAnalyticsTabState extends State<AttendanceAnalyticsTab> {
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceRecord> _records = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fetchMonthRecords();
  }

  Future<void> _fetchMonthRecords() async {
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final data = await provider.fetchRange(firstDay, lastDay);
      
      if (mounted) {
        setState(() {
          _records = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleExport() async {
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = AttendanceService(authService.dio);

    setState(() => _isExporting = true);

    try {
      final bytes = await attendanceService.exportMyReport(monthStr);
      final directory = await getTemporaryDirectory();
      final String safeName = (authService.user?.name ?? 'User').replaceAll(RegExp(r'\s+'), '_');
      final String fileName = 'Attendance_${monthStr}_$safeName.xlsx';
      final String filePath = '${directory.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved: $fileName'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () => OpenFilex.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600 && !isDesktop;

    // Analytics Calculations
    final totalDays = _records.length;
    final onTimeCount = _records.where((r) => r.status.toUpperCase() == 'PRESENT').length;
    final lateCount = _records.where((r) => r.status.toUpperCase() == 'LATE').length;
    
    final presentCount = onTimeCount + lateCount;
    final presentPercent = totalDays > 0 ? (presentCount / totalDays * 100).toStringAsFixed(0) : '0';
    final latePercent = presentCount > 0 ? (lateCount / presentCount * 100).toStringAsFixed(0) : '0';

    double totalHours = 0;
    int recordsWithHours = 0;
    for (var r in _records) {
      if (r.timeIn != null && r.timeOut != null) {
        final duration = DateTime.parse(r.timeOut!).difference(DateTime.parse(r.timeIn!));
        totalHours += duration.inMinutes / 60;
        recordsWithHours++;
      }
    }
    final avgHours = recordsWithHours > 0 ? (totalHours / recordsWithHours).toStringAsFixed(1) : '0.0';

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: const EdgeInsets.all(24),
      children: [
        MonthlyReportHeader(
          selectedMonth: _selectedMonth, 
          onMonthChanged: (newDate) {
            setState(() {
              _selectedMonth = newDate;
            });
            _fetchMonthRecords();
          },
          onDownload: _handleExport,
          isDownloading: _isExporting,
        ),
        const SizedBox(height: 24),
        
        // 1. Summary Cards
        isDesktop || isTablet
          ? Row(
              children: [
                Expanded(child: AttendanceSummaryCard(title: 'Total Records', value: '$totalDays', icon: Icons.calendar_today, color: Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: AttendanceSummaryCard(title: 'Present', value: '$presentPercent%', percentage: '$presentPercent%')),
                const SizedBox(width: 16),
                Expanded(child: AttendanceSummaryCard(title: 'Late', value: '$latePercent%', percentage: '$latePercent%')),
                const SizedBox(width: 16),
                Expanded(child: AttendanceSummaryCard(title: 'Avg Hours', value: avgHours, icon: Icons.access_time, color: Colors.blue)),
              ],
            )
          : Column(
              children: [
                AttendanceSummaryCard(title: 'Total Records', value: '$totalDays', icon: Icons.calendar_today, color: Colors.blue),
                const SizedBox(height: 12),
                AttendanceSummaryCard(title: 'Present', value: '$presentPercent%', percentage: '$presentPercent%'),
                const SizedBox(height: 12),
                AttendanceSummaryCard(title: 'Late', value: '$latePercent%', percentage: '$latePercent%'),
                const SizedBox(height: 12),
                AttendanceSummaryCard(title: 'Avg Hours', value: avgHours, icon: Icons.access_time, color: Colors.blue),
              ],
            ),
        
        const SizedBox(height: 24),

        // 2. Total Attendance Report Chart (Line Chart) - Kept Mock for now as it needs daily series
        GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Attendance Report', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 32),
              const SizedBox(
                height: 300,
                child: _LineChartWidget(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Bottom Row: Attendance Status (Pie) & Weekly Activity (Radar)
         isDesktop || isTablet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAttendanceStatusCard(context, onTimeCount, lateCount)),
                const SizedBox(width: 24),
                Expanded(child: _buildWeeklyActivityCard(context)),
              ],
            )
          : Column(
              children: [
                _buildAttendanceStatusCard(context, onTimeCount, lateCount),
                const SizedBox(height: 24),
                _buildWeeklyActivityCard(context),
              ],
            ),
      ],
    );
  }

  Widget _buildAttendanceStatusCard(BuildContext context, int onTime, int late) {
    final total = onTime + late;
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Status', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 60,
                          sections: [
                            PieChartSectionData(color: const Color(0xFF10B981), value: onTime.toDouble(), radius: 25, showTitle: false), // On Time
                            PieChartSectionData(color: const Color(0xFFF59E0B), value: late.toDouble(), radius: 25, showTitle: false), // Late
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('TOTAL', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(const Color(0xFF10B981), 'On Time'),
                    const SizedBox(height: 12),
                    _buildLegendItem(const Color(0xFFF59E0B), 'Late'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildWeeklyActivityCard(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Activity', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: RadarChart(
              RadarChartData(
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                tickCount: 1,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                gridBorderData: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
                radarShape: RadarShape.polygon,
                getTitle: (index, angle) {
                  const titles = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  if (index < titles.length) return RadarChartTitle(text: titles[index]);
                  return const RadarChartTitle(text: '');
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: const Color(0xFF5B60F6).withValues(alpha: 0.2),
                    borderColor: const Color(0xFF5B60F6),
                    entryRadius: 2,
                    dataEntries: [
                       const RadarEntry(value: 3),
                       const RadarEntry(value: 5),
                       const RadarEntry(value: 2),
                       const RadarEntry(value: 4),
                       const RadarEntry(value: 1),
                       const RadarEntry(value: 0),
                       const RadarEntry(value: 0),
                    ],
                    borderWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartWidget extends StatelessWidget {
  const _LineChartWidget();

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // Mock dates
                const dates = ['15', '18', '19', '19', '19', '21', '22', '23', '25', '25']; 
                if (value.toInt() >= 0 && value.toInt() < dates.length) {
                   return Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text(dates[value.toInt()], style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                   );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 0.2,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
              ),
              reservedSize: 30,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 9,
        minY: 0,
        maxY: 1.0,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 0.2),
              FlSpot(1, 0.4),
              FlSpot(2, 0.3),
              FlSpot(3, 0.7),
              FlSpot(4, 0.5),
              FlSpot(5, 0.8),
              FlSpot(6, 0.6),
              FlSpot(7, 0.9),
              FlSpot(8, 0.4),
              FlSpot(9, 0.5),
            ],
            isCurved: true,
            color: const Color(0xFF5B60F6),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// [upd:2026-04-16T09:00:00+05:30]

// [upd:2026-05-02T14:00:00+05:30]

// [rev:2026-08-24T13:30:00+05:30]
