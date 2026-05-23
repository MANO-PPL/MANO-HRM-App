import 'dart:io';
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
import '../../models/attendance_record.dart';
import '../../services/attendance_service.dart';
import '../widgets/correction_request_dialog.dart';
import '../../widgets/late_arrival_dialog.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../widgets/attendance_history_tab.dart';
import '../../widgets/attendance_analytics_tab.dart';
import '../../providers/attendance_provider.dart'; // Import Provider
import '../../admin/views/admin_correction_requests.dart';
import '../../widgets/attendance_header_widget.dart';
import '../../../../shared/widgets/interactive_image_viewer.dart';

class MyAttendanceView extends StatefulWidget {
  const MyAttendanceView({super.key});

  @override
  State<MyAttendanceView> createState() => _MyAttendanceViewState();
}

class _MyAttendanceViewState extends State<MyAttendanceView> {
  late AttendanceService _attendanceService;
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _attendanceService = AttendanceService(auth.dio);
    
    // Initial Fetch via Provider
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
    // 1. Get Location
    final position = await _getCurrentLocation();
    if (position == null) return;

    // 1. Permission Check with Settings Prompt
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
        return;
      }
      if (!status.isGranted) return; // Denied but not permanently
    }

    // 2. Capture Selfie (System Camera)
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, 
        preferredCameraDevice: CameraDevice.front,
      );
      
      if (photo == null) return; // User canceled

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      Future<void> performTimeIn({String? reason}) async {
         await _attendanceService.timeIn(
             latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: File(photo.path),
            lateReason: reason,
          );
      }

      // 3. Submit
      try {
        if (isTimeIn) {
          try {
             await performTimeIn(); // Try without reason first
          } catch (e) {
             final msg = e.toString().toLowerCase();
             // Check for specific error message or key keywords
             if (msg.contains("reason' is required") || 
                 msg.contains("late_reason") || 
                 msg.contains("reason is required") ||
                 msg.contains("late time in")) {
                // Show Input Dialog
                if (!mounted) return;
                Navigator.pop(context); // Hide loading
                
                final reason = await LateArrivalDialog.show(context);
                
                if (reason != null && reason.isNotEmpty) {
                   if (!mounted) return;
                   showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                   );
                   await performTimeIn(reason: reason); // Retry
                   if (mounted) {
                     context.showToast("Late arrival reason submitted successfully.", isSuccess: true);
                   }
                } else {
                   return; // Cancelled
                }
             } else {
               rethrow;
             }
          }
        } else {
          await _attendanceService.timeOut(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            imageFile: File(photo.path),
          );
        }
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          
          // Show toaster
          context.showToast(
            isTimeIn ? "Checked in successfully!" : "Checked out successfully!",
            isSuccess: true,
          );

          Provider.of<AttendanceProvider>(context, listen: false).invalidateCache(DateTime.now());
          _fetchRecords(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          context.showToast("Failed: $e", isError: true);
        }
      }
    } catch (e) {
       if (mounted) {
         context.showToast("Camera Error: $e", isError: true);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final _records = provider.records;
        final _isLoading = provider.isLoading;

        // Determine active state for buttons based on last record
        bool isCheckedIn = false;
        if (_records.isNotEmpty) {
          final activeRecord = _records.any((r) => r.timeOut == null);
          isCheckedIn = activeRecord;
        }

        return DefaultTabController(
          length: 2,
              child: Column(
            children: [
              AttendanceHeaderWidget(showTabBar: false),
              // Render the tab bar separately so it remains above the body and accepts taps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Center(child: AttendanceTabBar(maxWidth: 480)),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Mark Attendance
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActionButtons(context, isCheckedIn),
                          const SizedBox(height: 32),
                          _buildDateSelector(context),
                          const SizedBox(height: 16),
                          _buildHistoryList(context, _records, _isLoading), // No Expanded
                        ],
                      ),
                    ),

                    // Tab 2: My Attendance Reports
                    const _MyAttendanceReportsTab(),
                  ],
                ),
              ),
            ],
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
          onTap: () => _handleAttendanceAction(true),
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
    return InkWell(
      onTap: isActive ? onTap : null, // Fix: Disable tap if not active
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        height: 100,
        width: double.infinity,
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isActive ? color : color.withOpacity(0.7),
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
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(isActive ? 1.0 : 0.5),
                    ),
                  ),
                  Text(
                    subLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isActive)
                Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodySmall?.color),
            ],
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
                  CorrectionRequestDialog.show(context, date: _selectedDate, attendanceId: attendanceId);
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                color: statusColor.withOpacity(0.1),
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
                         Icon(Icons.arrow_forward, size: 16, color: Colors.grey.withOpacity(0.5)),
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
      final dt = DateTime.parse(isoTime);
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
          border: Border.all(color: accentColor.withOpacity(0.3)), // Increased from 0.1
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
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
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain, // best for no cropping
                            placeholder: (context, url) => const Icon(Icons.person, size: 20, color: Colors.grey),
                            errorWidget: (context, url, error) => const Icon(Icons.person_off, size: 20, color: Colors.grey),
                          )
                        : Icon(Icons.person, size: 24, color: Colors.white.withOpacity(0.8)),
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
                      Row(
                        children: [
                          Icon(Icons.place, size: 10, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color),
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
                       color: accentColor.withOpacity(0.1),
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
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
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
                    color: Theme.of(context).disabledColor.withOpacity(0.1),
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
        Expanded(
          child: _selectedIndex == 0 
            ? const AttendanceHistoryTab() 
            : _selectedIndex == 1
              ? const AttendanceAnalyticsTab()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const AdminCorrectionRequests(isPersonalView: true),
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
        border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.none), 
      ),
      child: Container(
         decoration: BoxDecoration(
           border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1), 
           borderRadius: BorderRadius.circular(12),
         ),
         child: child,
      ),
    );
  }
}
