import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/attendance/core/attendance_record.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_common_widgets.dart';

class AttendanceAnalyticsMobile extends StatefulWidget {
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AttendanceAnalyticsMobile({
    super.key,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<AttendanceAnalyticsMobile> createState() => _AttendanceAnalyticsMobileState();
}

class _AttendanceAnalyticsMobileState extends State<AttendanceAnalyticsMobile> {
  final DateTime _selectedMonth = DateTime.now();
  List<AttendanceRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchMonthRecords();
    });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        // 1. Summary Cards (2x2 Grid for Mobile)
        Column(
          children: [
            Row(
              children: [
                Expanded(child: AttendanceSummaryCard(title: 'Total Records', value: '$totalDays', icon: Icons.calendar_today, color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: AttendanceSummaryCard(title: 'Present', value: '$presentPercent%', percentage: '$presentPercent%')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: AttendanceSummaryCard(title: 'Late', value: '$latePercent%', percentage: '$latePercent%')),
                const SizedBox(width: 8),
                Expanded(child: AttendanceSummaryCard(title: 'Avg Hours', value: avgHours, icon: Icons.access_time, color: Colors.blue)),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 10),

        // 2. Line Chart
        GlassContainer(
          padding: const EdgeInsets.all(14),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Attendance', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200, // Compact height for mobile
                child: _LineChartWidget(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. Status & Weekly (Stacked)
        _buildAttendanceStatusCard(context, onTimeCount, lateCount),
        const SizedBox(height: 10),
        _buildWeeklyActivityCard(context),
      ],
    );
  }

  Widget _buildAttendanceStatusCard(BuildContext context, int onTime, int late) {
    final total = onTime + late;
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Status', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 42,
                          sections: [
                            PieChartSectionData(color: const Color(0xFF10B981), value: onTime.toDouble(), radius: 18, showTitle: false), 
                            PieChartSectionData(color: const Color(0xFFF59E0B), value: late.toDouble(), radius: 18, showTitle: false),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('TOTAL', style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.grey)),
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
                    const SizedBox(height: 8),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey)),
      ],
    );
  }

  Widget _buildWeeklyActivityCard(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Activity', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: Column(
              children: [
                Text('Weekly Activity (summary)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
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
                                decoration: BoxDecoration(color: const Color(0xFF5B60F6).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(height: 6),
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
            belowBarData: BarAreaData(show: true, color: const Color(0xFF5B60F6).withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }
}

// [upd:2026-04-16T09:00:00+05:30]

// [upd:2026-05-02T14:00:00+05:30]

// [rev:2026-08-24T13:30:00+05:30]
