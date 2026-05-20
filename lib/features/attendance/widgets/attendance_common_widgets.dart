import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/glass_container.dart';

// --- Header ---
class MonthlyReportHeader extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final bool isCompactHeader;

  const MonthlyReportHeader({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
    this.onDownload,
    this.isDownloading = false,
    this.isCompactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 550;

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: (isCompact || isCompactHeader) ? _buildCompact(context) : _buildWide(context),
        );
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        _buildIcon(),
        const SizedBox(width: 16),
        _buildTitle(context),
        const Spacer(),
        _buildActions(context),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            _buildTitle(context),
          ],
        ),
        const SizedBox(height: 16),
        _buildActions(context),
      ],
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12)
      ),
      child: const Icon(Icons.description_outlined, color: Color(0xFF5B60F6)),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Monthly Report', 
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ), 
            overflow: TextOverflow.ellipsis,
          ),
          Text('Download and view your logs', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildMonthDropdown(context),
        _buildYearDropdown(context),
        
        ElevatedButton.icon(
          onPressed: isDownloading ? null : onDownload,
          icon: isDownloading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download, size: 16),
          label: Text(isDownloading ? 'Downloading...' : 'Download'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B60F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
          items: List.generate(12, (index) {
            return DropdownMenuItem(
              value: index + 1,
              child: Text(months[index]),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

// --- Summary Card ---
class AttendanceSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? percentage;

  const AttendanceSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.color,
    this.percentage,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              if (icon != null) Icon(icon, color: color, size: 20),
              if (percentage != null) 
                 Container(
                   padding: const EdgeInsets.all(6),
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(color: Colors.green),
                   ),
                   child: Text(percentage!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                 )
            ],
          ),
          Text(
            value, 
            style: GoogleFonts.poppins(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
