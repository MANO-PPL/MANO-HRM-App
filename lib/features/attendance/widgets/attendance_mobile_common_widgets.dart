import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';

class MonthlyReportHeaderMobile extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback? onDownload;
  final bool isDownloading;

  const MonthlyReportHeaderMobile({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
    this.onDownload,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(12)
                 ),
                 child: const Icon(Icons.description_outlined, color: Color(0xFF5B60F6)),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       'Monthly Report', 
                       style: GoogleFonts.poppins(
                         fontWeight: FontWeight.w600, 
                         fontSize: 16,
                         color: Theme.of(context).textTheme.bodyLarge?.color,
                       )
                     ),
                     Text(
                       'Download and view your logs', 
                       style: GoogleFonts.poppins(
                         fontSize: 12, 
                         color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                       )
                     ),
                   ],
                 ),
               ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row 2: Controls
           Row(
            children: [
               Expanded(child: _buildMonthDropdown(context)),
               const SizedBox(width: 8),
               Expanded(child: _buildYearDropdown(context)),
               const SizedBox(width: 8),
               ElevatedButton(
                 onPressed: isDownloading ? null : onDownload,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF5B60F6),
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12), // Compact
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                   minimumSize: const Size(40, 40), // Ensure touch target
                 ),
                 child: isDownloading 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                   : const Icon(Icons.download, size: 20),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDropdown(BuildContext context) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return _buildDropdownWrapper(
      context: context,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMonth.month,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
          items: List.generate(12, (index) {
            return DropdownMenuItem(
              value: index + 1,
              child: Text(months[index], overflow: TextOverflow.ellipsis),
            );
          }),
          onChanged: (value) {
            if (value != null) {
              onMonthChanged(DateTime(selectedMonth.year, value));
            }
          },
        ),
      ),
    );
  }

  Widget _buildYearDropdown(BuildContext context) {
    return _buildDropdownWrapper(
      context: context,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMonth.year,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
          items: List.generate(2100 - 2024 + 1, (index) {
            final year = 2024 + index;
            return DropdownMenuItem(
              value: year,
              child: Text('$year'),
            );
          }),
          onChanged: (value) {
            if (value != null) {
              onMonthChanged(DateTime(value, selectedMonth.month));
            }
          },
        ),
      ),
    );
  }

  Widget _buildDropdownWrapper({required BuildContext context, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

// [upd:2026-04-16T11:30:00+05:30]
