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

/// Tablet Landscape Mode View for Labour & Site Worker Management
/// Exact replica of the Attendance-Web desktop/landscape experience with high-density roll call table,
/// batch action bar, quick fill shortcuts, conflict detection, and unsaved changes tracking.
class LabourTabletLandscapeView extends StatefulWidget {
  const LabourTabletLandscapeView({super.key});

  @override
  State<LabourTabletLandscapeView> createState() => _LabourTabletLandscapeViewState();
}

// Backward compatibility aliases
typedef LabourTabletLandscapeContent = LabourTabletLandscapeView;
typedef LabourDesktopContent = LabourTabletLandscapeView;

class _LabourTabletLandscapeViewState extends State<LabourTabletLandscapeView> with SingleTickerProviderStateMixin {
  late LabourService _labourService;
  bool _isLoading = true;
  bool _isSavingAttendance = false;

  // Active Main Tab: 'sites' or 'directory'
  String _activeTab = 'sites';

  // Selected site for drill-down (null = Site Directory view, non-null = Site Dashboard)
  LabourSite? _selectedSite;

  // Subtab inside Site Dashboard: 'attendance', 'grid', 'finances'
  String _subTab = 'attendance';

  // Monthly Grid View Mode: false = Fast Card View, true = Full Spreadsheet Table
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
  bool _attendanceLoading = false;

  DateTime _gridMonth = DateTime.now();
  String _gridRoleFilter = 'All';
  bool _gridLoading = false;

  final String _financeRoleFilter = 'All';
  bool _financeLoading = false;

  String _directorySearch = '';
  final dynamic _directorySiteFilter = 'All'; // 'All', 'Unassigned', or int site_id
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

