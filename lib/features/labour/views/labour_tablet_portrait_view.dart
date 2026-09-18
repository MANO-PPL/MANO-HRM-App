import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/shared/widgets/loading_screen.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/core/labour_service.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';
import 'package:flutter_application/features/labour/widgets/add_site_dialog.dart';
import 'package:flutter_application/features/labour/widgets/add_worker_dialog.dart';
import 'package:flutter_application/features/labour/widgets/bulk_transfer_dialog.dart';
import 'package:flutter_application/features/labour/widgets/borrow_worker_dialog.dart';
import 'package:flutter_application/features/labour/widgets/log_advance_dialog.dart';
import 'package:flutter_application/features/labour/widgets/settle_payout_dialog.dart';
import 'package:flutter_application/features/labour/widgets/labour_history_dialog.dart';
import 'package:flutter_application/features/labour/widgets/daily_schedule_dialog.dart';
import 'package:flutter_application/features/labour/widgets/confirm_dialog.dart';
import 'package:flutter_application/features/labour/widgets/bulk_upload_dialog.dart';
import 'package:flutter_application/features/labour/widgets/wage_revision_dialog.dart';
import 'package:flutter_application/features/labour/core/labour_excel_export.dart';

class LabourTabletContent extends StatefulWidget {
  const LabourTabletContent({super.key});

  @override
  State<LabourTabletContent> createState() => _LabourTabletContentState();
}

/// Tablet Portrait Mode View Typedefs
typedef LabourTabletPortraitView = LabourTabletContent;
typedef LabourTabletPortraitContent = LabourTabletContent;

class _LabourTabletContentState extends State<LabourTabletContent> with SingleTickerProviderStateMixin {
  late LabourService _labourService;
  bool _isLoading = true;
  bool _isSavingAttendance = false;

  // Active Main Tab: 'sites' or 'directory'
  String _activeTab = 'sites';

  // Selected site for drill-down (null = Site Directory view, non-null = Site Dashboard)
  LabourSite? _selectedSite;

  // Subtab inside Site Dashboard: 'attendance', 'grid', 'finances'
  String _subTab = 'attendance';

  // Monthly Grid View Mode: false = Fast Card View (lag-free), true = Full Spreadsheet Table
  bool _isGridTableMode = false;

  // Data from Backend
  List<LabourSite> _sites = [];
  List<LabourWorker> _workers = [];
  List<LabourAttendanceItem> _attendanceRoster = [];
  List<LabourMonthlyRow> _gridData = [];
  List<LabourPayoutSummary> _financeSummary = [];

  // Multi-Selection Roster Batch State & Unsaved Changes Tracking
  final Set<int> _selectedRosterIds = {};
  double _batchOvertimeHours = 0.0;
  bool _hasUnsavedChanges = false;

  // Filters & State
  String _siteSearch = '';
  String _siteStatusFilter = 'All'; // All, Active, Completed, On Hold

  DateTime _attendanceDate = DateTime.now();
  String _attendanceSearch = '';
  String _attendanceRoleFilter = 'All';
  String _attendanceStatusFilter = 'All'; // All, Present, Half Day, Absent, Paid Leave, Unmarked
  bool _showAttendanceSearch = false;
  bool _attendanceLoading = false;

  DateTime _gridMonth = DateTime.now();
  String _gridRoleFilter = 'All';
  bool _gridLoading = false;

  String _financeRoleFilter = 'All';
  bool _financeLoading = false;

  String _directorySearch = '';
  dynamic _directorySiteFilter = 'All'; // 'All', 'Unassigned', or int site_id
  String _directoryRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _labourService = LabourService(authService.dio);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final sites = await _labourService.getAllSites();
      final workers = await _labourService.getAllLabours();

      if (mounted) {
        setState(() {
          _sites = sites;
          _workers = workers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showExceptionToast(e, fallback: "Failed to load labour data.");
      }
    }
  }

  Future<void> _loadAttendanceRoster() async {
    if (_selectedSite == null) return;
    setState(() {
      _attendanceLoading = true;
      _selectedRosterIds.clear();
      _hasUnsavedChanges = false;
    });
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);

    try {
      final roster = await _labourService.getSiteAttendance(_selectedSite!.siteId, dateStr);
      if (mounted) {
        setState(() {
          _attendanceRoster = roster;
          _attendanceLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _attendanceLoading = false);
        context.showExceptionToast(e, fallback: "Failed to fetch site attendance roster.");
      }
    }
  }

  Future<void> _loadMonthlyGrid() async {
    if (_selectedSite == null) return;
    setState(() => _gridLoading = true);
    final monthStr = DateFormat('yyyy-MM').format(_gridMonth);

    try {
      final res = await _labourService.getMonthlyGridAttendance(
        siteId: _selectedSite!.siteId,
        monthStr: monthStr,
      );
      if (mounted) {
        setState(() {
          _gridData = res.grid;
          _gridLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gridLoading = false);
        context.showExceptionToast(e, fallback: "Failed to load monthly attendance grid.");
      }
    }
  }

  Future<void> _loadFinances() async {
    if (_selectedSite == null) return;
    setState(() => _financeLoading = true);
    final monthStr = DateFormat('yyyy-MM').format(_attendanceDate);

    try {
      final res = await _labourService.getFinancesSummary(
        siteId: _selectedSite!.siteId,
        monthStr: monthStr,
      );
      if (mounted) {
        setState(() {
          _financeSummary = res.summary;
          _financeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _financeLoading = false);
        context.showExceptionToast(e, fallback: "Failed to load financial breakdown.");
      }
    }
  }

  void _onSelectSite(LabourSite site) {
    setState(() {
      _selectedSite = site;
      _subTab = 'attendance';
      _attendanceStatusFilter = 'All';
      _gridMonth = DateTime(_attendanceDate.year, _attendanceDate.month);
    });
    _loadAttendanceRoster();
    _loadMonthlyGrid();
  }

  void _onBackToSites() {
    setState(() {
      _selectedSite = null;
    });
  }

  Future<void> _saveAttendance() async {
    if (_selectedSite == null) return;
    setState(() => _isSavingAttendance = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);
    final payload = _attendanceRoster.map((item) => item.toJson()).toList();

    try {
      await _labourService.saveSiteAttendance(_selectedSite!.siteId, dateStr, payload);
      if (mounted) {
        context.showToast("Attendance saved successfully!", isSuccess: true);
        setState(() {
          _hasUnsavedChanges = false;
          _selectedRosterIds.clear();
        });
        await _loadAttendanceRoster();
        _loadMonthlyGrid();
      }
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: "Failed to save attendance roster.");
      }
    } finally {
      if (mounted) setState(() => _isSavingAttendance = false);
    }
  }

