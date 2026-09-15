import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/models/dashboard_model.dart';

class TrendsChart extends StatelessWidget {
  final List<ChartData> chartData;

  const TrendsChart({super.key, required this.chartData});

  @override
  Widget build(BuildContext context) {
    // If no data, show placeholder or empty state
    if (chartData.isEmpty) {
      return const GlassContainer(
        padding: EdgeInsets.all(24),
        child: Center(child: Text("No data available")),
      );
    }

    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.1);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color;

    // Use a GlassContainer directly
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Trends',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Weekly Insight',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
              // Legend
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _buildLegendItem(const Color(0xFF10B981), 'Present'),
                   const SizedBox(width: 8),
                   _buildLegendItem(const Color(0xFFEF4444), 'Absent'),
                   const SizedBox(width: 8),
                   _buildLegendItem(const Color(0xFFF59E0B), 'Late'),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 15,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: dividerColor,
                      strokeWidth: 1,
                    );
                  },
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
                        if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              chartData[value.toInt()].name,
                              style: GoogleFonts.poppins(fontSize: 10, color: subTextColor),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(fontSize: 10, color: subTextColor),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (chartData.length - 1).toDouble(),
                minY: 0,
                maxY: 100, // Adjust max Y based on data if needed
                lineBarsData: [
                  // Present Line
                  LineChartBarData(
                    spots: chartData.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.present.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                   // Absent Line
                  LineChartBarData(
                    spots: chartData.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.absent.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFFEF4444), // Red
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Late Line
                  LineChartBarData(
                    spots: chartData.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.late.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFFF59E0B),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10)),
      ],
    );
  }
}

// [mod:2026-02-22T14:30:00+05:30]

// [upd:2026-05-10T17:00:00+05:30]

// [rev:2026-08-25T18:00:00+05:30]
