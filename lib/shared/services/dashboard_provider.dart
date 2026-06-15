import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../models/dashboard_model.dart';
import 'auth_service.dart';
import '../../features/attendance/services/attendance_service.dart';
import '../../features/employees/models/employee_model.dart';
import '../constants/api_constants.dart';

class DashboardProvider extends ChangeNotifier {
  final AuthService _authService;
  final AdminService _adminService;
  String? _lastUserId;
  
  DashboardProvider(AuthService authService) 
      : _authService = authService,
        _adminService = AdminService(authService) {
    _lastUserId = authService.user?.id;
    authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final currentUserId = _authService.user?.id;
    if (currentUserId != _lastUserId) {
      _cache.clear();
      _data = null;
      _userWorkLocations = [];
      _lastUserId = currentUserId;
      fetchDashboardData(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _activeRange = 'weekly';
  String get activeRange => _activeRange;
  
  String _viewMode = 'range'; // 'range' or 'calendar'
  String get viewMode => _viewMode;

  int _selectedMonth = DateTime.now().month;
  int get selectedMonth => _selectedMonth;

  int _selectedYear = DateTime.now().year;
  int get selectedYear => _selectedYear;

  DashboardData? _data;
  DashboardData? get data => _data;

  List<EmployeeWorkLocation> _userWorkLocations = [];
  List<EmployeeWorkLocation> get userWorkLocations => _userWorkLocations;

  // Initial empty data to prevent null checks everywhere if needed
  DashboardStats get stats => _data?.stats ?? DashboardStats(presentToday: 0, totalEmployees: 0, absentToday: 0, lateCheckins: 0);
  DashboardTrends get trends => _data?.trends ?? DashboardTrends(present: '0%', absent: '0%', late: '0%');
  List<ChartData> get chartData => _data?.chartData ?? [];
  List<ActivityLog> get activities => _data?.activities ?? [];

  // Cache
  final Map<String, DashboardData> _cache = {};

  Future<void> fetchDashboardData({bool forceRefresh = false}) async {
    // Determine effective range/params
    String range = _viewMode == 'range' ? _activeRange : 'custom';
    int? month = _viewMode == 'calendar' ? _selectedMonth : null;
    int? year = _viewMode == 'calendar' ? _selectedYear : null;

    String cacheKey = '${range}_${month ?? "now"}_${year ?? "now"}';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      _data = _cache[cacheKey];
      _isLoading = false;
        notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      // notifyListeners(); // Don't notify here to avoid flicker if just switching view modes quickly

      // Fetch user profile to get fresh avatar image, department, designation from backend
      await _authService.fetchUserProfile();

      final user = _authService.user;
      if (user != null && user.isEmployee) {
        // Fetch employee work locations
        try {
          final locRes = await _authService.dio.get(ApiConstants.employeeLocations);
          if (locRes.statusCode == 200 && locRes.data['locations'] != null) {
            final List<dynamic> locList = locRes.data['locations'];
            _userWorkLocations = locList
                .map((x) => EmployeeWorkLocation.fromJson(x as Map<String, dynamic>))
                .toList();
          } else {
            _userWorkLocations = [];
          }
        } catch (e) {
          debugPrint("Failed to fetch employee locations: $e");
          _userWorkLocations = [];
        }

        // Fetch employee's own records for the current month to calculate personal stats
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final formatter = DateFormat('yyyy-MM-dd');
        final startStr = formatter.format(startOfMonth);
        final endStr = formatter.format(now);

        final attendanceService = AttendanceService(_authService.dio);
        final records = await attendanceService.getMyRecords(
          fromDate: startStr,
          toDate: endStr,
          userId: user.employeeId,
        );

        int presentCount = 0;
        int absentCount = 0;
        int lateCount = 0;

        for (var rec in records) {
          if (rec.status.toUpperCase() == 'PRESENT') {
            presentCount++;
            if (rec.lateMinutes > 0) {
              lateCount++;
            }
          } else if (rec.status.toUpperCase() == 'ABSENT') {
            absentCount++;
          }
        }

        final employeeStats = DashboardStats(
          presentToday: presentCount,      // Map to "Present Days" in UI
          totalEmployees: 0,
          absentToday: absentCount,        // Map to "Absent Days" in UI
          lateCheckins: lateCount,         // Map to "Late Arrivals" in UI
        );

        final result = DashboardData(
          stats: employeeStats,
          trends: DashboardTrends(present: '0%', absent: '0%', late: '0%'),
          chartData: [],
          activities: [],
        );

        _data = result;
        _cache[cacheKey] = result;
      } else {
        // Admin or HR
        final result = await _adminService.getDashboardStats(
          range: range,
          month: month,
          year: year,
        );

        _data = result;
        _cache[cacheKey] = result;
      }
    } catch (e) {
      debugPrint("Dashboard Error: $e");
      // Optionally handle error state
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setRange(String range) {
    if (_activeRange != range) {
      _activeRange = range;
      fetchDashboardData();
    }
  }

  void setViewMode(String mode) {
    if (_viewMode != mode) {
      _viewMode = mode;
      fetchDashboardData();
    }
  }

  void setMonth(int month) {
    if (_selectedMonth != month) {
      _selectedMonth = month;
      if (_viewMode == 'calendar') fetchDashboardData();
    }
  }

  void setYear(int year) {
    if (_selectedYear != year) {
      _selectedYear = year;
      if (_viewMode == 'calendar') fetchDashboardData();
    }
  }
}
