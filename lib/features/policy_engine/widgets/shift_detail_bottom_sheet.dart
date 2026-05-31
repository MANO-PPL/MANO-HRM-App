import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/shift_model.dart';

class ShiftDetailBottomSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
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
          child: Column(
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

              // Scrollable content
              Expanded(
                child: ListView(
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
                                shift.name,
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
                                shift.startTime, Icons.wb_sunny_outlined)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildInfoItem(context, "End Time",
                                shift.endTime, Icons.nights_stay_outlined)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(context, "Grace Period",
                        "${shift.gracePeriodMins} Minutes", Icons.hourglass_empty),

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
                            shift.isOvertimeEnabled ? "Enabled" : "Disabled",
                            shift.isOvertimeEnabled
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            iconColor: shift.isOvertimeEnabled
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        if (shift.isOvertimeEnabled) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoItem(context, "Threshold",
                                "${shift.overtimeThresholdHours} Hours",
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
                                    "GPS", shift.entryGeofence, textColor),
                                const SizedBox(height: 4),
                                _buildRequirementRow(
                                    "Selfie", shift.entrySelfie, textColor),
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
                                    "GPS", shift.exitGeofence, textColor),
                                const SizedBox(height: 4),
                                _buildRequirementRow(
                                    "Selfie", shift.exitSelfie, textColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),


                  ],
                ),
              ),
            ],
          ),
        );
      },
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
}
