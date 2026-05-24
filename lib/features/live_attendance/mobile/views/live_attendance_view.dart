import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../dashboard/tablet/widgets/stat_card.dart';
import '../../../employees/services/employee_service.dart';
import '../../../employees/models/employee_model.dart';
import '../../../attendance/services/attendance_service.dart';
import '../../../attendance/models/attendance_record.dart';
import '../../../attendance/models/live_attendance_item.dart';
import '../../../attendance/providers/attendance_provider.dart';
import 'correction_requests_view.dart'; // Mobile version

class MobileLiveAttendanceContent extends StatefulWidget {
  const MobileLiveAttendanceContent({super.key});

  @override
  State<MobileLiveAttendanceContent> createState() => _MobileLiveAttendanceContentState();
}

class _MobileLiveAttendanceContentState extends State<MobileLiveAttendanceContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data State
  DateTime _selectedDate = DateTime.now();
  List<LiveAttendanceItem> _items = [];
  bool _isLoading = false;

  // Sub-tabs State
  String _activeSubTab = 'Overview'; // 'Overview', 'Analytics', 'Timeline', 'Map View'
  
  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _selectedDepartment = 'All Departments';
  List<String> _departments = ['All Departments'];

  // Map state
  LiveAttendanceItem? _selectedMapItem;
  AttendanceRecord? _selectedMapRecord;
  bool _isMapCheckIn = true;
  String _activeMapTheme = 'voyager'; // 'dark', 'light', 'voyager', 'satellite', 'streets'
  bool _isMapThemeMenuOpen = false;

  // Cache
  final Map<String, List<LiveAttendanceItem>> _dashboardCache = {};
  
  // Stats
  int _present = 0;
  int _active = 0;
  int _absent = 0;
  int _late = 0;

  late EmployeeService _employeeService;
  late AttendanceService _attendanceService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    _employeeService = EmployeeService(authService);
    _attendanceService = AttendanceService(authService.dio);
    
    _fetchDashboardData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AttendanceProvider>(context, listen: false).fetchPendingCorrectionCount();
      }
    });
  }

  Future<void> _fetchDashboardData({bool forceRefresh = false}) async {
    if (!mounted) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // 1. Check Cache
    if (!forceRefresh && _dashboardCache.containsKey(dateStr)) {
      _updateStateWithItems(_dashboardCache[dateStr]!);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _employeeService.getEmployees(),
        _attendanceService.getAdminAttendanceRecords(dateStr)
      ]);

      final users = results[0] as List<Employee>;
      final records = results[1] as List<AttendanceRecord>;

      final merged = mergeAttendanceData(users, records);
      
      merged.sort((a, b) {
        if (a.status == "Absent" && b.status != "Absent") return 1;
        if (a.status != "Absent" && b.status == "Absent") return -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      // 2. Update Cache
      _dashboardCache[dateStr] = merged;

      if (mounted) {
        _updateStateWithItems(merged);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateStateWithItems(List<LiveAttendanceItem> items) {
    final depts = items.map((i) => i.department).toSet().toList();
    depts.sort();

    setState(() {
      _items = items;
      _present = items.where((i) => i.status == "Present").length;
      _active = items.where((i) => i.status == "Active").length;
      _absent = items.where((i) => i.status == "Absent").length;
      _late = items.where((i) => i.isLate).length;
      _departments = ['All Departments', ...depts];
    });
  }

  List<LiveAttendanceItem> mergeAttendanceData(List<Employee> users, List<AttendanceRecord> records) {
    return users.map((user) {
      final userRecs = records.where((r) => r.userId == user.userId).toList();
      return LiveAttendanceItem(user: user, records: userRecs);
    }).toList();
  }

  List<LiveAttendanceItem> _getFilteredItems() {
    return _items.where((item) {
      final nameMatches = item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          item.designation.toLowerCase().contains(_searchText.toLowerCase());
      final deptMatches = _selectedDepartment == 'All Departments' || item.department == _selectedDepartment;
      return nameMatches && deptMatches;
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _buildTabs(context),
                ),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Live Dashboard
          _buildLiveDashboard(context),
          
          // Tab 2: Correction Requests
          const MobileCorrectionRequestsView(), 
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = context.watch<AttendanceProvider>().pendingCorrectionCount;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : const Color(0xFF4F46E5),
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.dashboard_rounded, size: 18),
                const SizedBox(width: 8),
                Text(MediaQuery.of(context).size.width < 600 ? "Dashboard" : "Live Dashboard"),
              ],
            ),
          ), 
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions_rounded, size: 18),
                const SizedBox(width: 8),
                Text(MediaQuery.of(context).size.width < 600 ? "Requests" : "Correction Requests"),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red, 
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDashboard(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      physics: const BouncingScrollPhysics(), 
      children: [
        const SizedBox(height: 12),
        // Date Selector
        _buildDateSelector(context),
        const SizedBox(height: 12),

        // 1. KPIs (2x2 Grid)
        _buildKPIGrid(),
        const SizedBox(height: 10),

        // 2. Sub-Tabs Switcher (Overview, Analytics, Timeline, Map View)
        _buildSubTabsSwitcher(context),
        const SizedBox(height: 10),

        // 3. Filters (Search & Dropdown) - Only show for Overview tab
        if (_activeSubTab == 'Overview') ...[
          _buildFilters(context),
          const SizedBox(height: 10),
        ],

        // 4. Dynamic sub-tab content
        _buildSubTabContent(context),
      ],
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () async {
            await showDialog(
              context: context,
              builder: (context) => GlassDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                onDateSelected: (newDate) {
                  setState(() => _selectedDate = newDate);
                  _fetchDashboardData();
                },
              ),
            );
          },
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            borderRadius: 10,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today, 
                  size: 13, 
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Theme.of(context).primaryColor
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEE, dd MMM').format(_selectedDate),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKPIGrid() {
    final totalEmployees = _items.length;

    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, 
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        StatCard(
          title: 'Total Present',
          value: '$_present',
          total: '/ $totalEmployees',
          percentage: '',
          contextText: 'For Selected Date',
          isPositive: true,
          icon: Icons.people_alt,
          baseColor: const Color(0xFF5B60F6),
        ),
        StatCard(
          title: 'Late',
          value: '$_late',
          total: '',
          percentage: '',
          contextText: 'Late Check-ins',
          isPositive: false,
          icon: Icons.access_time_filled,
          baseColor: const Color(0xFFF59E0B),
        ),
        StatCard(
          title: 'Absent',
          value: '$_absent',
          total: '',
          percentage: '',
          contextText: 'Not checked in',
          isPositive: false,
          icon: Icons.person_off,
          baseColor: const Color(0xFFEF4444),
        ),
        StatCard(
          title: 'Active Now',
          value: '$_active',
          total: '',
          percentage: '',
          contextText: 'Currently Clocked In',
          isPositive: true,
          icon: Icons.coffee,
          baseColor: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildSubTabsSwitcher(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final tabs = [
      {'id': 'Overview', 'label': 'Overview', 'icon': Icons.grid_view},
      {'id': 'Analytics', 'label': 'Analytics', 'icon': Icons.bar_chart},
      {'id': 'Timeline', 'label': 'Timeline', 'icon': Icons.view_timeline},
      {'id': 'Map View', 'label': 'Map View', 'icon': Icons.map},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeSubTab == tab['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeSubTab = tab['id'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                // FIX: Selected tab uses primaryColor with strong visibility in dark mode
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF21262D) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    size: 14,
                    // FIX: White icon on selected (primaryColor bg), grey on unselected
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      // FIX: Always white text on selected tab (primaryColor bg)
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubTabContent(BuildContext context) {
    switch (_activeSubTab) {
      case 'Analytics':
        return _buildAnalyticsTab(context);
      case 'Timeline':
        return _buildTimelineTab();
      case 'Map View':
        return _buildMapViewTab();
      case 'Overview':
      default:
        return _buildOverviewTab(context);
    }
  }

  Widget _buildOverviewTab(BuildContext context) {
    final filtered = _getFilteredItems();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No attendance records found.', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
      );
    }

    final presentItems = filtered.where((item) => item.status != "Absent").toList();
    final absentItems = filtered.where((item) => item.status == "Absent").toList();

    return Column(
      children: [
        if (presentItems.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: presentItems.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildMonitoringCard(context, presentItems[index]);
            },
          ),
        ],
        if (presentItems.isNotEmpty && absentItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "Not Checked In",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
              ],
            ),
          ),
        ],
        if (absentItems.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: absentItems.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildMonitoringCard(context, absentItems[index]);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Column(
      children: [
        // Search
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white.withOpacity(0.05) 
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey[300]!,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchText = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search employee...',
              prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        // Dropdown
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white.withOpacity(0.05) 
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedDepartment,
              icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).textTheme.bodySmall?.color),
              dropdownColor: Theme.of(context).cardColor, 
              items: _departments
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14))))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedDepartment = val;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringCard(BuildContext context, LiveAttendanceItem item) {
    Color color;
    switch (item.statusLabel) {
      case "Active": color = Colors.blue; break;
      case "Late Active": color = Colors.blueAccent; break; 
      case "Present": color = Colors.green; break;
      case "Late": color = Colors.orange; break;
      default: color = Colors.grey;
    }
    
    final inTime = item.record?.timeIn != null ? _formatTime(item.record!.timeIn) : '--';
    final outTime = item.record?.timeOut != null ? _formatTime(item.record!.timeOut) : '--';
    
    return InkWell(
      onTap: () => _showEmployeeDetailsBottomSheet(context, item),
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 16,
        child: Column(
          children: [
            // Row 1: Profile + Status
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.1),
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?', 
                    style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        "${item.designation} • ${item.department}",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
            const SizedBox(height: 6),

            // Row 2: Metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricItem(context, 'Time In', inTime),
                _buildMetricItem(context, 'Time Out', outTime),
                _buildMetricItem(context, 'Shift', item.user.shift ?? 'General'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '--';
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat('hh:mm a').format(dt); 
    } catch (e) {
      return ''; 
    }
  }

  Widget _buildMetricItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  // ================= ANALYTICS TAB BUILDERS =================

  Widget _buildAnalyticsTab(BuildContext context) {
    return Column(
      children: [
        _buildPieChartCard(),
        const SizedBox(height: 16),
        _buildHourlyActivityCard(),
        const SizedBox(height: 16),
        _buildDepartmentHealthCard(),
        const SizedBox(height: 16),
        _buildSessionIntensityCard(),
      ],
    );
  }

  Widget _buildPieChartCard() {
    final presentCount = _items.where((i) => i.status == "Present").length;
    final activeCount = _items.where((i) => i.status == "Active").length;
    final absentCount = _items.where((i) => i.status == "Absent").length;
    final lateCount = _items.where((i) => i.isLate).length;
    final total = _items.length;

    List<PieChartSectionData> sections = [];
    if (presentCount > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFF10B981),
        value: presentCount.toDouble(),
        title: '$presentCount',
        radius: 35,
        titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (activeCount > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFF3B82F6),
        value: activeCount.toDouble(),
        title: '$activeCount',
        radius: 35,
        titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (lateCount > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFFF59E0B),
        value: lateCount.toDouble(),
        title: '$lateCount',
        radius: 35,
        titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (absentCount > 0) {
      sections.add(PieChartSectionData(
        color: const Color(0xFFEF4444),
        value: absentCount.toDouble(),
        title: '$absentCount',
        radius: 35,
        titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color: Colors.grey,
        value: 1,
        title: '0',
        radius: 35,
        titleStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Attendance Distribution", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    sections: sections,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$total', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Total Staff', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem("Present", const Color(0xFF10B981)),
              _buildLegendItem("Active", const Color(0xFF3B82F6)),
              _buildLegendItem("Late Arrival", const Color(0xFFF59E0B)),
              _buildLegendItem("Absent", const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyActivityCard() {
    List<FlSpot> checkinSpots = [];
    List<FlSpot> activeSpots = [];
    
    final Map<int, int> checkinsPerHour = {};
    final Map<int, int> activePerHour = {};
    for (int h = 6; h <= 22; h++) {
      checkinsPerHour[h] = 0;
      activePerHour[h] = 0;
    }

    for (final item in _items) {
      for (final session in item.records) {
        if (session.timeIn != null) {
          final dtIn = DateTime.tryParse(session.timeIn!);
          if (dtIn != null) {
            final hour = dtIn.hour;
            if (hour >= 6 && hour <= 22) {
              checkinsPerHour[hour] = (checkinsPerHour[hour] ?? 0) + 1;
            }
            
            final parsedOut = session.timeOut != null ? DateTime.tryParse(session.timeOut!) : null;
            final dtOut = parsedOut ?? DateTime.now();
            final outHour = dtOut.hour;
            for (int h = hour; h <= outHour; h++) {
              if (h >= 6 && h <= 22) {
                activePerHour[h] = (activePerHour[h] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    int idx = 0;
    for (int h = 6; h <= 22; h++) {
      checkinSpots.add(FlSpot(idx.toDouble(), (checkinsPerHour[h] ?? 0).toDouble()));
      activeSpots.add(FlSpot(idx.toDouble(), (activePerHour[h] ?? 0).toDouble()));
      idx++;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Staff Activity Velocity", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        int h = 6 + value.toInt();
                        if (h > 22) return const SizedBox();
                        final label = h == 12 ? '12PM' : h > 12 ? '${h - 12}PM' : '${h}AM';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(label, style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: activeSpots,
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 2.5,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withOpacity(0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: checkinSpots,
                    isCurved: true,
                    color: const Color(0xFF6366F1),
                    barWidth: 2.5,
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Active Staff", const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _buildLegendItem("Check-ins", const Color(0xFF6366F1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentHealthCard() {
    final Map<String, List<LiveAttendanceItem>> deptGroups = {};
    for (final item in _items) {
      final dept = item.department;
      deptGroups.putIfAbsent(dept, () => []).add(item);
    }

    final depts = deptGroups.keys.toList();
    depts.sort();

    List<BarChartGroupData> barGroups = [];
    int idx = 0;
    for (final dept in depts) {
      final list = deptGroups[dept]!;
      final presentCount = list.where((i) => i.status == "Present").length;
      final activeCount = list.where((i) => i.status == "Active").length;
      final lateCount = list.where((i) => i.isLate).length;
      final absentCount = list.where((i) => i.status == "Absent").length;

      final totPresent = presentCount + activeCount;

      barGroups.add(BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: (totPresent + lateCount + absentCount).toDouble(),
            color: Colors.transparent, 
            width: 12,
            rodStackItems: [
              BarChartRodStackItem(0, totPresent.toDouble(), const Color(0xFF10B981)),
              BarChartRodStackItem(totPresent.toDouble(), (totPresent + lateCount).toDouble(), const Color(0xFFF59E0B)),
              BarChartRodStackItem((totPresent + lateCount).toDouble(), (totPresent + lateCount + absentCount).toDouble(), const Color(0xFFEF4444)),
            ],
          )
        ],
      ));
      idx++;
    }

    if (barGroups.isEmpty) {
      barGroups.add(BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(toY: 0, color: Colors.grey, width: 12),
        ],
      ));
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Department Health Stack", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= depts.length) return const SizedBox();
                        String label = depts[i];
                        if (label.length > 5) label = "${label.substring(0, 5)}.";
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(label, style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Present", const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildLegendItem("Late", const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildLegendItem("Absent", const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionIntensityCard() {
    int s1 = 0;
    int s2 = 0;
    int s3 = 0;
    int s4Plus = 0;

    for (final item in _items) {
      if (item.status != "Absent") {
        final count = item.records.length;
        if (count == 1) s1++;
        else if (count == 2) s2++;
        else if (count == 3) s3++;
        else if (count >= 4) s4Plus++;
      }
    }

    final List<int> values = [s1, s2, s3, s4Plus];
    final List<String> labels = ["1 Session", "2 Sessions", "3 Sessions", "4+ Sessions"];

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < values.length; i++) {
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: values[i].toDouble(),
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 14,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          )
        ],
      ));
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Session Intensity Distribution", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(labels[i], style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Session Count Intensity", const Color(0xFF6366F1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  // ── Gantt Timeline ──────────────────────────────────────────────

  Widget _buildTimelineTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Only employees with at least one session
    final activeItems = _items.where((item) => item.records.isNotEmpty).toList();
    if (activeItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.view_timeline, size: 40, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text('No session data for this date.', style: GoogleFonts.poppins(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    const int startHour = 6;  // 6 AM
    const int endHour = 23;   // 11 PM
    const double rowHeight = 52.0;
    const double labelWidth = 90.0;
    const double hourWidth = 44.0;
    final double totalWidth = (endHour - startHour) * hourWidth;

    return GlassContainer(
      padding: const EdgeInsets.all(0),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(
              children: [
                Icon(Icons.view_timeline, size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text('Session Gantt Chart',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${activeItems.length} employees',
                      style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
          // Gantt body — horizontally scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: labelWidth + totalWidth + 16,
              child: Column(
                children: [
                  // Hour axis header
                  Row(
                    children: [
                      SizedBox(width: labelWidth),
                      ...List.generate(endHour - startHour, (i) {
                        final h = startHour + i;
                        final label = h == 12 ? '12P' : (h > 12 ? '${h - 12}P' : '${h}A');
                        return SizedBox(
                          width: hourWidth,
                          child: Center(
                            child: Text(label,
                                style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[500])),
                          ),
                        );
                      }),
                    ],
                  ),
                  // Divider under hour labels
                  Container(height: 1, color: Colors.grey.withOpacity(0.15)),
                  // Employee rows
                  ...activeItems.map((item) => _buildGanttRow(
                        item: item,
                        startHour: startHour,
                        endHour: endHour,
                        hourWidth: hourWidth,
                        rowHeight: rowHeight,
                        labelWidth: labelWidth,
                        isDark: isDark,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _buildLegendItem('Check In Session', const Color(0xFF10B981)),
                const SizedBox(width: 16),
                _buildLegendItem('No Time Out Yet', const Color(0xFF6366F1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttRow({
    required LiveAttendanceItem item,
    required int startHour,
    required int endHour,
    required double hourWidth,
    required double rowHeight,
    required double labelWidth,
    required bool isDark,
  }) {
    final now = DateTime.now();
    final rangeMinutes = (endHour - startHour) * 60.0;
    final totalWidth = (endHour - startHour) * hourWidth;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      height: rowHeight,
      child: Row(
        children: [
          // Employee label
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.name.split(' ').first,
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gantt chart area
          SizedBox(
            width: totalWidth,
            height: rowHeight,
            child: Stack(
              children: [
                // Hour grid lines
                ...List.generate(endHour - startHour, (i) {
                  return Positioned(
                    left: i * hourWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: Colors.grey.withOpacity(0.08),
                    ),
                  );
                }),
                // Session bars
                ...item.records.map((record) {
                  final inDt = record.timeIn != null ? DateTime.tryParse(record.timeIn!) : null;
                  if (inDt == null) return const SizedBox.shrink();
                  final outDt = record.timeOut != null ? DateTime.tryParse(record.timeOut!) : null;
                  final effectiveOut = outDt ?? now;

                  // Clamp to chart range
                  final chartStart = DateTime(inDt.year, inDt.month, inDt.day, startHour);
                  final inMinutes = inDt.difference(chartStart).inMinutes.clamp(0, (endHour - startHour) * 60).toDouble();
                  final outMinutes = effectiveOut.difference(chartStart).inMinutes.clamp(0, (endHour - startHour) * 60).toDouble();

                  if (outMinutes <= inMinutes) return const SizedBox.shrink();

                  final left = (inMinutes / rangeMinutes) * totalWidth;
                  final width = ((outMinutes - inMinutes) / rangeMinutes) * totalWidth;
                  final barColor = outDt != null ? const Color(0xFF10B981) : const Color(0xFF6366F1);

                  return Positioned(
                    left: left,
                    top: rowHeight * 0.25,
                    height: rowHeight * 0.5,
                    width: width < 4 ? 4 : width,
                    child: GestureDetector(
                      onTap: () => _showEmployeeDetailsBottomSheet(context, item),
                      child: Tooltip(
                        message: '${_formatTime(record.timeIn)} – ${outDt != null ? _formatTime(record.timeOut) : "Active"}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: barColor.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                // Current time line (today only)
                if (DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now()))
                  Builder(builder: (context) {
                    final chartStart = DateTime(now.year, now.month, now.day, startHour);
                    final nowMins = now.difference(chartStart).inMinutes.clamp(0, (endHour - startHour) * 60).toDouble();
                    final left = (nowMins / rangeMinutes) * totalWidth;
                    return Positioned(
                      left: left - 0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1.5,
                        color: Colors.red.withOpacity(0.6),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── flutter_map (OpenStreetMap / CARTO) ─────────────────────────

  static const Map<String, Map<String, String>> _mapThemes = {
    'dark':    {'name': 'Night Mode',  'url': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'},
    'light':   {'name': 'Light Mode',  'url': 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'},
    'voyager': {'name': 'Day Mode',    'url': 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'},
    'satellite':{'name': 'Satellite',  'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'},
    'streets': {'name': 'Streets',     'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'},
  };

  List<_MapMarkerData> _buildFlutterMapMarkers() {
    final list = <_MapMarkerData>[];
    for (final item in _items) {
      for (final record in item.records) {
        if (record.timeInLat != null && record.timeInLng != null) {
          list.add(_MapMarkerData(
            employee: item,
            record: record,
            isCheckIn: true,
            latlng: LatLng(record.timeInLat!, record.timeInLng!),
          ));
        }
        if (record.timeOutLat != null && record.timeOutLng != null) {
          list.add(_MapMarkerData(
            employee: item,
            record: record,
            isCheckIn: false,
            latlng: LatLng(record.timeOutLat!, record.timeOutLng!),
          ));
        }
      }
    }
    return list;
  }

  Widget _buildMapViewTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markerData = _buildFlutterMapMarkers();

    if (markerData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 40, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text(
                'No coordinate records found for this date.',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final initialCenter = markerData.first.latlng;
    final tileUrl = _mapThemes[_activeMapTheme]!['url']!;
    final markers = markerData.map((md) {
      final color = md.isCheckIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      return Marker(
        point: md.latlng,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedMapItem = md.employee;
              _selectedMapRecord = md.record;
              _isMapCheckIn = md.isCheckIn;
              _isMapThemeMenuOpen = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: Text(
                md.employee.name.isNotEmpty ? md.employee.name[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    }).toList();

    return SizedBox(
      height: 420,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 11.0,
                onTap: (_, __) {
                  if (_selectedMapItem != null || _isMapThemeMenuOpen) {
                    setState(() {
                      _selectedMapItem = null;
                      _selectedMapRecord = null;
                      _isMapThemeMenuOpen = false;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: _activeMapTheme == 'satellite' ? const [] : const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.flutter_application',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            // Map theme switcher (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: _buildMapThemeSwitcherButton(),
            ),
            // Legend (top-left)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapLegendDot(const Color(0xFF10B981), 'In'),
                    const SizedBox(width: 10),
                    _buildMapLegendDot(const Color(0xFFEF4444), 'Out'),
                  ],
                ),
              ),
            ),
            // Marker detail overlay (bottom)
            if (_selectedMapItem != null && _selectedMapRecord != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _buildMapDetailOverlayWidget(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapThemeSwitcherButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isMapThemeMenuOpen = !_isMapThemeMenuOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.75) : Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers, size: 14, color: Theme.of(context).primaryColor),
                const SizedBox(width: 4),
                Text(
                  _mapThemes[_activeMapTheme]!['name']!,
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(width: 4),
                Icon(_isMapThemeMenuOpen ? Icons.expand_less : Icons.expand_more,
                    size: 12, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_isMapThemeMenuOpen)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _mapThemes.entries.map((e) {
                final isActive = e.key == _activeMapTheme;
                return GestureDetector(
                  onTap: () => setState(() {
                    _activeMapTheme = e.key;
                    _isMapThemeMenuOpen = false;
                  }),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Text(
                      e.value['name']!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMapLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMapDetailOverlayWidget() {
    final item = _selectedMapItem!;
    final record = _selectedMapRecord!;
    final isCheckIn = _isMapCheckIn;
    final color = isCheckIn ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final label = isCheckIn ? 'Check In' : 'Check Out';
    final address = isCheckIn ? record.timeInAddress : record.timeOutAddress;
    final time = isCheckIn ? record.timeIn : record.timeOut;
    final image = isCheckIn ? record.timeInImage : record.timeOutImage;
    final coords = isCheckIn
        ? '${record.timeInLat}, ${record.timeInLng}'
        : '${record.timeOutLat}, ${record.timeOutLng}';

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.1),
                child: Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(item.designation, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _selectedMapItem = null;
                    _selectedMapRecord = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.withOpacity(0.2), height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session Status', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Time Captured', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                    Text(
                      _formatTime(time),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text('Address', style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                    Text(
                      address ?? coords,
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (image != null && image.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => _showPhotoViewer(context, image, item.name),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: image,
                        height: 90,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: Colors.grey[800], child: const Center(child: CircularProgressIndicator())),
                        errorWidget: (c, u, e) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, String imageUrl, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const SizedBox(width: 80, height: 80, child: CircularProgressIndicator()),
                  errorWidget: (c, u, e) => const Icon(Icons.broken_image, size: 48, color: Colors.red),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeDetailsBottomSheet(BuildContext context, LiveAttendanceItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xEB161B22) : const Color(0xEBFFFFFF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Profile Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${item.designation} • ${item.department}",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.withOpacity(0.2), height: 1),
              const SizedBox(height: 16),
              
              // Daily Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPopupStat("Shift", item.user.shift ?? 'General'),
                  _buildPopupStat("Sessions", "${item.records.length}"),
                  _buildPopupStat("Status", item.statusLabel, color: _getStatusColor(item.statusLabel)),
                ],
              ),
              const SizedBox(height: 20),
              
              Text(
                "Sessions Activity",
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Flexible scrollable session items
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: item.records.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text("No session activity", style: GoogleFonts.poppins(color: Colors.grey)),
                          ),
                        )
                      : Column(
                          children: item.records.asMap().entries.map((entry) {
                            final index = entry.key;
                            final session = entry.value;
                            final inTime = _formatTime(session.timeIn);
                            final outTime = _formatTime(session.timeOut);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Session #${index + 1}",
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Time In", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                                            Text(inTime, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Time Out", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                                            Text(outTime, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (session.timeInAddress != null) ...[
                                    const SizedBox(height: 8),
                                    Text("Time In Address", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                                    Text(session.timeInAddress!, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
                                  ],
                                  if (session.timeOutAddress != null) ...[
                                    const SizedBox(height: 8),
                                    Text("Time Out Address", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                                    Text(session.timeOutAddress!, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
                                  ],
                                  
                                  if ((session.timeInImage != null && session.timeInImage!.trim().isNotEmpty) ||
                                      (session.timeOutImage != null && session.timeOutImage!.trim().isNotEmpty)) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        if (session.timeInImage != null && session.timeInImage!.trim().isNotEmpty)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("Selfie In", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _showPhotoViewer(context, session.timeInImage!, item.name),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: CachedNetworkImage(
                                                      imageUrl: session.timeInImage!,
                                                      height: 70,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      placeholder: (c, u) => Container(color: Colors.grey[800], child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))),
                                                      errorWidget: (c, u, e) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, size: 14, color: Colors.grey)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (session.timeOutImage != null && session.timeOutImage!.trim().isNotEmpty) ...[
                                          if (session.timeInImage != null && session.timeInImage!.trim().isNotEmpty)
                                            const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("Selfie Out", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _showPhotoViewer(context, session.timeOutImage!, item.name),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: CachedNetworkImage(
                                                      imageUrl: session.timeOutImage!,
                                                      height: 70,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      placeholder: (c, u) => Container(color: Colors.grey[800], child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))),
                                                      errorWidget: (c, u, e) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, size: 14, color: Colors.grey)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String statusLabel) {
    switch (statusLabel) {
      case "Active": return Colors.blue;
      case "Late Active": return Colors.blueAccent;
      case "Present": return Colors.green;
      case "Late": return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class _MapMarkerData {
  final LiveAttendanceItem employee;
  final AttendanceRecord record;
  final bool isCheckIn;
  final LatLng latlng;

  _MapMarkerData({
    required this.employee,
    required this.record,
    required this.isCheckIn,
    required this.latlng,
  });
}