  void _toggleSelectRoster(int labourId) {
    setState(() {
      if (_selectedRosterIds.contains(labourId)) {
        _selectedRosterIds.remove(labourId);
      } else {
        _selectedRosterIds.add(labourId);
      }
    });
  }

  void _toggleSelectAllVisible(List<LabourAttendanceItem> visibleRoster) {
    setState(() {
      final visibleIds = visibleRoster.map((r) => r.labourId).toSet();
      if (_selectedRosterIds.containsAll(visibleIds) && visibleIds.isNotEmpty) {
        _selectedRosterIds.removeAll(visibleIds);
      } else {
        _selectedRosterIds.addAll(visibleIds);
      }
    });
  }

  void _markAllVisible(List<LabourAttendanceItem> visibleRoster, String status) {
    setState(() {
      for (final item in visibleRoster) {
        final bool isConflict = (status == 'Present' || status == 'Half Day' || status == 'Paid Leave') &&
            item.alreadyMarkedAt != null &&
            !item.isScheduledMultiSite;
        if (!isConflict) {
          if (status == 'Paid Leave' && !item.wageType.toLowerCase().contains('fixed')) {
            continue;
          }
          item.status = status;
        }
      }
      _hasUnsavedChanges = true;
      if (_attendanceStatusFilter == 'Unmarked' && status.isNotEmpty) {
        _attendanceStatusFilter = 'All';
      }
    });
    context.showToast("Marked visible workers as $status. Click 'Save Roster' to commit.", isSuccess: true);
  }

  void _markUnmarkedVisible(List<LabourAttendanceItem> visibleRoster, String status) {
    int changed = 0;
    setState(() {
      for (final item in visibleRoster) {
        if (item.status.isEmpty) {
          final bool isConflict = (status == 'Present' || status == 'Half Day' || status == 'Paid Leave') &&
              item.alreadyMarkedAt != null &&
              !item.isScheduledMultiSite;
          if (!isConflict) {
            if (status == 'Paid Leave' && !item.wageType.toLowerCase().contains('fixed')) {
              continue;
            }
            item.status = status;
            changed++;
          }
        }
      }
      if (changed > 0) _hasUnsavedChanges = true;
      if (_attendanceStatusFilter == 'Unmarked') {
        _attendanceStatusFilter = 'All';
      }
    });
    context.showToast("Marked $changed unmarked workers as $status.", isSuccess: true);
  }

  void _resetAllVisible(List<LabourAttendanceItem> visibleRoster) {
    setState(() {
      for (final item in visibleRoster) {
        item.status = '';
        item.overtimeHours = 0.0;
      }
      _hasUnsavedChanges = true;
    });
    context.showToast("Cleared attendance marks for visible workers.", isSuccess: true);
  }

  void _batchSetStatus(String status) {
    if (_selectedRosterIds.isEmpty) return;
    int updated = 0;
    setState(() {
      for (final item in _attendanceRoster) {
        if (_selectedRosterIds.contains(item.labourId)) {
          final bool isConflict = (status == 'Present' || status == 'Half Day' || status == 'Paid Leave') &&
              item.alreadyMarkedAt != null &&
              !item.isScheduledMultiSite;
          if (!isConflict) {
            if (status == 'Paid Leave' && !item.wageType.toLowerCase().contains('fixed')) {
              continue;
            }
            item.status = status;
            updated++;
          }
        }
      }
      _hasUnsavedChanges = true;
    });
    context.showToast("Updated $updated selected workers to $status.", isSuccess: true);
  }

  void _batchSetOvertime(double hours) {
    if (_selectedRosterIds.isEmpty) return;
    setState(() {
      _batchOvertimeHours = hours.clamp(0.0, 12.0);
      for (final item in _attendanceRoster) {
        if (_selectedRosterIds.contains(item.labourId) && item.status == 'Present') {
          item.overtimeHours = _batchOvertimeHours;
        }
      }
      _hasUnsavedChanges = true;
    });
    context.showToast("Set overtime to ${_batchOvertimeHours.toStringAsFixed(1)}h for present selected workers.", isSuccess: true);
  }

  void _setItemStatus(LabourAttendanceItem item, String status) {
    final bool isConflict = (status == 'Present' || status == 'Half Day' || status == 'Paid Leave') &&
        item.alreadyMarkedAt != null &&
        !item.isScheduledMultiSite;
    if (isConflict) {
      context.showToast("Worker is already marked ${item.alreadyMarkedAt!['status']} at ${item.alreadyMarkedAt!['site_name']}.", isError: true);
      return;
    }
    setState(() {
      item.status = item.status == status ? '' : status;
      _hasUnsavedChanges = true;
    });
  }

  void _setItemOvertime(LabourAttendanceItem item, double hours) {
    setState(() {
      item.overtimeHours = hours.clamp(0.0, 12.0);
      _hasUnsavedChanges = true;
    });
  }

  void _openWageHistoryDialog(LabourWorker worker) {
    WageRevisionDialog.show(
      context,
      worker: worker,
      labourService: _labourService,
      onRevisionUpdated: () {
        _loadInitialData();
      },
    );
  }

  void _markAllPresent() {
    _markAllVisible(_attendanceRoster, 'Present');
  }