  // ===========================================================================
  // BUILD METHOD (TABLET LANDSCAPE)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LoadingScreen(
      isLoading: _isLoading,
      message: "Loading Labour Management (Landscape)...",
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.engineering_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                "Labour & Sites Management",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildMainTabButton('sites', Icons.business_rounded, "Sites (${_sites.length})", isDark),
                const SizedBox(width: 4),
                _buildMainTabButton('directory', Icons.badge_rounded, "Workers Directory (${_workers.length})", isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabButton(String id, IconData icon, String label, bool isDark) {
    final isSelected = _activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
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
  // SITES OVERVIEW (LANDSCAPE MULTI-COLUMN GRID)
  // ---------------------------------------------------------------------------
  Widget _buildSitesOverview(bool isDark) {
    final filteredSites = _sites.where((s) {
      if (_siteStatusFilter != 'All' && s.status != _siteStatusFilter) return false;
      if (_siteSearch.isNotEmpty) {
        final q = _siteSearch.toLowerCase();
        if (!s.siteName.toLowerCase().contains(q) && !(s.locationDetails?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filter & Action Toolbar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() => _siteSearch = val.trim()),
                    style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Search construction sites...",
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status Filter Chips
              Row(
                children: ['All', 'Active', 'Completed', 'On Hold'].map((st) {
                  final isSelected = _siteStatusFilter == st;
                  int count = st == 'All' ? _sites.length : _sites.where((s) => s.status == st).length;
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
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                ),
                onPressed: _openBulkTransferDialog,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF6366F1)),
                label: Text("Bulk Transfer", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openAddSiteDialog,
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: Text("Add Site", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Landscape Multi-Column Grid (3-4 columns)
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
                      final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: crossAxisCount == 3 ? 3.0 : 3.6,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  Text("All Sites", style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    site.siteName,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SiteStatusBadge(status: site.status),
                if (site.locationDetails != null && site.locationDetails!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text("• ${site.locationDetails!}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Subtab Switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildSubTabItem('attendance', Icons.how_to_reg_rounded, "Daily Attendance", isDark),
                const SizedBox(width: 4),
                _buildSubTabItem('grid', Icons.calendar_view_month_rounded, "Monthly Grid", isDark),
                const SizedBox(width: 4),
                _buildSubTabItem('finances', Icons.account_balance_wallet_rounded, "Finances & Advances", isDark),
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
  // SUB-TAB 1: DAILY ATTENDANCE (WIDE ROLL CALL TABLE FOR TABLET LANDSCAPE)
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 70),
            child: Column(
              children: [
                // Top Action Toolbar (Date, Search, Role Filter, Borrow Worker)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Date Selector
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
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF6366F1)),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('EEEE, dd MMM yyyy').format(_attendanceDate),
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text("Today", style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                                ),
                              ],
                            ],
                          ),
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
                      const SizedBox(width: 16),

                      // Search Box
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            onChanged: (val) => setState(() => _attendanceSearch = val.trim()),
                            style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Search workers by name or role...",
                              hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[500]),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Role Filter Dropdown
                      SizedBox(
                        width: 150,
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
                      const SizedBox(width: 12),

                      // Borrow Worker Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                        ),
                        onPressed: _openBorrowWorkerDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 15),
                        label: Text("+ Borrow Worker", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filter Pills
                Row(
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
                const SizedBox(height: 10),

                // Quick Fill Bar (0 Selected) or Batch Action Bar (N Selected)
                _buildQuickFillOrBatchBar(filteredRoster, unmarkedCount, isDark),
                const SizedBox(height: 10),

                // Wide Roll Call Table (Master Header + Rows)
                Expanded(
                  child: _attendanceLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                      : filteredRoster.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 48, color: Colors.grey[500]),
                                  const SizedBox(height: 8),
                                  Text("No workers matching filter", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  // Table Header
                                  _buildTableHeader(filteredRoster, isDark),
                                  const Divider(height: 1, thickness: 1),
                                  // Table Body
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: filteredRoster.length,
                                      separatorBuilder: (_, _) => Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                      ),
                                      itemBuilder: (context, i) {
                                        final item = filteredRoster[i];
                                        return _buildTableRow(item, isDark);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Save Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (markedCount == totalCount && totalCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          markedCount == totalCount && totalCount > 0 ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 18,
                          color: markedCount == totalCount && totalCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$markedCount / $totalCount Marked",
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          Text(
                            unmarkedCount == 0 ? "Ready to save" : "$unmarkedCount remaining",
                            style: GoogleFonts.poppins(fontSize: 11, color: unmarkedCount == 0 ? const Color(0xFF10B981) : Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: _isSavingAttendance || totalCount == 0 ? null : _saveAttendance,
                    icon: _isSavingAttendance
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSavingAttendance ? "Saving..." : "Save Roster",
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        if (_hasUnsavedChanges) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0xFFF59E0B), blurRadius: 5, spreadRadius: 1),
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

  // Table Master Header
  Widget _buildTableHeader(List<LabourAttendanceItem> visibleRoster, bool isDark) {
    final allVisibleSelected = visibleRoster.isNotEmpty && visibleRoster.every((r) => _selectedRosterIds.contains(r.labourId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          // Select All Checkbox
          InkWell(
            onTap: () => _toggleSelectAllVisible(visibleRoster),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: allVisibleSelected ? const Color(0xFF6366F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: allVisibleSelected ? const Color(0xFF6366F1) : Colors.grey,
                  width: 1.4,
                ),
              ),
              child: allVisibleSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 14),

          // Worker Name & Badges
          Expanded(
            flex: 4,
            child: Text(
              "WORKER",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5),
            ),
          ),

          // Role
          Expanded(
            flex: 2,
            child: Text(
              "ROLE",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5),
            ),
          ),

          // Wage Type
          Expanded(
            flex: 2,
            child: Text(
              "WAGE TYPE",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5),
            ),
          ),

          // Status Buttons
          Expanded(
            flex: 5,
            child: Text(
              "ATTENDANCE STATUS",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5),
            ),
          ),

          // Overtime Stepper
          Expanded(
            flex: 4,
            child: Text(
              "OVERTIME (HOURS)",
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Table Row
  Widget _buildTableRow(LabourAttendanceItem item, bool isDark) {
    final hasStatus = item.status.isNotEmpty;
    final isPresent = item.status == 'Present';
    final isFixedSalary = item.wageType.toLowerCase().contains('fixed');
    final isSelected = _selectedRosterIds.contains(item.labourId);
    final initials = item.name.trim().isNotEmpty
        ? item.name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join('').toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: isSelected
          ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEEF2FF))
          : (hasStatus
              ? _getStatusColor(item.status).withValues(alpha: isDark ? 0.03 : 0.02)
              : Colors.transparent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Row Checkbox
          InkWell(
            onTap: () => _toggleSelectRoster(item.labourId),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF0D1117) : Colors.white),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF484F58) : const Color(0xFFCBD5E1)),
                  width: 1.4,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 14),

          // Worker Name + Badges + Conflict Banner
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Avatar Circle
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(initials, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.name,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isBorrowed) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text("Added", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                      ),
                    ],
                    if (item.status.isEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text("Unmarked", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w500, color: Colors.grey[500])),
                      ),
                    ],
                    if (item.isScheduledMultiSite) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text("Multi-Site", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6))),
                      ),
                    ],
                  ],
                ),
                if (item.alreadyMarkedAt != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          "Marked ${item.alreadyMarkedAt!['status']} at ${item.alreadyMarkedAt!['site_name']}",
                          style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Role
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SkillBadge(skill: item.role),
            ),
          ),

          // Wage Type
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isFixedSalary
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                        : const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.wageType,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isFixedSalary ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "OT: ₹${item.overtimePayPerHour.toStringAsFixed(0)}/h",
                  style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Status Action Buttons
          Expanded(
            flex: 5,
            child: Row(
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
          ),

          // Overtime Stepper
          Expanded(
            flex: 4,
            child: isPresent
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
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
                            child: const Icon(Icons.remove, size: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Center(
                            child: Text(
                              "${item.overtimeHours.toStringAsFixed(1)}h (+₹${(item.overtimeHours * item.overtimePayPerHour).toStringAsFixed(0)})",
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                            child: const Icon(Icons.add, size: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            _setItemOvertime(item, (item.overtimeHours + 1.0).clamp(0.0, 12.0));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text("+1h", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                          ),
                        ),
                      ],
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "—",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ),
          ),
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

  Widget _buildQuickFillOrBatchBar(List<LabourAttendanceItem> filteredRoster, int unmarkedCount, bool isDark) {
    final hasSelection = _selectedRosterIds.isNotEmpty;
    final allVisibleSelected = filteredRoster.isNotEmpty &&
        filteredRoster.every((r) => _selectedRosterIds.contains(r.labourId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
          ? Row(
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
                const SizedBox(width: 12),

                // Set Present
                InkWell(
                  onTap: () => _batchSetStatus('Present'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("Set Present", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),

                // Set Half Day
                InkWell(
                  onTap: () => _batchSetStatus('Half Day'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("Set Half Day", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),

                // Set Absent
                InkWell(
                  onTap: () => _batchSetStatus('Absent'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("Set Absent", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),

                // Batch OT Stepper
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Overtime:", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text("${_batchOvertimeHours.toStringAsFixed(0)}h", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600)),
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
                const Spacer(),

                // Deselect
                InkWell(
                  onTap: () => setState(() => _selectedRosterIds.clear()),
                  child: Text(
                    "Deselect All",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6366F1),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            )
          : Row(
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
                const SizedBox(width: 16),

                Container(width: 1, height: 18, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(width: 16),

                Text(
                  "Quick Fill:",
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                ),
                const SizedBox(width: 10),

                // Mark All Present
                InkWell(
                  onTap: () => _markAllVisible(filteredRoster, 'Present'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 5),
                        Text("Mark All Present", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Mark Unmarked as Present (N)
                if (unmarkedCount > 0) ...[
                  InkWell(
                    onTap: () => _markUnmarkedVisible(filteredRoster, 'Present'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 14, color: Color(0xFF6366F1)),
                          const SizedBox(width: 5),
                          Text("Mark Unmarked as Present ($unmarkedCount)", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Mark All Absent
                InkWell(
                  onTap: () => _markAllVisible(filteredRoster, 'Absent'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 5),
                        Text("Mark All Absent", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Reset
                InkWell(
                  onTap: () => _resetAllVisible(filteredRoster),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restart_alt_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("Reset Marks", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            Container(width: 7, height: 7, decoration: BoxDecoration(color: isSelected ? Colors.white : color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              "$label ($count)",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
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
  // SUB-TAB 2: MONTHLY GRID (DUAL MODE SPREADSHEET FOR LANDSCAPE)
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyGridSubTab(bool isDark) {
    final roles = ['All', ...{..._gridData.map((r) => r.role)}];
    final filtered = _gridData.where((r) => _gridRoleFilter == 'All' || r.role == _gridRoleFilter).toList();
    final daysInMonth = DateTime(_gridMonth.year, _gridMonth.month + 1, 0).day;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Month Navigator & Actions
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() => _gridMonth = DateTime(_gridMonth.year, _gridMonth.month - 1));
                  _loadMonthlyGrid();
                },
              ),
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
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMMM yyyy').format(_gridMonth),
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() => _gridMonth = DateTime(_gridMonth.year, _gridMonth.month + 1));
                  _loadMonthlyGrid();
                },
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 150,
                child: CustomDropdown<String>(
                  value: _gridRoleFilter,
                  height: 36,
                  fontSize: 11.5,
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _gridRoleFilter = val);
                  },
                ),
              ),
              const Spacer(),
              // Toggle Grid / Card mode
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                ),
                onPressed: () => setState(() => _isGridTableMode = !_isGridTableMode),
                icon: Icon(_isGridTableMode ? Icons.view_agenda_outlined : Icons.table_chart_outlined, size: 16, color: const Color(0xFF6366F1)),
                label: Text(_isGridTableMode ? "Card View" : "Full Table Mode", style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF6366F1))),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _exportMonthlyGridToExcel,
                icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                label: Text("Export Excel", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: _gridLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : filtered.isEmpty
                    ? Center(child: Text("No records found for this month", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])))
                    : _isGridTableMode
                        ? _buildFullSpreadsheetView(filtered, daysInMonth, isDark)
                        : _buildLandscapeGridCards(filtered, daysInMonth, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFullSpreadsheetView(List<LabourMonthlyRow> rows, int daysInMonth, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 10,
            horizontalMargin: 12,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            columns: [
              const DataColumn(label: Text("Worker")),
              const DataColumn(label: Text("Role")),
              ...List.generate(
                daysInMonth,
                (i) => DataColumn(
                  label: Center(
                    child: Text("${i + 1}", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const DataColumn(label: Text("Total")),
            ],
            rows: rows.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.name, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  DataCell(Text(row.role, style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500]))),
                  ...List.generate(daysInMonth, (i) {
                    final status = row.days["${i + 1}"] ?? '';
                    Color c = Colors.grey;
                    if (status == 'P') {
                      c = const Color(0xFF10B981);
                    } else if (status == 'HD') {
                      c = const Color(0xFFF59E0B);
                    } else if (status == 'A') {
                      c = const Color(0xFFEF4444);
                    } else if (status == 'PL') {
                      c = const Color(0xFF3B82F6);
                    }

                    return DataCell(
                      Center(
                        child: Text(
                          status.isEmpty ? '-' : status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: c,
                          ),
                        ),
                      ),
                    );
                  }),
                  DataCell(Text("${row.totalPresent}d", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeGridCards(List<LabourMonthlyRow> rows, int daysInMonth, bool isDark) {
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, idx) {
        final row = rows[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(row.role, style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500])),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(daysInMonth, (i) {
                      final status = row.days["${i + 1}"] ?? '';
                      Color cellColor;
                      if (status == 'P') {
                        cellColor = const Color(0xFF10B981);
                      } else if (status == 'HD') {
                        cellColor = const Color(0xFFF59E0B);
                      } else if (status == 'A') {
                        cellColor = const Color(0xFFEF4444);
                      } else if (status == 'PL') {
                        cellColor = const Color(0xFF3B82F6);
                      } else {
                        cellColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
                      }

                      return Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: cellColor.withValues(alpha: status.isNotEmpty ? 0.18 : 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: cellColor.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: Text(
                            "${i + 1}",
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: cellColor,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("${row.totalPresent}d Present", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 3: FINANCES & ADVANCES (LANDSCAPE)
  // ---------------------------------------------------------------------------
  Widget _buildFinancesSubTab(bool isDark) {
    final filtered = _financeSummary.where((s) => _financeRoleFilter == 'All' || s.role == _financeRoleFilter).toList();
    final totalWages = filtered.fold<double>(0.0, (acc, s) => acc + s.accruedCredit);
    final totalAdvances = filtered.fold<double>(0.0, (acc, s) => acc + s.totalAdvance);
    final netOutstanding = filtered.fold<double>(0.0, (acc, s) => acc + s.netPayable);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Stat Overview Cards
          Row(
            children: [
              _buildFinanceStatCard("Total Earned", totalWages, Icons.payments_outlined, const Color(0xFF6366F1), isDark),
              const SizedBox(width: 12),
              _buildFinanceStatCard("Advances Taken", totalAdvances, Icons.money_off_rounded, const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 12),
              _buildFinanceStatCard("Net Due", netOutstanding, Icons.account_balance_wallet_outlined, const Color(0xFF10B981), isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Worker Financial Breakdown List
          Expanded(
            child: _financeLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : filtered.isEmpty
                    ? Center(child: Text("No financial ledger rows found", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final summary = filtered[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161B22) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(summary.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                                      Text("${summary.role} • ${summary.daysPresent}d worked", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildFinanceMiniColumn("Earned", "₹${summary.accruedCredit.toStringAsFixed(0)}", const Color(0xFF6366F1)),
                                      _buildFinanceMiniColumn("Advance", "₹${summary.totalAdvance.toStringAsFixed(0)}", const Color(0xFFF59E0B)),
                                      _buildFinanceMiniColumn("Due", "₹${summary.netPayable.toStringAsFixed(0)}", const Color(0xFF10B981)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        side: const BorderSide(color: Color(0xFFF59E0B)),
                                      ),
                                      onPressed: () => _openLogAdvanceDialog(summary),
                                      child: Text("+ Advance", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _openSettlePayoutDialog(summary),
                                      child: Text("Settle", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ),
                                  ],
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
  }

  Widget _buildFinanceStatCard(String label, double amount, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                Text("₹${amount.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceMiniColumn(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
        Text(val, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WORKER DIRECTORY (LANDSCAPE MULTI-COLUMN)
  // ---------------------------------------------------------------------------
  Widget _buildLabourDirectory(bool isDark) {
    final roles = ['All', ...{..._workers.map((w) => w.role)}];
    final filteredWorkers = _workers.where((w) {
      if (_directorySiteFilter != 'All') {
        if (_directorySiteFilter == 'Unassigned') {
          if (w.siteId != null) return false;
        } else if (w.siteId != _directorySiteFilter && !w.siteIds.contains(_directorySiteFilter)) {
          return false;
        }
      }
      if (_directoryRoleFilter != 'All' && w.role != _directoryRoleFilter) return false;
      if (_directorySearch.isNotEmpty) {
        final q = _directorySearch.toLowerCase();
        if (!w.name.toLowerCase().contains(q) && !(w.phone?.contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Filter Toolbar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() => _directorySearch = val.trim()),
                    style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Search workers by name or phone...",
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: CustomDropdown<String>(
                  value: _directoryRoleFilter,
                  height: 38,
                  fontSize: 11.5,
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _directoryRoleFilter = val);
                  },
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openAddWorkerDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                label: Text("Add Worker", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
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
          const SizedBox(height: 14),

          // Worker Multi-Column Grid (3-4 columns)
          Expanded(
            child: filteredWorkers.isEmpty
                ? Center(child: Text("No workers found", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: crossAxisCount == 3 ? 3.0 : 3.6,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(initials, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openLabourHistory(w),
                      child: Text(
                        w.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
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
              const SizedBox(width: 4),
              SkillBadge(skill: w.role),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Wage: ₹${w.monthlySalary.toStringAsFixed(0)}/d • OT: ₹${w.overtimePayPerHour.toStringAsFixed(0)}/h",
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history_edu_rounded, size: 15, color: Color(0xFF10B981)),
                    onPressed: () => _openWageHistoryDialog(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: "Wage Revisions",
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF6366F1)),
                    onPressed: () => _openDailyScheduleDialog(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: "Daily Schedule",
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 15, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    onPressed: () => _openEditWorkerDialog(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: "Edit Worker",
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDeleteWorker(w),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
            _hasUnsavedChanges = true;
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
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
            if (!mounted) return;
            context.showToast("Transferred ${labourIds.length} worker(s) successfully!", isSuccess: true);
            _loadInitialData();
            if (_selectedSite != null) _loadAttendanceRoster();
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
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
            if (!mounted) return;
            context.showToast("Salary advance logged successfully!", isSuccess: true);
            _loadFinances();
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
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
            if (!mounted) return;
            context.showToast("Payout settled successfully!", isSuccess: true);
            _loadFinances();
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
