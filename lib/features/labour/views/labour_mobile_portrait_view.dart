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
import 'package:flutter_application/features/labour/widgets/bulk_upload_dialog.dart';
import 'package:flutter_application/features/labour/widgets/confirm_dialog.dart';
import 'package:flutter_application/features/labour/widgets/wage_revision_dialog.dart';
import 'package:flutter_application/features/labour/core/labour_excel_export.dart';

class LabourMobileContent extends StatefulWidget {
  const LabourMobileContent({super.key});

  @override
  State<LabourMobileContent> createState() => _LabourMobileContentState();
}

/// Mobile Portrait Mode View Typedefs
typedef LabourMobilePortraitView = LabourMobileContent;
typedef LabourMobilePortraitContent = LabourMobileContent;

class _LabourMobileContentState extends State<LabourMobileContent> with SingleTickerProviderStateMixin {
  late LabourService _labourService;
  bool _isLoading = true;
  bool _isSavingAttendance = false;

  // Active Main Tab: 'sites' (Sites Overview / Drill-down) or 'directory' (Worker Directory)
  String _activeTab = 'sites';

  // Selected site for drill-down (null = Site Directory view, non-null = Site Dashboard)
  LabourSite? _selectedSite;

  // Subtab inside Site Dashboard: 'attendance', 'grid', 'finances'
  String _subTab = 'attendance';

  // Monthly Grid View Mode: false = Mobile Card/Strip View, true = Full Spreadsheet Table
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
    setState(() => _attendanceLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate);

