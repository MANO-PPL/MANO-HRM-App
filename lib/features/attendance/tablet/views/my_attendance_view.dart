import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/network_monitor.dart';
import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import '../widgets/correction_request_dialog.dart';
import '../../models/correction_request.dart'; // Added
import '../../widgets/late_arrival_dialog.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../widgets/attendance_history_tab.dart';
import '../../widgets/attendance_analytics_tab.dart';
import '../../providers/attendance_provider.dart'; // Import Provider
import '../../admin/views/admin_correction_requests.dart';
import '../../widgets/attendance_header_widget.dart';
import '../../../../shared/widgets/interactive_image_viewer.dart';
import '../../../../shared/widgets/loading_screen.dart';
import '../../../../shared/widgets/selfie_camera_screen.dart';
import '../../../../shared/services/attendance_image_cache_manager.dart';

class MyAttendanceView extends StatefulWidget {
  const MyAttendanceView({super.key});

  @override
  State<MyAttendanceView> createState() => _MyAttendanceViewState();
}

class _MyAttendanceViewState extends State<MyAttendanceView> with WidgetsBindingObserver {
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
    
    // Initial Fetch via Provider
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
      debugPrint('Attendance location flow (tablet): $stage took ${stopwatch.elapsedMilliseconds} ms');
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
      debugPrint('Attendance location flow (tablet): total took ${locationStopwatch.elapsedMilliseconds} ms');
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
        debugPrint('Attendance location flow (tablet): total took ${locationStopwatch.elapsedMilliseconds} ms');
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
      debugPrint('Attendance location flow (tablet): total took ${locationStopwatch.elapsedMilliseconds} ms');
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
      var provider = context.read<AttendanceProvider>();
      var shiftPolicy = provider.shiftPolicy;
      if (shiftPolicy == null) {
        await provider.fetchShiftPolicy();
        shiftPolicy = provider.shiftPolicy;
      }

      final isSelfieRequired = isTimeIn
          ? (shiftPolicy?.entrySelfie ?? false)
          : (shiftPolicy?.exitSelfie ?? false);

      XFile? photo;
      if (isSelfieRequired) {
        final cameraPermissionStopwatch = Stopwatch()..start();
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (status.isPermanentlyDenied) {
            if (mounted) {
               CustomDialog.show(
                 context: context,
                 title: "Permission Required",
                 message: "Camera access is needed to mark attendance. Please enable it in settings.",
                 positiveButtonText: "Open Settings",
                 onPositivePressed: () {
                   openAppSettings();
                 },
                 negativeButtonText: "Cancel",
                 onNegativePressed: () {},
                 icon: Icons.camera_alt_outlined,
               );
            }
            logStage('camera permission', cameraPermissionStopwatch);
            setState(() {
              _isProcessing = false;
              _isTimeInProcessing = false;
              _isTimeOutProcessing = false;
            });
            return;
          }
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
        try {
          photo = await _picker.pickImage(
            source: ImageSource.camera, 
            preferredCameraDevice: CameraDevice.front,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 70,
          );
        } catch (e) {
          debugPrint('ImagePicker failed, fallback to SelfieCameraScreen: $e');
        }

        if (photo == null && mounted) {
          try {
            photo = await Navigator.push<XFile?>(
              context,
              MaterialPageRoute(builder: (_) => const SelfieCameraScreen()),
            );
          } catch (e) {
            debugPrint('SelfieCameraScreen failed: $e');
          }
        }
        logStage('camera capture', cameraCaptureStopwatch);
        
        if (photo == null) {
          setState(() {
            _isProcessing = false;
            _isTimeInProcessing = false;
            _isTimeOutProcessing = false;
          });
          return; // User canceled
        }
      }

      if (!mounted) return;

