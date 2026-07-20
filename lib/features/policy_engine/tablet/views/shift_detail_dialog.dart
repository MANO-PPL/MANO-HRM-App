import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../models/shift_model.dart';

class ShiftDetailDialog extends StatelessWidget {
  final Shift shift;

  const ShiftDetailDialog({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 40.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: GlassContainer(
          borderRadius: 20,
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      shift.name,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: subTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Shift Details",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigoAccent),
              ),
              SizedBox(height: isMobile ? 16 : 24),
              const Divider(height: 1, color: Colors.white10),
              SizedBox(height: isMobile ? 16 : 24),

              // Timing Section
              _buildSectionTitle("Timing & Schedule", textColor),
              SizedBox(height: isMobile ? 8 : 12),
              Row(
                children: [
                  Expanded(child: _buildInfoItem(context, "Start Time", shift.startTime, Icons.wb_sunny_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoItem(context, "End Time", shift.endTime, Icons.nights_stay_outlined)),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              _buildInfoItem(context, "Grace Period", "${shift.gracePeriodMins} Minutes", Icons.hourglass_empty),

              SizedBox(height: isMobile ? 16 : 24),

              // Overtime Section
              _buildSectionTitle("Overtime Configuration", textColor),
              SizedBox(height: isMobile ? 8 : 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      context, 
                      "Status", 
                      shift.isOvertimeEnabled ? "Enabled" : "Disabled", 
                      shift.isOvertimeEnabled ? Icons.check_circle_outline : Icons.cancel_outlined,
                      iconColor: shift.isOvertimeEnabled ? Colors.green : Colors.grey
                    )
                  ),
                  if (shift.isOvertimeEnabled) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        context, 
                        "Threshold", 
                        "${shift.overtimeThresholdHours} Hours", 
                        Icons.timelapse
                      )
                    ),
                  ]
                ],
              ),
              
              SizedBox(height: isMobile ? 16 : 24),

              // Attendance Validation
              _buildSectionTitle("Attendance Validation", textColor),
              SizedBox(height: isMobile ? 8 : 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CHECK-IN", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildRequirementRow("GPS (Mandatory)", true, textColor),
                          const SizedBox(height: 4),
                          _buildRequirementRow("Selfie", shift.entrySelfie, textColor),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("CHECK-OUT", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildRequirementRow("GPS (Mandatory)", true, textColor),
                          const SizedBox(height: 4),
                          _buildRequirementRow("Selfie", shift.exitSelfie, textColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 16 : 24),

              // Correction Policy
              _buildSectionTitle("Correction Policy", textColor),
              SizedBox(height: isMobile ? 8 : 12),
              _buildInfoItem(
                context,
                "Missed Punch Deadline",
                "${shift.correctionDeadline} Day${shift.correctionDeadline == 1 ? '' : 's'}",
                Icons.edit_calendar_outlined,
                iconColor: Colors.deepOrangeAccent,
              ),

              SizedBox(height: isMobile ? 24 : 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Close", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
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

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon, {Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.indigoAccent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? Colors.indigoAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87
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

  Widget _buildRequirementRow(String label, bool isRequired, Color textColor) {
    return Row(
      children: [
        Icon(
          isRequired ? Icons.check_circle_rounded : Icons.cancel_outlined,
          size: 16,
          color: isRequired ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          "$label ${isRequired ? 'Required' : 'Optional'}",
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isRequired ? textColor : Colors.grey,
            fontWeight: isRequired ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
