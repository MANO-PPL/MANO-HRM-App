import 'package:flutter/material.dart';

enum PageType {
  dashboard,
  employees,
  myAttendance,
  liveAttendance,
  dailyActivity, // ADDED
  leavesAndHolidays,    // RENAMED from leaves, MERGED with holidays
  reports,

  policyEngine,
  geoFencing,
  profile,
  feedback,  // ADDED - Moved to end
}

// Map PageType to Title
extension PageTypeExtension on PageType {
  String get title {
    switch (this) {
      case PageType.dashboard: return 'Dashboard';
      case PageType.employees: return 'Employees';
      case PageType.myAttendance: return 'Attendance';
      case PageType.liveAttendance: return 'Live Attendance';
        case PageType.dailyActivity: return 'Daily Activity';
      case PageType.leavesAndHolidays: return 'Holidays & Leave'; // UPDATED
      case PageType.reports: return 'Reports & Exports';

      case PageType.policyEngine: return 'Shift Management';
      case PageType.geoFencing: return 'Geo-Fencing';
      case PageType.feedback: return 'Feedback & Support'; // ADDED
      case PageType.profile: return 'My Profile';
    }
  }

  IconData get icon {
    switch (this) {
      case PageType.dashboard: return Icons.dashboard_outlined;
      case PageType.employees: return Icons.people_outline;
      case PageType.myAttendance: return Icons.calendar_today_outlined;
      case PageType.liveAttendance: return Icons.access_time;
        case PageType.dailyActivity: return Icons.today;
      case PageType.leavesAndHolidays: return Icons.date_range_outlined; // UPDATED
      case PageType.reports: return Icons.show_chart;

      case PageType.policyEngine: return Icons.settings_suggest_outlined;
      case PageType.geoFencing: return Icons.location_on_outlined;
      case PageType.feedback: return Icons.feedback_outlined; // ADDED
      case PageType.profile: return Icons.person_outline;
    }
  }
}

// Global Singleton for Navigation State
final navigationNotifier = ValueNotifier<PageType>(PageType.dashboard);

void navigateTo(PageType page) {
  navigationNotifier.value = page;
}
