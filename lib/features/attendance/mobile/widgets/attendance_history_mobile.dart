import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance_record.dart';
import 'attendance_mobile_common_widgets.dart';

class AttendanceHistoryMobile extends StatefulWidget {
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AttendanceHistoryMobile({
    super.key, 
    this.shrinkWrap = false, 
    this.physics,
  });

  @override
  State<AttendanceHistoryMobile> createState() => _AttendanceHistoryMobileState();
}

class _AttendanceHistoryMobileState extends State<AttendanceHistoryMobile> {
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

    // Group records by week
    final Map<int, List<AttendanceRecord>> groupedRecords = {};
    for (var record in _records) {
      if (record.timeIn != null) {
        final date = DateTime.parse(record.timeIn!);
        final weekOfMonth = ((date.day - 1) / 7).floor() + 1;
        groupedRecords.putIfAbsent(weekOfMonth, () => []).add(record);
      }
    }

    // Sort weeks descending
    final sortedWeeks = groupedRecords.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        // 1. Report Header (Mobile)
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
            weekRecords.sort((a, b) => b.timeIn!.compareTo(a.timeIn!));
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildWeekSection(context, 'Week $week', weekRecords.map((r) => _buildHistoryCard(context, r)).toList()),
            );
          }),
      ],
    );
  }

  Widget _buildWeekSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
          title, 
          style: GoogleFonts.poppins(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7) ?? Colors.grey[600]
          )
        ),
        const SizedBox(height: 16),
        ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)),
      ],
    );
  }

  Widget _buildHistoryCard(BuildContext context, AttendanceRecord record) {
    if (record.timeIn == null) return const SizedBox.shrink();
    
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
      child: Column(
        children: [
           Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // Date Box
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$day', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF5B60F6))),
                ),
                const SizedBox(width: 12),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr, 
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, 
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyLarge?.color
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location, 
                        style: GoogleFonts.poppins(
                          fontSize: 10, 
                          color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusColor?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(status, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: statusText)),
                      ),
                    ],
                  ),
                ),
             ],
           ),
           const SizedBox(height: 12),
           const Divider(height: 1),
           const SizedBox(height: 12),
           // Times Row (Space Between)
           Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 _buildTimeColumn(context, 'IN', displayIn, imageUrl: record.timeInImage),
                 _buildTimeColumn(context, 'OUT', displayOut, imageUrl: record.timeOutImage),
                 _buildTimeColumn(context, 'HRS', hrs),
              ],
           )
        ],
      ),
    );
  }

  Widget _buildTimeColumn(BuildContext context, String label, String value, {String? imageUrl}) {
    final isUndefined = value == '-' || value.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: GoogleFonts.poppins(
            fontSize: 9, 
            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey, 
            fontWeight: FontWeight.w600
          )
        ),
        const SizedBox(height: 2),
        if (imageUrl != null && !isUndefined)
          InkWell(
            onTap: () => _showImagePreview(context, imageUrl, "$label Image"),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value, 
                  style: GoogleFonts.poppins(
                    decoration: TextDecoration.underline,
                  )
                ),
                const SizedBox(width: 4),
                Icon(Icons.remove_red_eye_outlined, size: 12, color: Theme.of(context).primaryColor),
              ],
            ),
          )
        else
          Text(
            value, 
            style: GoogleFonts.poppins(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color
            )
          ),
      ],
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 450, // Allow sufficient height for portrait
                  width: double.infinity,
                  fit: BoxFit.contain, // Show full image without cropping
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                         const SizedBox(height: 8),
                         Text("Image not available", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                         // Debug helper
                         // Text(imageUrl, style: const TextStyle(fontSize: 8)),
                       ],
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
