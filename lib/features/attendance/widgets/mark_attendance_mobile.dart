import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/widgets/glass_date_picker.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/services/network_monitor.dart';
import 'package:flutter_application/shared/services/local_notification_service.dart';
import 'package:flutter_application/features/attendance/core/attendance_record.dart';
import 'package:flutter_application/features/attendance/core/attendance_service.dart';
import 'package:flutter_application/features/attendance/widgets/late_arrival_dialog_mobile.dart';
import 'package:flutter_application/features/attendance/widgets/correction_request_dialog_mobile.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart'; // Added
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/widgets/interactive_image_viewer.dart';

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
  bool _isCheckpointProcessing = false;
  StreamSubscription<Position>? _positionStreamSub;
  Position? _realtimePosition;
  DateTime? _lastResumeFetchTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = Provider.of<AuthService>(context, listen: false);
    _attendanceService = AttendanceService(auth.dio);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
      attProvider.fetchRecords(_selectedDate);
      attProvider.fetchShiftPolicy();
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
      final now = DateTime.now();
      if (_lastResumeFetchTime == null || now.difference(_lastResumeFetchTime!) > const Duration(seconds: 60)) {
        _lastResumeFetchTime = now;
        _fetchRecords(silent: true);
      }
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

  Future<void> _fetchRecords({bool silent = false}) async {
    await Provider.of<AttendanceProvider>(context, listen: false)
        .fetchRecords(_selectedDate, forceRefresh: false, silentRefresh: silent);
  }

  Future<Position?> _getCurrentLocation() async {
    void logLocationStage(String stage, Stopwatch stopwatch) {
      debugPrint('Attendance location flow (mobile): $stage took ${stopwatch.elapsedMilliseconds} ms');
    }

    final serviceCheckStopwatch = Stopwatch()..start();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    logLocationStage('location service check', serviceCheckStopwatch);

    if (!serviceEnabled) {
      if (mounted) {
        context.showToast(
          "Location services disabled. Please enable GPS.",
          isError: true,
          actionLabel: "SETTINGS",
          onActionPressed: () async {
            await Geolocator.openLocationSettings();
          },
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          context.showToast("Location permission is required to mark attendance.", isWarning: true);
        }
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

    // 1. Try last known position FIRST. If it is fresh (under 45 seconds & good accuracy), use it immediately for instant retrieval.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age.inSeconds < 45 && lastKnown.accuracy <= 100) {
          debugPrint("Using fresh last known position: age=${age.inSeconds}s, accuracy=${lastKnown.accuracy}m");
          return lastKnown;
        }
      }
    } catch (e) {
      debugPrint("Error checking last known location: $e");
    }

    // 2. Otherwise, fetch high accuracy with a reasonable timeout (4 seconds)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
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
            timeLimit: Duration(seconds: 3),
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
      var provider = context.read<AttendanceProvider>();
      var shiftPolicy = provider.shiftPolicy;
      if (shiftPolicy == null) {
        await provider.fetchShiftPolicy();
        shiftPolicy = provider.shiftPolicy;
      }

      final isSelfieRequired = isTimeIn
          ? (shiftPolicy?.entrySelfie ?? true)
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
            if (mounted) {
              context.showToast('Camera permission is required for ${isTimeIn ? "Time In" : "Time Out"}.', isError: true);
            }
            return;
          }
        }
        logStage('camera permission', cameraPermissionStopwatch);

        final cameraCaptureStopwatch = Stopwatch()..start();
        try {
          photo = await _picker.pickImage(
            source: ImageSource.camera, 
            preferredCameraDevice: CameraDevice.front,
          );
        } catch (e) {
          debugPrint('ImagePicker failed: $e');
        }
        logStage('camera capture', cameraCaptureStopwatch);
        
        if (photo == null) {
          setState(() {
            _isProcessing = false;
            _isTimeInProcessing = false;
            _isTimeOutProcessing = false;
          });
          if (mounted) {
            context.showToast('Attendance cancelled: Selfie not captured.', isWarning: true);
          }
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
      // 1. Await today's record loading silently so existing cards do not flicker
      await Provider.of<AttendanceProvider>(context, listen: false)
          .fetchRecords(DateTime.now(), forceRefresh: true, silentRefresh: true);
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
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
          children: [
            // 0. Missed Punch Warning Banner
            if (missedDate != null) ...[
              _buildMissedPunchBanner(context, missedDate, provider),
              const SizedBox(height: 8),
            ],

            // 1. Action Buttons
            _buildActionButtons(context, isCheckedIn),
            const SizedBox(height: 10),
            
            // 2. Select Date Header
            _buildSelectDateHeader(context),
            const SizedBox(height: 6),
            
            // 3. Horizontal Date Scroller
            _buildHorizontalDateScroller(context),
            const SizedBox(height: 10),
            
            // 4. Logs Header (with + Correction)
            _buildLogsHeader(context, records),
            const SizedBox(height: 8),
            
            // 5. Logs List or Empty State
            if (isLoading && records.isEmpty)
               const Center(child: Padding(
                 padding: EdgeInsets.symmetric(vertical: 40),
                 child: CircularProgressIndicator(),
               ))
            else if (records.isEmpty)
               _buildEmptyState(context)
            else
               ...records.map((record) => Padding(
                 padding: const EdgeInsets.only(bottom: 8),
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
                    isExpired ? 'Missed Punch - Deadline Passed' : 'Missed Time-Out Detected',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
                  'Request Corrections',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCheckpointModal() async {
    if (!NetworkMonitor().isOnline) {
      if (mounted) {
        context.showToast("No internet connection. Offline checkpoint is disabled.", isError: true);
      }
      return;
    }

    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    var shiftPolicy = provider.shiftPolicy;
    if (shiftPolicy == null) {
      setState(() => _isCheckpointProcessing = true);
      try {
        await provider.fetchShiftPolicy();
        shiftPolicy = provider.shiftPolicy;
      } finally {
        if (mounted) setState(() => _isCheckpointProcessing = false);
      }
    }

    if (shiftPolicy != null && !shiftPolicy.checkpointEnabled) {
      if (mounted) {
        context.showToast('Checkpoints are disabled by your shift policy.', isWarning: true);
      }
      return;
    }

    final bool isSelfieRequired = shiftPolicy?.checkpointSelfie ?? false;

    // Immediately kick off parallel background GPS resolution
    final Future<Position?> locationFuture = _getCurrentLocation();

    if (!mounted) return;
    _openCheckpointBottomSheet(
      isSelfieRequired: isSelfieRequired,
      locationFuture: locationFuture,
    );
  }

  void _openCheckpointBottomSheet({
    required bool isSelfieRequired,
    required Future<Position?> locationFuture,
  }) {
    bool isSubmitting = false;
    XFile? capturedPhoto;
    String? selectedPreset;
    final noteController = TextEditingController();
    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    final List<String> presetChips = [
      'Client Visit',
      'Site Work',
      'Meeting',
      'In Transit',
      'Head Office',
      'Delivery',
    ];

    Future<void> submitCheckpoint(
      BuildContext ctx,
      StateSetter setModalState, {
      XFile? photo,
    }) async {
      final photoFile = photo ?? capturedPhoto;
      if (isSelfieRequired && photoFile == null) {
        if (ctx.mounted) {
          ctx.showToast('Selfie is required to mark checkpoint.', isWarning: true);
        }
        return;
      }

      setModalState(() => isSubmitting = true);
      try {
        // Await pre-warmed GPS resolution
        Position? pos;
        try {
          pos = await locationFuture.timeout(const Duration(seconds: 4));
        } catch (_) {}
        pos ??= _realtimePosition;
        if (pos == null) {
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (_) {}
        }

        if (pos == null) {
          if (ctx.mounted) {
            ctx.showToast('Unable to acquire GPS location. Please check location settings.', isError: true);
          }
          setModalState(() => isSubmitting = false);
          return;
        }

        final noteText = noteController.text.trim();
        await provider.markCheckpoint(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          note: noteText.isEmpty ? null : noteText,
          imageFile: photoFile != null ? File(photoFile.path) : null,
        );

        HapticFeedback.heavyImpact();
        if (ctx.mounted) {
          Navigator.of(ctx).pop();
        }
        if (mounted) {
          context.showToast('Checkpoint marked successfully!');
        }
      } catch (e) {
        if (ctx.mounted) {
          ctx.showToast('Failed to mark checkpoint: ${e.toString().replaceAll("Exception: ", "")}', isError: true);
        }
      } finally {
        if (ctx.mounted) {
          setModalState(() => isSubmitting = false);
        }
      }
    }

    Future<void> handleCameraAndSubmit(
      BuildContext ctx,
      StateSetter setModalState,
    ) async {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!status.isGranted) {
        if (ctx.mounted) {
          ctx.showToast('Camera permission is required for checkpoint selfie.', isError: true);
        }
        return;
      }

      XFile? photo;
      try {
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
        );
      } catch (e) {
        debugPrint('Checkpoint camera error: $e');
      }

      if (photo != null) {
        if (!ctx.mounted) return;
        setModalState(() => capturedPhoto = photo);
        // Instant auto-submit on camera capture
        await submitCheckpoint(ctx, setModalState, photo: photo);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.my_location_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Checkpoint',
                              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Time: ${DateFormat('hh:mm a').format(DateTime.now())}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Live GPS Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33232644) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _realtimePosition != null
                                  ? 'GPS Ready (±${_realtimePosition!.accuracy.toInt()}m)'
                                  : 'GPS Active',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Note Label
                  Text(
                    'QUICK NOTE (TAP TO SELECT)',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Note Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetChips.map((preset) {
                      final isSelected = selectedPreset == preset;
                      return InkWell(
                        onTap: isSubmitting
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  if (isSelected) {
                                    selectedPreset = null;
                                    noteController.clear();
                                  } else {
                                    selectedPreset = preset;
                                    noteController.text = preset;
                                  }
                                });
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                preset,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Custom Note Input
                  TextField(
                    controller: noteController,
                    maxLines: 1,
                    onChanged: (val) {
                      if (selectedPreset != null && val != selectedPreset) {
                        setModalState(() => selectedPreset = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Or type custom note...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.25)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.grey),
                      suffixIcon: noteController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                setModalState(() {
                                  noteController.clear();
                                  selectedPreset = null;
                                });
                              },
                            )
                          : null,
                    ),
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  // Selfie Info / Preview Tile if required
                  if (isSelfieRequired) ...[
                    if (capturedPhoto != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(capturedPhoto!.path),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selfie Captured',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    'Ready to submit',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      await handleCameraAndSubmit(ctx, setModalState);
                                    },
                              icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF6366F1)),
                              label: Text(
                                'Retake',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Camera will open automatically on submit',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],

                  // Submit Action Button
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (isSelfieRequired && capturedPhoto == null) {
                              await handleCameraAndSubmit(ctx, setModalState);
                            } else {
                              await submitCheckpoint(ctx, setModalState);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    ),
                    child: isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Recording Checkpoint...',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSelfieRequired && capturedPhoto == null
                                    ? Icons.camera_alt_rounded
                                    : Icons.check_circle_rounded,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isSelfieRequired && capturedPhoto == null
                                    ? 'Snap Selfie & Submit'
                                    : 'Mark Checkpoint Now',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
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
        const SizedBox(height: 7),
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
        const SizedBox(height: 7),
        _buildLargeActionButton(
          context,
          label: 'Checkpoint',
          subLabel: isCheckedIn ? 'Mark your current location' : 'Check in first',
          icon: Icons.location_on_rounded,
          color: const Color(0xFF6366F1),
          isActive: isCheckedIn, 
          isLoading: _isCheckpointProcessing,
          onTap: () {
            if (!isCheckedIn) {
              context.showToast('Please check in first.', isWarning: true);
            } else {
              _showCheckpointModal();
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
        borderRadius: 14,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (isActive || isLoading) ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          )
                        : Icon(
                            icon, 
                            color: isActive ? color : Colors.grey, 
                            size: 20
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label, 
                          style: GoogleFonts.poppins(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600, 
                            color: isDark 
                                ? (isActive || isLoading ? Colors.white : Colors.white38) 
                                : (isActive || isLoading ? Colors.black87 : Colors.black38),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isLoading ? 'Processing punch...' : subLabel, 
                          style: GoogleFonts.poppins(
                            fontSize: 10, 
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right, 
                    size: 18,
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
            fontWeight: FontWeight.w600,
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
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
                _fetchRecords();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 68,
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black12),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
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
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFFC7D2FE)
                                : Colors.grey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayNum,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
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
                fontWeight: FontWeight.w600,
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
                  'Request Corrections',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 14,
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
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 24,
                    color: Colors.grey.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Time & Address
              Expanded(
                child: _buildTimeInfo(
                  context,
                  time: 'TIME IN - ${_formatTime(record.timeIn)}',
                  location: record.timeInAddress ?? 'Unknown Address',
                ),
              ),
              // Avatar (Only if image is present)
              if (record.timeInImage != null && record.timeInImage!.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                _buildAvatar(context, record.timeInImage, title: "Time In Selfie"),
              ],
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
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: record.timeOut != null ? Colors.red : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
              ),
              // Avatar (Only if checked out and image is present)
              if (record.timeOut != null && record.timeOutImage != null && record.timeOutImage!.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                _buildAvatar(context, record.timeOutImage, title: "Time Out Selfie"),
              ],
            ],
          ),

          // Checkpoints Section in Today's Log
          if (record.checkpoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E38).withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CHECKPOINTS (${record.checkpoints.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...record.checkpoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cp = entry.value;
                    final timeStr = _formatTime(cp.time);
                    final locStr = (cp.address != null && cp.address!.isNotEmpty)
                        ? cp.address!
                        : (cp.latitude != null && cp.longitude != null)
                            ? '${cp.latitude!.toStringAsFixed(4)}, ${cp.longitude!.toStringAsFixed(4)}'
                            : 'Location recorded';

                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (cp.imageUrl != null && cp.imageUrl!.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Selfie',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  locStr,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (cp.note != null && cp.note!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '"${cp.note!}"',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (cp.imageUrl != null && cp.imageUrl!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildAvatar(context, cp.imageUrl, title: "Checkpoint #${index + 1} Photo"),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
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
            fontWeight: FontWeight.w600,
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

  Widget _buildAvatar(BuildContext context, String? imageUrl, {String title = "Attendance Image"}) {
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        return const SizedBox.shrink();
      }

      final cleanUrl = imageUrl.trim();

      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => InteractiveImageViewerDialog.show(context, cleanUrl, title: title),
        child: Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: cleanUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                  ),
                ),
                errorWidget: (context, url, err) => Image.network(
                  cleanUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, st) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 20),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_red_eye, size: 10, color: Colors.white70),
                ),
              ),
            ],
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

// [mod:2026-02-17T14:00:00+05:30]

// [upd:2026-05-06T17:00:00+05:30]