      // Await location in parallel
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
        return; // error shown in _getCurrentLocation
      }

      if (!mounted) return;

      final punchTimestamp = DateTime.now().toIso8601String();

      Future<void> performTimeIn({String? reason}) async {
         await _attendanceService.timeIn(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              imageFile: photo != null ? File(photo.path) : null,
              lateReason: reason,
              timestamp: punchTimestamp,
           );
      }

      // 3. Submit Online
      try {
        if (isTimeIn) {
          try {
           final apiStopwatch = Stopwatch()..start();
             await performTimeIn(); // Try without reason first
           logStage('Time In API call', apiStopwatch);
          } catch (e) {
             final msg = e.toString().toLowerCase();
             if (msg.contains("reason") || 
                 msg.contains("late") || 
                 msg.contains("remark") ||
                 msg.contains("lateness")) {
                if (!mounted) return;

                final reason = await LateArrivalDialog.show(context);
                
                if (reason != null && reason.isNotEmpty) {
                   if (!mounted) return;
                   try {
                     await performTimeIn(reason: reason); // Retry
                   } catch (retryErr) {
                     rethrow;
                   }
                   if (mounted) {
                     context.showToast("Late arrival reason submitted successfully.", isSuccess: true);
                   }
                } else {
                   setState(() {
                     _isProcessing = false;
                     _isTimeInProcessing = false;
                     _isTimeOutProcessing = false;
                   });
                   return; // Cancelled
                }
             } else {
               rethrow;
             }
          }
        } else {
          final apiStopwatch = Stopwatch()..start();
          await _attendanceService.timeOut(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: photo != null ? File(photo.path) : null,
            timestamp: punchTimestamp,
          );
          logStage('Time Out API call', apiStopwatch);
        }
        
        if (mounted) {
          context.showToast(
            isTimeIn ? "Checked in successfully!" : "Checked out successfully!",
            isSuccess: true,
          );

          // 1. Await today's record loading
          await Provider.of<AttendanceProvider>(context, listen: false)
              .fetchRecords(DateTime.now(), forceRefresh: true);
          // 2. Start background sync for geocoding and image loading
          if (mounted) {
            Provider.of<AttendanceProvider>(context, listen: false).startRealtimeSync(DateTime.now());
          }
        }
      } catch (e) {
        if (mounted) {
          context.showExceptionToast(
            e,
            fallback: isTimeIn
                ? 'Failed to clock in. Please try again.'
                : 'Failed to clock out. Please try again.',
          );
        }
      }
    } catch (e) {
       if (mounted) {
         context.showExceptionToast(e, fallback: 'Camera error. Please try again.');
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        return LoadingScreen(
          isLoading: provider.isLoading && provider.records.isEmpty,
          message: "Loading attendance records...",
          child: DefaultTabController(
            length: 2,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const AttendanceHeaderWidget(showTabBar: false),
                  // Render the tab bar separately so it remains above the body and accepts taps
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Center(child: AttendanceTabBar(maxWidth: 480)),
                  ),
                  Builder(
                    builder: (context) {
                      final tabController = DefaultTabController.of(context);

                      return _TabContentBuilder(
                        controller: tabController,
                        builder: (context, index) {
                          final records = provider.records;
                          final isLoading = provider.isLoading;

                          bool isCheckedIn = false;
                          if (records.isNotEmpty) {
                            isCheckedIn = records.any((r) => r.timeOut == null);
                          }

                          if (index == 0) {
                            final missedDate = provider.missedPunchDate;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (missedDate != null) ...[
                                    _buildMissedPunchBanner(context, missedDate, provider),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildActionButtons(context, isCheckedIn),
                                  const SizedBox(height: 32),
                                  _buildDateSelector(context),
                                  const SizedBox(height: 16),
                                  _buildHistoryList(context, records, isLoading),
                                ],
                              ),
                            );
                          } else {
                            return const _MyAttendanceReportsTab();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildActionButtons(BuildContext context, bool isCheckedIn) {
    // Stacked vertically as requested using Glass Cards
    return Column(
      children: [
        // Time In Button
        _buildLargeActionButton(
          context,
          label: 'Time In',
          subLabel: isCheckedIn ? 'You are currently checked in' : 'Start your shift',
          icon: Icons.login,
          color: const Color(0xFF10B981), // Green
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
        // Time Out Button
        _buildLargeActionButton(
          context,
          label: 'Time Out',
          subLabel: isCheckedIn ? 'End current shift' : 'Not checked in',
          icon: Icons.logout,
          color: const Color(0xFFEF4444), // Red
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
    final bool canTap = isActive && !_isProcessing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canTap ? onTap : null,
      child: GlassContainer(
        height: 100,
        width: double.infinity,
        borderRadius: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (isActive || isLoading) ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          )
                        : Icon(
                            icon,
                            color: isActive ? color : color.withValues(alpha: 0.7),
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: (isActive || isLoading) ? 1.0 : 0.5),
                        ),
                      ),
                      Text(
                        isLoading ? 'Processing punch...' : subLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (isActive && !isLoading)
                    Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodySmall?.color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Row(
      children: [
        Text(
          'Todays Activity',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const Spacer(),
        // Correction Button (ADDED)
             // Correction Button 
             // Same as Mobile, removing complex logic or relying on global/passed state if needed.
             // For now just triggering dialog which needs id.
             // We can get ID from provider inside default dialog if current day.
             // But simpler to just show for now with null ID or handle internally.
             InkWell(
                onTap: () {
                  // Get records from Provider directly if needed, or pass them down.
                  final provider = Provider.of<AttendanceProvider>(context, listen: false);
                  final records = provider.records;
                  final attendanceId = records.isNotEmpty ? records.first.attendanceId : null;
                  CorrectionRequestDialog.show(
                    context,
                    date: _selectedDate,
                    attendanceId: attendanceId,
                    type: CorrectionType.correction,
                  );
                },
                child: GlassContainer(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text('Correction', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
             ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () async {
            await showDialog(
              context: context,
              builder: (context) => GlassDatePicker(
                isLarge: true, // Larger for tablet
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
          child: GlassContainer(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today, 
                  size: 14, 
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Theme.of(context).primaryColor
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList(BuildContext context, List<AttendanceRecord> records, bool isLoading) {
    if (isLoading && records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (records.isEmpty) {
      return Center(
        child: Text(
          "No records for this date",
          style: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 16
          )
        )
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildSessionCard(context, records[index]);
      },
    );
  }

  Widget _buildSessionCard(BuildContext context, AttendanceRecord record) {
    final statusColor = record.status == 'ABSENT' ? Colors.red : Colors.green; // Logic can be improved
    final statusText = record.timeOut == null ? "Running" : "Completed"; 

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session Indicator Strip
            Container(
              width: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history, size: 18, color: statusColor),
                   const SizedBox(height: 4),
                   RotatedBox(
                     quarterTurns: 3,
                     child: Text(
                       statusText,
                       style: GoogleFonts.poppins(
                         fontSize: 10,
                         fontWeight: FontWeight.w600,
                         color: statusColor,
                         letterSpacing: 0.5,
                       ),
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // In & Out Columns
            Expanded(
              child: Row(
                children: [
                   // IN PUNCH
                   Expanded(
                     child: _buildPunchBlock(
                       context, 
                       type: 'TIME IN', 
                       time: _formatTime(record.timeIn), 
                       location: record.timeInAddress ?? 'Unknown', 
                       imageUrl: record.timeInImage,
                       icon: Icons.login,
                       accentColor: const Color(0xFF10B981),
                     ),
                   ),
                   
                   // Divider / Connector
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 12),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.arrow_forward, size: 16, color: Colors.grey.withValues(alpha: 0.5)),
                         const SizedBox(height: 4),
                         Text(
                           "View", 
                           style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                         )
                       ],
                     ),
                   ),
      
                   // OUT PUNCH
                   Expanded(
                     child: record.timeOut != null 
                       ? _buildPunchBlock(
                           context, 
                           type: 'TIME OUT', 
                           time: _formatTime(record.timeOut), 
                           location: record.timeOutAddress ?? 'Unknown Location', 
                           imageUrl: record.timeOutImage,
                           icon: Icons.logout,
                           accentColor: const Color(0xFFEF4444),
                         )
                       : _buildActivePlaceholder(context),
                   ),
                ],
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

  Widget _buildPunchBlock(BuildContext context, {
    required String type,
    required String time,
    required String location,
    required String? imageUrl,
    required IconData icon,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => _showPunchDetails(
        context,
        type: type,
        time: time,
        location: location,
        imageUrl: imageUrl,
        icon: icon,
        accentColor: accentColor,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white, // Use White instead of grey[100] for cleaner look
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)), // Increased from 0.1
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Icon(icon, size: 12, color: accentColor),
                ),
                const SizedBox(width: 6),
                Text(
                  type,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Avatar / Photo Placeholder
                GestureDetector(
                  onTap: imageUrl != null && imageUrl.isNotEmpty ? () {
                    InteractiveImageViewerDialog.show(context, imageUrl, title: "$type Image");
                  } : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black, // Dark background for photos
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            cacheManager: AttendanceImageCacheManager.instance,
                            fit: BoxFit.contain, // best for no cropping
                            placeholder: (context, url) => const Icon(Icons.person, size: 20, color: Colors.grey),
                            errorWidget: (context, url, error) => const Icon(Icons.person_off, size: 20, color: Colors.grey),
                          )
                        : Icon(Icons.person, size: 24, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      Text(
                        location,
                        style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlaceholder(BuildContext context) {
     return DottedBorderContainer(
       child: Center(
         child: Text(
           'On Shift',
           style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
         ),
       ),
     );
  }
  void _showPunchDetails(
    BuildContext context, {
    required String type,
    required String time,
    required String location,
    required String? imageUrl,
    required IconData icon,
    required Color accentColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        alignment: Alignment.bottomCenter,
        child: GlassContainer(
          width: 400,
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: accentColor.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Icon(icon, color: accentColor),
                   ),
                   const SizedBox(width: 16),
                   Text(
                     type,
                     style: GoogleFonts.poppins(
                       fontSize: 20,
                       fontWeight: FontWeight.bold,
                       color: Theme.of(context).textTheme.bodyLarge?.color,
                     ),
                   ),
                   const Spacer(),
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: const Icon(Icons.close),
                   ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Image
              if (imageUrl != null && imageUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => InteractiveImageViewerDialog.show(context, imageUrl, title: "$type Image"),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheManager: AttendanceImageCacheManager.instance,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.image_not_supported, size: 40, color: Theme.of(context).disabledColor),
                ),
                
              const SizedBox(height: 24),
              
              // Time & Location
              _buildDetailRow(context, Icons.access_time, 'Time', time),
              const SizedBox(height: 16),
              _buildDetailRow(context, Icons.place_outlined, 'Location', location),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              Text(
                value, 
                style: GoogleFonts.poppins(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
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
              CorrectionRequestDialog.show(
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
                  CorrectionRequestDialog.show(
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
}



class _MyAttendanceReportsTab extends StatefulWidget {
  const _MyAttendanceReportsTab();

  @override
  State<_MyAttendanceReportsTab> createState() => _MyAttendanceReportsTabState();
}

class _MyAttendanceReportsTabState extends State<_MyAttendanceReportsTab> {
  int _selectedIndex = 0; // 0: History, 1: Analytics, 2: Corrections

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSubTab('History', 0, Icons.history),
              const SizedBox(width: 32),
              _buildSubTab('Analytics', 1, Icons.analytics_outlined),
              const SizedBox(width: 32),
              _buildSubTab('Corrections', 2, Icons.edit_calendar_outlined),
            ],
          ),
        ),
        
        // Content
        _selectedIndex == 0 
          ? const AttendanceHistoryTab(shrinkWrap: true, physics: NeverScrollableScrollPhysics()) 
          : _selectedIndex == 1
            ? const AttendanceAnalyticsTab(shrinkWrap: true, physics: NeverScrollableScrollPhysics())
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AdminCorrectionRequests(
                  isPersonalView: true,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              ),
      ],
    );
  }

  Widget _buildSubTab(String label, int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Standardized Tab Colors
    final selectedColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
    final unselectedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final activeColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: activeColor),
              const SizedBox(width: 8),
              Text(
                label, 
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, 
                  color: activeColor
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 80,
            color: isSelected ? selectedColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  const DottedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.none), 
      ),
      child: Container(
         decoration: BoxDecoration(
           border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1), 
           borderRadius: BorderRadius.circular(12),
         ),
         child: child,
      ),
    );
  }
}

class _TabContentBuilder extends StatefulWidget {
  final TabController controller;
  final Widget Function(BuildContext context, int index) builder;

  const _TabContentBuilder({
    required this.controller,
    required this.builder,
  });

  @override
  State<_TabContentBuilder> createState() => _TabContentBuilderState();
}

class _TabContentBuilderState extends State<_TabContentBuilder> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.index;
    widget.controller.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(_TabContentBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleTabChange);
      _currentIndex = widget.controller.index;
      widget.controller.addListener(_handleTabChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (widget.controller.index != _currentIndex) {
      setState(() {
        _currentIndex = widget.controller.index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentIndex);
  }
}
