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
import '../../../../shared/services/network_monitor.dart';
import '../../../../shared/services/local_notification_service.dart';
import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import 'late_arrival_dialog_mobile.dart';
import 'correction_request_dialog_mobile.dart';
import '../../models/correction_request.dart'; // Added
import '../../providers/attendance_provider.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/widgets/interactive_image_viewer.dart';

class MarkAttendanceMobile extends StatefulWidget {
  const MarkAttendanceMobile({super.key});

  @override
  State<MarkAttendanceMobile> createState() => _MarkAttendanceMobileState();
}

class _MarkAttendanceMobileState extends State<MarkAttendanceMobile> with WidgetsBindingObserver {
  late AttendanceService _attendanceService;
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now();
  bool _isProcessing = false;
  bool _isTimeInProcessing = false;
  bool _isTimeOutProcessing = false;
  StreamSubscription<Position>? _positionStreamSub;
  Position? _realtimePosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = Provider.of<AuthService>(context, listen: false);
    _attendanceService = AttendanceService(auth.dio);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).fetchRecords(_selectedDate);
      _prewarmLocation();
      _startLocationListening();
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchRecords();
    }
  }

  void _startLocationListening() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _positionStreamSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          _realtimePosition = position;
        }, onError: (e) {
          debugPrint("Error in position stream: $e");
        });
      }
    } catch (e) {
      debugPrint("Failed to start location listening: $e");
    }
  }

  void _prewarmLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Geolocator.getLastKnownPosition().then((_) => null, onError: (_) => null);
        Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 3),
          ),
        ).then((_) => null, onError: (_) => null);
      }
    } catch (e) {
      debugPrint("Pre-warm location error: $e");
    }
  }

  Future<void> _fetchRecords() async {
    await Provider.of<AttendanceProvider>(context, listen: false)
        .fetchRecords(_selectedDate, forceRefresh: false);
  }

  Future<Position?> _getCurrentLocation() async {
    final locationStopwatch = Stopwatch()..start();

    void logLocationStage(String stage, Stopwatch stopwatch) {
      debugPrint('Attendance location flow (mobile): $stage took ${stopwatch.elapsedMilliseconds} ms');
    }

    final serviceCheckStopwatch = Stopwatch()..start();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    logLocationStage('location service check', serviceCheckStopwatch);
    if (!serviceEnabled) {
      if (mounted) {
        context.showToast(
          "Location services are disabled.",
          isWarning: true,
          actionLabel: "ENABLE",
          onActionPressed: () async {
            await Geolocator.openLocationSettings();
          },
        );
      }
      return null;
    }

    final permissionCheckStopwatch = Stopwatch()..start();
    LocationPermission permission = await Geolocator.checkPermission();
    logLocationStage('permission check', permissionCheckStopwatch);
    if (permission == LocationPermission.denied) {
      final permissionRequestStopwatch = Stopwatch()..start();
      permission = await Geolocator.requestPermission();
      logLocationStage('permission request', permissionRequestStopwatch);
      if (permission == LocationPermission.denied) {
        if (mounted) {
          context.showToast("Location permission denied.", isWarning: true);
        }
        debugPrint('Attendance location flow (mobile): total took ${locationStopwatch.elapsedMilliseconds} ms');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        context.showToast(
          "Location permission permanently denied.",
          isWarning: true,
          actionLabel: "SETTINGS",
          onActionPressed: () async {
            await openAppSettings();
          },
        );
      }
      debugPrint('Attendance location flow (mobile): total took ${locationStopwatch.elapsedMilliseconds} ms');
      return null;
    }

    // 0. Try the real-time position stream first if it is fresh and accurate
    if (_realtimePosition != null) {
      final age = DateTime.now().difference(_realtimePosition!.timestamp);
      if (age.inSeconds < 15 && _realtimePosition!.accuracy <= 100) {
        debugPrint("Using fresh stream position: age=${age.inSeconds}s, accuracy=${_realtimePosition!.accuracy}m");
        return _realtimePosition;
      }
    }

    // 1. Try last known position FIRST. If it is fresh (under 15 minutes), use it immediately for instant retrieval.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age.inMinutes < 15) {
          debugPrint("Using fresh last known position: age=${age.inSeconds}s, accuracy=${lastKnown.accuracy}m");
          return lastKnown;
        }
      }
    } catch (e) {
      debugPrint("Error checking last known location: $e");
    }

    // 2. Otherwise, fetch high accuracy with a strict timeout (2 seconds)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("High accuracy location fetch failed/timed out. Trying any last known fallback...");
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
      } catch (_) {}
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 2),
          ),
        );
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _handleAttendanceAction(bool isTimeIn) async {
    if (_isProcessing) return;

    final flowStopwatch = Stopwatch()..start();

    void logStage(String stage, Stopwatch stopwatch) {
      debugPrint(
        'Attendance flow (${isTimeIn ? 'Time In' : 'Time Out'}): $stage took ${stopwatch.elapsedMilliseconds} ms',
      );
    }

    if (!NetworkMonitor().isOnline) {
      if (mounted) {
        context.showToast("No internet connection. Offline check-in/out is disabled.", isError: true);
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      if (isTimeIn) {
        _isTimeInProcessing = true;
      } else {
        _isTimeOutProcessing = true;
      }
    });

    // Start getting location in the background immediately
    final locationStopwatch = Stopwatch()..start();
    final Future<Position?> locationFuture = _getCurrentLocation();

    try {
      final shiftPolicy = context.read<AttendanceProvider>().shiftPolicy;
      final isSelfieRequired = isTimeIn
          ? (shiftPolicy?.entrySelfie ?? false)
          : (shiftPolicy?.exitSelfie ?? false);

      XFile? photo;
      if (isSelfieRequired) {
        final cameraPermissionStopwatch = Stopwatch()..start();
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (!status.isGranted) {
            logStage('camera permission', cameraPermissionStopwatch);
            setState(() {
              _isProcessing = false;
              _isTimeInProcessing = false;
              _isTimeOutProcessing = false;
            });
            return;
          }
        }
        logStage('camera permission', cameraPermissionStopwatch);

        final cameraCaptureStopwatch = Stopwatch()..start();
        photo = await _picker.pickImage(
          source: ImageSource.camera, 
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 70,
        );
        logStage('camera capture', cameraCaptureStopwatch);
        
        if (photo == null) {
          setState(() {
            _isProcessing = false;
            _isTimeInProcessing = false;
            _isTimeOutProcessing = false;
          });
          return;
        }
      }

      if (!mounted) return;

      // Await location in parallel (or wait for the background request to finish)
      final locationWaitStopwatch = Stopwatch()..start();
      final position = await locationFuture;
      logStage('location fetch', locationStopwatch);
      logStage('waiting for location after camera', locationWaitStopwatch);
      if (position == null) {
        setState(() {
          _isProcessing = false;
          _isTimeInProcessing = false;
          _isTimeOutProcessing = false;
        });
        return;
      }

      final punchTimestamp = DateTime.now().toIso8601String();

      Future<void> performApiCall(String? lateReason) async {
        if (isTimeIn) {
          await _attendanceService.timeIn(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: photo != null ? File(photo.path) : null,
            lateReason: lateReason,
            timestamp: punchTimestamp,
          );
        } else {
          await _attendanceService.timeOut(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: photo != null ? File(photo.path) : null,
            timestamp: punchTimestamp,
          );
        }
      }

      // Online Submit Flow
      bool success = false;
      String? caughtReasonError;

      try {
        final apiStopwatch = Stopwatch()..start();
        await performApiCall(null);
        logStage(isTimeIn ? 'Time In API call' : 'Time Out API call', apiStopwatch);
        success = true;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (isTimeIn && (
            msg.contains("reason") || 
            msg.contains("late") || 
            msg.contains("remark") || 
            msg.contains("lateness")
        )) {
           caughtReasonError = msg;
        } else {
           if (mounted) {
             final lateReasonStopwatch = Stopwatch()..start();
             context.showExceptionToast(
               e,
               fallback: isTimeIn
                   ? 'Failed to clock in. Please try again.'
                   : 'Failed to clock out. Please try again.',
             );
             logStage('error handling before fallback toast', lateReasonStopwatch);
           }
           final isBg = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
           if (isBg) {
             LocalNotificationService.showNotification(
               title: isTimeIn ? 'Clock In Failed' : 'Clock Out Failed',
               body: 'Failed to complete: ${e.toString().replaceAll("Exception: ", "")}',
             );
           }
           setState(() {
             _isProcessing = false;
             _isTimeInProcessing = false;
             _isTimeOutProcessing = false;
           });
           return;
        }
      }

      if (success) {
        if (mounted) {
          await _showSuccessDialog(isTimeIn);
        }
        final isBg = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
        if (isBg) {
          LocalNotificationService.showNotification(
            title: isTimeIn ? 'Clock In Successful' : 'Clock Out Successful',
            body: isTimeIn ? 'You have successfully clocked in.' : 'You have successfully clocked out.',
          );
        }
        setState(() {
          _isProcessing = false;
          _isTimeInProcessing = false;
          _isTimeOutProcessing = false;
        });
        return;
      }

      if (caughtReasonError != null) {
        if (!mounted) return;

        final isBg = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
        if (isBg) {
          LocalNotificationService.showNotification(
            title: 'Late Arrival Reason Required',
            body: 'Please open the app to submit your late arrival reason and complete Clock In.',
          );
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        final reason = await LateArrivalDialogMobile.show(context);
        
        if (reason == null || reason.isEmpty) {
          setState(() {
            _isProcessing = false;
            _isTimeInProcessing = false;
            _isTimeOutProcessing = false;
          });
          return;
        }

        if (!mounted) return;

        try {
          final retryApiStopwatch = Stopwatch()..start();
          await performApiCall(reason);
          logStage('Time In API retry with late reason', retryApiStopwatch);
          
          if (mounted) {
             context.showToast("Late arrival reason submitted successfully.", isSuccess: true);
             await _showSuccessDialog(isTimeIn);
          }
          final isBgNow = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
          if (isBgNow) {
            LocalNotificationService.showNotification(
              title: 'Clock In Successful',
              body: 'Clocked in successfully with late arrival reason.',
            );
          }
        } catch (e) {
          if (mounted) {
            context.showExceptionToast(e, fallback: 'Failed to submit late arrival reason.');
          }
          final isBgNow = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
          if (isBgNow) {
            LocalNotificationService.showNotification(
              title: 'Clock In Failed',
              body: 'Failed to submit late arrival reason: ${e.toString().replaceAll("Exception: ", "")}',
            );
          }
        }
      }

    } catch (e) {
       if (mounted) {
         context.showExceptionToast(e, fallback: 'Camera or location error. Please try again.');
       }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isTimeInProcessing = false;
          _isTimeOutProcessing = false;
        });
      }
      debugPrint(
        'Attendance flow (${isTimeIn ? 'Time In' : 'Time Out'}) total completed in ${flowStopwatch.elapsedMilliseconds} ms',
      );
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
      // 1. Await today's record loading
      await Provider.of<AttendanceProvider>(context, listen: false)
          .fetchRecords(DateTime.now(), forceRefresh: true);
      // 2. Start background sync for geocoding and image loading
      if (mounted) {
        Provider.of<AttendanceProvider>(context, listen: false).startRealtimeSync(DateTime.now());
      }
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

        final missedDate = provider.missedPunchDate;

        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            // 0. Missed Punch Warning Banner
            if (missedDate != null) ...[
              _buildMissedPunchBanner(context, missedDate, provider),
              const SizedBox(height: 16),
            ],

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

  Widget _buildMissedPunchBanner(BuildContext context, DateTime missedDate, AttendanceProvider provider) {
    final dateLabel = DateFormat('EEE, MMM d').format(missedDate);
    final deadlineDays = provider.correctionDeadlineDays;
    // Expiry = end-of-day on (missedDate + deadlineDays days)
    final expiry = DateTime(missedDate.year, missedDate.month, missedDate.day)
        .add(Duration(days: deadlineDays + 1)); // +1 so the full last day counts
    final hoursLeft = expiry.difference(DateTime.now()).inHours;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final daysLeftLabel = hoursLeft <= 0 ? 'Expired' : daysLeft == 0 ? 'Last chance today' : '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
    final isExpired = hoursLeft <= 0;

    return InkWell(
      onTap: isExpired
          ? null
          : () {
              CorrectionRequestDialogMobile.show(
                context,
                date: missedDate,
                attendanceId: null,
                type: CorrectionType.missedPunch,
              ).then((_) => provider.clearMissedPunch());
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isExpired
                ? [Colors.red.shade900, Colors.red.shade700]
                : [const Color(0xFFEA580C), const Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpired ? Icons.block_rounded : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired ? 'Missed Punch — Deadline Passed' : '⚠️  Missed Time-Out Detected',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isExpired
                        ? 'No time-out recorded for $dateLabel. The correction window has expired.'
                        : 'No time-out recorded for $dateLabel ($daysLeftLabel).',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!isExpired) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  CorrectionRequestDialogMobile.show(
                    context,
                    date: missedDate,
                    attendanceId: null,
                    type: CorrectionType.missedPunch,
                  ).then((_) => provider.clearMissedPunch());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFEA580C),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Fix Now',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
          isLoading: _isTimeInProcessing,
          onTap: () {
            if (isCheckedIn) {
              context.showToast("You have already checked in.", isWarning: true);
            } else {
              _handleAttendanceAction(true);
            }
          },
        ),
        const SizedBox(height: 16),
        _buildLargeActionButton(
          context,
          label: 'Time Out',
          subLabel: isCheckedIn ? 'End current shift' : 'No active session',
          icon: Icons.logout_rounded,
          color: const Color(0xFFEF4444),
          isActive: isCheckedIn,
          isLoading: _isTimeOutProcessing,
          onTap: () {
            if (!isCheckedIn) {
              context.showToast("You have already checked out.", isWarning: true);
            } else {
              _handleAttendanceAction(false);
            }
          },
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
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canTap = isActive && !_isProcessing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canTap ? onTap : null,
      child: GlassContainer(
        width: double.infinity,
        borderRadius: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isActive || isLoading) ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          )
                        : Icon(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label, 
                          style: GoogleFonts.poppins(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: isDark 
                                ? (isActive || isLoading ? Colors.white : Colors.white38) 
                                : (isActive || isLoading ? Colors.black87 : Colors.black38),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoading ? 'Processing punch...' : subLabel, 
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
                    color: isDark 
                        ? (isActive && !isLoading ? Colors.white38 : Colors.white10) 
                        : (isActive && !isLoading ? Colors.grey[400] : Colors.grey[200]),
                  ),
                ],
              ),
            ),
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
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black12),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
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
            CorrectionRequestDialogMobile.show(
              context,
              date: _selectedDate,
              attendanceId: attendanceId,
              type: CorrectionType.correction,
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E38) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
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
      final dt = DateTime.parse(isoTime).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return 'Err'; 
    }
  }

  Widget _buildSessionCard(BuildContext context, AttendanceRecord record) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Time In
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator Dot + Line
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 36,
                    color: Colors.grey.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Time & Address
              Expanded(
                child: _buildTimeInfo(
                  context,
                  time: 'TIME IN - ${_formatTime(record.timeIn)}',
                  location: record.timeInAddress ?? 'Unknown Address',
                ),
              ),
              const SizedBox(width: 8),
              // Avatar
              _buildAvatar(context, record.timeInImage),
            ],
          ),
          
          // Row 2: Time Out / Active State
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator Dot
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: record.timeOut != null ? Colors.red : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Time & Address / Currently Active
              Expanded(
                child: record.timeOut != null
                    ? _buildTimeInfo(
                        context,
                        time: 'TIME OUT - ${_formatTime(record.timeOut)}',
                        location: record.timeOutAddress ?? 'Unknown Address',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TIME OUT',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Currently Active',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              // Avatar (Only if checked out)
              if (record.timeOut != null)
                _buildAvatar(context, record.timeOutImage)
              else
                const SizedBox(width: 40, height: 40),
            ],
          ),
        ],
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
            fontSize: 13, 
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
          )
        ),
        const SizedBox(height: 4),
        Text(
          location, 
          style: GoogleFonts.poppins(
            fontSize: 11, 
            color: Colors.grey, 
            height: 1.3
          )
        ),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: CachedNetworkImage(
            imageUrl: imageUrl, 
            fit: BoxFit.cover,
            errorWidget: (_,_,_) => const Icon(Icons.person, color: Colors.white),
            placeholder: (_,_) => const Center(child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
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
