import 'package:flutter/material.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/features/leave/core/leave_service.dart';
import 'package:flutter_application/features/employees/core/employee_model.dart';
import 'package:flutter_application/features/employees/core/employee_service.dart';
import 'package:flutter_application/shared/services/auth_service.dart';

class LeaveProvider with ChangeNotifier {
  final AuthService _authService;
  late final LeaveService _leaveService;
  late final EmployeeService _employeeService;

  // Employee State
  List<LeaveRequest> _myLeaves = [];
  bool _isLoadingMyLeaves = false;
  String? _myLeavesError;

  // Employee Filter States (0-11 for months, matching web)
  int _selectedMonth = DateTime.now().month - 1;
  int _selectedYear = DateTime.now().year;

  // Admin State
  List<LeaveRequest> _pendingRequests = [];
  bool _isLoadingPending = false;
  String? _pendingError;

  List<LeaveRequest> _adminHistory = [];
  bool _isLoadingAdminHistory = false;
  String? _adminHistoryError;

  // Admin Filter States
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  LeaveRequest? _selectedAdminLeave;
  List<Map<String, dynamic>> _selectedEmployeeBalances = [];
  bool _isLoadingEmployeeBalances = false;

  // Balance & Policy State
  List<Map<String, dynamic>> _myLeaveBalances = [];
  List<Map<String, dynamic>> _myLeavePolicies = [];
  bool _isLoadingBalances = false;
  String? _balancesError;

  // Staff Assignment State
  List<Employee> _allEmployees = [];
  List<Map<String, dynamic>> _allStaffBalances = [];
  bool _isLoadingStaffAssignment = false;
  String? _staffAssignmentError;
  int _staffAssignmentYear = DateTime.now().year;
  String _staffSearchQuery = '';

  LeaveProvider(this._authService) {
    _leaveService = LeaveService(_authService.dio);
    _employeeService = EmployeeService(_authService);
  }

  // --------------------------------------------------------------------------
  // GETTERS
  // --------------------------------------------------------------------------

  List<LeaveRequest> get myLeaves => _myLeaves;
  bool get isLoadingMyLeaves => _isLoadingMyLeaves;
  String? get myLeavesError => _myLeavesError;

  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  List<LeaveRequest> get pendingRequests => _pendingRequests;
  bool get isLoadingPending => _isLoadingPending;
  String? get pendingError => _pendingError;

  List<LeaveRequest> get adminHistory => _adminHistory;
  bool get isLoadingAdminHistory => _isLoadingAdminHistory;
  String? get adminHistoryError => _adminHistoryError;

  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  LeaveRequest? get selectedAdminLeave => _selectedAdminLeave;
  List<Map<String, dynamic>> get selectedEmployeeBalances => _selectedEmployeeBalances;
  bool get isLoadingEmployeeBalances => _isLoadingEmployeeBalances;

  List<Map<String, dynamic>> get myLeaveBalances => _myLeaveBalances;
  List<Map<String, dynamic>> get myLeavePolicies => _myLeavePolicies;
  bool get isLoadingBalances => _isLoadingBalances;
  String? get balancesError => _balancesError;

  List<Employee> get allEmployees => _allEmployees;
  List<Map<String, dynamic>> get allStaffBalances => _allStaffBalances;
  bool get isLoadingStaffAssignment => _isLoadingStaffAssignment;
  String? get staffAssignmentError => _staffAssignmentError;
  int get staffAssignmentYear => _staffAssignmentYear;
  String get staffSearchQuery => _staffSearchQuery;

  // Filtered leaves for employee by selected month & year
  List<LeaveRequest> get filteredMyLeaves {
    final monthStr = (_selectedMonth + 1).toString().padLeft(2, '0');
    final prefix = '$_selectedYear-$monthStr';
    return _myLeaves.where((leave) {
      final startIso = leave.startDate.toIso8601String();
      return startIso.startsWith(prefix);
    }).toList();
  }

  // Total approved days for current month/year filter
  int get totalApprovedDays {
    return filteredMyLeaves
        .where((l) => l.status == 'approved')
        .fold<int>(0, (sum, curr) => sum + curr.durationDays);
  }

  // Quota totals for employee
  int get totalQuota => _myLeaveBalances.fold<int>(0, (acc, b) {
        final allocated = num.tryParse(b['allocated']?.toString() ?? '0') ?? 0;
        final carried = num.tryParse(b['carried_forward']?.toString() ?? '0') ?? 0;
        return acc + allocated.toInt() + carried.toInt();
      });

