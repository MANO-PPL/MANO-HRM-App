import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../employees/models/employee_model.dart';
import './dar_admin_controller.dart';
import './dar_admin_sheet.dart';
import '../../../../shared/widgets/glass_date_picker.dart';

/// Mobile-portrait layout for the admin DAR overview.
/// Uses a compact single-column list (not a grid) with a slim 2-row filter bar.
class DarAdminMobileView extends StatelessWidget {
  const DarAdminMobileView({super.key});

  static const _kPad = 16.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<DarAdminController>(
      builder: (context, ctrl, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final filtered = ctrl.filteredEmployees;

        return Column(
          children: [
            _FilterBar(ctrl: ctrl, isDark: isDark),
            Expanded(
              child: ctrl.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmpty(isDark)
                      : RefreshIndicator(
                          onRefresh: ctrl.fetchAll,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                _kPad, 8, _kPad, 80),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) => _EmployeeListTile(
                              emp: filtered[i],
                              ctrl: ctrl,
                              isDark: isDark,
                            ),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 44, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            'No employees found',
            style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Compact 2-row filter bar ─────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  static const _h = 36.0;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    final fieldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

    return Container(
      color: fieldBg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Search ─────────────────────────────────────────────
          SizedBox(
            height: _h,
            child: TextField(
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search employee name or role…',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, size: 16, color: Colors.grey),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF5B60F6))),
              ),
              onChanged: ctrl.setSearchQuery,
            ),
          ),
          const SizedBox(height: 6),
          // ── Row 2: Mode | Dates | Dept ────────────────────────────────
          Row(
            children: [
              // Mode toggle pill
              _ModeToggle(ctrl: ctrl, isDark: isDark),
              const SizedBox(width: 6),
              // Date button(s)
              Expanded(child: _DateControls(ctrl: ctrl, isDark: isDark)),
              const SizedBox(width: 6),
              // Dept icon button
              _DeptButton(ctrl: ctrl, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fieldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab(context, 'Single', !ctrl.isRange),
          _tab(context, 'Range', ctrl.isRange),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, bool active) {
    return GestureDetector(
      onTap: () => ctrl.toggleRange(label == 'Range'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF2D3139) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3)
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active
                ? (isDark ? Colors.white : const Color(0xFF5B60F6))
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _DateControls extends StatelessWidget {
  const _DateControls({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (!ctrl.isRange) {
      return _dateBtn(
        context,
        label: DateFormat('MMM d, yy').format(ctrl.singleDate),
        icon: Icons.calendar_today_outlined,
        onTap: () async {
          await showDialog(
            context: context,
            builder: (context) => GlassDatePicker(
              initialDate: ctrl.singleDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateSelected: (d) => ctrl.setSingleDate(d),
            ),
          );
        },
      );
    }
    return Row(
      children: [
        Expanded(
          child: _dateBtn(
            context,
            label: DateFormat('MMM d').format(ctrl.startDate),
            icon: Icons.calendar_month_outlined,
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) => GlassDatePicker(
                  initialDate: ctrl.startDate,
                  firstDate: DateTime(2020),
                  lastDate: ctrl.endDate,
                  onDateSelected: (d) => ctrl.setStartDate(d),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text('→',
              style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ),
        Expanded(
          child: _dateBtn(
            context,
            label: DateFormat('MMM d').format(ctrl.endDate),
            icon: Icons.calendar_month,
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) => GlassDatePicker(
                  initialDate: ctrl.endDate,
                  firstDate: ctrl.startDate,
                  lastDate: DateTime(2030),
                  onDateSelected: (d) => ctrl.setEndDate(d),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _dateBtn(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeptButton extends StatelessWidget {
  const _DeptButton({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasDept = ctrl.selectedDepartment != null;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: hasDept
              ? const Color(0xFF5B60F6).withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDept
                ? const Color(0xFF5B60F6)
                : (isDark
                    ? const Color(0xFF30363D)
                    : Colors.grey[200]!),
          ),
        ),
        child: Icon(Icons.business,
            size: 16,
            color:
                hasDept ? const Color(0xFF5B60F6) : Colors.grey),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by Department',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(ctx, null, 'All Departments'),
                ...ctrl.departments.map((d) => _chip(ctx, d, d)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext ctx, String? dept, String label) {
    final selected = ctrl.selectedDepartment == dept;
    return GestureDetector(
      onTap: () {
        ctrl.setDepartment(dept);
        Navigator.pop(ctx);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF5B60F6)
              : (isDark
                  ? const Color(0xFF0D1117)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

// ── Compact list card ─────────────────────────────────────────────────────────

class _EmployeeListTile extends StatelessWidget {
  const _EmployeeListTile(
      {required this.emp, required this.ctrl, required this.isDark});
  final Employee emp;
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final stats = ctrl.getStats(emp.userId);
    final tasks = stats['tasks']!;
    final meetings = stats['meetings']!;
    final hasData = tasks > 0 || meetings > 0;
    final initials = emp.userName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Material(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => DarAdminSheet.show(context, emp, ctrl),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF30363D)
                  : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFF5B60F6).withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5B60F6),
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),

              // Name + sub-info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.userName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [emp.designation, emp.department]
                          .where((s) => s?.isNotEmpty == true)
                          .join(' · '),
                      style: GoogleFonts.poppins(
                          fontSize: 10.5, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Stat badges
              if (hasData) ...[
                if (tasks > 0) _badge('${tasks}T', Colors.blue),
                if (tasks > 0 && meetings > 0)
                  const SizedBox(width: 4),
                if (meetings > 0)
                  _badge('${meetings}M', Colors.teal),
              ] else
                Text('—',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[400])),

              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
