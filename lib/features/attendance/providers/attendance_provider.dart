import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/auth_service.dart';
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

  AttendanceProvider(this._authService) {
    _attendanceService = AttendanceService(_authService.dio);
    _lastUserId = _authService.user?.employeeId;
    _authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final currentUserId = _authService.user?.employeeId;
    if (currentUserId != _lastUserId) {
      debugPrint('AttendanceProvider: User changed from $_lastUserId to $currentUserId. Clearing cache.');
      clearCache();
      _lastUserId = currentUserId;
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

  // Fetch Records for a specific date
  Future<void> fetchRecords(DateTime date, {bool forceRefresh = false}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final userId = _authService.user?.employeeId ?? 'anon';
    final cacheKey = "${userId}_$dateStr";
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

      final userId = _authService.user?.employeeId;
      final data = await _attendanceService.getMyRecords(
        fromDate: dateStr, 
        toDate: dateStr,
        userId: userId,
      );
      
      // Update Cache
      _recordsCache[cacheKey] = data;
      _currentRecords = data;
      
    } catch (e) {
      _error = e.toString();
      // If error, maybe clear current records or keep old? 
      // Keeping empty to indicate failure/no data found state is safer for now.
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
    final cacheKey = "${userId}_${fromStr}_$toStr";
    
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
    _recordsCache.remove("${userId}_$dateStr");
    
    // Also clear range cache to be safe as it might include this date
    _rangeCache.clear();
    
    // Note: We don't automatically refetch here, usually the UI will trigger refetch 
    // or we can call fetchRecords(date, forceRefresh: true) immediately.
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
    notifyListeners();
  }
}