  int get totalUsed => _myLeaveBalances.fold<int>(0, (acc, b) {
        final used = num.tryParse(b['used']?.toString() ?? '0') ?? 0;
        return acc + used.toInt();
      });

  int get totalAvailable => _myLeaveBalances.fold<int>(0, (acc, b) {
        final avail = num.tryParse(b['available']?.toString() ?? '0') ?? 0;
        return acc + avail.toInt();
      });

  int get usedPercentage => totalQuota > 0 ? ((totalUsed / totalQuota) * 100).round() : 0;

  // Filtered leaves for admin (search + status)
  List<LeaveRequest> get adminFilteredLeaves {
    final query = _searchQuery.trim().toLowerCase();
    final status = _statusFilter.toLowerCase();

    return _adminHistory.where((leaf) {
      final matchesSearch = query.isEmpty ||
          (leaf.userName ?? '').toLowerCase().contains(query) ||
          (leaf.userEmail ?? '').toLowerCase().contains(query);
      final matchesStatus = status == 'all' || leaf.status.toLowerCase() == status;
      final isUserActive = leaf.isActive;
      final isUserDeleted = leaf.isDeleted;
      return matchesSearch && matchesStatus && isUserActive && !isUserDeleted;
    }).toList();
  }

  // --------------------------------------------------------------------------
  // EMPLOYEE ACTIONS & FILTERS
  // --------------------------------------------------------------------------

  void setSelectedMonth(int month) {
    if (_selectedMonth != month) {
      _selectedMonth = month;
      notifyListeners();
    }
  }

  void setSelectedYear(int year) {
    if (_selectedYear != year) {
      _selectedYear = year;
      notifyListeners();
      // Refetch balances for year
      fetchMyLeaveBalancesAndPolicies(forceRefresh: true);
    }
  }

  Future<void> fetchMyLeaves({bool forceRefresh = false}) async {
    if (!forceRefresh && _myLeaves.isNotEmpty) return;

    _isLoadingMyLeaves = true;
    _myLeavesError = null;
    notifyListeners();

    try {
      final leaves = await _leaveService.getMyHistory();
      _myLeaves = leaves;
    } catch (e) {
      _myLeavesError = e.toString();
    } finally {
      _isLoadingMyLeaves = false;
      notifyListeners();
    }
  }

  Future<void> submitLeaveRequest(Map<String, dynamic> requestData) async {
    _isLoadingMyLeaves = true;
    notifyListeners();
    try {
      await _leaveService.submitLeaveRequest(requestData);
      await Future.wait([
        fetchMyLeaves(forceRefresh: true),
        fetchMyLeaveBalancesAndPolicies(forceRefresh: true),
      ]);
    } catch (e) {
      _myLeavesError = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoadingMyLeaves = false;
      notifyListeners();
    }
  }

