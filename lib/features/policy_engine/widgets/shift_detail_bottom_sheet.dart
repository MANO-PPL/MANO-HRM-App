import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/shift_model.dart';
import '../../employees/services/employee_service.dart';
import '../../employees/models/employee_model.dart' as emp_model;
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/constants/api_constants.dart';
import '../utils/week_off_policy_helper.dart';
import 'shift_action_sheet.dart';

class ShiftDetailBottomSheet extends StatefulWidget {
  final Shift shift;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ShiftDetailBottomSheet({
    super.key,
    required this.shift,
    this.onEdit,
    this.onDelete,
  });

  /// Static convenience method to show the bottom sheet
  static void show(
    BuildContext context, {
    required Shift shift,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShiftDetailBottomSheet(
        shift: shift,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<ShiftDetailBottomSheet> createState() => _ShiftDetailBottomSheetState();
}

class _ShiftDetailBottomSheetState extends State<ShiftDetailBottomSheet> {
  late EmployeeService _employeeService;
  List<emp_model.Employee> _employees = [];
  bool _isLoadingEmployees = true;
  bool _isAssignMode = false;
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  // Toast status inside bottom sheet
  bool _isToastVisible = false;
  String? _toastMessage;
  bool _isToastSuccess = false;
  bool _isToastError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      _employeeService = EmployeeService(authService);
      _fetchEmployees();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final list = await _employeeService.getEmployees();
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
        _showLocalToast("Failed to load staff: $e", isError: true);
      }
    }
  }

