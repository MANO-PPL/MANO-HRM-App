import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../models/shift_model.dart';
import '../../services/shift_service.dart';
import '../../widgets/shift_detail_bottom_sheet.dart';

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



  @override
  Widget build(BuildContext context) {
    if (_isLoadingShifts) return const Center(child: CircularProgressIndicator()); 

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          _buildHelperHeader(context),
          const SizedBox(height: 24),

          // Shifts Grid
          Expanded(
            child: _shifts.isEmpty 
              ? Center(child: Text("No shifts found", style: GoogleFonts.poppins(color: Colors.grey)))
              : LayoutBuilder(
              builder: (context, constraints) {
                // Determine if we should stack vertically or horizontally
                final isPortrait = constraints.maxWidth < 900; 

                // We'll wrap in Wrap or Grid or ListView depending on layout.
                // Reusing _buildShiftCard for each item.
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.start,
                    children: _shifts.map<Widget>((shift) {
                       final itemWidth = isPortrait ? constraints.maxWidth : (constraints.maxWidth - 48) / 3;
                       
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
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Shifts',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage work timings and grace periods',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, {required Shift shift}) {
    final color = Colors.indigoAccent;
    final icon = Icons.access_time_filled;
    
    // Calculate duration (simple approximation if needed, or pass from backend)
    // Display shift data
    final title = shift.name;
    final type = "Shift"; // Backend doesn't seem to have type yet, or maybe 'shift_name' implies it?
    final timing = "${shift.startTime} - ${shift.endTime}";
    final gracePeriod = "${shift.gracePeriodMins} Mins";
    final overtime = shift.isOvertimeEnabled ? "On (> ${shift.overtimeThresholdHours}h)" : "Off";
    
    
    return InkWell(
      onTap: () => ShiftDetailBottomSheet.show(context, shift: shift),
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigoAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1, color: Colors.white10),
            const SizedBox(height: 16),
  
            // Details List
            _buildDetailRow(context, 'Timing', timing, isBold: true),
            const SizedBox(height: 12),
            // _buildDetailRow(context, 'Duration', duration), // Duration omitted for simplicity or calculated
            // const SizedBox(height: 16),
            // const Divider(height: 1, thickness: 1, color: Colors.white10),
            // const SizedBox(height: 16),
            _buildDetailRow(context, 'Grace Period', gracePeriod, icon: Icons.warning_amber_rounded, iconColor: Colors.amber),
            const SizedBox(height: 12),
            _buildDetailRow(context, 'Overtime', overtime, icon: Icons.bolt, iconColor: const Color(0xFF5B60F6)),
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
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: icon != null ? iconColor : Colors.grey,
                fontWeight: icon != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
           ],
        ),
        const SizedBox(width: 16), // Minimum gap
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold || icon != null ? FontWeight.w600 : FontWeight.w500,
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
