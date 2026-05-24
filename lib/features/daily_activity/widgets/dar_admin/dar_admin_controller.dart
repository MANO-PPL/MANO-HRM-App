import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../employees/services/employee_service.dart';
import '../../../employees/models/employee_model.dart';

class DarAdminController extends ChangeNotifier {
  final AuthService auth;

  DarAdminController(this.auth) {
    fetchAll();
  }

  // ── Date filter ──────────────────────────────────────────────────────────
  bool isRange = false;
  DateTime singleDate = DateTime.now();
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  // ── Employee filter ───────────────────────────────────────────────────────
  String searchQuery = '';
  String? selectedDepartment;

  // ── Data ─────────────────────────────────────────────────────────────────
  List<Employee> employees = [];
  List<String> departments = [];
  bool isLoading = false;
  List<dynamic> allActivities = [];
  List<dynamic> allEvents = [];
  String? errorMessage;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> fetchAll() async {
    isLoading = employees.isEmpty;
    _notify();

    try {
      if (employees.isEmpty) {
        final empService = EmployeeService(auth);
        final list = await empService.getEmployees();
        employees = list.where((e) => !e.isDeleted).toList();
        departments = employees
            .map((e) => e.department)
            .whereType<String>()
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }

      final startStr =
          DateFormat('yyyy-MM-dd').format(isRange ? startDate : singleDate);
      final endStr =
          DateFormat('yyyy-MM-dd').format(isRange ? endDate : singleDate);

      final results = await Future.wait([
        auth.dio.get('/dar/activities/admin/all', queryParameters: {
          'startDate': startStr,
          'endDate': endStr,
        }),
        auth.dio.get('/dar/events/admin/all', queryParameters: {
          'date_from': startStr,
          'date_to': endStr,
        }),
      ]);

      allActivities =
          results[0].statusCode == 200 && results[0].data != null
              ? (results[0].data['data'] as List? ?? [])
              : [];
      allEvents =
          results[1].statusCode == 200 && results[1].data != null
              ? (results[1].data['data'] as List? ?? [])
              : [];
      errorMessage = null;
    } catch (e) {
      debugPrint('DarAdminController.fetchAll error: $e');
      errorMessage = 'Failed to load data';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  List<Employee> get filteredEmployees {
    final list = employees.where((emp) {
      final q = searchQuery.toLowerCase();
      final matchSearch = emp.userName.toLowerCase().contains(q) ||
          (emp.designation?.toLowerCase().contains(q) ?? false);
      final matchDept =
          selectedDepartment == null || emp.department == selectedDepartment;
      return matchSearch && matchDept;
    }).toList();
    list.sort((a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));
    return list;
  }

  Map<String, int> getStats(int userId) => {
        'tasks': allActivities
            .where((a) => a['user_id'] == userId)
            .length,
        'meetings': allEvents.where((e) => e['user_id'] == userId).length,
      };

  Map<String, List<dynamic>> getTimeline(Employee employee) {
    final acts = allActivities
        .where((a) => a['user_id'] == employee.userId)
        .map((a) => <String, dynamic>{
              'date': a['activity_date'] != null
                  ? (a['activity_date'] as String).split('T')[0]
                  : '',
              'startTime': a['start_time'] ?? '',
              'endTime': a['end_time'] ?? '',
              'type': 'task',
              'category': a['activity_type'] ?? 'General',
              'title': a['title'] ?? 'Work Task',
              'description': a['description'] ?? '',
            })
        .toList();

    final evts = allEvents
        .where((e) => e['user_id'] == employee.userId)
        .map((e) => <String, dynamic>{
              'date': e['event_date'] != null
                  ? (e['event_date'] as String).split('T')[0]
                  : '',
              'startTime': e['start_time'] ?? '',
              'endTime': e['end_time'] ?? '',
              'type': 'meeting',
              'category': 'Meeting',
              'title': e['title'] ?? 'Meeting Sync',
              'description': e['location'] != null
                  ? 'Location: ${e['location']}'
                  : 'Online Meeting',
            })
        .toList();

    final combined = [...acts, ...evts]
      ..sort((a, b) {
        final dc = (a['date'] as String).compareTo(b['date'] as String);
        return dc != 0
            ? dc
            : (a['startTime'] as String)
                .compareTo(b['startTime'] as String);
      });

    final Map<String, List<dynamic>> grouped = {};
    for (final item in combined) {
      grouped.putIfAbsent(item['date'] as String, () => []).add(item);
    }
    return grouped;
  }

  // ── Setters ───────────────────────────────────────────────────────────────
  void setSearchQuery(String val) {
    searchQuery = val;
    _notify();
  }

  void setDepartment(String? val) {
    selectedDepartment = val;
    _notify();
  }

  void toggleRange(bool val) {
    isRange = val;
    fetchAll();
  }

  void setSingleDate(DateTime d) {
    singleDate = d;
    fetchAll();
  }

  void setStartDate(DateTime d) {
    startDate = d;
    fetchAll();
  }

  void setEndDate(DateTime d) {
    endDate = d;
    fetchAll();
  }

  // ── Formatters ────────────────────────────────────────────────────────────
  String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        final ampm = h >= 12 ? 'PM' : 'AM';
        final dh = h % 12 == 0 ? 12 : h % 12;
        return '${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }
    }
    return timeStr;
  }

  String formatDate(String dateStr) {
    try {
      return DateFormat('EEE, MMM d, yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  Map<String, dynamic> categoryTheme(String category, bool isDark) {
    final cat = category.toLowerCase();
    if (cat.contains('dev') || cat.contains('code')) {
      return {
        'color': Colors.blue,
        'bg': isDark
            ? Colors.blue.withValues(alpha: 0.15)
            : const Color(0xFFEFF6FF),
        'text': isDark ? Colors.blue[300]! : Colors.blue[700]!,
      };
    }
    if (cat.contains('design') || cat.contains('creative')) {
      return {
        'color': Colors.purple,
        'bg': isDark
            ? Colors.purple.withValues(alpha: 0.15)
            : const Color(0xFFFAF5FF),
        'text': isDark ? Colors.purple[300]! : Colors.purple[700]!,
      };
    }
    if (cat.contains('meet') || cat.contains('sync')) {
      return {
        'color': Colors.teal,
        'bg': isDark
            ? Colors.teal.withValues(alpha: 0.15)
            : const Color(0xFFECFDF5),
        'text': isDark ? Colors.teal[300]! : Colors.teal[700]!,
      };
    }
    if (cat.contains('break') ||
        cat.contains('lunch') ||
        cat.contains('rest')) {
      return {
        'color': Colors.amber,
        'bg': isDark
            ? Colors.amber.withValues(alpha: 0.15)
            : const Color(0xFFFFFBEB),
        'text': isDark ? Colors.amber[300]! : Colors.amber[700]!,
      };
    }
    return {
      'color': Colors.grey,
      'bg': isDark
          ? Colors.grey.withValues(alpha: 0.15)
          : const Color(0xFFF8FAFC),
      'text': isDark ? Colors.grey[300]! : Colors.grey[700]!,
    };
  }
}