    try {
      final roster = await _labourService.getSiteAttendance(_selectedSite!.siteId, dateStr);
      if (mounted) {
        setState(() {
          _attendanceRoster = roster;
          _selectedRosterIds.clear();
          _hasUnsavedChanges = false;
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
      _selectedRosterIds.clear();
      _hasUnsavedChanges = false;
      _gridMonth = DateTime(_attendanceDate.year, _attendanceDate.month);
    });
    _loadAttendanceRoster();
    _loadMonthlyGrid();
  }

  void _onBackToSites() {
    setState(() {
      _selectedSite = null;
      _selectedRosterIds.clear();
      _hasUnsavedChanges = false;
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

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LoadingScreen(
      isLoading: _isLoading,
      message: "Loading Labour Management...",
      child: Container(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Top Primary Navigation Bar (Only visible if not drill-down into a specific site)
            if (_selectedSite == null) _buildPrimaryTabBar(isDark),

            // Main Body Content
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
  // PRIMARY TAB BAR
  // ---------------------------------------------------------------------------
  Widget _buildPrimaryTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabPill(
              id: 'sites',
              title: "Sites Overview",
              count: _sites.length,
              icon: Icons.apartment_rounded,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabPill(
              id: 'directory',
              title: "Worker Directory",
              count: _workers.length,
              icon: Icons.people_alt_rounded,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String id,
    required String title,
    required int count,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _activeTab == id;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = id;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? Colors.transparent : Colors.white.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.22) : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SITES OVERVIEW (NO SITE SELECTED)
  // ---------------------------------------------------------------------------
  Widget _buildSitesOverview(bool isDark) {
    final activeCount = _sites.where((s) => s.status == 'Active').length;
    final completedCount = _sites.where((s) => s.status == 'Completed').length;
    final totalWorkers = _workers.length;

    final filteredSites = _sites.where((s) {
      if (_siteStatusFilter != 'All' && s.status != _siteStatusFilter) {
        return false;
      }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            // KPI Stat Cards Grid (2x2)
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: "Active Sites",
                    value: "$activeCount",
                    icon: Icons.construction_rounded,
                    iconColor: const Color(0xFF10B981),
                    subtitle: "Ongoing operations",
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
                    subtitle: "Past projects",
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: "Registered Labours",
                    value: "$totalWorkers",
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF6366F1),
                    subtitle: "Active workforce",
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LabourStatCard(
                    title: "Total Sites",
                    value: "${_sites.length}",
                    icon: Icons.apartment_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    subtitle: "All contracts",
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Actions and Search Bar Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (val) => setState(() => _siteSearch = val.trim()),
                      style: GoogleFonts.poppins(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Search site or location...",
                        hintStyle: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500]),
                        prefixIcon: const Icon(Icons.search, size: 15),
                        prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        isDense: true,
                        suffixIcon: _siteSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 15),
                                onPressed: () => setState(() => _siteSearch = ''),
                                padding: EdgeInsets.zero,
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                  ),
                  onPressed: _openAddSiteDialog,
                  icon: const Icon(Icons.add, color: Colors.white, size: 15),
                  label: Text("Add Site", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Completed', 'On Hold'].map((st) {
                  final isSelected = _siteStatusFilter == st;
                  int count = 0;
                  if (st == 'All') {
                    count = _sites.length;
                  } else {
                    count = _sites.where((s) => s.status == st).length;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text("$st ($count)"),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _siteStatusFilter = st),
                      selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF6366F1),
                      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Sites Card List
            Expanded(
              child: filteredSites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_city_outlined, size: 44, color: Colors.grey[500]),
                          const SizedBox(height: 10),
                          Text(
                            "No construction sites found",
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Try clearing filters or add a new site",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _openAddSiteDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Create Construction Site"),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredSites.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 5),
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
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SITE DRILL-DOWN DASHBOARD (WITH 3 SUB-TABS)
  // ---------------------------------------------------------------------------
  Widget _buildSiteDashboard(bool isDark) {
    final site = _selectedSite!;

    return Column(
      children: [
        // Unified Header: Back Button + Site Name + Sub-Tab Switcher
        _buildUnifiedSiteHeader(site, isDark),

        // Sub-Tab Content View
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Back to Sites + Site Name + Status Badge
          Row(
            children: [
              InkWell(
                onTap: _onBackToSites,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        "Sites",
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  site.siteName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              SiteStatusBadge(status: site.status),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Sleek Sub-Tab Switcher
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
    return Expanded(
      child: InkWell(
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
          padding: const EdgeInsets.symmetric(vertical: 6),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 1: DAILY ATTENDANCE (CLEAN, UNCLUTTERED, WORLD-CLASS UI/UX)
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
      if (_attendanceRoleFilter != 'All' && r.role != _attendanceRoleFilter) {
        return false;
      }
      if (_attendanceStatusFilter != 'All') {
        if (_attendanceStatusFilter == 'Unmarked') {
          if (r.status.isNotEmpty) return false;
        } else if (r.status != _attendanceStatusFilter) {
          return false;
        }
      }
      if (_attendanceSearch.isNotEmpty) {
        final q = _attendanceSearch.toLowerCase();
        if (!r.name.toLowerCase().contains(q) && !r.role.toLowerCase().contains(q)) {
          return false;
        }
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
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 64), // Extra bottom padding for sticky save bar
            child: Column(
              children: [
                // 1. Sleek Date Navigator & Actions Bar (All-in-One Row!)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Prev Day Button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _attendanceDate = _attendanceDate.subtract(const Duration(days: 1));
                            _gridMonth = DateTime(_attendanceDate.year, _attendanceDate.month);
                          });
                          _loadAttendanceRoster();
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_left_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Date Picker Pill
                      Expanded(
                        child: InkWell(
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
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF6366F1)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(_attendanceDate),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Today",
                                    style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Next Day Button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _attendanceDate = _attendanceDate.add(const Duration(days: 1));
                            _gridMonth = DateTime(_attendanceDate.year, _attendanceDate.month);
                          });
                          _loadAttendanceRoster();
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_right_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Toggle Search Button
                      IconButton(
                        icon: Icon(
                          _showAttendanceSearch || _attendanceSearch.isNotEmpty ? Icons.search_off_rounded : Icons.search_rounded,
                          size: 19,
                          color: _showAttendanceSearch || _attendanceSearch.isNotEmpty ? const Color(0xFF6366F1) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        tooltip: "Search & Filter",
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() => _showAttendanceSearch = !_showAttendanceSearch);
                        },
                      ),
                      const SizedBox(width: 4),

                      // Borrow Worker Quick Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                          minimumSize: Size.zero,
                        ),
                        onPressed: _openBorrowWorkerDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 13),
                        label: Text("+ Borrow", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                      ),
                    ],
                  ),
                ),

                // 2. Expandable Search & Role Filter Bar (Saves vertical space when closed!)
                if (_showAttendanceSearch || _attendanceSearch.isNotEmpty || _attendanceRoleFilter != 'All') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 34,
                          child: TextField(
                            onChanged: (val) => setState(() => _attendanceSearch = val.trim()),
                            style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Search workers...",
                              hintStyle: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500]),
                              prefixIcon: const Icon(Icons.search, size: 14),
                              prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              isDense: true,
                              suffixIcon: _attendanceSearch.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 14),
                                      onPressed: () => setState(() => _attendanceSearch = ''),
                                      padding: EdgeInsets.zero,
                                    )
                                  : null,
                              fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: CustomDropdown<String>(
                          value: _attendanceRoleFilter,
                          height: 34,
                          fontSize: 10,
                          items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _attendanceRoleFilter = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),

                // 3. Interactive Status Filter Pills
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildStatusFilterPill('All', "All", totalCount, const Color(0xFF6366F1), isDark),
                            const SizedBox(width: 5),
                            _buildStatusFilterPill('Present', "Present", presentCount, const Color(0xFF10B981), isDark),
                            const SizedBox(width: 5),
                            _buildStatusFilterPill('Half Day', "Half Day", halfCount, const Color(0xFFF59E0B), isDark),
                            const SizedBox(width: 5),
                            _buildStatusFilterPill('Absent', "Absent", absentCount, const Color(0xFFEF4444), isDark),
                            if (plCount > 0) ...[
                              const SizedBox(width: 5),
                              _buildStatusFilterPill('Paid Leave', "Leave", plCount, const Color(0xFF3B82F6), isDark),
                            ],
                            if (unmarkedCount > 0) ...[
                              const SizedBox(width: 5),
                              _buildStatusFilterPill('Unmarked', "Unmarked", unmarkedCount, const Color(0xFF8B5CF6), isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 4. Quick Fill Bar (0 Selected) or Batch Action Bar (N Selected) - Exact Web Replica!
                _buildQuickFillOrBatchBar(filteredRoster, unmarkedCount, isDark),
                const SizedBox(height: 8),

                // 5. Worker Attendance List (Clean, Space-Efficient, Checkbox-Enabled!)
                Expanded(
                  child: _attendanceLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                      : filteredRoster.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 36, color: Colors.grey[500]),
                                  const SizedBox(height: 8),
                                  Text(
                                    _attendanceStatusFilter != 'All'
                                        ? "No workers with status '$_attendanceStatusFilter'"
                                        : "No workers on roster for this date",
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_attendanceStatusFilter != 'All')
                                    OutlinedButton(
                                      onPressed: () => setState(() => _attendanceStatusFilter = 'All'),
                                      child: const Text("Show All Workers"),
                                    )
                                  else
                                    OutlinedButton.icon(
                                      onPressed: _openBorrowWorkerDialog,
                                      icon: const Icon(Icons.add, size: 14),
                                      label: const Text("Borrow Worker to Roster"),
                                    ),
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

          // 6. Floating Bottom Save Bar with Unsaved Changes Indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  )
                ],
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Progress counter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (markedCount == totalCount && totalCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          markedCount == totalCount && totalCount > 0 ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 15,
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
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            unmarkedCount == 0 ? "Ready to save" : "$unmarkedCount remaining",
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: unmarkedCount == 0 ? const Color(0xFF10B981) : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Save Roster Button with Unsaved Indicator
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: _isSavingAttendance || totalCount == 0 ? null : _saveAttendance,
                    icon: _isSavingAttendance
                        ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSavingAttendance ? "Saving..." : "Save Roster",
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_box_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          "${_selectedRosterIds.length} Selected",
                          style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Set Present
                  InkWell(
                    onTap: () => _batchSetStatus('Present'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Set Present", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Set Half Day
                  InkWell(
                    onTap: () => _batchSetStatus('Half Day'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Set Half Day", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Set Absent
                  InkWell(
                    onTap: () => _batchSetStatus('Absent'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Set Absent", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Batch OT Stepper
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("OT:", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 3),
                      InkWell(
                        onTap: () {
                          if (_batchOvertimeHours > 0) _batchSetOvertime(_batchOvertimeHours - 1.0);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(3)),
                          child: const Icon(Icons.remove, size: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text("${_batchOvertimeHours.toStringAsFixed(0)}h", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      InkWell(
                        onTap: () => _batchSetOvertime(_batchOvertimeHours + 1.0),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(3)),
                          child: const Icon(Icons.add, size: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Deselect
                  InkWell(
                    onTap: () => setState(() => _selectedRosterIds.clear()),
                    child: Text(
                      "Deselect",
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
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
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: allVisibleSelected ? const Color(0xFF6366F1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: allVisibleSelected ? const Color(0xFF6366F1) : Colors.grey,
                              width: 1.2,
                            ),
                          ),
                          child: allVisibleSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          allVisibleSelected ? "Deselect All" : "Select All",
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),

                  Text(
                    "Quick Fill:",
                    style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 6),

                  // Mark All Present
                  InkWell(
                    onTap: () => _markAllVisible(filteredRoster, 'Present'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 11, color: Color(0xFF10B981)),
                          const SizedBox(width: 3),
                          Text("All Present", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Mark Unmarked as Present (N)
                  if (unmarkedCount > 0) ...[
                    InkWell(
                      onTap: () => _markUnmarkedVisible(filteredRoster, 'Present'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 11, color: Color(0xFF6366F1)),
                            const SizedBox(width: 3),
                            Text("Unmarked ($unmarkedCount)", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],

                  // Mark All Absent
                  InkWell(
                    onTap: () => _markAllVisible(filteredRoster, 'Absent'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cancel_outlined, size: 11, color: Color(0xFFEF4444)),
                          const SizedBox(width: 3),
                          Text("All Absent", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Reset
                  InkWell(
                    onTap: () => _resetAllVisible(filteredRoster),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restart_alt_rounded, size: 11, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text("Reset", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w500, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusFilterPill(String filterKey, String label, int count, Color color, bool isDark) {
    final isSelected = _attendanceStatusFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceStatusFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
          ),
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
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$count",
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRosterCard(LabourAttendanceItem item, bool isDark) {
    final initials = item.name.isNotEmpty ? item.name[0].toUpperCase() : 'W';
    final hasStatus = item.status.isNotEmpty;
    final isPresent = item.status == 'Present';
    final isFixedSalary = item.wageType.toLowerCase().contains('fixed');
    final isSelected = _selectedRosterIds.contains(item.labourId);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.5) : const Color(0xFFEEF2FF))
            : (isDark ? const Color(0xFF161B22) : Colors.white),
        borderRadius: BorderRadius.circular(10),
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Checkbox + Avatar + Name + Badges + Rate + Role
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

              // Avatar
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
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

              // Name & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isBorrowed) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text("Added", style: GoogleFonts.poppins(fontSize: 7.5, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                          ),
                        ],
                        if (item.status.isEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                            ),
                            child: Text("Unmarked", style: GoogleFonts.poppins(fontSize: 7.5, fontWeight: FontWeight.w500, color: Colors.grey[500])),
                          ),
                        ],
                        if (item.isScheduledMultiSite) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text("Multi-Site", style: GoogleFonts.poppins(fontSize: 7.5, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6))),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          item.role,
                          style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: isFixedSalary
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            item.wageType,
                            style: GoogleFonts.poppins(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w500,
                              color: isFixedSalary ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "OT: ₹${item.overtimePayPerHour.toStringAsFixed(0)}/h",
                          style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Already Marked Alert Banner
          if (item.alreadyMarkedAt != null) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Marked ${item.alreadyMarkedAt!['status']} at ${item.alreadyMarkedAt!['site_name']}",
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 7),

          // Row 2: Status Buttons
          Row(
            children: [
              _buildTactileStatusBtn(item, 'Present', 'Present', Icons.check_circle_rounded, const Color(0xFF10B981)),
              const SizedBox(width: 5),
              _buildTactileStatusBtn(item, 'Half Day', 'Half Day', Icons.schedule_rounded, const Color(0xFFF59E0B)),
              const SizedBox(width: 5),
              _buildTactileStatusBtn(item, 'Absent', 'Absent', Icons.cancel_rounded, const Color(0xFFEF4444)),
              if (isFixedSalary) ...[
                const SizedBox(width: 5),
                _buildTactileStatusBtn(item, 'Paid Leave', 'Paid Leave', Icons.beach_access_rounded, const Color(0xFF3B82F6)),
              ],
            ],
          ),

          // Row 3: Overtime Stepper (shown when Present)
          if (isPresent) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 5),
                  Text(
                    "Overtime:",
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  const Spacer(),
                  // Minus Button
                  InkWell(
                    onTap: () {
                      if (item.overtimeHours > 0) {
                        _setItemOvertime(item, (item.overtimeHours - 0.5).clamp(0.0, 12.0));
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.remove, size: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Hours Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${item.overtimeHours.toStringAsFixed(1)} h",
                      style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Plus Button
                  InkWell(
                    onTap: () {
                      _setItemOvertime(item, (item.overtimeHours + 0.5).clamp(0.0, 12.0));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.add, size: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // +1h Quick Preset Button
                  InkWell(
                    onTap: () {
                      _setItemOvertime(item, (item.overtimeHours + 1.0).clamp(0.0, 12.0));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("+1h", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
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
          padding: const EdgeInsets.symmetric(vertical: 5.5),
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
              Icon(
                isConflict ? Icons.block_rounded : icon,
                size: 12,
                color: isConflict ? Colors.grey[400] : (isSelected ? Colors.white : color),
              ),
              const SizedBox(width: 3.5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isConflict ? Colors.grey[400] : (isSelected ? Colors.white : color),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
  // SUB-TAB 2: MONTHLY GRID
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            // Month Selector & Actions Bar (Row 1)
            Row(
              children: [
                // Month Picker with Prev/Next
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _gridMonth = DateTime(_gridMonth.year, _gridMonth.month - 1);
                          });
                          _loadMonthlyGrid();
                        },
                        child: const Icon(Icons.chevron_left_rounded, size: 18),
                      ),
                      const SizedBox(width: 4),
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
                          DateFormat('MMM yyyy').format(_gridMonth),
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _gridMonth = DateTime(_gridMonth.year, _gridMonth.month + 1);
                          });
                          _loadMonthlyGrid();
                        },
                        child: const Icon(Icons.chevron_right_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // View Mode Toggle (Card vs Full Spreadsheet)
                IconButton(
                  icon: Icon(
                    _isGridTableMode ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
                    size: 18,
                    color: const Color(0xFF6366F1),
                  ),
                  tooltip: _isGridTableMode ? "Switch to Mobile Cards" : "Switch to Table View",
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _isGridTableMode = !_isGridTableMode),
                ),
                const Spacer(),

                // Export Excel
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                  ),
                  onPressed: _exportMonthlyGridToExcel,
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 14),
                  label: Text("Export Excel", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Role Filter Row (Row 2)
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String>(
                    value: _gridRoleFilter,
                    height: 34,
                    fontSize: 10.5,
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _gridRoleFilter = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Legend Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendItem("P", "Present", const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _buildLegendItem("HD", "Half Day", const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _buildLegendItem("A", "Absent", const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  _buildLegendItem("PL", "Paid Leave", const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _buildLegendItem("WO", "Week Off", Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Monthly Grid Content
            Expanded(
              child: _gridLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : filteredGrid.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month_outlined, size: 36, color: Colors.grey[500]),
                              const SizedBox(height: 8),
                              Text(
                                _gridRoleFilter != 'All'
                                    ? "No records for role '$_gridRoleFilter'"
                                    : "No monthly grid attendance recorded for ${DateFormat('MMM yyyy').format(_gridMonth)}",
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _loadMonthlyGrid,
                                icon: const Icon(Icons.refresh_rounded, size: 15),
                                label: const Text("Refresh Monthly Grid"),
                              ),
                            ],
                          ),
                        )
                      : _isGridTableMode
                          ? _buildMonthlySpreadsheetTable(filteredGrid, daysInMonth, isDark)
                          : _buildMonthlyCardList(filteredGrid, daysInMonth, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile Card List with Day-by-Day Calendar Strip
  Widget _buildMonthlyCardList(List<LabourMonthlyRow> grid, int daysInMonth, bool isDark) {
    return ListView.builder(
      itemCount: grid.length,
      itemBuilder: (context, i) {
        final row = grid[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name & Role Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
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
                  SkillBadge(skill: row.role),
                ],
              ),
              const SizedBox(height: 6),

              // KPI Summary Pills Row
              Row(
                children: [
                  _buildMiniStatBadge("P: ${row.totalPresent}", const Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  _buildMiniStatBadge("HD: ${row.totalHalfDays}", const Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  _buildMiniStatBadge("A: ${row.totalAbsent}", const Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  _buildMiniStatBadge("PL: ${row.totalPaidLeaves}", const Color(0xFF3B82F6)),
                  const Spacer(),
                  Text(
                    "OT: ${row.totalOvertimeHours.toStringAsFixed(1)}h",
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Horizontal Day-by-Day Status Strip (Days 1 to End of Month)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: daysInMonth,
                  separatorBuilder: (context, index) => const SizedBox(width: 4),
                  itemBuilder: (context, d) {
                    final dayNum = d + 1;
                    final dayStr = "$dayNum";
                    String st = row.days[dayStr] ?? '';
                    if (st.isEmpty) {
                      final dt = DateTime(_gridMonth.year, _gridMonth.month, dayNum);
                      if (dt.weekday == DateTime.sunday) {
                        st = 'WO';
                      }
                    }
                    final bg = _getGridCellBg(st);
                    final fg = _getGridCellFg(st);

                    return Container(
                      width: 28,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: st.isNotEmpty ? fg.withValues(alpha: 0.3) : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$dayNum",
                            style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[500]),
                          ),
                          Text(
                            st.isEmpty ? '-' : st,
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: fg),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // Full Spreadsheet Table View
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
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            columnSpacing: 12,
            horizontalMargin: 10,
            columns: [
              const DataColumn(label: Text("Worker")),
              const DataColumn(label: Text("Role")),
              ...List.generate(
                daysInMonth,
                (d) => DataColumn(
                  label: Text(
                    "${d + 1}",
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const DataColumn(label: Text("P")),
              const DataColumn(label: Text("HD")),
              const DataColumn(label: Text("A")),
              const DataColumn(label: Text("PL")),
              const DataColumn(label: Text("OT")),
            ],
            rows: grid.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.name, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600))),
                  DataCell(SkillBadge(skill: row.role)),
                  ...List.generate(daysInMonth, (d) {
                    final dayNum = d + 1;
                    final dayStr = "$dayNum";
                    String st = row.days[dayStr] ?? '';
                    if (st.isEmpty) {
                      final dt = DateTime(_gridMonth.year, _gridMonth.month, dayNum);
                      if (dt.weekday == DateTime.sunday) {
                        st = 'WO';
                      }
                    }
                    return DataCell(
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getGridCellBg(st),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            st.isEmpty ? '-' : st,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _getGridCellFg(st),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  DataCell(Text("${row.totalPresent}", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))),
                  DataCell(Text("${row.totalHalfDays}", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)))),
                  DataCell(Text("${row.totalAbsent}", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)))),
                  DataCell(Text("${row.totalPaidLeaves}", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)))),
                  DataCell(Text("${row.totalOvertimeHours.toStringAsFixed(1)}h", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)))),
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
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(code, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: color)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Color _getGridCellBg(String status) {
    switch (status.toUpperCase().trim()) {
      case 'P':
      case 'PRESENT':
        return const Color(0xFF10B981).withValues(alpha: 0.2);
      case 'HD':
      case 'HALF DAY':
      case 'H':
        return const Color(0xFFF59E0B).withValues(alpha: 0.2);
      case 'A':
      case 'ABSENT':
        return const Color(0xFFEF4444).withValues(alpha: 0.2);
      case 'PL':
      case 'PAID LEAVE':
        return const Color(0xFF3B82F6).withValues(alpha: 0.2);
      case 'WO':
      case 'WEEK OFF':
        return Colors.grey.withValues(alpha: 0.15);
      default:
        return Colors.transparent;
    }
  }

  Color _getGridCellFg(String status) {
    switch (status.toUpperCase().trim()) {
      case 'P':
      case 'PRESENT':
        return const Color(0xFF10B981);
      case 'HD':
      case 'HALF DAY':
      case 'H':
        return const Color(0xFFF59E0B);
      case 'A':
      case 'ABSENT':
        return const Color(0xFFEF4444);
      case 'PL':
      case 'PAID LEAVE':
        return const Color(0xFF3B82F6);
      case 'WO':
      case 'WEEK OFF':
        return Colors.grey;
      default:
        return Colors.grey[400]!;
    }
  }

  Future<void> _exportMonthlyGridToExcel() async {
    if (_gridData.isEmpty) {
      context.showToast("No grid data available to export", isSuccess: false);
      return;
    }
    try {
      await LabourExcelExportHelper.exportMonthlyGridToExcel(
        grid: _gridData,
        siteName: _selectedSite?.siteName ?? 'Site',
        month: _gridMonth,
      );
      if (mounted) context.showToast("Monthly attendance exported to Excel!", isSuccess: true);
    } catch (e) {
      if (mounted) context.showExceptionToast(e, fallback: "Failed to export Excel file.");
    }
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 3: FINANCES & SALARY CREDIT
  // ---------------------------------------------------------------------------
  Widget _buildFinancesSubTab(bool isDark) {
    final filteredFinances = _financeSummary.where((s) {
      if (_financeRoleFilter != 'All' && s.role != _financeRoleFilter) return false;
      return true;
    }).toList();

    double totalAccrued = 0;
    double totalAdvances = 0;
    double totalNet = 0;
    double totalPaid = 0;

    for (final f in filteredFinances) {
      totalAccrued += f.accruedCredit;
      totalAdvances += f.totalAdvance;
      totalNet += f.netPayable;
      totalPaid += f.paidAmount;
    }

    return RefreshIndicator(
      onRefresh: _loadFinances,
      color: const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            // 4 Financial Summary KPI Cards
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: "Total Accrued",
                    value: "₹${totalAccrued.toStringAsFixed(0)}",
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF6366F1),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LabourStatCard(
                    title: "Advances Paid",
                    value: "₹${totalAdvances.toStringAsFixed(0)}",
                    icon: Icons.price_change_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: LabourStatCard(
                    title: "Net Payable",
                    value: "₹${totalNet.toStringAsFixed(0)}",
                    icon: Icons.pending_actions_rounded,
                    iconColor: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LabourStatCard(
                    title: "Total Paid",
                    value: "₹${totalPaid.toStringAsFixed(0)}",
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Role Filter & Export Payroll Button
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String>(
                    value: _financeRoleFilter,
                    height: 36,
                    fontSize: 10.5,
                    items: ['All', ...{..._financeSummary.map((f) => f.role)}].map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _financeRoleFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                  ),
                  onPressed: _exportPayoutsToExcel,
                  icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 14),
                  label: Text("Export Payroll", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Finance Worker Cards
            Expanded(
              child: _financeLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : filteredFinances.isEmpty
                      ? Center(child: Text("No financial ledger entries for this site", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])))
                      : ListView.builder(
                          itemCount: filteredFinances.length,
                          itemBuilder: (context, i) {
                            final f = filteredFinances[i];
                            return _buildFinanceCard(f, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceCard(LabourPayoutSummary f, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Role Badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Rate: ₹${f.dailyRate.toStringAsFixed(0)}/day • ${f.daysPresent}P + ${f.halfDays}HD • OT: ${f.overtimeHours.toStringAsFixed(1)}h",
                      style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SkillBadge(skill: f.role),
            ],
          ),
          const SizedBox(height: 6),

          // Numbers Row (Credit, Advance, Net Payable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFinanceMetric("Credit", "₹${f.accruedCredit.toStringAsFixed(0)}", const Color(0xFF6366F1)),
                _buildFinanceMetric("Advance", "-₹${f.totalAdvance.toStringAsFixed(0)}", const Color(0xFFEF4444)),
                _buildFinanceMetric("Net Payable", "₹${f.netPayable.toStringAsFixed(0)}", const Color(0xFF10B981)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  minimumSize: Size.zero,
                ),
                onPressed: () => _openLogAdvanceDialog(f),
                child: Text("+ Advance", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: Size.zero,
                ),
                onPressed: () => _openSettlePayoutDialog(f),
                child: Text("Settle Payout", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _exportPayoutsToExcel() async {
    if (_financeSummary.isEmpty) {
      context.showToast("No payouts data available to export", isSuccess: false);
      return;
    }
    try {
      final siteName = _selectedSite?.siteName ?? 'Site';
      final monthStr = DateFormat('yyyy_MM').format(_attendanceDate);
      await LabourExcelExportHelper.exportPayoutsToExcel(
        payouts: _financeSummary,
        siteName: siteName,
        monthStr: monthStr,
      );
      if (mounted) context.showToast("Payout ledger exported to Excel!", isSuccess: true);
    } catch (e) {
      if (mounted) context.showExceptionToast(e, fallback: "Failed to export Excel file.");
    }
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 4: LABOUR DIRECTORY (MOBILE VIEW)
  // ---------------------------------------------------------------------------
  Widget _buildLabourDirectory(bool isDark) {
    final roles = ['All', ...{..._workers.map((w) => w.role)}];

    final filteredWorkers = _workers.where((w) {
      if (_directoryRoleFilter != 'All' && w.role != _directoryRoleFilter) return false;
      if (_directorySiteFilter == 'Unassigned' && (w.siteId != null || w.siteIds.isNotEmpty)) return false;
      if (_directorySiteFilter != 'All' && _directorySiteFilter != 'Unassigned') {
        final sId = _directorySiteFilter is int ? _directorySiteFilter as int : int.tryParse(_directorySiteFilter.toString());
        if (sId != null && w.siteId != sId && !w.siteIds.contains(sId)) return false;
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

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF6366F1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            // Action Buttons Bar (Add Worker, Transfer, Bulk Upload)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _openAddWorkerDialog,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 14),
                    label: Text("+ Add Worker", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                    onPressed: () => _openBulkTransferDialog(),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF6366F1)),
                    label: Text("Transfer", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF6366F1)),
                  onPressed: _openBulkUploadDialog,
                  tooltip: "Bulk Upload Excel",
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Search Bar
            SizedBox(
              height: 36,
              child: TextField(
                onChanged: (val) => setState(() => _directorySearch = val.trim()),
                style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Search name, phone or role...",
                  hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, size: 14),
                  prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  isDense: true,
                  suffixIcon: _directorySearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () => setState(() => _directorySearch = ''),
                          padding: EdgeInsets.zero,
                        )
                      : null,
                  fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Filters Row (Site & Role Dropdowns)
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<dynamic>(
                    value: _directorySiteFilter,
                    height: 34,
                    fontSize: 10.5,
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text("All Sites", maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const DropdownMenuItem(value: 'Unassigned', child: Text("Unassigned", maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ..._sites.map((s) => DropdownMenuItem(value: s.siteId, child: Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setState(() => _directorySiteFilter = val),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomDropdown<String>(
                    value: _directoryRoleFilter,
                    height: 34,
                    fontSize: 10.5,
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _directoryRoleFilter = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Worker Directory Card List
            Expanded(
              child: filteredWorkers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 40, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text("No workers match directory filters", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredWorkers.length,
                      itemBuilder: (context, i) {
                        final w = filteredWorkers[i];
                        return _buildWorkerDirectoryCard(w, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerDirectoryCard(LabourWorker w, bool isDark) {
    final initials = w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6),
                      const Color(0xFF6366F1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Name & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openLabourHistoryDialog(w),
                      child: Text(
                        w.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
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
                      style: GoogleFonts.poppins(fontSize: 10, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SkillBadge(skill: w.role),
            ],
          ),
          const SizedBox(height: 8),

          // Rates & Actions Row
          Row(
            children: [
              Expanded(
                child: Text(
                  "Wage: ₹${w.monthlySalary.toStringAsFixed(0)}/day • OT: ₹${w.overtimePayPerHour.toStringAsFixed(0)}/h",
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF6366F1)),
                    onPressed: () => _openDailyScheduleDialog(w),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: "Daily Schedule",
                  ),
                  IconButton(
                    icon: const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF10B981)),
                    onPressed: () => _openWageHistoryDialog(w),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: "Wage History",
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    onPressed: () => _openEditWorkerDialog(w),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: "Edit Worker",
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDeleteWorker(w),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
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

  // ===========================================================================
  // MODAL DIALOG LAUNCHERS (BOTTOM SHEET IN MOBILE)
  // ===========================================================================

  Future<T?> _showMobilePopup<T>(Widget Function(BuildContext) builder) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (ctx) => builder(ctx),
    );
  }

  void _openAddSiteDialog() {
    _showMobilePopup(
      (ctx) => AddSiteDialog(
        isBottomSheet: true,
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
    _showMobilePopup(
      (ctx) => AddSiteDialog(
        initialSite: site,
        isBottomSheet: true,
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
    _showMobilePopup(
      (ctx) => ConfirmActionDialog(
        title: "Delete Construction Site",
        message: "Are you sure you want to delete '${site.siteName}'? This will permanently remove its site allocations and schedules.",
        isDestructive: true,
        confirmText: "Delete Site",
        isBottomSheet: true,
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
    _showMobilePopup(
      (ctx) => AddWorkerDialog(
        availableSites: _sites,
        isBottomSheet: true,
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
    _showMobilePopup(
      (ctx) => AddWorkerDialog(
        initialWorker: worker,
        availableSites: _sites,
        isBottomSheet: true,
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
    _showMobilePopup(
      (ctx) => ConfirmActionDialog(
        title: "Delete Worker Profile",
        message: "Are you sure you want to delete '${worker.name}'? This action cannot be undone.",
        isDestructive: true,
        confirmText: "Delete Worker",
        isBottomSheet: true,
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

  void _openBulkTransferDialog([List<int> initialSelected = const []]) {
    _showMobilePopup(
      (ctx) => BulkTransferDialog(
        sites: _sites,
        workers: _workers,
        initialSourceSiteId: _selectedSite?.siteId ?? 'All',
        initialSelectedLabourIds: initialSelected,
        isBottomSheet: true,
        onTransfer: ({required sourceSiteId, required destinationSiteId, required labourIds, required roleFilter}) async {
          try {
            await _labourService.bulkTransferLabours(
              sourceSiteId: sourceSiteId,
              destinationSiteId: destinationSiteId,
              labourIds: labourIds,
              roleFilter: roleFilter,
            );
            if (mounted) {
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

  void _openBorrowWorkerDialog() {
    if (_selectedSite == null) return;
    final existingIds = _attendanceRoster.map((r) => r.labourId).toSet();

    _showMobilePopup(
      (ctx) => BorrowWorkerDialog(
        currentSiteId: _selectedSite!.siteId,
        currentSiteName: _selectedSite!.siteName,
        allWorkers: _workers,
        existingLabourIds: existingIds,
        isBottomSheet: true,
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
          context.showToast("Added ${worker.name} to roster. Click 'Save Roster' to confirm.", isSuccess: true);
        },
      ),
    );
  }

  void _openLogAdvanceDialog(LabourPayoutSummary summary) {
    _showMobilePopup(
      (ctx) => LogAdvanceDialog(
        labourId: summary.labourId,
        labourName: summary.name,
        siteId: _selectedSite?.siteId,
        siteName: _selectedSite?.siteName ?? summary.siteName,
        isBottomSheet: true,
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
    _showMobilePopup(
      (ctx) => SettlePayoutDialog(
        summary: summary,
        siteId: _selectedSite?.siteId,
        month: monthStr,
        isBottomSheet: true,
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

  void _openLabourHistoryDialog(LabourWorker worker) {
    _showMobilePopup(
      (ctx) => LabourHistoryDialog(
        labour: worker,
        labourService: _labourService,
        isBottomSheet: true,
      ),
    );
  }

  void _openDailyScheduleDialog(LabourWorker worker) {
    _showMobilePopup(
      (ctx) => DailyScheduleDialog(
        labour: worker,
        sites: _sites,
        labourService: _labourService,
        isBottomSheet: true,
        onSaved: () {
          context.showToast("Daily schedule updated!", isSuccess: true);
          _loadInitialData();
        },
      ),
    );
  }

  void _openBulkUploadDialog() {
    _showMobilePopup(
      (ctx) => BulkUploadDialog(
        labourService: _labourService,
        isBottomSheet: true,
        onSuccess: () {
          context.showToast("Workers imported successfully from Excel!", isSuccess: true);
          _loadInitialData();
        },
      ),
    );
  }
}
