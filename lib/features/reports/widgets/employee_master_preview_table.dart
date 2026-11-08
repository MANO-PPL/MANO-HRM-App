import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmployeeMasterRecord {
  final int srNo;
  final String code;
  final String name;
  final String department;
  final String designation;
  final String shift;
  final String phone;
  final String email;
  final String joiningDate;
  final String role;
  final String status;

  const EmployeeMasterRecord({
    required this.srNo,
    required this.code,
    required this.name,
    required this.department,
    required this.designation,
    required this.shift,
    required this.phone,
    required this.email,
    required this.joiningDate,
    required this.role,
    required this.status,
  });
}

class EmployeeMasterPreviewTable extends StatefulWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final String searchQuery;
  final VoidCallback? onExportExcel;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportPdf;
  final bool isExporting;

  const EmployeeMasterPreviewTable({
    super.key,
    required this.columns,
    required this.rows,
    this.searchQuery = '',
    this.onExportExcel,
    this.onExportCsv,
    this.onExportPdf,
    this.isExporting = false,
  });

  @override
  State<EmployeeMasterPreviewTable> createState() => _EmployeeMasterPreviewTableState();
}

class _EmployeeMasterPreviewTableState extends State<EmployeeMasterPreviewTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive', 'Deleted'

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  List<EmployeeMasterRecord> _parseRecords() {
    final cols = widget.columns;
    final rows = widget.rows;

    String getVal(List<dynamic> row, String colName, int fallbackIdx) {
      final cIdx = cols.indexWhere((c) => c.toLowerCase().trim() == colName.toLowerCase().trim());
      if (cIdx != -1 && cIdx < row.length && row[cIdx] != null) {
        return row[cIdx].toString();
      }
      if (fallbackIdx < row.length && row[fallbackIdx] != null) {
        return row[fallbackIdx].toString();
      }
      return '-';
    }

    final List<EmployeeMasterRecord> list = [];
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final code = getVal(row, 'Code', 0);
      final name = getVal(row, 'Name', 1);
      final dept = getVal(row, 'Department', 2);
      final desg = getVal(row, 'Designation', 3);
      final shift = getVal(row, 'Shift', 4);
      final phone = getVal(row, 'Phone', 5);
      final email = getVal(row, 'Email', 6);
      final joinDate = getVal(row, 'Joining Date', 7);
      final role = getVal(row, 'Role', 8);
      final status = getVal(row, 'Status', 9);

      list.add(EmployeeMasterRecord(
        srNo: i + 1,
        code: code.isNotEmpty ? code : "EMP-${i + 1}",
        name: name.isNotEmpty ? name : "Unknown",
        department: dept.isNotEmpty ? dept : "-",
        designation: desg.isNotEmpty ? desg : "-",
        shift: shift.isNotEmpty ? shift : "General Shift",
        phone: phone.isNotEmpty ? phone : "-",
        email: email.isNotEmpty ? email : "-",
        joiningDate: joinDate.isNotEmpty ? joinDate : "-",
        role: role.isNotEmpty ? role : "employee",
        status: status.isNotEmpty ? status : "Active",
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allRecords = _parseRecords();

    // Compute status counts
    int activeCount = 0;
    int inactiveCount = 0;
    int deletedCount = 0;
    for (final r in allRecords) {
      final s = r.status.toLowerCase();
      if (s == 'active') {
        activeCount++;
      } else if (s == 'deleted') {
        deletedCount++;
      } else {
        inactiveCount++;
      }
    }

    // Filter by search query & status filter
    final q = widget.searchQuery.toLowerCase().trim();
    final filtered = allRecords.where((r) {
      if (_statusFilter != 'All') {
        if (r.status.toLowerCase() != _statusFilter.toLowerCase()) return false;
      }
      if (q.isNotEmpty) {
        final matches = r.name.toLowerCase().contains(q) ||
            r.code.toLowerCase().contains(q) ||
            r.department.toLowerCase().contains(q) ||
            r.designation.toLowerCase().contains(q) ||
            r.phone.toLowerCase().contains(q) ||
            r.email.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar with Filter Badges ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Employee Master Data",
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${filtered.length} of ${allRecords.length}",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusPill(
                        label: "All (${allRecords.length})",
                        isSelected: _statusFilter == 'All',
                        onTap: () => setState(() => _statusFilter = 'All'),
                        selectedColor: const Color(0xFF6366F1),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 5),
                      _buildStatusPill(
                        label: "Active ($activeCount)",
                        isSelected: _statusFilter == 'Active',
                        onTap: () => setState(() => _statusFilter = _statusFilter == 'Active' ? 'All' : 'Active'),
                        selectedColor: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 5),
                      _buildStatusPill(
                        label: "Inactive ($inactiveCount)",
                        isSelected: _statusFilter == 'Inactive',
                        onTap: () => setState(() => _statusFilter = _statusFilter == 'Inactive' ? 'All' : 'Inactive'),
                        selectedColor: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                      if (deletedCount > 0) ...[
                        const SizedBox(width: 5),
                        _buildStatusPill(
                          label: "Deleted ($deletedCount)",
                          isSelected: _statusFilter == 'Deleted',
                          onTap: () => setState(() => _statusFilter = _statusFilter == 'Deleted' ? 'All' : 'Deleted'),
                          selectedColor: const Color(0xFFEF4444),
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Table Area ──────────────────────────────────────
          Expanded(
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: Scrollbar(
                controller: _horizontalController,
                notificationPredicate: (notif) => notif.depth == 1,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: _buildTable(isDark, filtered),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color selectedColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(bool isDark, List<EmployeeMasterRecord> records) {
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    const headerBg = Color(0xFF1F4E78);

    if (records.isEmpty) {
      return Container(
        width: 600,
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Text(
          "No employee records matched your filter criteria.",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
        ),
      );
    }

    return Table(
      defaultColumnWidth: const FixedColumnWidth(110),
      columnWidths: const {
        0: FixedColumnWidth(42),  // SR No
        1: FixedColumnWidth(95),  // Code
        2: FixedColumnWidth(160), // Name
        3: FixedColumnWidth(115), // Department
        4: FixedColumnWidth(115), // Designation
        5: FixedColumnWidth(105), // Shift
        6: FixedColumnWidth(110), // Phone
        7: FixedColumnWidth(165), // Email
        8: FixedColumnWidth(100), // Joining Date
        9: FixedColumnWidth(80),  // Role
        10: FixedColumnWidth(90), // Status
      },
      border: TableBorder.all(color: borderColor, width: 1),
      children: [
        // Header Row
        TableRow(
          decoration: const BoxDecoration(color: headerBg),
          children: [
            _buildHeaderCell("SR"),
            _buildHeaderCell("CODE"),
            _buildHeaderCell("EMPLOYEE NAME", alignLeft: true),
            _buildHeaderCell("DEPARTMENT"),
            _buildHeaderCell("DESIGNATION"),
            _buildHeaderCell("SHIFT"),
            _buildHeaderCell("PHONE"),
            _buildHeaderCell("EMAIL"),
            _buildHeaderCell("JOIN DATE"),
            _buildHeaderCell("ROLE"),
            _buildHeaderCell("STATUS"),
          ],
        ),

        // Data Rows
        for (int i = 0; i < records.length; i++)
          _buildRow(records[i], i, isDark),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {bool alignLeft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  TableRow _buildRow(EmployeeMasterRecord emp, int idx, bool isDark) {
    final isEven = idx % 2 == 0;
    final rowBg = isEven
        ? (isDark ? const Color(0xFF0D1117) : Colors.white)
        : (isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC));

    final isActive = emp.status.toLowerCase() == 'active';
    final isDeleted = emp.status.toLowerCase() == 'deleted';

    final initial = emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E';

    return TableRow(
      decoration: BoxDecoration(color: rowBg),
      children: [
        // SR No
        _buildTextCell('${emp.srNo}', isDark, isMono: true, center: true),

        // Code
        _buildTextCell(emp.code, isDark, isMono: true, center: true),

        // Employee Name with Avatar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  emp.name,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Department
        _buildTextCell(emp.department, isDark),

        // Designation
        _buildTextCell(emp.designation, isDark),

        // Shift
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              emp.shift,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF475569),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // Phone
        _buildTextCell(emp.phone, isDark, isMono: true, center: true),

        // Email
        _buildTextCell(emp.email, isDark, isLink: true),

        // Joining Date
        _buildTextCell(emp.joiningDate, isDark, isMono: true, center: true),

        // Role
        _buildTextCell(emp.role.toUpperCase(), isDark, isSmall: true, center: true),

        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : isDeleted
                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : isDeleted
                        ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF10B981)
                        : isDeleted
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  emp.status,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF10B981)
                        : isDeleted
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextCell(
    String text,
    bool isDark, {
    bool isMono = false,
    bool isLink = false,
    bool isSmall = false,
    bool center = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(
        text,
        style: isMono
            ? GoogleFonts.robotoMono(
                fontSize: 10,
                color: isDark ? const Color(0xFFC9D1D9) : const Color(0xFF334155),
              )
            : GoogleFonts.poppins(
                fontSize: isSmall ? 9.5 : 10.5,
                fontWeight: isLink ? FontWeight.w500 : FontWeight.normal,
                color: isLink
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFFC9D1D9) : const Color(0xFF334155)),
              ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
