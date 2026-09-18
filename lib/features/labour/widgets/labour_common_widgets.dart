import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/leave/widgets/custom_date_picker_dialog.dart';
export 'package:flutter_application/features/leave/widgets/custom_date_picker_dialog.dart';

class SkillBadge extends StatelessWidget {
  final String skill;

  const SkillBadge({super.key, required this.skill});

  static Color getSkillColor(String skillName) {
    switch (skillName.toLowerCase().trim()) {
      case 'mason':
        return const Color(0xFF6366F1); // Indigo
      case 'electrician':
        return const Color(0xFF06B6D4); // Cyan
      case 'carpenter':
        return const Color(0xFFF59E0B); // Amber
      case 'plumber':
        return const Color(0xFF3B82F6); // Blue
      case 'welder':
        return const Color(0xFF14B8A6); // Teal
      case 'painter':
        return const Color(0xFFEC4899); // Pink
      case 'foreman':
      case 'supervisor':
        return const Color(0xFF10B981); // Emerald
      case 'bar bender':
      case 'tile layer':
        return const Color(0xFF8B5CF6); // Purple
      case 'helper':
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getSkillColor(skill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        skill.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class SiteStatusBadge extends StatelessWidget {
  final String status;

  const SiteStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color color;
    if (s == 'active') {
      color = const Color(0xFF10B981); // Emerald Green
    } else if (s == 'completed') {
      color = const Color(0xFF3B82F6); // Blue
    } else {
      color = const Color(0xFFF59E0B); // Amber (On Hold)
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceStatusChip extends StatelessWidget {
  final String status;

  const AttendanceStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status.toLowerCase().trim()) {
      case 'present':
      case 'p':
        bg = const Color(0xFF065F46);
        fg = const Color(0xFFA7F3D0);
        break;
      case 'absent':
      case 'a':
        bg = const Color(0xFF991B1B);
        fg = const Color(0xFFFECACA);
        break;
      case 'half day':
      case 'hd':
      case 'h':
        bg = const Color(0xFF78350F);
        fg = const Color(0xFFFDE68A);
        break;
      case 'paid leave':
      case 'pl':
        bg = const Color(0xFF1E3A8A);
        fg = const Color(0xFFBFDBFE);
        break;
      case 'wo':
      case 'week off':
        bg = const Color(0xFF334155);
        fg = const Color(0xFF94A3B8);
        break;
      default:
        bg = const Color(0xFF334155);
        fg = const Color(0xFFCBD5E1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.isEmpty ? 'NOT MARKED' : status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class LabourStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final bool isDark;

  const LabourStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LabourSiteCard extends StatelessWidget {
  final LabourSite site;
  final int assignedWorkers;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDark;

  const LabourSiteCard({
    super.key,
    required this.site,
    required this.assignedWorkers,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.business_rounded, color: Color(0xFF6366F1), size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        site.siteName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (site.locationDetails != null && site.locationDetails!.isNotEmpty)
                        Text(
                          site.locationDetails!,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SiteStatusBadge(status: site.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 12, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "$assignedWorkers Worker${assignedWorkers == 1 ? '' : 's'}",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  onPressed: onEdit,
                  tooltip: "Edit Site",
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                  onPressed: onDelete,
                  tooltip: "Delete Site",
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF6366F1)),
                  onPressed: onSelect,
                  tooltip: "Dashboard",
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Date Picker Helper using CustomDatePickerDialog
Future<DateTime?> showLabourDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => CustomDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
    ),
  );
}

/// Custom Styled Dropdown Widget with dark/light mode support, clean borders, and custom arrow
class CustomDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hintText;
  final Widget? prefixIcon;
  final double height;
  final double fontSize;
  final bool isExpanded;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.height = 36,
    this.fontSize = 11.5,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                prefixIcon!,
                const SizedBox(width: 6),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: isExpanded,
                    dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    items: items,
                    onChanged: onChanged,
                    hint: hintText != null
                        ? Text(
                            hintText!,
                            style: GoogleFonts.poppins(
                              fontSize: fontSize,
                              color: Colors.grey[500],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// [upd:2026-04-13T09:00:00+05:30]
