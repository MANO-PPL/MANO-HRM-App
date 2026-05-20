import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance_record.dart';
import '../../widgets/attendance_common_widgets.dart'; // Keep for SummaryCard
import 'attendance_mobile_common_widgets.dart'; // Mobile Header

class AttendanceAnalyticsMobile extends StatefulWidget {
  const AttendanceAnalyticsMobile({super.key});

  @override
  State<AttendanceAnalyticsMobile> createState() => _AttendanceAnalyticsMobileState();
}

class _AttendanceAnalyticsMobileState extends State<AttendanceAnalyticsMobile> {
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
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = 'Attendance_${monthStr}_${authService.user?.name ?? "User"}.xlsx';
      final String filePath = '${directory.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report saved'),
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

    // Analytics Calculations
    final totalDays = _records.length;
    final onTimeCount = _records.where((r) => r.status.toUpperCase() == 'PRESENT').length;
    final lateCount = _records.where((r) => r.status.toUpperCase() == 'LATE').length;
    final absentCount = _records.where((r) => r.status.toUpperCase() == 'ABSENT').length;
    
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
      padding: const EdgeInsets.all(24),
      children: [
        MonthlyReportHeaderMobile(
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
        
        // 1. Summary Cards (Stacked for Mobile)
        Column(
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

        // 2. Line Chart
        GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Attendance', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 250, // Slightly shorter for mobile
                child: _LineChartWidget(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Status & Weekly (Stacked)
        _buildAttendanceStatusCard(context, onTimeCount, lateCount),
        const SizedBox(height: 24),
        _buildWeeklyActivityCard(context),
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
          Text('Attendance Status', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 50,
                          sections: [
                            PieChartSectionData(color: const Color(0xFF10B981), value: onTime.toDouble(), radius: 20, showTitle: false), 
                            PieChartSectionData(color: const Color(0xFFF59E0B), value: late.toDouble(), radius: 20, showTitle: false),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('TOTAL', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
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
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
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
          Text('Weekly Activity', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Column(
              children: [
                Text('Weekly Activity (summary)', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                      final values = [3.0,5.0,2.0,4.0,1.0,0.0,0.0];
                      final maxVal = values.fold<double>(0, (prev, e) => e > prev ? e : prev);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(labels.length, (i) {
                          final heightFactor = maxVal > 0 ? values[i] / maxVal : 0.0;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: (constraints.maxWidth - 24) / 14,
                                height: constraints.maxHeight * 0.65 * heightFactor,
                                decoration: BoxDecoration(color: const Color(0xFF5B60F6).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(height: 8),
                              Text(labels[i], style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                            ],
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                  // Simplified for mobile
                  const dates = ['15', '', '19', '', '', '21', '', '23', '', '25']; 
                  if (value.toInt() >= 0 && value.toInt() < dates.length) {
                     return Text(dates[value.toInt()], style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey));
                  }
                  return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 9,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 0.2), FlSpot(1, 0.4), FlSpot(2, 0.3), FlSpot(3, 0.7),
              FlSpot(4, 0.5), FlSpot(5, 0.8), FlSpot(6, 0.6), FlSpot(7, 0.9),
              FlSpot(8, 0.4), FlSpot(9, 0.5),
            ],
            isCurved: true,
            color: const Color(0xFF5B60F6),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF5B60F6).withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}
