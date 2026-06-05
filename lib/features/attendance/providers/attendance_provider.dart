import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/models/shift_model.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

class AttendanceProvider with ChangeNotifier {
  final AuthService _authService;
  late final AttendanceService _attendanceService;

  // Cache: "userId_YYYY-MM-DD" -> List<AttendanceRecord>
  final Map<String, List<AttendanceRecord>> _recordsCache = {};

  // Range Cache: "userId_from_to" -> List<AttendanceRecord>
  final Map<String, List<AttendanceRecord>> _rangeCache = {};
  
  // Current State
  List<AttendanceRecord> _currentRecords = [];
  bool _isLoading = false;
  String? _error;

  // Shift Policy (cached)
  Shift? _shiftPolicy;
  Shift? get shiftPolicy => _shiftPolicy;

  // Missed Punch State
  // Non-null when the last check found a session with no time-out on a past day
  DateTime? _missedPunchDate;
  DateTime? get missedPunchDate => _missedPunchDate;

  // How many days the employee has left to submit a correction for the missed punch
  int get correctionDeadlineDays => _shiftPolicy?.correctionDeadline ?? 2;

  // Returns true if the missed punch correction window has NOT expired
  bool get canSubmitCorrection {
    if (_missedPunchDate == null) return false;
    final deadline = _missedPunchDate!.add(Duration(days: correctionDeadlineDays));
    return DateTime.now().isBefore(deadline);
  }

  AttendanceProvider(this._authService) {
    _attendanceService = AttendanceService(_authService.dio);
    _lastUserId = _authService.user?.employeeId;
    _authService.addListener(_onAuthChanged);
    // Kick off policy + missed punch check on construction
    _initShiftPolicyAndMissedPunch();
  }

  void _onAuthChanged() {
    final currentUserId = _authService.user?.employeeId;
    if (currentUserId != _lastUserId) {
      debugPrint('AttendanceProvider: User changed from $_lastUserId to $currentUserId. Clearing cache.');
      clearCache();
      _lastUserId = currentUserId;
      _initShiftPolicyAndMissedPunch();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  String? _lastUserId;

  // Getters
  List<AttendanceRecord> get records => _currentRecords;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Shift Policy ──────────────────────────────────────────────────────────

  Future<void> _initShiftPolicyAndMissedPunch() async {
    await _fetchShiftPolicy();
    await checkMissedPunch();
  }

  Future<void> _fetchShiftPolicy() async {
    try {
      _shiftPolicy = await _attendanceService.getMyShiftPolicy();
      notifyListeners();
    } catch (e) {
      debugPrint('AttendanceProvider: Could not fetch shift policy: $e');
    }
  }

  // ── Missed Punch Detection ────────────────────────────────────────────────

  /// Checks yesterday's (and up to correctionDeadlineDays back) attendance records
  /// for sessions that have a time-in but no time-out. Surfaces the most recent one.
  Future<void> checkMissedPunch() async {
    final deadline = correctionDeadlineDays;
    final today = DateTime.now();
    DateTime? found;

    for (int i = 1; i <= deadline; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final checkStr = DateFormat('yyyy-MM-dd').format(checkDate);
      final userId = _authService.user?.employeeId ?? 'anon';
      final cacheKey = '${userId}_$checkStr';

      List<AttendanceRecord> dayRecords;
      if (_recordsCache.containsKey(cacheKey)) {
        dayRecords = _recordsCache[cacheKey]!;
      } else {
        try {
          dayRecords = await _attendanceService.getMyRecords(
            fromDate: checkStr,
            toDate: checkStr,
            userId: userId,
          );
          _recordsCache[cacheKey] = dayRecords;
        } catch (_) {
          dayRecords = [];
        }
      }

      // A missed punch = session that was clocked in but never clocked out
      final hasMissedPunch = dayRecords.any((r) => r.timeIn != null && r.timeOut == null);
      if (hasMissedPunch) {
        found = checkDate;
        break; // Surface the most recent (closest to today) missed day
      }
    }

    if (_missedPunchDate != found) {
      _missedPunchDate = found;
      notifyListeners();
    }
  }

  /// Call this after a correction request is submitted to hide the banner
  void clearMissedPunch() {
    _missedPunchDate = null;
    notifyListeners();
  }

  // ── Records ───────────────────────────────────────────────────────────────

  // Fetch Records for a specific date
  Future<void> fetchRecords(DateTime date, {bool forceRefresh = false}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final userId = _authService.user?.employeeId ?? 'anon';
    final cacheKey = '${userId}_$dateStr';
    _error = null;

    // 1. Return from Cache if available and not forcing refresh
    if (!forceRefresh && _recordsCache.containsKey(cacheKey)) {
      _currentRecords = _recordsCache[cacheKey]!;
      notifyListeners();
      return;
    }

    // 2. Fetch from API
    try {
      _isLoading = true;
      notifyListeners();

      final uid = _authService.user?.employeeId;
      final data = await _attendanceService.getMyRecords(
        fromDate: dateStr, 
        toDate: dateStr,
        userId: uid,
      );
      
      // Update Cache
      _recordsCache[cacheKey] = data;
      _currentRecords = data;
      
    } catch (e) {
      _error = e.toString();
      _currentRecords = []; 
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch Records for a range
  Future<List<AttendanceRecord>> fetchRange(DateTime from, DateTime to, {bool forceRefresh = false}) async {
    final fromStr = DateFormat('yyyy-MM-dd').format(from);
    final toStr = DateFormat('yyyy-MM-dd').format(to);
    final userId = _authService.user?.employeeId ?? 'anon';
    final cacheKey = '${userId}_${fromStr}_$toStr';
    
    // 1. Return from Cache
    if (!forceRefresh && _rangeCache.containsKey(cacheKey)) {
      return _rangeCache[cacheKey]!;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final data = await _attendanceService.getMyRecords(
        fromDate: fromStr, 
        toDate: toStr,
        userId: userId,
      );
      
      // 2. Update Cache
      _rangeCache[cacheKey] = data;
      return data;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Invalidate cache for today (e.g. after punching in/out)
  void invalidateCache(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final userId = _authService.user?.employeeId ?? 'anon';
    _recordsCache.remove('${userId}_$dateStr');
    
    // Also clear range cache to be safe as it might include this date
    _rangeCache.clear();
    
    // Re-check missed punch after an action (e.g. user just timed out)
    checkMissedPunch();
  }

  // Pending correction requests count
  int _pendingCorrectionCount = 0;
  int get pendingCorrectionCount => _pendingCorrectionCount;

  Future<void> fetchPendingCorrectionCount({String? userId}) async {
    try {
      final list = await _attendanceService.getCorrectionRequests(
        status: 'pending',
        userId: userId,
      );
      _pendingCorrectionCount = list.length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pending correction count: $e');
    }
  }

  void updatePendingCorrectionCount(int count) {
    _pendingCorrectionCount = count;
    notifyListeners();
  }

  // Clear all caches (e.g. on logout)
  void clearCache() {
    _recordsCache.clear();
    _rangeCache.clear();
    _currentRecords = [];
    _pendingCorrectionCount = 0;
    _missedPunchDate = null;
    _shiftPolicy = null;
    notifyListeners();
  }
}
