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

class PolicyEngineView extends StatefulWidget {
  const PolicyEngineView({super.key});

  @override
  State<PolicyEngineView> createState() => _PolicyEngineViewState();
}

class _PolicyEngineViewState extends State<PolicyEngineView> {
  late ShiftService _shiftService;

  List<Shift> _shifts = [];
  bool _isLoadingShifts = true;

  @override
  void initState() {
    super.initState();
    // Initialize Services
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final dio = Provider.of<AuthService>(context, listen: false).dio;
       _shiftService = ShiftService(dio);
       _fetchShifts();
    });
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoadingShifts = true);
    try {
      final data = await _shiftService.getShifts();
      if (mounted) setState(() => _shifts = data);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${shift.name}"? This action will unassign all staff currently on this shift.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
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

          // Shifts Grid (occupies full width, compact multi-column)
          Expanded(
            child: _shifts.isEmpty 
              ? Center(child: Text("No shifts found", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)))
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
                    children: _shifts.map<Widget>((shift) {
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
                    Text(
                      'Active Shifts',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
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
                  'Manage work timings and grace periods',
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
                      Text(
                        'Active Shifts',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage work timings and grace periods',
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
}

// [mod:2026-03-18T11:30:00+05:30]
