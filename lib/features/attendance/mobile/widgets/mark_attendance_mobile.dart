import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../../../../shared/services/auth_service.dart';
import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import 'late_arrival_dialog_mobile.dart';
import 'correction_request_dialog_mobile.dart';
import '../../providers/attendance_provider.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/widgets/interactive_image_viewer.dart';

class MarkAttendanceMobile extends StatefulWidget {
  const MarkAttendanceMobile({super.key});

  @override
  State<MarkAttendanceMobile> createState() => _MarkAttendanceMobileState();
}

class _MarkAttendanceMobileState extends State<MarkAttendanceMobile> {
  late AttendanceService _attendanceService;
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _attendanceService = AttendanceService(auth.dio);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).fetchRecords(_selectedDate);
    });
  }

  Future<void> _fetchRecords() async {
    await Provider.of<AttendanceProvider>(context, listen: false)
        .fetchRecords(_selectedDate, forceRefresh: false);
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        context.showToast("Location services are disabled.", isWarning: true);
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          context.showToast("Location permission denied.", isWarning: true);
        }
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        context.showToast("Location permission permanently denied.", isWarning: true);
      }
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _handleAttendanceAction(bool isTimeIn) async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, 
        preferredCameraDevice: CameraDevice.front,
      );
      
      if (photo == null) return;

      if (!mounted) return;
      
      void showLoading() {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      Future<void> performApiCall(String? lateReason) async {
        if (isTimeIn) {
          await _attendanceService.timeIn(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: File(photo.path),
            lateReason: lateReason,
          );
        } else {
          await _attendanceService.timeOut(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: File(photo.path),
          );
        }
      }

      showLoading();
      bool success = false;
      String? caughtReasonError;

      try {
        await performApiCall(null);
        success = true;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (isTimeIn && (msg.contains("reason") || msg.contains("late"))) {
           caughtReasonError = msg;
        } else {
           if (mounted) {
             Navigator.pop(context); // Pop Loading
             context.showToast("Failed: $e", isError: true);
           }
           return;
        }
      }

      if (success) {
        if (mounted) {
          Navigator.pop(context); // Pop Loading
          await _showSuccessDialog(isTimeIn);
        }
        return;
      }

      if (caughtReasonError != null) {
        if (mounted) Navigator.pop(context); // Pop Loading
        
        if (!mounted) return;
        final reason = await LateArrivalDialogMobile.show(context);
        
        if (reason == null || reason.isEmpty) return;

        if (!mounted) return;
        showLoading();

        try {
          await performApiCall(reason);
          
          if (mounted) {
             Navigator.pop(context); // Pop Loading
             context.showToast("Late arrival reason submitted successfully.", isSuccess: true);
             await _showSuccessDialog(isTimeIn);
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Pop Loading
            context.showToast("Failed with reason: $e", isError: true);
          }
        }
      }

    } catch (e) {
       if (mounted) {
         context.showToast("Camera/Location Error: $e", isError: true);
       }
    }
  }

  Future<void> _showSuccessDialog(bool isTimeIn) async {
    if (mounted) {
      context.showToast(
        isTimeIn ? "Checked in successfully!" : "Checked out successfully!",
        isSuccess: true,
      );
    }
    
    if (mounted) {
      Provider.of<AttendanceProvider>(context, listen: false).invalidateCache(DateTime.now());
      _fetchRecords(); 
    }
  }

  List<DateTime> _generateScrollerDates() {
    final today = DateTime.now();
    final list = <DateTime>[];
    for (int i = -15; i <= 15; i++) {
      list.add(today.add(Duration(days: i)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final records = provider.records;
        final isLoading = provider.isLoading;

        bool isCheckedIn = false;
        if (records.isNotEmpty) {
           isCheckedIn = records.any((r) => r.timeOut == null);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          physics: const BouncingScrollPhysics(),
          children: [
            // 1. Action Buttons
            _buildActionButtons(context, isCheckedIn),
            const SizedBox(height: 24),
            
            // 2. Select Date Header
            _buildSelectDateHeader(context),
            const SizedBox(height: 12),
            
            // 3. Horizontal Date Scroller
            _buildHorizontalDateScroller(context),
            const SizedBox(height: 24),
            
            // 4. Logs Header (with + Correction)
            _buildLogsHeader(context, records),
            const SizedBox(height: 16),
            
            // 5. Logs List or Empty State
            if (isLoading)
               const Center(child: Padding(
                 padding: EdgeInsets.symmetric(vertical: 40),
                 child: CircularProgressIndicator(),
               ))
            else if (records.isEmpty)
               _buildEmptyState(context)
            else
               ...records.map((record) => Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: _buildSessionCard(context, record),
               )),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isCheckedIn) {
    return Column(
      children: [
        _buildLargeActionButton(
          context,
          label: 'Time In',
          subLabel: isCheckedIn ? 'You are currently checked in' : 'Start shift for today',
          icon: Icons.arrow_forward_rounded,
          color: const Color(0xFF10B981),
          isActive: !isCheckedIn, 
          onTap: () => _handleAttendanceAction(true),
        ),
        const SizedBox(height: 16),
        _buildLargeActionButton(
          context,
          label: 'Time Out',
          subLabel: isCheckedIn ? 'End current shift' : 'No active session',
          icon: Icons.logout_rounded,
          color: const Color(0xFFEF4444),
          isActive: isCheckedIn,
          onTap: () => _handleAttendanceAction(false),
        ),
      ],
    );
  }

  Widget _buildLargeActionButton(BuildContext context, {
    required String label,
    required String subLabel,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: isActive ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        height: 84,
        width: double.infinity,
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  color: isActive ? color : Colors.grey, 
                  size: 24
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label, 
                      style: GoogleFonts.poppins(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subLabel, 
                      style: GoogleFonts.poppins(
                        fontSize: 11, 
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right, 
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectDateHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'SELECT DATE',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 1.0,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.calendar_month_outlined,
            color: const Color(0xFF4F46E5),
            size: 20,
          ),
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (context) => GlassDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                onDateSelected: (newDate) {
                  setState(() => _selectedDate = newDate);
                  _fetchRecords();
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHorizontalDateScroller(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final selectedStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dates = _generateScrollerDates();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: dates.map((date) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final isSelected = dateStr == selectedStr;
          final isToday = dateStr == todayStr;
          final dayName = DateFormat('EEE').format(date).toUpperCase();
          final dayNum = date.day.toString();
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
                _fetchRecords();
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 68,
                height: 90,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF161B22)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black12),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? const Color(0xFFC7D2FE)
                                : Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNum,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    if (isToday && !isSelected)
                      Positioned(
                        bottom: 8,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogsHeader(BuildContext context, List<AttendanceRecord> records) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final selectedStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final isToday = todayStr == selectedStr;
    
    final title = isToday
        ? "TODAY'S LOGS"
        : "LOGS FOR ${DateFormat('MMM dd').format(_selectedDate).toUpperCase()}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        
        InkWell(
          onTap: () {
            final attendanceId = records.isNotEmpty ? records.first.attendanceId : null;
            CorrectionRequestDialogMobile.show(context, date: _selectedDate, attendanceId: attendanceId);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E38) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF4F46E5).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 4),
                Text(
                  'CORRECTION',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4F46E5),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: 140,
      margin: const EdgeInsets.only(top: 8),
      child: CustomPaint(
        painter: DashedRectPainter(
          color: isDark ? Colors.white24 : Colors.grey[300]!,
          gap: 6,
          radius: 16,
          strokeWidth: 1.5,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 32,
              color: isDark ? Colors.white30 : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No records found for today',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '--:--';
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return 'Err'; 
    }
  }

  Widget _buildSessionCard(BuildContext context, AttendanceRecord record) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                Expanded(child: Container(width: 2, color: Colors.grey.withOpacity(0.3), margin: const EdgeInsets.symmetric(vertical: 4))),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: record.timeOut != null ? Colors.red : Colors.grey, shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTimeInfo(context, time: _formatTime(record.timeIn), location: record.timeInAddress ?? 'Unknown'),
                  const SizedBox(height: 24),
                  record.timeOut != null 
                    ? _buildTimeInfo(context, time: _formatTime(record.timeOut), location: record.timeOutAddress ?? 'Unknown')
                    : Text(
                        'Currently Active', 
                        style: GoogleFonts.poppins(
                          fontSize: 13, 
                          fontWeight: FontWeight.w600, 
                          color: const Color(0xFF10B981)
                        )
                      ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAvatar(context, record.timeInImage),
                if (record.timeOut != null) _buildAvatar(context, record.timeOutImage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(BuildContext context, {required String time, required String location}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          time, 
          style: GoogleFonts.poppins(
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
          )
        ),
        const SizedBox(height: 4),
        Text(location, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey, height: 1.3)),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, String? imageUrl) {
      if (imageUrl == null || imageUrl.isEmpty) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: const Icon(Icons.person, size: 24, color: Colors.white),
        );
      }

      return InkWell(
        onTap: () => InteractiveImageViewerDialog.show(context, imageUrl, title: "Attendance Image"),
        child: Container(
          width: 40,
          height: 40,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: CachedNetworkImage(
            imageUrl: imageUrl, 
            fit: BoxFit.cover,
            errorWidget: (_,__,___) => const Icon(Icons.person, color: Colors.white),
            placeholder: (_,__) => const Center(child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          ),
        ),
      );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedRectPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final len = gap;
        if (distance + len > metric.length) {
          dashPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
