import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../employees/models/employee_model.dart';
import './dar_admin_controller.dart';
import './dar_admin_sheet.dart';
import '../../../../shared/widgets/glass_date_picker.dart';

/// Tablet-portrait layout for the admin DAR overview.
/// Full filter panel on top, 3-column employee grid below.
class DarAdminTabletPortraitView extends StatelessWidget {
  const DarAdminTabletPortraitView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DarAdminController>(
      builder: (context, ctrl, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final filtered = ctrl.filteredEmployees;

        return Column(
          children: [
            _TabletFilterPanel(ctrl: ctrl, isDark: isDark),
            Expanded(
              child: ctrl.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmpty(isDark)
                      : RefreshIndicator(
                          onRefresh: ctrl.fetchAll,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 10, 16, 80),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.35,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _EmployeeCard(
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
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No employees found',
              style: GoogleFonts.poppins(
                  color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Full filter panel ─────────────────────────────────────────────────────────

class _TabletFilterPanel extends StatelessWidget {
  const _TabletFilterPanel({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    final fieldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + mode toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.tune,
                    color: Color(0xFF5B60F6), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87),
                ),
              ]),
              // Mode toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border)),
                child: Row(children: [
                  _modeTab(ctrl, 'Single', !ctrl.isRange),
                  _modeTab(ctrl, 'Range', ctrl.isRange),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search + Dept + Date(s) – all in one row
          Row(
            children: [
              // Search (flex 3)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    style: GoogleFonts.poppins(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search employee…',
                      prefixIcon: const Icon(Icons.search,
                          size: 15, color: Colors.grey),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: fieldBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF5B60F6))),
                    ),
                    onChanged: ctrl.setSearchQuery,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Department dropdown (flex 2)
              Expanded(
                flex: 2,
                child: _DeptDropdown(
                    ctrl: ctrl, isDark: isDark, fieldBg: fieldBg),
              ),
              const SizedBox(width: 8),

              // Date controls
              if (!ctrl.isRange)
                _dateBtn(
                  context,
                  label: DateFormat('MMM d, yyyy')
                      .format(ctrl.singleDate),
                  icon: Icons.calendar_today,
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => GlassDatePicker(
                        initialDate: ctrl.singleDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        isLarge: true,
                        onDateSelected: (d) => ctrl.setSingleDate(d),
                      ),
                    );
                  },
                )
              else ...[
                _dateBtn(
                  context,
                  label:
                      'From: ${DateFormat('MMM d').format(ctrl.startDate)}',
                  icon: Icons.calendar_month_outlined,
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => GlassDatePicker(
                        initialDate: ctrl.startDate,
                        firstDate: DateTime(2020),
                        lastDate: ctrl.endDate,
                        isLarge: true,
                        onDateSelected: (d) => ctrl.setStartDate(d),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _dateBtn(
                  context,
                  label:
                      'To: ${DateFormat('MMM d').format(ctrl.endDate)}',
                  icon: Icons.calendar_month,
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => GlassDatePicker(
                        initialDate: ctrl.endDate,
                        firstDate: ctrl.startDate,
                        lastDate: DateTime(2030),
                        isLarge: true,
                        onDateSelected: (d) => ctrl.setEndDate(d),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeTab(DarAdminController ctrl, String label, bool active) {
    return GestureDetector(
      onTap: () => ctrl.toggleRange(label == 'Range'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF2D3139) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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

  Widget _dateBtn(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _DeptDropdown extends StatelessWidget {
  const _DeptDropdown(
      {required this.ctrl,
      required this.isDark,
      required this.fieldBg});
  final DarAdminController ctrl;
  final bool isDark;
  final Color fieldBg;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ctrl.selectedDepartment,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down,
              size: 16, color: Colors.grey),
          style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black87),
          dropdownColor:
              isDark ? const Color(0xFF161B22) : Colors.white,
          items: [
            DropdownMenuItem(
                value: null,
                child: Row(children: [
                  const Icon(Icons.business,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('All Depts',
                      style: GoogleFonts.poppins(fontSize: 12)),
                ])),
            ...ctrl.departments.map(
              (d) => DropdownMenuItem(
                  value: d,
                  child: Text(d,
                      style: GoogleFonts.poppins(fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
            ),
          ],
          onChanged: ctrl.setDepartment,
        ),
      ),
    );
  }
}

// ── Employee card (3-col grid) ────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard(
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

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: isDark
                ? const Color(0xFF30363D)
                : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => DarAdminSheet.show(context, emp, ctrl),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Avatar + name row
              Row(children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor:
                      const Color(0xFF5B60F6).withValues(alpha: 0.12),
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5B60F6),
                        fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.userName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(emp.department ?? 'Staff',
                          style: GoogleFonts.poppins(
                              fontSize: 9.5, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),

              // Designation
              Text(emp.designation ?? 'Employee',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),

              // Divider + stats
              const Divider(height: 8, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasData)
                    Flexible(
                      child: Wrap(spacing: 4, children: [
                        if (tasks > 0)
                          _badge(
                              '$tasks Tasks', Colors.blue, isDark),
                        if (meetings > 0)
                          _badge('$meetings Meets', Colors.teal,
                              isDark),
                      ]),
                    )
                  else
                    Text('No activity',
                        style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic)),
                  const Icon(Icons.arrow_forward_ios,
                      size: 9, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }
}
