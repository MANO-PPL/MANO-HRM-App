import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/policies/core/salary_package_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class SalaryPackagesTabView extends StatefulWidget {
  const SalaryPackagesTabView({super.key});

  @override
  State<SalaryPackagesTabView> createState() => _SalaryPackagesTabViewState();
}

class _SalaryPackagesTabViewState extends State<SalaryPackagesTabView> {
  SalaryPackageService? _packageService;

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  List<Map<String, dynamic>> _packageGroups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      _packageService = SalaryPackageService(auth.dio);
      _fetchPackagesData();
    });
  }

  Future<void> _fetchPackagesData() async {
    if (_packageService == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _packageService!.getPackageGroups(),
        _packageService!.getEmployeesWithPackages(),
      ]);

      final packages = results[0];
      final employees = results[1];

      if (mounted) {
        setState(() {
          _packageGroups = packages.map((pkg) {
            final pkgId = pkg['package_group_id'];
            final assigned = employees.where((e) => e['package_group_id'] == pkgId).toList();
            final updated = Map<String, dynamic>.from(pkg);
            updated['assigned_count'] = assigned.length;
            updated['assigned_employees'] = assigned;
            return updated;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        context.showToast(_errorMessage!, isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final filtered = _packageGroups.where((p) {
      if (_searchQuery.isEmpty) return true;
      final name = (p['package_name'] ?? p['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Space-Saving Toolbar: Search + Refresh + Add Package
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: "Search package...",
                      hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 15),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              onPressed: () => setState(() => _searchQuery = ''),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  tooltip: "Refresh Packages",
                  onPressed: _isLoading ? null : _fetchPackagesData,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  onPressed: () => _showAddPackageModal(isDark),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                  label: Text(
                    "Add Package",
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Packages List / State Views
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  )
                : _errorMessage != null && _packageGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 36, color: Colors.red[400]),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: _fetchPackagesData,
                              icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
                              label: Text("Retry", style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined, size: 30, color: Color(0xFF6366F1)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? "No packages match '$_searchQuery'"
                                      : "No salary packages found",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? "Try a different search term"
                                      : "Create salary package groups with overtime rules",
                                  style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () => _showAddPackageModal(isDark),
                                    icon: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                                    label: Text(
                                      "Create Package",
                                      style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isMultiColumn = constraints.maxWidth > 850;
                              if (isMultiColumn) {
                                return RefreshIndicator(
                                  onRefresh: _fetchPackagesData,
                                  color: const Color(0xFF6366F1),
                                  child: GridView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 10),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 3.8,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final pkg = filtered[index];
                                      return _buildPackageCard(pkg, isDark, currencyFormatter, isGrid: true);
                                    },
                                  ),
                                );
                              }
                              return RefreshIndicator(
                                onRefresh: _fetchPackagesData,
                                color: const Color(0xFF6366F1),
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 10),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final pkg = filtered[index];
                                    return _buildPackageCard(pkg, isDark, currencyFormatter, isGrid: false);
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg, bool isDark, NumberFormat formatter, {bool isGrid = false}) {
    final String name = pkg['package_name']?.toString() ?? pkg['name']?.toString() ?? 'Unnamed Package';
    final dynamic rate = pkg['active_rate'];

    final double gross = rate != null
        ? (num.tryParse(rate['gross_salary']?.toString() ?? '0')?.toDouble() ?? 0.0)
        : (num.tryParse(pkg['gross_salary']?.toString() ?? '0')?.toDouble() ?? 0.0);

    final bool hasOvertime = rate != null
        ? (rate['overtime_enabled'] == 1 || rate['overtime_enabled'] == true)
        : (pkg['overtime_enabled'] == true || pkg['overtime_enabled'] == 1);

    final double overtimeRate = rate != null
        ? (num.tryParse(rate['overtime_rate']?.toString() ?? '0')?.toDouble() ?? 0.0)
        : (num.tryParse(pkg['overtime_rate']?.toString() ?? '0')?.toDouble() ?? 0.0);

    final String rawDate = (rate != null ? rate['effective_from'] : pkg['effective_from'])?.toString() ?? '';
    final String effectiveFrom = rawDate.isNotEmpty ? rawDate.split('T')[0] : 'N/A';

    final int assignedCount = (pkg['assigned_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showPackageDetailModal(pkg, isDark, formatter),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Row: Title + Assigned Pill + Chevron
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "$assignedCount Staff",
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Metrics Strip
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("MONTHLY GROSS", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                          const SizedBox(height: 1),
                          Text(
                            formatter.format(gross),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("OVERTIME", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                          const SizedBox(height: 1),
                          Text(
                            hasOvertime ? "${formatter.format(overtimeRate)}/hr" : "Disabled",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasOvertime ? const Color(0xFFF59E0B) : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("EFFECTIVE FROM", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                          const SizedBox(height: 1),
                          Text(
                            effectiveFrom,
                            style: GoogleFonts.poppins(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPackageDetailModal(
    Map<String, dynamic> pkg,
    bool isDark,
    NumberFormat formatter,
  ) {
    final String name = pkg['package_name']?.toString() ?? pkg['name']?.toString() ?? 'Package Details';
    final dynamic pkgId = pkg['package_group_id'] ?? pkg['id'];
    final dynamic rate = pkg['active_rate'];

    final double gross = rate != null
        ? (num.tryParse(rate['gross_salary']?.toString() ?? '0')?.toDouble() ?? 0.0)
        : (num.tryParse(pkg['gross_salary']?.toString() ?? '0')?.toDouble() ?? 0.0);

    final bool hasOvertime = rate != null
        ? (rate['overtime_enabled'] == 1 || rate['overtime_enabled'] == true)
        : (pkg['overtime_enabled'] == true || pkg['overtime_enabled'] == 1);

    final double overtimeRate = rate != null
        ? (num.tryParse(rate['overtime_rate']?.toString() ?? '0')?.toDouble() ?? 0.0)
        : (num.tryParse(pkg['overtime_rate']?.toString() ?? '0')?.toDouble() ?? 0.0);

    final int assignedCount = (pkg['assigned_count'] as num?)?.toInt() ?? 0;
    final List<dynamic> assignedEmployees = (pkg['assigned_employees'] as List<dynamic>?) ?? [];

    final String rawDate = (rate != null ? rate['effective_from'] : pkg['effective_from'])?.toString() ?? '';
    final String effectiveFrom = rawDate.isNotEmpty ? rawDate.split('T')[0] : 'N/A';

    final bool isActive = (pkg['is_active'] == 1 || pkg['is_active'] == true);
    final String rawCreated = pkg['created_at']?.toString() ?? '';
    final String createdAt = rawCreated.isNotEmpty ? rawCreated.split('T')[0] : '';

    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC);

    List<Map<String, dynamic>> revisions = [];
    bool isLoadingRevisions = true;
    bool hasInitiatedFetch = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (!hasInitiatedFetch && _packageService != null && pkgId != null) {
            hasInitiatedFetch = true;
            _packageService!.getPackageRevisions(pkgId).then((data) {
              if (sheetCtx.mounted) {
                setSheetState(() {
                  revisions = data;
                  isLoadingRevisions = false;
                });
              }
            }).catchError((_) {
              if (sheetCtx.mounted) {
                setSheetState(() {
                  isLoadingRevisions = false;
                });
              }
            });
          }

          return Material(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1),
                ),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF30363D) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF6366F1),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isActive ? "Active" : "Inactive",
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? const Color(0xFF10B981) : Colors.grey,
                                    ),
                                  ),
                                ),
                                if (createdAt.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    "Created: $createdAt",
                                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : Colors.grey[600]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Monthly Gross & Assignment Banner Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                    : [const Color(0xFFEEF2FF), const Color(0xFFF1F5F9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "MONTHLY GROSS SALARY",
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatter.format(gross),
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "$assignedCount",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF6366F1),
                                        ),
                                      ),
                                      Text(
                                        "Employees",
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Database Configuration Card
                          Text(
                            "RATE & POLICY CONFIGURATION",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  "Effective From",
                                  effectiveFrom,
                                  textColor,
                                  isDark,
                                  leadingIcon: Icons.calendar_today_outlined,
                                ),
                                Divider(height: 12, color: borderColor),
                                _buildDetailRow(
                                  "Overtime Pay",
                                  hasOvertime ? "Eligible" : "Disabled",
                                  hasOvertime ? const Color(0xFF10B981) : Colors.grey,
                                  isDark,
                                  leadingIcon: hasOvertime ? Icons.check_circle_outline : Icons.cancel_outlined,
                                ),
                                if (hasOvertime) ...[
                                  Divider(height: 12, color: borderColor),
                                  _buildDetailRow(
                                    "Overtime Rate",
                                    "${formatter.format(overtimeRate)} / hr",
                                    const Color(0xFFF59E0B),
                                    isDark,
                                    leadingIcon: Icons.timer_outlined,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Assigned Employees (if any exist)
                          if (assignedEmployees.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              "ASSIGNED EMPLOYEES ($assignedCount)",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: assignedEmployees.map((emp) {
                                  final empName = emp['user_name'] ?? emp['name'] ?? 'Staff #${emp['user_id']}';
                                  final desg = emp['desg_name']?.toString() ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                          child: Text(
                                            empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          empName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                        if (desg.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            "($desg)",
                                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          // Revision History from Database (if available)
                          if (!isLoadingRevisions && revisions.length > 1) ...[
                            const SizedBox(height: 14),
                            Text(
                              "RATE REVISION HISTORY",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: revisions.map((rev) {
                                  final double revGross = num.tryParse(rev['gross_salary']?.toString() ?? '0')?.toDouble() ?? 0.0;
                                  final bool revOt = rev['overtime_enabled'] == 1 || rev['overtime_enabled'] == true;
                                  final double revOtRate = num.tryParse(rev['overtime_rate']?.toString() ?? '0')?.toDouble() ?? 0.0;
                                  final String revFrom = rev['effective_from']?.toString().split('T')[0] ?? '';
                                  final String revTo = rev['effective_to']?.toString().split('T')[0] ?? '';
                                  final bool isCurrent = revTo.isEmpty;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              formatter.format(revGross),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            ),
                                            Text(
                                              revOt ? "OT: ${formatter.format(revOtRate)}/hr" : "OT: Disabled",
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: revOt ? const Color(0xFFF59E0B) : Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isCurrent
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                    : Colors.grey.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isCurrent ? "Active" : "Till $revTo",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isCurrent ? const Color(0xFF10B981) : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "From: $revFrom",
                                              style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Bottom Action Buttons (Delete & Done)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: sheetCtx,
                                      builder: (dlgCtx) => AlertDialog(
                                        backgroundColor: bgColor,
                                        title: Text(
                                          "Delete Package Group?",
                                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                        content: Text(
                                          "Are you sure you want to delete '$name'? This action will soft-delete the package from the database.",
                                          style: GoogleFonts.poppins(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dlgCtx, false),
                                            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11.5)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => Navigator.pop(dlgCtx, true),
                                            child: Text("Delete", style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.5)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      if (sheetCtx.mounted) {
                                        Navigator.pop(sheetCtx);
                                      }
                                      try {
                                        await _packageService!.deletePackageGroup(pkgId);
                                        if (!mounted) return;
                                        context.showToast("Salary package deleted successfully!", isSuccess: true);
                                        _fetchPackagesData();
                                      } catch (err) {
                                        if (!mounted) return;
                                        context.showToast(err.toString().replaceAll('Exception: ', ''), isSuccess: false);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                                  label: Text(
                                    "Delete",
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  icon: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                                  label: Text(
                                    "Done",
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor, bool isDark, {IconData? leadingIcon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildBreakdownRow(String label, String value, Color valueColor, bool isDark, {IconData? leadingIcon}) {
    return _buildDetailRow(label, value, valueColor, isDark, leadingIcon: leadingIcon);
  }

  void _showAddPackageModal(bool isDark) {
    final nameCtrl = TextEditingController();
    final grossCtrl = TextEditingController();
    final otCtrl = TextEditingController();
    DateTime effectiveDate = DateTime.now();
    bool otEnabled = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Material(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 14,
              left: 14,
              right: 14,
              top: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Create Salary Package Group",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white70 : Colors.grey[600]),
                      onPressed: () => Navigator.pop(modalCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Package Name
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.poppins(fontSize: 11.5),
                  decoration: InputDecoration(
                    labelText: "Package Group Name",
                    labelStyle: GoogleFonts.poppins(fontSize: 10.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),

                // Monthly Gross
                TextField(
                  controller: grossCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 11.5),
                  decoration: InputDecoration(
                    labelText: "Monthly Gross Salary (₹)",
                    labelStyle: GoogleFonts.poppins(fontSize: 10.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),

                // Effective From Date Selector
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: modalCtx,
                      initialDate: effectiveDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setModalState(() => effectiveDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Effective From Date", style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey[500])),
                            Text(
                              DateFormat('yyyy-MM-dd').format(effectiveDate),
                              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF6366F1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Overtime Switch wrapped in Material for zero assertion warnings
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Enable Overtime Pay", style: GoogleFonts.poppins(fontSize: 11.5)),
                    value: otEnabled,
                    onChanged: (val) => setModalState(() => otEnabled = val),
                  ),
                ),
                if (otEnabled) ...[
                  TextField(
                    controller: otCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(fontSize: 11.5),
                    decoration: InputDecoration(
                      labelText: "Overtime Rate (₹ / hr)",
                      labelStyle: GoogleFonts.poppins(fontSize: 10.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),

                // Save Package Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 9.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final grossText = grossCtrl.text.trim();

                            if (name.isEmpty || grossText.isEmpty) {
                              context.showToast("Please fill in package name and gross salary", isSuccess: false);
                              return;
                            }

                            final double? grossVal = double.tryParse(grossText);
                            if (grossVal == null || grossVal < 0) {
                              context.showToast("Please enter a valid gross salary", isSuccess: false);
                              return;
                            }

                            final double otRateVal = otEnabled ? (double.tryParse(otCtrl.text.trim()) ?? 0.0) : 0.0;
                            final effectiveDateStr = DateFormat('yyyy-MM-dd').format(effectiveDate);

                            setModalState(() => isSaving = true);

                            try {
                              await _packageService!.createPackageGroup(
                                packageName: name,
                                grossSalary: grossVal,
                                overtimeEnabled: otEnabled,
                                overtimeRate: otRateVal,
                                effectiveFrom: effectiveDateStr,
                              );

                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }

                              if (!mounted) return;
                              context.showToast("Salary Package Group created in database!", isSuccess: true);
                              _fetchPackagesData();
                            } catch (err) {
                              setModalState(() => isSaving = false);
                              if (!mounted) return;
                              context.showToast(err.toString().replaceAll('Exception: ', ''), isSuccess: false);
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            "Save Package to Database",
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
