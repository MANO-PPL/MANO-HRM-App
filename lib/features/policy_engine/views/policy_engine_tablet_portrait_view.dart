import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/loading_screen.dart';
import 'package:flutter_application/features/policy_engine/core/shift_model.dart';
import 'package:flutter_application/features/policy_engine/core/shift_service.dart';
import 'package:flutter_application/features/policy_engine/widgets/shift_detail_bottom_sheet.dart';
import 'package:flutter_application/features/policy_engine/widgets/add_shift_dialog.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/features/employees/core/employee_model.dart' hide Shift;
import 'package:flutter_application/features/employees/core/employee_service.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/widgets/pfp_viewer_dialog.dart';

class PolicyEngineView extends StatefulWidget {
  const PolicyEngineView({super.key});

  @override
  State<PolicyEngineView> createState() => _PolicyEngineViewState();
}

class _PolicyEngineViewState extends State<PolicyEngineView> {
  late ShiftService _shiftService;
  late EmployeeService _employeeService;

  List<Shift> _shifts = [];
  Map<int, int> _shiftStaffCounts = {};
  Map<int, List<Employee>> _shiftAssignedEmployees = {};
  String _searchQuery = '';
  bool _isLoadingShifts = true;

  @override
  void initState() {
    super.initState();
    // Initialize Services
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final authService = Provider.of<AuthService>(context, listen: false);
       _shiftService = ShiftService(authService.dio);
       _employeeService = EmployeeService(authService);
       _fetchShifts();
    });
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoadingShifts = true);
    try {
      final results = await Future.wait([
        _shiftService.getShifts(),
        _shiftService.getShiftUsers(),
        _employeeService.getEmployees().catchError((_) => <Employee>[]),
      ]);
      final shiftsData = results[0] as List<Shift>;
      final usersData = results[1] as List<Map<String, dynamic>>;
      final employeesData = results[2] as List<Employee>;

      final counts = <int, int>{};
      final assignedMap = <int, List<Employee>>{};

      // Map employees by shiftId
      for (final emp in employeesData) {
        if (emp.shiftId != null) {
          assignedMap.putIfAbsent(emp.shiftId!, () => []).add(emp);
          counts[emp.shiftId!] = (counts[emp.shiftId!] ?? 0) + 1;
        }
      }

      // If any user from usersData was not in employeesData, supplement it
      for (final u in usersData) {
        final sId = u['shift_id'] as int?;
        final uId = u['user_id'] as int? ?? u['id'] as int?;
        if (sId != null && uId != null) {
          final alreadyPresent = assignedMap[sId]?.any((e) => e.userId == uId) ?? false;
          if (!alreadyPresent) {
            final emp = Employee(
              userId: uId,
              userName: u['user_name'] ?? u['name'] ?? 'Staff',
              email: u['email'] ?? '',
              userType: u['user_type'] ?? 'employee',
              designation: u['desg_name'] ?? u['designation'],
              department: u['dept_name'] ?? u['department'],
              profileImage: u['profile_image'] ?? u['avatar_url'],
              shiftId: sId,
            );
            assignedMap.putIfAbsent(sId, () => []).add(emp);
            counts[sId] = (counts[sId] ?? 0) + 1;
          }
        }
      }

      if (mounted) {
        setState(() {
          _shifts = shiftsData;
          _shiftStaffCounts = counts;
          _shiftAssignedEmployees = assignedMap;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading shifts: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingShifts = false);
    }
  }

  void _showAddShiftDialog({Shift? existingShift}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddShiftDialog(
        existingShift: existingShift,
        onSubmit: (shift) async {
          Navigator.pop(context);
          setState(() => _isLoadingShifts = true);
          try {
            if (existingShift == null) {
              await _shiftService.createShift(shift);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Shift created successfully")),
                );
              }
            } else {
              await _shiftService.updateShift(existingShift.id!, shift);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Shift updated successfully")),
                );
              }
            }
            _fetchShifts();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error saving shift: $e")),
              );
            }
            setState(() => _isLoadingShifts = false);
          }
        },
      ),
    );
  }

  Future<void> _deleteShift(Shift shift) async {
    final confirm = await CustomDialog.show(
      context: context,
      title: 'Delete Shift',
      message: 'Are you sure you want to delete "${shift.name}"? This action will unassign all staff currently on this shift.',
      positiveButtonText: 'Delete',
      negativeButtonText: 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      onPositivePressed: () {},
    );

    if (confirm == true) {
      setState(() => _isLoadingShifts = true);
      try {
        await _shiftService.deleteShift(shift.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Shift deleted successfully")),
          );
        }
        _fetchShifts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting shift: $e")),
          );
        }
        setState(() => _isLoadingShifts = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 10.0 : 14.0;

    final filteredShifts = _shifts.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.startTime.toLowerCase().contains(q) ||
          s.endTime.toLowerCase().contains(q);
    }).toList();

    return LoadingScreen(
      isLoading: _isLoadingShifts,
      message: "Fetching policy rules...",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isMobile ? 10 : 12,
              horizontalPadding,
              0,
            ),
            child: _buildHelperHeader(context),
          ),
          const SizedBox(height: 8),

          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search shifts...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 15, color: Colors.grey),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Shifts Grid (occupies full width, compact multi-column)
          Expanded(
            child: filteredShifts.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.work_outline, size: 36, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text("No shifts found", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 950 ? 3 : (constraints.maxWidth > 580 ? 2 : 1);
                final usableWidth = constraints.maxWidth - (2 * horizontalPadding);
                const spacing = 8.0;
                final itemWidth = (usableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    12,
                  ),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.start,
                    children: filteredShifts.map<Widget>((shift) {
                       return SizedBox(
                         width: itemWidth,
                         child: _buildShiftCard(
                           context,
                           shift: shift,
                         ),
                       );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 8 : 10,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Work Shifts',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_shifts.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddShiftDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: Text(
                        'Add Shift',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage work timings, grace periods and rules',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Work Shifts',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_shifts.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage work timings, grace periods and staff assignments',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddShiftDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add, size: 15),
                  label: Text(
                    'Add Shift',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildShiftCard(BuildContext context, {required Shift shift}) {
    final color = Colors.indigoAccent;
    final icon = Icons.access_time_filled;
    
    // Calculate duration
    String duration = "";
    try {
      final sParts = shift.startTime.split(':');
      final eParts = shift.endTime.split(':');
      int sMins = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      int eMins = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      if (eMins < sMins) eMins += 24 * 60; // overnight shift
      final diff = eMins - sMins;
      duration = "${diff ~/ 60}h ${diff % 60}m";
    } catch (_) {
      duration = "";
    }

    final title = shift.name;
    final timing = "${shift.startTime} - ${shift.endTime}";
    final gracePeriod = "${shift.gracePeriodMins} Mins";
    final overtime = shift.isOvertimeEnabled ? "On (> ${shift.overtimeThresholdHours}h)" : "Off";
    final checkpointText = shift.checkpointEnabled
        ? (shift.checkpointSelfie ? "Selfie Required" : "GPS Only")
        : "Disabled";
    
    return InkWell(
      onTap: () => ShiftDetailBottomSheet.show(
        context,
        shift: shift,
        onEdit: () => _showAddShiftDialog(existingShift: shift),
        onDelete: () => _deleteShift(shift),
      ),
      borderRadius: BorderRadius.circular(12),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            "Shift",
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          if (duration.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.indigoAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                duration,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigoAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigoAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 1, color: Colors.white10),
            const SizedBox(height: 6),
  
            // Details List
            _buildDetailRow(context, 'Timing', timing, isBold: true),
            const SizedBox(height: 4),
            _buildDetailRow(
              context,
              'Checkpoints',
              checkpointText,
              icon: Icons.location_pin,
              iconColor: shift.checkpointEnabled ? const Color(0xFF6366F1) : Colors.grey,
            ),
            const SizedBox(height: 4),
            _buildDetailRow(context, 'Grace Period', gracePeriod, icon: Icons.warning_amber_rounded, iconColor: Colors.amber),
            const SizedBox(height: 4),
            _buildDetailRow(context, 'Overtime', overtime, icon: Icons.bolt, iconColor: const Color(0xFF5B60F6)),
            const SizedBox(height: 4),
            _buildDetailRow(
              context,
              'Correction Deadline',
              '${shift.correctionDeadline} Day${shift.correctionDeadline == 1 ? '' : 's'}',
              icon: Icons.edit_calendar_outlined,
              iconColor: Colors.deepOrangeAccent,
            ),
            const SizedBox(height: 6),
            _buildAssignedStaffRow(context, shift),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isBold = false, IconData? icon, Color? iconColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
           mainAxisSize: MainAxisSize.min,
           children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: icon != null ? iconColor : Colors.grey,
                fontWeight: icon != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
           ],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedStaffRow(BuildContext context, Shift shift) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffList = _shiftAssignedEmployees[shift.id] ?? const [];
    final totalCount = _shiftStaffCounts[shift.id] ?? staffList.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 12, color: Color(0xFF10B981)),
            const SizedBox(width: 5),
            Text(
              'Assigned Staff',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        if (staffList.isEmpty)
          Text(
            totalCount > 0 ? '$totalCount Staff' : '0 Staff',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Overlapping Avatar Stack
              SizedBox(
                height: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < staffList.take(4).length; i++) ...[
                      Align(
                        widthFactor: i == 0 ? 1.0 : 0.65,
                        child: _buildStaffAvatar(context, staffList[i], isDark),
                      ),
                    ],
                    if (totalCount > 4)
                      Align(
                        widthFactor: 0.65,
                        child: InkWell(
                          onTap: () => ShiftDetailBottomSheet.show(
                            context,
                            shift: shift,
                            onEdit: () => _showAddShiftDialog(existingShift: shift),
                            onDelete: () => _deleteShift(shift),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6366F1),
                              border: Border.all(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+${totalCount - 4}',
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '($totalCount)',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStaffAvatar(BuildContext context, Employee staff, bool isDark) {
    final name = staff.userName;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final hasImg = staff.profileImage != null && staff.profileImage!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () {
        PfpViewerDialog.show(
          context,
          imageUrl: staff.profileImage,
          name: staff.userName,
          subtitle: staff.designation ?? staff.department ?? 'Staff',
          heroTag: 'shift-staff-${staff.userId}-${staff.hashCode}',
        );
      },
      child: Tooltip(
        message: staff.userName,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              width: 1.5,
            ),
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          ),
          child: ClipOval(
            child: hasImg
                ? CachedNetworkImage(
                    imageUrl: staff.profileImage!.startsWith('http')
                        ? staff.profileImage!
                        : (staff.profileImage!.startsWith('/')
                            ? '${ApiConstants.baseUrl}${staff.profileImage!}'
                            : '${ApiConstants.baseUrl}/${staff.profileImage!}'),
                    fit: BoxFit.cover,
                    width: 22,
                    height: 22,
                    placeholder: (_, _) => Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// [mod:2026-03-18T11:30:00+05:30]
