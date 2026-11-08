class DashboardData {
  final DashboardStats stats;
  final DashboardTrends trends;
  final List<ChartData> chartData;
  final List<ActivityLog> activities;

  DashboardData({
    required this.stats,
    required this.trends,
    required this.chartData,
    required this.activities,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      stats: DashboardStats.fromJson(json['stats'] ?? {}),
      trends: DashboardTrends.fromJson(json['trends'] ?? {}),
      chartData: (json['chartData'] as List? ?? [])
          .map((e) => ChartData.fromJson(e))
          .toList(),
      activities: (json['activities'] as List? ?? [])
          .map((e) => ActivityLog.fromJson(e))
          .toList(),
    );
  }
}

class DashboardStats {
  final int presentToday;
  final int totalEmployees;
  final int absentToday;
  final int lateCheckins;
  final double avgHours;

  DashboardStats({
    required this.presentToday,
    required this.totalEmployees,
    required this.absentToday,
    required this.lateCheckins,
    this.avgHours = 0.0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      presentToday: json['presentToday'] ?? 0,
      totalEmployees: json['totalEmployees'] ?? 0,
      absentToday: json['absentToday'] ?? 0,
      lateCheckins: json['lateCheckins'] ?? 0,
      avgHours: (json['avgHours'] is num) ? (json['avgHours'] as num).toDouble() : 0.0,
    );
  }
}

class DashboardTrends {
  final String present;
  final String absent;
  final String late;

  DashboardTrends({
    required this.present,
    required this.absent,
    required this.late,
  });

  factory DashboardTrends.fromJson(Map<String, dynamic> json) {
    return DashboardTrends(
      present: json['present'] ?? '0%',
      absent: json['absent'] ?? '0%',
      late: json['late'] ?? '0%',
    );
  }
}

class ChartData {
  final String name; // Label (e.g., "Mon", "Jan")
  final int present;
  final int absent;
  final int late;

  ChartData({
    required this.name,
    required this.present,
    required this.absent,
    required this.late,
  });

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      name: json['name'] ?? '',
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      late: json['late'] ?? 0,
    );
  }
}

class ActivityLog {
  final String id;
  final String user;
  final String role;
  final String action;
  final String time;
  final String type; // 'check-in', 'check-out', etc.

  ActivityLog({
    required this.id,
    required this.user,
    required this.role,
    required this.action,
    required this.time,
    this.type = 'info',
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id']?.toString() ?? '',
      user: json['user'] ?? 'Unknown',
      role: json['role'] ?? '',
      action: json['action'] ?? '',
      time: json['time'] ?? '',
      type: json['type'] ?? 'info',
    );
  }
}
