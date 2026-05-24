import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../employees/models/employee_model.dart';
import './dar_admin_controller.dart';
import './dar_admin_sheet.dart';
import '../../../../shared/widgets/glass_date_picker.dart';

/// Tablet-landscape layout for the admin DAR overview.
/// 260 px left sidebar (all filters + overview stats) + 4-column employee grid.
class DarAdminTabletLandscapeView extends StatelessWidget {
  const DarAdminTabletLandscapeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DarAdminController>(
      builder: (context, ctrl, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final filtered = ctrl.filteredEmployees;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left filter sidebar ──────────────────────────────────────
            SizedBox(
              width: 260,
              child: _Sidebar(ctrl: ctrl, isDark: isDark),
            ),

            // Divider
            Container(
              width: 1,
              color: isDark
                  ? const Color(0xFF30363D)
                  : Colors.grey[200],
            ),

            // ── Right employee grid ──────────────────────────────────────
            Expanded(
              child: ctrl.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmpty(isDark)
                      : RefreshIndicator(
                          onRefresh: ctrl.fetchAll,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 24, 16, 80),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.3,
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

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final fieldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(children: [
            const Icon(Icons.tune, color: Color(0xFF5B60F6), size: 15),
            const SizedBox(width: 6),
            Text(
              'Filters',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87),
            ),
          ]),
          const SizedBox(height: 12),

          // Mode toggle (full width)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border)),
            child: Row(children: [
              Expanded(child: _modeTab('Single', !ctrl.isRange)),
              Expanded(child: _modeTab('Range', ctrl.isRange)),
            ]),
          ),
          const SizedBox(height: 10),

          // Date control(s)
          if (!ctrl.isRange)
            _dateSidebarBtn(
              context,
              label: DateFormat('MMM d, yyyy').format(ctrl.singleDate),
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
            _dateSidebarBtn(
              context,
              label:
                  'From: ${DateFormat('MMM d, yyyy').format(ctrl.startDate)}',
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
            const SizedBox(height: 6),
            _dateSidebarBtn(
              context,
              label:
                  'To: ${DateFormat('MMM d, yyyy').format(ctrl.endDate)}',
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
          const SizedBox(height: 12),

          // Search field
          SizedBox(
            height: 38,
            child: TextField(
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search employee…',
                prefixIcon: const Icon(Icons.search,
                    size: 15, color: Colors.grey),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF5B60F6))),
              ),
              onChanged: ctrl.setSearchQuery,
            ),
          ),
          const SizedBox(height: 8),

          // Department dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: bg,
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
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('All Departments',
                          style: GoogleFonts.poppins(fontSize: 12)),
                    ]),
                  ),
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
          ),

          const SizedBox(height: 18),
          Divider(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]),
          const SizedBox(height: 14),

          // Overview stats
          Text('Overview',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 10),
          _OverviewStats(ctrl: ctrl, isDark: isDark),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool active) {
    return GestureDetector(
      onTap: () => ctrl.toggleRange(label == 'Range'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF2D3139) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3)
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active
                  ? (isDark ? Colors.white : const Color(0xFF5B60F6))
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateSidebarBtn(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
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
          children: [
            Icon(icon, size: 13, color: const Color(0xFF5B60F6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.arrow_drop_down,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ── Overview stats in sidebar ─────────────────────────────────────────────────

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.ctrl, required this.isDark});
  final DarAdminController ctrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final filtered = ctrl.filteredEmployees;
    int totalTasks = 0, totalMeetings = 0, withActivity = 0;
    for (final emp in filtered) {
      final s = ctrl.getStats(emp.userId);
      totalTasks += s['tasks']!;
      totalMeetings += s['meetings']!;
      if (s['tasks']! > 0 || s['meetings']! > 0) withActivity++;
    }

    return Column(
      children: [
        _statRow(Icons.people_outline, 'Total Employees',
            '${filtered.length}', Colors.blue),
        const SizedBox(height: 6),
        _statRow(Icons.check_circle_outline, 'With Activity',
            '$withActivity', Colors.teal),
        const SizedBox(height: 6),
        _statRow(Icons.task_alt_outlined, 'Total Tasks',
            '$totalTasks', Colors.orange),
        const SizedBox(height: 6),
        _statRow(Icons.event_outlined, 'Total Meetings',
            '$totalMeetings', Colors.purple),
      ],
    );
  }

  Widget _statRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color:
                          isDark ? Colors.white70 : Colors.black87))),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Employee card (4-col grid) ────────────────────────────────────────────────

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
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor:
                      const Color(0xFF5B60F6).withValues(alpha: 0.12),
                  child: Text(initials,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5B60F6),
                          fontSize: 10.5)),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.userName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(emp.department ?? 'Staff',
                          style: GoogleFonts.poppins(
                              fontSize: 9, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
              Text(emp.designation ?? 'Employee',
                  style: GoogleFonts.poppins(
                      fontSize: 9.5, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const Divider(height: 6, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasData)
                    Flexible(
                      child: Wrap(spacing: 3, children: [
                        if (tasks > 0)
                          _badge('${tasks}T', Colors.blue),
                        if (meetings > 0)
                          _badge('${meetings}M', Colors.teal),
                      ]),
                    )
                  else
                    Text('—',
                        style: GoogleFonts.poppins(
                            fontSize: 9.5, color: Colors.grey[400])),
                  const Icon(Icons.arrow_forward_ios,
                      size: 8, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }
}