  Future<void> withdrawRequest(int id) async {
    try {
      await _leaveService.withdrawRequest(id);
      _myLeaves.removeWhere((r) => r.id == id);
      if (_selectedAdminLeave?.id == id) {
        _selectedAdminLeave = null;
      }
      notifyListeners();
      // Also refresh balances as withdrawn pending might return quota if applicable
      fetchMyLeaveBalancesAndPolicies(forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchMyLeaveBalancesAndPolicies({bool forceRefresh = false}) async {
    if (!forceRefresh && _myLeaveBalances.isNotEmpty) return;

    _isLoadingBalances = true;
    _balancesError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _leaveService.getMyLeaveBalances(year: _selectedYear),
        _leaveService.getMyLeavePolicies(),
      ]);
      _myLeaveBalances = results[0];
      _myLeavePolicies = results[1];
    } catch (e) {
      _balancesError = e.toString();
    } finally {
      _isLoadingBalances = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // STAFF POLICY ASSIGNMENT (ADMIN)
  // --------------------------------------------------------------------------

  void setStaffAssignmentYear(int year) {
    if (_staffAssignmentYear == year) return;
    _staffAssignmentYear = year;
    notifyListeners();
    fetchStaffAssignmentData(year: year, forceRefresh: true);
  }

  void setStaffSearchQuery(String query) {
    _staffSearchQuery = query;
    notifyListeners();
  }

  Future<void> fetchStaffAssignmentData({int? year, bool forceRefresh = false}) async {
    final targetYear = year ?? _staffAssignmentYear;
    _isLoadingStaffAssignment = true;
    _staffAssignmentError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        if (forceRefresh || _allEmployees.isEmpty)
          _employeeService.getEmployees()
        else
          Future.value(_allEmployees),
        _leaveService.getAllEmployeesLeaveBalances(year: targetYear),
        if (forceRefresh || _myLeavePolicies.isEmpty)
          _leaveService.getMyLeavePolicies()
        else
          Future.value(_myLeavePolicies),
      ]);

      _allEmployees = results[0] as List<Employee>;
      _allStaffBalances = results[1] as List<Map<String, dynamic>>;
      _myLeavePolicies = results[2] as List<Map<String, dynamic>>;
    } catch (e) {
      debugPrint('Error fetching staff assignment data: $e');
      _staffAssignmentError = e.toString();
    } finally {
      _isLoadingStaffAssignment = false;
      notifyListeners();
    }
  }

  Future<bool> assignPolicyToStaff({
    required int policyId,
    required int userId,
    int? year,
  }) async {
    final targetYear = year ?? _staffAssignmentYear;
    try {
      final success = await _leaveService.assignPolicyToEmployees(
        policyId,
        userIds: [userId],
        year: targetYear,
      );
      if (success) {
        _allStaffBalances = await _leaveService.getAllEmployeesLeaveBalances(year: targetYear);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error in assignPolicyToStaff: $e');
      rethrow;
    }
  }

  Future<bool> unassignPolicyFromStaff({
    required int userId,
    required List<int> balanceIds,
    int? year,
  }) async {
    final targetYear = year ?? _staffAssignmentYear;
    try {
      final deleteResults = await Future.wait(
        balanceIds.map((id) => _leaveService.deleteLeaveBalance(id)),
      );
      final allSuccess = deleteResults.every((s) => s);
      _allStaffBalances = await _leaveService.getAllEmployeesLeaveBalances(year: targetYear);
      notifyListeners();
      return allSuccess;
    } catch (e) {
      debugPrint('Error in unassignPolicyFromStaff: $e');
      rethrow;
    }
  }

  Map<String, dynamic> getStaffClassification(int? policyId, {String? queryOverride}) {
    if (policyId == null) {
      return {
        'assigned': <Map<String, dynamic>>[],
        'available': _allEmployees,
      };
    }

    final query = (queryOverride ?? _staffSearchQuery).trim().toLowerCase();

    final policy = _myLeavePolicies.firstWhere(
      (p) => p['lp_id'] == policyId,
      orElse: () => <String, dynamic>{},
    );
    final rules = (policy['rules'] as List<dynamic>?) ?? [];
    final ruleIds = rules.map((r) => r['rule_id']).toSet();

    final Map<int, List<Map<String, dynamic>>> userBalanceMap = {};
    for (final bal in _allStaffBalances) {
      final uid = bal['user_id'];
      if (uid != null) {
        final userIdInt = int.tryParse(uid.toString()) ?? 0;
        userBalanceMap.putIfAbsent(userIdInt, () => []).add(bal);
      }
    }

    final List<Map<String, dynamic>> assigned = [];
    final List<Employee> available = [];

    for (final emp in _allEmployees) {
      final name = emp.userName.toLowerCase();
      final email = emp.email.toLowerCase();
      final desig = (emp.designation ?? '').toLowerCase();
      final dept = (emp.department ?? '').toLowerCase();

      if (query.isNotEmpty &&
          !name.contains(query) &&
          !email.contains(query) &&
          !desig.contains(query) &&
          !dept.contains(query)) {
        continue;
      }

      final empBalances = userBalanceMap[emp.userId] ?? [];
      final empPolicyBalances = empBalances.where((b) => ruleIds.contains(b['rule_id'])).toList();

      if (empPolicyBalances.isNotEmpty) {
        assigned.add({
          'employee': emp,
          'balances': empPolicyBalances,
        });
      } else {
        available.add(emp);
      }
    }

    return {
      'assigned': assigned,
      'available': available,
    };
  }

  // --------------------------------------------------------------------------
  // ADMIN ACTIONS & FILTERS
  // --------------------------------------------------------------------------

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void selectAdminLeave(LeaveRequest? leave) {
    _selectedAdminLeave = leave;
    notifyListeners();
    if (leave != null) {
      fetchSelectedEmployeeBalances(leave.userId);
    } else {
      _selectedEmployeeBalances = [];
      notifyListeners();
    }
  }

  Future<void> fetchPendingRequests({bool forceRefresh = false}) async {
    if (!forceRefresh && _pendingRequests.isNotEmpty) return;

    _isLoadingPending = true;
    _pendingError = null;
    notifyListeners();

    try {
      _pendingRequests = await _leaveService.getPendingRequests();
    } catch (e) {
      _pendingError = e.toString();
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  Future<void> fetchAdminHistory({
    int? userId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _adminHistory.isNotEmpty) return;

    _isLoadingAdminHistory = true;
    _adminHistoryError = null;
    notifyListeners();

    try {
      final history = await _leaveService.getAdminHistory(
        userId: userId,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );

      _adminHistory = history.where((l) => l.isActive && !l.isDeleted).toList();

      // If no item selected or selected item not in list, select first item
      if (_selectedAdminLeave == null && _adminHistory.isNotEmpty) {
        selectAdminLeave(_adminHistory.first);
      } else if (_selectedAdminLeave != null) {
        final existing = _adminHistory.firstWhere(
          (l) => l.id == _selectedAdminLeave!.id,
          orElse: () => _adminHistory.isNotEmpty ? _adminHistory.first : _selectedAdminLeave!,
        );
        selectAdminLeave(existing);
      }
    } catch (e) {
      _adminHistoryError = e.toString();
    } finally {
      _isLoadingAdminHistory = false;
      notifyListeners();
    }
  }

  Future<void> fetchSelectedEmployeeBalances(int userId) async {
    _isLoadingEmployeeBalances = true;
    notifyListeners();
    try {
      final balances = await _leaveService.getEmployeeLeaveBalance(userId, year: _selectedYear);
      _selectedEmployeeBalances = balances;
    } catch (e) {
      debugPrint('Error fetching employee balance for user $userId: $e');
      _selectedEmployeeBalances = [];
    } finally {
      _isLoadingEmployeeBalances = false;
      notifyListeners();
    }
  }

  Future<void> reviewRequest(
    int id, {
    required String status,
    String? comment,
    String? payType,
    int? payPercentage,
  }) async {
    try {
      // Capitalize status for backend
      final formattedStatus = status.isNotEmpty
          ? '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}'
          : status;

      await _leaveService.updateRequestStatus(
        id,
        formattedStatus,
        comment: comment,
        payType: payType,
        payPercentage: payPercentage,
      );

      // Update in adminHistory
      final lowerStatus = formattedStatus.toLowerCase();
      final index = _adminHistory.indexWhere((r) => r.id == id);
      if (index != -1) {
        final updated = _adminHistory[index].copyWith(
          status: lowerStatus,
          adminComment: comment,
          payType: payType,
          payPercentage: payPercentage,
          reviewedAt: DateTime.now(),
        );
        _adminHistory[index] = updated;

        if (_selectedAdminLeave?.id == id) {
          _selectedAdminLeave = updated;
        }
      }

      // Also update in pendingRequests if present
      _pendingRequests.removeWhere((r) => r.id == id);

      // Also update in myLeaves if present
      final myIndex = _myLeaves.indexWhere((r) => r.id == id);
      if (myIndex != -1) {
        _myLeaves[myIndex] = _myLeaves[myIndex].copyWith(
          status: lowerStatus,
          adminComment: comment,
          payType: payType,
          payPercentage: payPercentage,
          reviewedAt: DateTime.now(),
        );
      }

      notifyListeners();

      // Refresh balances for the employee
      if (_selectedAdminLeave != null) {
        fetchSelectedEmployeeBalances(_selectedAdminLeave!.userId);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> approveRequest(int id, {String? comment, String? payType = 'Paid', int? payPercentage = 100}) async {
    return reviewRequest(id, status: 'Approved', comment: comment, payType: payType, payPercentage: payPercentage);
  }

  Future<void> rejectRequest(int id, {String? comment, String? payType = 'Unpaid'}) async {
    return reviewRequest(id, status: 'Rejected', comment: comment, payType: payType);
  }

  // --------------------------------------------------------------------------
  // UNIVERSAL INITIALIZER
  // --------------------------------------------------------------------------

  Future<void> fetchLeaves({bool forceRefresh = false}) async {
    final isAdmin = _authService.user?.isAdmin ?? false;
    if (isAdmin) {
      await fetchAdminHistory(forceRefresh: forceRefresh);
    } else {
      await Future.wait([
        fetchMyLeaves(forceRefresh: forceRefresh),
        fetchMyLeaveBalancesAndPolicies(forceRefresh: forceRefresh),
      ]);
    }
  }
}
