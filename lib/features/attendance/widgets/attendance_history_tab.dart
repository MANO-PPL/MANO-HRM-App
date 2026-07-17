import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/attendance_provider.dart';
import '../services/attendance_service.dart';
import '../models/attendance_record.dart';
import 'attendance_common_widgets.dart';
import '../../../../shared/widgets/interactive_image_viewer.dart';

class AttendanceHistoryTab extends StatefulWidget {
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const AttendanceHistoryTab({
    super.key, 
    this.shrinkWrap = false, 
    this.physics,
    this.padding,
  });

  @override
  State<AttendanceHistoryTab> createState() => _AttendanceHistoryTabState();
}

class _AttendanceHistoryTabState extends State<AttendanceHistoryTab> {
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceRecord> _records = [];
  bool _isLoading = false;
  bool _isExporting = false;

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

    // Group records by week
    final Map<int, List<AttendanceRecord>> groupedRecords = {};
    for (var record in _records) {
      if (record.timeIn != null) {
        final date = DateTime.parse(record.timeIn!);
        // Calculate week number or just group by 7-day windows?
        // Let's group by "Week of [Month] [Day]"
        final weekOfMonth = ((date.day - 1) / 7).floor() + 1;
        groupedRecords.putIfAbsent(weekOfMonth, () => []).add(record);
      }
    }

    // Sort weeks descending
    final sortedWeeks = groupedRecords.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding ?? const EdgeInsets.all(24),
      children: [
        // 1. Report Header
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
        const SizedBox(height: 32),

        if (_records.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.history_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No records found for this month",
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ...sortedWeeks.map((week) {
            final weekRecords = groupedRecords[week]!;
            // Sort records in week descending by date
            weekRecords.sort((a, b) => b.timeIn!.compareTo(a.timeIn!));
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildWeekSection(context, 'Week $week', weekRecords),
            );
          }),
      ],
    );
  }

  Widget _buildWeekSection(BuildContext context, String title, List<AttendanceRecord> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 16),
        ...records.map((record) => Padding(
          padding: const EdgeInsets.only(bottom: 12), 
          child: _buildHistoryCard(record),
        )),
      ],
    );
  }

  Widget _buildHistoryCard(AttendanceRecord record) {
    final timeIn = DateTime.parse(record.timeIn!);
    final day = timeIn.day;
    final dateStr = DateFormat('EEEE, MMM d').format(timeIn);
    
    final status = record.status.toUpperCase();
    final isLate = status == 'LATE';
    final isAbsent = status == 'ABSENT';
    
    final statusColor = isLate ? Colors.orange : (isAbsent ? Colors.red : Colors.green[100]);
    final statusText = isLate ? Colors.orange[800] : (isAbsent ? Colors.red[800] : Colors.green[800]);

    String displayIn = DateFormat('hh:mm a').format(timeIn);
    String displayOut = '-';
    String hrs = '-';

    if (record.timeOut != null) {
      final timeOut = DateTime.parse(record.timeOut!);
      displayOut = DateFormat('hh:mm a').format(timeOut);
      
      final diff = timeOut.difference(timeIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      hrs = '${hours}h ${minutes}m';
    }

    final location = record.timeInAddress ?? 'Unknown Location';

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 460;
          
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Date Box
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$day', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5B60F6))),
                    ),
                    const SizedBox(width: 16),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr, 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusColor?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(status, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusText)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location, 
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTimeColumn('IN', displayIn, imageUrl: record.timeInImage),
                    _buildTimeColumn('OUT', displayOut, imageUrl: record.timeOutImage),
                    _buildTimeColumn('HRS', hrs),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              children: [
                // Date Box
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$day', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5B60F6))),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateStr, 
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statusColor?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(status, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusText)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              location, 
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Times
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTimeColumn('IN', displayIn, imageUrl: record.timeInImage),
                        const SizedBox(width: 8),
                        _buildTimeColumn('OUT', displayOut, imageUrl: record.timeOutImage),
                        const SizedBox(width: 8),
                        _buildTimeColumn('HRS', hrs),
                      ],
                    )
                  ],
                )
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildTimeColumn(String label, String value, {String? imageUrl}) {
    final isUndefined = value == '-' || value.isEmpty;

    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (imageUrl != null && !isUndefined)
          InkWell(
            onTap: () => InteractiveImageViewerDialog.show(context, imageUrl, title: "$label Image"),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.remove_red_eye_outlined, size: 12, color: Theme.of(context).primaryColor),
              ],
            ),
          )
        else
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