  void _showLocalToast(String message, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _isToastSuccess = isSuccess;
      _isToastError = isError;
      _isToastVisible = true;
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isToastVisible = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isToastVisible) {
            setState(() {
              _toastMessage = null;
            });
          }
        });
      }
    });
  }

  Future<void> _toggleShiftAssignment(int userId, String userName, bool isCurrentlyAssigned) async {
    final isAdding = !isCurrentlyAssigned;
    final newShiftId = isAdding ? widget.shift.id : null;

    _showLocalToast(
      isAdding ? "Assigning $userName..." : "Removing $userName...",
      isSuccess: false,
    );

    try {
      await _employeeService.assignShiftToUser(userId, newShiftId);
      await _fetchEmployees();
      
      _showLocalToast(
        isAdding 
            ? "$userName assigned to shift successfully" 
            : "$userName removed from shift successfully",
        isSuccess: true,
      );
    } catch (e) {
      final errText = e.toString().replaceAll('Exception:', '').trim();
      _showLocalToast("Failed to update shift: $errText", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF161B22) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _isAssignMode
                        ? _buildAssignModeView(scrollController)
                        : _buildDetailsModeView(scrollController),
                  ),
                ],
              ),
              
              // Local toast notification
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                bottom: _isToastVisible ? 16.0 : -80.0,
                left: 24,
                right: 24,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isToastVisible ? 1.0 : 0.0,
                  child: _toastMessage == null 
                      ? const SizedBox.shrink() 
                      : Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _isToastError
                                  ? const Color(0xFFDA3637)
                                  : (_isToastSuccess ? const Color(0xFF2EA043) : Colors.indigo),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_isToastSuccess && !_isToastError)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                else
                                  Icon(
                                    _isToastError
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _toastMessage!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsModeView(ScrollController scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigoAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.access_time_filled,
                  color: Colors.indigoAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.shift.name,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "Shift Details",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigoAccent),
                  ),
                ],
              ),
            ),
            if (widget.onEdit != null || widget.onDelete != null) ...[
              IconButton(
                onPressed: () {
                  ShiftActionSheet.show(
                    context,
                    shiftName: widget.shift.name,
                    onEdit: () {
                      Navigator.pop(context); // Close bottom sheet
                      widget.onEdit?.call();
                    },
                    onDelete: () {
                      Navigator.pop(context); // Close bottom sheet
                      widget.onDelete?.call();
                    },
                  );
                },
                icon: Icon(Icons.more_vert, color: subTextColor),
              ),
            ],
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: subTextColor),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey.shade200),
        const SizedBox(height: 20),

        // --- Timing & Schedule ---
        _buildSectionTitle("Timing & Schedule"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildInfoItem(context, "Start Time",
                    widget.shift.startTime, Icons.wb_sunny_outlined)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildInfoItem(context, "End Time",
                    widget.shift.endTime, Icons.nights_stay_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(context, "Grace Period",
                  "${widget.shift.gracePeriodMins} Minutes", Icons.hourglass_empty),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoItem(context, "Corr. Deadline",
                  "${widget.shift.correctionDeadline} Days", Icons.edit_calendar_outlined),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // --- Working Days & Policy ---
        _buildSectionTitle("Working Days & Schedule"),
        const SizedBox(height: 12),
        _buildSchedulePolicyDetails(context, isDark, textColor),

        const SizedBox(height: 20),

        // --- Overtime ---
        _buildSectionTitle("Overtime Configuration"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                "Status",
                widget.shift.isOvertimeEnabled ? "Enabled" : "Disabled",
                widget.shift.isOvertimeEnabled
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                iconColor: widget.shift.isOvertimeEnabled
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
            if (widget.shift.isOvertimeEnabled) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem(context, "Threshold",
                    "${widget.shift.overtimeThresholdHours} Hours",
                    Icons.timelapse),
              ),
            ]
          ],
        ),

        const SizedBox(height: 20),

        // --- Attendance Validation ---
        _buildSectionTitle("Attendance Validation"),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CHECK-IN",
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildRequirementRow(
                        "GPS (Mandatory)", true, textColor),
                    const SizedBox(height: 4),
                    _buildRequirementRow(
                        "Selfie", widget.shift.entrySelfie, textColor),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CHECK-OUT",
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildRequirementRow(
                        "GPS (Mandatory)", true, textColor),
                    const SizedBox(height: 4),
                    _buildRequirementRow(
                        "Selfie", widget.shift.exitSelfie, textColor),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- Assigned Staff Section ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Assigned Staff"),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.indigoAccent),
              onPressed: () {
                setState(() {
                  _isAssignMode = true;
                });
              },
              tooltip: "Assign Staff",
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAssignedStaffList(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAssignedStaffList() {
    if (_isLoadingEmployees) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final assigned = _employees.where((e) => e.shiftId == widget.shift.id).toList();

    if (assigned.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 36, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              "No staff assigned to this shift",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isAssignMode = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text("Assign Staff", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assigned.length,
      itemBuilder: (context, index) {
        final emp = assigned[index];
        final name = emp.userName;
        final role = emp.designation ?? 'Staff';
        final profileImage = _resolveAvatarUrl(emp.profileImage);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.indigoAccent.withValues(alpha: 0.1),
                backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                    ? NetworkImage(profileImage)
                    : null,
                child: (profileImage == null || profileImage.isEmpty)
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 13))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    Text(role, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                iconSize: 20,
                onPressed: () => _toggleShiftAssignment(emp.userId, emp.userName, true),
                tooltip: "Remove from shift",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignModeView(ScrollController scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final filtered = _employees.where((emp) {
      final query = _searchQuery.toLowerCase();
      final name = emp.userName.toLowerCase();
      final role = (emp.designation ?? '').toLowerCase();
      return name.contains(query) || role.contains(query);
    }).toList();

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _isLoadingEmployees ? 3 : (filtered.isEmpty ? 3 : filtered.length + 2),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _isAssignMode = false;
                      _searchQuery = "";
                      _searchCtrl.clear();
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Assign Staff",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        "Shift: ${widget.shift.name}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }

        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: textColor),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = "";
                            });
                          },
                        )
                      : null,
                  hintText: "Search employees...",
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          );
        }

        if (index == 2 && _isLoadingEmployees) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (index == 2 && filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                "No employees found",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        final empIndex = index - 2;
        final emp = filtered[empIndex];
        final name = emp.userName;
        final role = emp.designation ?? 'Staff';
        final profileImage = _resolveAvatarUrl(emp.profileImage);
        final isAssigned = emp.shiftId == widget.shift.id;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? (isAssigned ? Colors.indigo.withValues(alpha: 0.1) : Colors.transparent)
                : (isAssigned ? Colors.indigo[50]!.withValues(alpha: 0.5) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAssigned
                  ? Colors.indigo.withValues(alpha: 0.2)
                  : (isDark ? Colors.white10 : Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? Colors.indigo.withValues(alpha: 0.2)
                    : Colors.indigo[100],
                backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                    ? NetworkImage(profileImage)
                    : null,
                child: (profileImage == null || profileImage.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      isAssigned
                          ? "Current Shift: ${widget.shift.name}"
                          : (emp.shift != null && emp.shift!.isNotEmpty
                              ? "Shift: ${emp.shift}"
                              : role),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isAssigned ? Colors.indigoAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _buildToggleButton(emp.userId, name, isAssigned),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleButton(int userId, String name, bool isAssigned) {
    return InkWell(
      onTap: () => _toggleShiftAssignment(userId, name, isAssigned),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAssigned ? Colors.green : Colors.indigoAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAssigned ? Icons.check : Icons.add,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              isAssigned ? "Assigned" : "Assign",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.indigoAccent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18, color: iconColor ?? Colors.indigoAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
      String label, bool isRequired, Color textColor) {
    return Row(
      children: [
        Icon(
          isRequired
              ? Icons.check_circle_rounded
              : Icons.cancel_outlined,
          size: 16,
          color: isRequired ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          "$label ${isRequired ? 'Required' : 'Optional'}",
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isRequired ? textColor : Colors.grey,
            fontWeight:
                isRequired ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  Widget _buildSchedulePolicyDetails(BuildContext context, bool isDark, Color textColor) {
    final parsed = WeekOffPolicyHelper.parsePolicy(
      widget.shift.policyRules['week_off_policy'] ?? widget.shift.policyRules['week_off'] ?? [],
    );
    final activeDays = parsed.workingDays;
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WORKING DAYS",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allDays.map((day) {
              final isWork = activeDays.contains(day);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isWork
                      ? Colors.blue.withValues(alpha: 0.15)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isWork ? FontWeight.bold : FontWeight.normal,
                    color: isWork ? Colors.blue[600] : Colors.grey,
                    decoration: isWork ? null : TextDecoration.lineThrough,
                  ),
                ),
              );
            }).toList(),
          ),
          if (parsed.weekOffRules.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "ALTERNATE FULL DAYS OFF",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.amber[600],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: parsed.weekOffRules.map((rule) {
                final suffixWeeks = rule.weeks.map((w) => '$w${w == 1 ? "st" : w == 2 ? "nd" : w == 3 ? "rd" : "th"}').join(', ');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "${rule.day} ($suffixWeeks week off)",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (parsed.halfDayRules.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "HALF DAYS",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.indigoAccent,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: parsed.halfDayRules.map((rule) {
                final suffixWeeks = rule.weeks.map((w) => '$w${w == 1 ? "st" : w == 2 ? "nd" : w == 3 ? "rd" : "th"}').join(', ');
                final timing = rule.timing != null
                    ? " [${rule.timing!['start_time']} - ${rule.timing!['end_time']}]"
                    : "";
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "${rule.day} ($suffixWeeks week)$timing",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigoAccent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

String? _resolveAvatarUrl(dynamic profileImage) {
  if (profileImage == null || profileImage.toString().isEmpty) return null;
  final url = profileImage.toString();
  if (url.startsWith('http')) return url;
  final cleanUrl = url.startsWith('/') ? url : '/$url';
  return '${ApiConstants.baseUrl}$cleanUrl';
}