  // ===========================================================================
  // BUILD METHOD (TABLET PORTRAIT)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LoadingScreen(
      isLoading: _isLoading,
      message: "Loading Labour Management (Tablet)...",
      child: Container(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        child: Column(
          children: [
            if (_selectedSite == null) _buildPrimaryTabBar(isDark),
            Expanded(
              child: _activeTab == 'sites'
                  ? (_selectedSite == null ? _buildSitesOverview(isDark) : _buildSiteDashboard(isDark))
                  : _buildLabourDirectory(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRIMARY NAVIGATION BAR (SITES VS DIRECTORY)
  // ---------------------------------------------------------------------------
  Widget _buildPrimaryTabBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))),
      ),
      child: Container(
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _buildTabPill('sites', Icons.apartment_rounded, "Contract Sites", _sites.length, isDark),
            const SizedBox(width: 6),
            _buildTabPill('directory', Icons.groups_rounded, "Worker Directory", _workers.length, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String tabKey, IconData icon, String title, int count, bool isDark) {
    final isSelected = _activeTab == tabKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tabKey),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.22) : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SITES OVERVIEW (TABLET RESPONSIVE GRID)
  // ---------------------------------------------------------------------------
  Widget _buildSitesOverview(bool isDark) {
    final activeCount = _sites.where((s) => s.status == 'Active').length;
    final completedCount = _sites.where((s) => s.status == 'Completed').length;
    final totalWorkers = _workers.length;

    final filteredSites = _sites.where((s) {
      if (_siteStatusFilter != 'All' && s.status != _siteStatusFilter) return false;
      if (_siteSearch.isNotEmpty) {
        final q = _siteSearch.toLowerCase();
        final matchName = s.siteName.toLowerCase().contains(q);
        final matchLoc = s.locationDetails?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchLoc) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            // KPI Stat Cards (4 columns on tablet portrait)
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: "Active Sites",
                    value: "$activeCount",
                    icon: Icons.construction_rounded,
                    iconColor: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LabourStatCard(
                    title: "Completed",
                    value: "$completedCount",
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LabourStatCard(
                    title: "Total Labours",
                    value: "$totalWorkers",
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF6366F1),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LabourStatCard(
                    title: "All Sites",
                    value: "${_sites.length}",
                    icon: Icons.apartment_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search Bar + Actions Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (val) => setState(() => _siteSearch = val.trim()),
                      style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Search site by name or address...",
                        hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        suffixIcon: _siteSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 15),
                                onPressed: () => setState(() => _siteSearch = ''),
                              )
                            : null,
                        fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  onPressed: _openBulkTransferDialog,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF6366F1)),
                  label: Text("Transfer", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openAddSiteDialog,
                  icon: const Icon(Icons.add, color: Colors.white, size: 15),
                  label: Text("Add Site", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Completed', 'On Hold'].map((st) {
                  final isSelected = _siteStatusFilter == st;
                  int count = st == 'All' ? _sites.length : _sites.where((s) => s.status == st).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text("$st ($count)"),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _siteStatusFilter = st),
                      selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF6366F1),
                      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Site Cards (Responsive Tablet Grid - 2 columns in portrait)
            Expanded(
              child: filteredSites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_city_outlined, size: 48, color: Colors.grey[500]),
                          const SizedBox(height: 10),
                          Text("No construction sites found", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: crossAxisCount == 3 ? 2.6 : 3.4,
                          ),
                          itemCount: filteredSites.length,
                          itemBuilder: (context, i) {
                            final site = filteredSites[i];
                            final assignedWorkers = _workers.where((w) => w.siteId == site.siteId || w.siteIds.contains(site.siteId)).length;
                            return LabourSiteCard(
                              site: site,
                              assignedWorkers: assignedWorkers,
                              onSelect: () => _onSelectSite(site),
                              onEdit: () => _openEditSiteDialog(site),
                              onDelete: () => _confirmDeleteSite(site),
                              isDark: isDark,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SITE DRILL-DOWN DASHBOARD
  // ---------------------------------------------------------------------------
  Widget _buildSiteDashboard(bool isDark) {
    final site = _selectedSite!;
    return Column(
      children: [
        _buildUnifiedSiteHeader(site, isDark),
        Expanded(
          child: _subTab == 'attendance'
              ? _buildAttendanceSubTab(isDark)
              : (_subTab == 'grid' ? _buildMonthlyGridSubTab(isDark) : _buildFinancesSubTab(isDark)),
        ),
      ],
    );
  }

  Widget _buildUnifiedSiteHeader(LabourSite site, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _onBackToSites,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text("Sites", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    site.siteName,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SiteStatusBadge(status: site.status),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Subtab Switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildSubTabItem('attendance', Icons.how_to_reg_rounded, "Attendance", isDark),
                const SizedBox(width: 4),
                _buildSubTabItem('grid', Icons.calendar_view_month_rounded, "Monthly Grid", isDark),
                const SizedBox(width: 4),
                _buildSubTabItem('finances', Icons.account_balance_wallet_rounded, "Finances", isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(String id, IconData icon, String label, bool isDark) {
    final isSelected = _subTab == id;
    return InkWell(
      onTap: () {
        setState(() => _subTab = id);
        if (id == 'attendance') {
          if (_attendanceRoster.isEmpty) _loadAttendanceRoster();
        } else if (id == 'grid') {
          _loadMonthlyGrid();
        } else if (id == 'finances') {
          if (_financeSummary.isEmpty) _loadFinances();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 1: DAILY ATTENDANCE (FAST & PERFORMANT WITH STATUS PILLS & TACTILE BUTTONS)
  // ---------------------------------------------------------------------------
  Widget _buildAttendanceSubTab(bool isDark) {
    final roles = ['All', ...{..._attendanceRoster.map((r) => r.role)}];

    final totalCount = _attendanceRoster.length;
    final presentCount = _attendanceRoster.where((r) => r.status == 'Present').length;
    final halfCount = _attendanceRoster.where((r) => r.status == 'Half Day').length;
    final absentCount = _attendanceRoster.where((r) => r.status == 'Absent').length;
    final plCount = _attendanceRoster.where((r) => r.status == 'Paid Leave').length;
    final unmarkedCount = _attendanceRoster.where((r) => r.status.isEmpty).length;
    final markedCount = totalCount - unmarkedCount;

    final filteredRoster = _attendanceRoster.where((r) {
      if (_attendanceRoleFilter != 'All' && r.role != _attendanceRoleFilter) return false;
      if (_attendanceStatusFilter != 'All') {
        if (_attendanceStatusFilter == 'Unmarked') {
          if (r.status.isNotEmpty) return false;
        } else if (r.status != _attendanceStatusFilter) {
          return false;
        }
      }
      if (_attendanceSearch.isNotEmpty) {
        final q = _attendanceSearch.toLowerCase();
        if (!r.name.toLowerCase().contains(q) && !r.role.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    final isToday = DateFormat('yyyy-MM-dd').format(_attendanceDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _loadAttendanceRoster,
      color: const Color(0xFF6366F1),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 68),
            child: Column(
              children: [
                // Date Navigator & Quick Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _attendanceDate = _attendanceDate.subtract(const Duration(days: 1));
                            _gridMonth = DateTime(_attendanceDate.year, _attendanceDate.month);
                          });
                          _loadAttendanceRoster();
                        },
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showLabourDatePicker(
                            context,
                            initialDate: _attendanceDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 7)),
                          );
                          if (picked != null) {
                            setState(() {
                              _attendanceDate = picked;
                              _gridMonth = DateTime(picked.year, picked.month);
                            });
                            _loadAttendanceRoster();
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('EEEE, dd MMM yyyy').format(_attendanceDate),
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text("Today", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _attendanceDate = _attendanceDate.add(const Duration(days: 1));
                            _gridMonth = DateTime(_attendanceDate.year, _attendanceDate.month);
                          });
                          _loadAttendanceRoster();
                        },
                      ),
                      const Spacer(),

                      // Search Toggle
                      IconButton(
                        icon: Icon(
                          _showAttendanceSearch || _attendanceSearch.isNotEmpty ? Icons.search_off_rounded : Icons.search_rounded,
                          size: 20,
                          color: _showAttendanceSearch || _attendanceSearch.isNotEmpty ? const Color(0xFF6366F1) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        onPressed: () => setState(() => _showAttendanceSearch = !_showAttendanceSearch),
                      ),
                      const SizedBox(width: 6),

                      // Borrow Worker Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                        ),
                        onPressed: _openBorrowWorkerDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 14),
                        label: Text("+ Borrow", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                      ),
                      const SizedBox(width: 8),

                      // Mark All Present
                      _buildMarkAllPresentButton(isDark, totalCount, unmarkedCount),
                    ],
                  ),
                ),

                // Expandable Search & Role Filter
                if (_showAttendanceSearch || _attendanceSearch.isNotEmpty || _attendanceRoleFilter != 'All') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            onChanged: (val) => setState(() => _attendanceSearch = val.trim()),
                            style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Search workers by name or role...",
                              hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: CustomDropdown<String>(
                          value: _attendanceRoleFilter,
                          height: 36,
                          fontSize: 11.5,
                          items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _attendanceRoleFilter = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                // Status Filter Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterPill('All', 'All', totalCount, const Color(0xFF6366F1), isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterPill('Present', 'Present', presentCount, const Color(0xFF10B981), isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterPill('Half Day', 'Half Day', halfCount, const Color(0xFFF59E0B), isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterPill('Absent', 'Absent', absentCount, const Color(0xFFEF4444), isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterPill('Paid Leave', 'Leave', plCount, const Color(0xFF3B82F6), isDark),
                      const SizedBox(width: 6),
                      _buildStatusFilterPill('Unmarked', 'Unmarked', unmarkedCount, Colors.grey, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Quick Fill Bar (0 Selected) or Batch Action Bar (N Selected)
                _buildQuickFillOrBatchBar(filteredRoster, unmarkedCount, isDark),
                const SizedBox(height: 8),

                // Attendance Roster Cards
                Expanded(
                  child: _attendanceLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                      : filteredRoster.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 44, color: Colors.grey[500]),
                                  const SizedBox(height: 8),
                                  Text("No workers matching filter", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredRoster.length,
                              itemBuilder: (context, i) {
                                final item = filteredRoster[i];
                                return _buildAttendanceRosterCard(item, isDark);
                              },
                            ),
                ),
              ],
            ),
          ),

          // Floating Bottom Save Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  )
                ],
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: (markedCount == totalCount && totalCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          markedCount == totalCount && totalCount > 0 ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 16,
                          color: markedCount == totalCount && totalCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$markedCount / $totalCount Marked",
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          Text(
                            unmarkedCount == 0 ? "Ready to save" : "$unmarkedCount remaining",
                            style: GoogleFonts.poppins(fontSize: 10, color: unmarkedCount == 0 ? const Color(0xFF10B981) : Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: _isSavingAttendance || totalCount == 0 ? null : _saveAttendance,
                    icon: _isSavingAttendance
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, color: Colors.white, size: 16),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSavingAttendance ? "Saving..." : "Save Roster",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        if (_hasUnsavedChanges) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0xFFF59E0B), blurRadius: 4, spreadRadius: 1),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFillOrBatchBar(List<LabourAttendanceItem> filteredRoster, int unmarkedCount, bool isDark) {
    final hasSelection = _selectedRosterIds.isNotEmpty;
    final allVisibleSelected = filteredRoster.isNotEmpty &&
        filteredRoster.every((r) => _selectedRosterIds.contains(r.labourId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasSelection
            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasSelection
              ? const Color(0xFF6366F1).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: hasSelection
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Selected count chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_box_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          "${_selectedRosterIds.length} Selected",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Set Present
                  InkWell(
                    onTap: () => _batchSetStatus('Present'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Set Present", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Set Half Day
                  InkWell(
                    onTap: () => _batchSetStatus('Half Day'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Set Half Day", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Set Absent
                  InkWell(
                    onTap: () => _batchSetStatus('Absent'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Set Absent", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Batch OT Stepper
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("OT:", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          if (_batchOvertimeHours > 0) _batchSetOvertime(_batchOvertimeHours - 1.0);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.remove, size: 12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text("${_batchOvertimeHours.toStringAsFixed(0)}h", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      InkWell(
                        onTap: () => _batchSetOvertime(_batchOvertimeHours + 1.0),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.add, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Deselect
                  InkWell(
                    onTap: () => setState(() => _selectedRosterIds.clear()),
                    child: Text(
                      "Deselect",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6366F1),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Select All / Deselect All Toggle Checkbox
                  InkWell(
                    onTap: () => _toggleSelectAllVisible(filteredRoster),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: allVisibleSelected ? const Color(0xFF6366F1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: allVisibleSelected ? const Color(0xFF6366F1) : Colors.grey,
                              width: 1.2,
                            ),
                          ),
                          child: allVisibleSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          allVisibleSelected ? "Deselect All" : "Select All",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Container(width: 1, height: 18, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(width: 10),

                  Text(
                    "Quick Fill:",
                    style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),

                  // Mark All Present
                  InkWell(
                    onTap: () => _markAllVisible(filteredRoster, 'Present'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text("All Present", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Mark Unmarked as Present (N)
                  if (unmarkedCount > 0) ...[
                    InkWell(
                      onTap: () => _markUnmarkedVisible(filteredRoster, 'Present'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 13, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text("Unmarked ($unmarkedCount)", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Mark All Absent
                  InkWell(
                    onTap: () => _markAllVisible(filteredRoster, 'Absent'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cancel_outlined, size: 13, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text("All Absent", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Reset
                  InkWell(
                    onTap: () => _resetAllVisible(filteredRoster),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restart_alt_rounded, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text("Reset", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMarkAllPresentButton(bool isDark, int totalCount, int unmarkedCount) {
    final isEnabled = totalCount > 0 && !_attendanceLoading;

    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: !isEnabled ? (isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _markAllPresent : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.done_all_rounded, color: isEnabled ? Colors.white : Colors.grey[400], size: 16),
                const SizedBox(width: 5),
                Text(
                  "Mark All Present",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? Colors.white : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterPill(String filterKey, String label, int count, Color color, bool isDark) {
    final isSelected = _attendanceStatusFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _attendanceStatusFilter = filterKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: isSelected ? Colors.white : color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(
              "$label ($count)",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRosterCard(LabourAttendanceItem item, bool isDark) {
    final hasStatus = item.status.isNotEmpty;
    final isPresent = item.status == 'Present';
    final isFixedSalary = item.wageType.toLowerCase().contains('fixed');
    final isSelected = _selectedRosterIds.contains(item.labourId);
    final initials = item.name.trim().isNotEmpty
        ? item.name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join('').toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.5) : const Color(0xFFEEF2FF))
            : (isDark ? const Color(0xFF161B22) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (hasStatus
                  ? _getStatusColor(item.status).withValues(alpha: 0.35)
                  : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))),
          width: isSelected ? 1.5 : (hasStatus ? 1.2 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Custom Themed Checkbox
              InkWell(
                onTap: () => _toggleSelectRoster(item.labourId),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF0D1117) : Colors.white),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : (isDark ? const Color(0xFF484F58) : const Color(0xFFCBD5E1)),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),

              // Avatar Initials
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(initials, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isBorrowed) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text("Added", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                          ),
                        ],
                        if (item.status.isEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text("Unmarked", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w500, color: Colors.grey[500])),
                          ),
                        ],
                        if (item.isScheduledMultiSite) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text("Multi-Site", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6))),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          item.role,
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isFixedSalary
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            item.wageType,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: isFixedSalary ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "OT: ₹${item.overtimePayPerHour.toStringAsFixed(0)}/h",
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SkillBadge(skill: item.role),
            ],
          ),

          // Already Marked Alert Banner
          if (item.alreadyMarkedAt != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Marked ${item.alreadyMarkedAt!['status']} at ${item.alreadyMarkedAt!['site_name']}",
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Tactile Status Buttons Row
          Row(
            children: [
              _buildTactileStatusBtn(item, 'Present', 'Present', Icons.check_circle_rounded, const Color(0xFF10B981)),
              const SizedBox(width: 6),
              _buildTactileStatusBtn(item, 'Half Day', 'Half Day', Icons.schedule_rounded, const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              _buildTactileStatusBtn(item, 'Absent', 'Absent', Icons.cancel_rounded, const Color(0xFFEF4444)),
              if (isFixedSalary) ...[
                const SizedBox(width: 6),
                _buildTactileStatusBtn(item, 'Paid Leave', 'Leave', Icons.beach_access_rounded, const Color(0xFF3B82F6)),
              ],
            ],
          ),

          // Overtime Stepper (shown when Present)
          if (isPresent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text("Overtime:", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      if (item.overtimeHours > 0) {
                        _setItemOvertime(item, (item.overtimeHours - 0.5).clamp(0.0, 12.0));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.remove, size: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${item.overtimeHours.toStringAsFixed(1)} hrs (+₹${(item.overtimeHours * item.overtimePayPerHour).toStringAsFixed(0)})",
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _setItemOvertime(item, (item.overtimeHours + 0.5).clamp(0.0, 12.0));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.add, size: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _setItemOvertime(item, (item.overtimeHours + 1.0).clamp(0.0, 12.0));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("+1h", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTactileStatusBtn(LabourAttendanceItem item, String status, String label, IconData icon, Color color) {
    final isSelected = item.status == status;
    final isConflict = (status == 'Present' || status == 'Half Day' || status == 'Paid Leave') &&
        item.alreadyMarkedAt != null &&
        !item.isScheduledMultiSite;

    return Expanded(
      child: InkWell(
        onTap: isConflict
            ? () {
                context.showToast(
                  "Worker already marked ${item.alreadyMarkedAt!['status']} at ${item.alreadyMarkedAt!['site_name']}",
                  isError: true,
                );
              }
            : () {
                _setItemStatus(item, status);
              },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6.5),
          decoration: BoxDecoration(
            color: isConflict
                ? (Colors.grey.withValues(alpha: 0.05))
                : (isSelected ? color : color.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isConflict
                  ? Colors.grey.withValues(alpha: 0.2)
                  : (isSelected ? color : color.withValues(alpha: 0.25)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected && !isConflict
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isConflict ? Colors.grey[400] : (isSelected ? Colors.white : color)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isConflict ? Colors.grey[400] : (isSelected ? Colors.white : color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF10B981);
      case 'Half Day':
        return const Color(0xFFF59E0B);
      case 'Absent':
        return const Color(0xFFEF4444);
      case 'Paid Leave':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 2: MONTHLY GRID (DUAL-MODE TOGGLE PREVENTS TABLET LAG)
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyGridSubTab(bool isDark) {
    final daysInMonth = DateTime(_gridMonth.year, _gridMonth.month + 1, 0).day;
    final roles = ['All', ...{..._gridData.map((r) => r.role)}];

    final filteredGrid = _gridData.where((r) {
      if (_gridRoleFilter != 'All' && r.role != _gridRoleFilter) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadMonthlyGrid,
      color: const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _gridMonth = DateTime(_gridMonth.year, _gridMonth.month - 1));
                          _loadMonthlyGrid();
                        },
                        child: const Icon(Icons.chevron_left_rounded, size: 20),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showLabourDatePicker(
                            context,
                            initialDate: _gridMonth,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _gridMonth = DateTime(picked.year, picked.month));
                            _loadMonthlyGrid();
                          }
                        },
                        child: Text(
                          DateFormat('MMMM yyyy').format(_gridMonth),
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(() => _gridMonth = DateTime(_gridMonth.year, _gridMonth.month + 1));
                          _loadMonthlyGrid();
                        },
                        child: const Icon(Icons.chevron_right_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // View Mode Toggle (Card vs Full Spreadsheet Table)
                IconButton(
                  icon: Icon(
                    _isGridTableMode ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
                    size: 20,
                    color: const Color(0xFF6366F1),
                  ),
                  tooltip: _isGridTableMode ? "Switch to Cards" : "Switch to Table View",
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _isGridTableMode = !_isGridTableMode),
                ),
                const SizedBox(width: 8),

                // Role Filter
                Expanded(
                  child: CustomDropdown<String>(
                    value: _gridRoleFilter,
                    height: 38,
                    fontSize: 11.5,
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _gridRoleFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Export Excel
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _exportMonthlyGridToExcel,
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 16),
                  label: Text("Export Excel", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Legend Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendItem("P", "Present", const Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  _buildLegendItem("HD", "Half Day", const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _buildLegendItem("A", "Absent", const Color(0xFFEF4444)),
                  const SizedBox(width: 10),
                  _buildLegendItem("PL", "Paid Leave", const Color(0xFF3B82F6)),
                  const SizedBox(width: 10),
                  _buildLegendItem("WO", "Week Off", Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Monthly Grid Content
            Expanded(
              child: _gridLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : filteredGrid.isEmpty
                      ? Center(child: Text("No monthly grid data for selected period", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])))
                      : _isGridTableMode
                          ? _buildMonthlySpreadsheetTable(filteredGrid, daysInMonth, isDark)
                          : _buildMonthlyCardList(filteredGrid, daysInMonth, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCardList(List<LabourMonthlyRow> grid, int daysInMonth, bool isDark) {
    return ListView.builder(
      itemCount: grid.length,
      itemBuilder: (context, i) {
        final row = grid[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        Text("Role: ${row.role} • Wage: ₹${row.monthlySalary.toStringAsFixed(0)}/day", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  _buildGridStatBadge("P: ${row.totalPresent}", const Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  _buildGridStatBadge("HD: ${row.totalHalfDays}", const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  _buildGridStatBadge("A: ${row.totalAbsent}", const Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  _buildGridStatBadge("OT: ${row.totalOvertimeHours.toStringAsFixed(1)}h", const Color(0xFF6366F1)),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(daysInMonth, (d) {
                    final day = d + 1;
                    final status = row.days["$day"] ?? '';
                    Color cellColor;
                    String text = status;
                    if (status == 'P') cellColor = const Color(0xFF10B981);
                    else if (status == 'HD') cellColor = const Color(0xFFF59E0B);
                    else if (status == 'A') cellColor = const Color(0xFFEF4444);
                    else if (status == 'PL') cellColor = const Color(0xFF3B82F6);
                    else if (status == 'WO') cellColor = Colors.grey;
                    else { cellColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0); text = '-'; }

                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 28,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cellColor.withValues(alpha: status.isNotEmpty ? 0.18 : 0.06),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: cellColor.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("$day", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
                          Text(text, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: cellColor)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildMonthlySpreadsheetTable(List<LabourMonthlyRow> grid, int daysInMonth, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 42,
            columnSpacing: 12,
            horizontalMargin: 12,
            columns: [
              const DataColumn(label: Text("Worker Name")),
              const DataColumn(label: Text("Role")),
              const DataColumn(label: Text("Wage")),
              ...List.generate(daysInMonth, (d) => DataColumn(label: Text("${d + 1}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)))),
              const DataColumn(label: Text("P")),
              const DataColumn(label: Text("HD")),
              const DataColumn(label: Text("A")),
              const DataColumn(label: Text("OT (h)")),
            ],
            rows: grid.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.name, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  DataCell(SkillBadge(skill: row.role)),
                  DataCell(Text("₹${row.monthlySalary.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 11))),
                  ...List.generate(daysInMonth, (d) {
                    final status = row.days["${d + 1}"] ?? '';
                    Color c = Colors.grey;
                    if (status == 'P') c = const Color(0xFF10B981);
                    else if (status == 'HD') c = const Color(0xFFF59E0B);
                    else if (status == 'A') c = const Color(0xFFEF4444);
                    else if (status == 'PL') c = const Color(0xFF3B82F6);

                    return DataCell(
                      Center(
                        child: Text(
                          status.isEmpty ? '-' : status,
                          style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: c),
                        ),
                      ),
                    );
                  }),
                  DataCell(Text("${row.totalPresent}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))),
                  DataCell(Text("${row.totalHalfDays}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)))),
                  DataCell(Text("${row.totalAbsent}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)))),
                  DataCell(Text(row.totalOvertimeHours.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String code, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          child: Center(child: Text(code, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w600))),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500])),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 3: FINANCES & WAGE LEDGER
  // ---------------------------------------------------------------------------
  Widget _buildFinancesSubTab(bool isDark) {
    final filteredFinances = _financeSummary.where((f) {
      if (_financeRoleFilter != 'All' && f.role != _financeRoleFilter) return false;
      return true;
    }).toList();

    final totalGross = filteredFinances.fold<double>(0, (sum, item) => sum + item.accruedCredit);
    final totalAdvances = filteredFinances.fold<double>(0, (sum, item) => sum + item.totalAdvance);
    final totalNet = filteredFinances.fold<double>(0, (sum, item) => sum + item.netPayable);

    return RefreshIndicator(
      onRefresh: _loadFinances,
      color: const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(title: "Gross Wages", value: "₹${totalGross.toStringAsFixed(0)}", icon: Icons.payments_rounded, iconColor: const Color(0xFF6366F1), subtitle: "Earned wages", isDark: isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabourStatCard(title: "Advances Paid", value: "₹${totalAdvances.toStringAsFixed(0)}", icon: Icons.money_off_rounded, iconColor: const Color(0xFFEF4444), subtitle: "Issued loans", isDark: isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabourStatCard(title: "Net Payable", value: "₹${totalNet.toStringAsFixed(0)}", icon: Icons.account_balance_wallet_rounded, iconColor: const Color(0xFF10B981), subtitle: "Outstanding balance", isDark: isDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _financeLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : filteredFinances.isEmpty
                      ? Center(child: Text("No wage ledger entries found", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])))
                      : ListView.builder(
                          itemCount: filteredFinances.length,
                          itemBuilder: (context, i) {
                            final fin = filteredFinances[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fin.name, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                        Text("Role: ${fin.role} • ${fin.daysPresent} Present days", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("₹${fin.netPayable.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                                      Text("Adv: -₹${fin.totalAdvance.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 9.5, color: const Color(0xFFEF4444))),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => _openLogAdvanceDialog(fin),
                                    child: const Text("Advance", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => _openSettlePayoutDialog(fin),
                                    child: const Text("Settle", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WORKER DIRECTORY TAB (TABLET RESPONSIVE)
  // ---------------------------------------------------------------------------
  Widget _buildLabourDirectory(bool isDark) {
    final filteredWorkers = _workers.where((w) {
      if (_directoryRoleFilter != 'All' && w.role != _directoryRoleFilter) return false;
      if (_directorySiteFilter != 'All') {
        if (_directorySiteFilter == 'Unassigned') {
          if (w.siteId != null || w.siteIds.isNotEmpty) return false;
        } else {
          final sId = _directorySiteFilter as int;
          if (w.siteId != sId && !w.siteIds.contains(sId)) return false;
        }
      }
      if (_directorySearch.isNotEmpty) {
        final q = _directorySearch.toLowerCase();
        final matchName = w.name.toLowerCase().contains(q);
        final matchPhone = w.phone?.toLowerCase().contains(q) ?? false;
        final matchRole = w.role.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchRole) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (val) => setState(() => _directorySearch = val.trim()),
                    style: GoogleFonts.poppins(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Search labours by name, phone or skill...",
                      hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openAddWorkerDialog,
                icon: const Icon(Icons.person_add, color: Colors.white, size: 16),
                label: Text("+ Add Worker", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                ),
                onPressed: () => _openBulkTransferDialog(),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF6366F1)),
                label: Text("Transfer", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                  side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18, color: Color(0xFF6366F1)),
                onPressed: _openBulkUploadDialog,
                tooltip: "Bulk Upload Excel",
              ),
            ],
          ),
          // Worker Directory List
          Expanded(
            child: filteredWorkers.isEmpty
                ? Center(child: Text("No workers found", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: crossAxisCount == 3 ? 2.6 : 3.2,
                        ),
                        itemCount: filteredWorkers.length,
                        itemBuilder: (context, i) {
                          final worker = filteredWorkers[i];
                          return _buildWorkerCard(worker, isDark);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(LabourWorker w, bool isDark) {
    final initials = w.name.isNotEmpty
        ? w.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF6366F1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openLabourHistory(w),
                      child: Text(
                        w.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "Phone: ${w.phone ?? 'N/A'} • Site: ${w.siteName}",
                      style: GoogleFonts.poppins(fontSize: 9.5, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SkillBadge(skill: w.role),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Wage: ₹${w.monthlySalary.toStringAsFixed(0)}/d • OT: ₹${w.overtimePayPerHour.toStringAsFixed(0)}/h",
                  style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF6366F1)),
                    onPressed: () => _openDailyScheduleDialog(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: "Daily Schedule",
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.history_edu_rounded, size: 14, color: Color(0xFF10B981)),
                    onPressed: () => _openWageHistoryDialog(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: "Wage Revisions",
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    onPressed: () => _openEditWorkerDialog(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: "Edit Worker",
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDeleteWorker(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    tooltip: "Delete Worker",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOG ACTIONS
  // ---------------------------------------------------------------------------
  void _openAddSiteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddSiteDialog(
        onSave: (name, loc, status, endDate) async {
          try {
            await _labourService.createSite(
              siteName: name,
              locationDetails: loc,
              status: status,
              endDate: endDate,
            );
            if (mounted) {
              context.showToast("Site created successfully!", isSuccess: true);
              _loadInitialData();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to create site.");
          }
        },
      ),
    );
  }

  void _openEditSiteDialog(LabourSite site) {
    showDialog(
      context: context,
      builder: (ctx) => AddSiteDialog(
        initialSite: site,
        onSave: (name, loc, status, endDate) async {
          try {
            await _labourService.updateSite(
              siteId: site.siteId,
              siteName: name,
              locationDetails: loc,
              status: status,
              endDate: endDate,
            );
            if (mounted) {
              context.showToast("Site updated successfully!", isSuccess: true);
              _loadInitialData();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to update site.");
          }
        },
      ),
    );
  }

  void _confirmDeleteSite(LabourSite site) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmActionDialog(
        title: "Delete Construction Site",
        message: "Are you sure you want to delete '${site.siteName}'? This will permanently remove its site allocations and schedules.",
        isDestructive: true,
        confirmText: "Delete Site",
        onConfirm: () async {
          try {
            await _labourService.deleteSite(site.siteId);
            if (mounted) {
              context.showToast("Site deleted successfully", isSuccess: true);
              _loadInitialData();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to delete site.");
          }
        },
      ),
    );
  }

  void _openAddWorkerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddWorkerDialog(
        availableSites: _sites,
        onSave: (data) async {
          try {
            await _labourService.createLabour(data);
            if (mounted) {
              context.showToast("Worker profile registered successfully!", isSuccess: true);
              _loadInitialData();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to create worker.");
          }
        },
      ),
    );
  }

  void _openEditWorkerDialog(LabourWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AddWorkerDialog(
        initialWorker: worker,
        availableSites: _sites,
        onOpenWageHistory: () => _openWageHistoryDialog(worker),
        onSave: (data) async {
          try {
            await _labourService.updateLabour(worker.labourId, data);
            if (mounted) {
              context.showToast("Worker profile updated!", isSuccess: true);
              _loadInitialData();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to update worker.");
          }
        },
      ),
    );
  }

  void _confirmDeleteWorker(LabourWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmActionDialog(
        title: "Delete Worker Profile",
        message: "Are you sure you want to delete '${worker.name}'? This action cannot be undone.",
        isDestructive: true,
        confirmText: "Delete Worker",
        onConfirm: () async {
          try {
            await _labourService.deleteLabour(worker.labourId);
            if (mounted) {
              context.showToast("Worker profile deleted", isSuccess: true);
              _loadInitialData();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to delete worker.");
          }
        },
      ),
    );
  }

  void _openBorrowWorkerDialog() {
    if (_selectedSite == null) return;
    final existingIds = _attendanceRoster.map((r) => r.labourId).toSet();

    showDialog(
      context: context,
      builder: (ctx) => BorrowWorkerDialog(
        currentSiteId: _selectedSite!.siteId,
        currentSiteName: _selectedSite!.siteName,
        allWorkers: _workers,
        existingLabourIds: existingIds,
        onBorrow: (worker) {
          setState(() {
            _attendanceRoster.add(
              LabourAttendanceItem(
                labourId: worker.labourId,
                name: worker.name,
                role: worker.role,
                wageType: worker.wageType,
                status: 'Present',
                isBorrowed: true,
                overtimePayPerHour: worker.overtimePayPerHour,
                overtimeHours: 0.0,
              ),
            );
          });
          Navigator.pop(ctx);
          context.showToast("Added ${worker.name} to roster. Click 'Save Roster' to confirm.", isSuccess: true);
        },
      ),
    );
  }

  void _openBulkTransferDialog([List<int> initialSelected = const []]) {
    showDialog(
      context: context,
      builder: (ctx) => BulkTransferDialog(
        sites: _sites,
        workers: _workers,
        initialSourceSiteId: _selectedSite?.siteId ?? 'All',
        initialSelectedLabourIds: initialSelected,
        onTransfer: ({required sourceSiteId, required destinationSiteId, required labourIds, required roleFilter}) async {
          try {
            await _labourService.bulkTransferLabours(
              sourceSiteId: sourceSiteId,
              destinationSiteId: destinationSiteId,
              labourIds: labourIds,
              roleFilter: roleFilter,
            );
            if (mounted) {
              Navigator.pop(ctx);
              context.showToast("Transferred ${labourIds.length} worker(s) successfully!", isSuccess: true);
              _loadInitialData();
              if (_selectedSite != null) _loadAttendanceRoster();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to transfer workers.");
          }
        },
      ),
    );
  }

  void _openLogAdvanceDialog(LabourPayoutSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) => LogAdvanceDialog(
        labourId: summary.labourId,
        labourName: summary.name,
        siteId: _selectedSite?.siteId,
        siteName: _selectedSite?.siteName ?? summary.siteName,
        onSave: ({required labourId, siteId, required amount, required date, required notes}) async {
          try {
            await _labourService.logAdvance(
              labourId: labourId,
              siteId: siteId,
              amount: amount,
              date: date,
              notes: notes,
            );
            if (mounted) {
              Navigator.pop(ctx);
              context.showToast("Salary advance logged successfully!", isSuccess: true);
              _loadFinances();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to log advance.");
          }
        },
      ),
    );
  }

  void _openSettlePayoutDialog(LabourPayoutSummary summary) {
    final monthStr = DateFormat('yyyy-MM').format(_attendanceDate);
    showDialog(
      context: context,
      builder: (ctx) => SettlePayoutDialog(
        summary: summary,
        siteId: _selectedSite?.siteId,
        month: monthStr,
        onSave: ({required labourId, siteId, required amount, required date, required paymentMode, required notes}) async {
          try {
            await _labourService.logPayout(
              labourId: labourId,
              siteId: siteId,
              amount: amount,
              date: date,
              paymentMode: paymentMode,
              notes: notes,
            );
            if (mounted) {
              Navigator.pop(ctx);
              context.showToast("Payout settled successfully!", isSuccess: true);
              _loadFinances();
            }
          } catch (e) {
            if (mounted) context.showExceptionToast(e, fallback: "Failed to process payout.");
          }
        },
      ),
    );
  }

  void _openLabourHistory(LabourWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => LabourHistoryDialog(
        labour: worker,
        labourService: _labourService,
      ),
    );
  }

  void _openDailyScheduleDialog(LabourWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => DailyScheduleDialog(
        labour: worker,
        sites: _sites,
        labourService: _labourService,
        onSaved: () => _loadInitialData(),
      ),
    );
  }

  void _openBulkUploadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BulkUploadDialog(
        labourService: _labourService,
        onSuccess: () {
          context.showToast("Workers imported from Excel file!", isSuccess: true);
          _loadInitialData();
        },
      ),
    );
  }

  Future<void> _exportMonthlyGridToExcel() async {
    if (_selectedSite == null) return;
    try {
      await LabourExcelExportHelper.exportMonthlyGridToExcel(
        siteName: _selectedSite!.siteName,
        month: _gridMonth,
        grid: _gridData,
      );
      if (mounted) context.showToast("Excel spreadsheet generated successfully!", isSuccess: true);
    } catch (e) {
      if (mounted) context.showExceptionToast(e, fallback: "Failed to export Excel matrix");
    }
  }
}
