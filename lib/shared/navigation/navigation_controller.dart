import 'package:flutter/material.dart';

enum PageType {
  dashboard,
  employees,
  labourManagement,
  myAttendance,
  liveAttendance,
  reports,
  payroll,
  dailyActivity,
  policies, // Merges Shift Management, Geo-Fencing, and Salary Packages
  leavesAndHolidays, // Merges Holidays and Leaves
  feedback, // Bugs & Feedback
  collaboration, // Chat & Collaborate
  profile, // My Profile
  // Legacy aliases for backward-compatibility during migration
  policyEngine,
  geoFencing,
}

// Map PageType to Title
extension PageTypeExtension on PageType {
  String get title {
    switch (this) {
      case PageType.dashboard:
        return 'Dashboard';
      case PageType.employees:
        return 'Employees';
      case PageType.labourManagement:
        return 'Labour Management';
      case PageType.myAttendance:
        return 'Attendance';
      case PageType.liveAttendance:
        return 'Live Attendance';
      case PageType.reports:
        return 'Reports';
      case PageType.payroll:
        return 'Payroll';
      case PageType.dailyActivity:
        return 'Daily Activity Report';
      case PageType.policies:
        return 'Policies';
      case PageType.leavesAndHolidays:
        return 'Holidays & Leaves';
      case PageType.feedback:
        return 'Bugs & Feedback';
      case PageType.collaboration:
        return 'Chat & Collaborate';
      case PageType.profile:
        return 'My Profile';
      case PageType.policyEngine:
        return 'Shift Management';
      case PageType.geoFencing:
        return 'Geo-Fencing';
    }
  }

  String getTitle(bool isEmployee) {
    if (this == PageType.reports && isEmployee) {
      return 'My Reports';
    }
    return title;
  }

  IconData get icon {
    switch (this) {
      case PageType.dashboard:
        return Icons.dashboard_outlined;
      case PageType.employees:
        return Icons.people_outline;
      case PageType.labourManagement:
        return Icons.construction_outlined;
      case PageType.myAttendance:
        return Icons.calendar_today_outlined;
      case PageType.liveAttendance:
        return Icons.access_time_rounded;
      case PageType.reports:
        return Icons.trending_up_rounded;
      case PageType.payroll:
        return Icons.payments_outlined;
      case PageType.dailyActivity:
        return Icons.assignment_outlined;
      case PageType.policies:
        return Icons.shield_outlined;
      case PageType.leavesAndHolidays:
        return Icons.event_note_outlined;
      case PageType.feedback:
        return Icons.bug_report_outlined;
      case PageType.collaboration:
        return Icons.forum_outlined;
      case PageType.profile:
        return Icons.person_outline;
      case PageType.policyEngine:
        return Icons.settings_suggest_outlined;
      case PageType.geoFencing:
        return Icons.location_on_outlined;
    }
  }
}

// Global Singleton for Navigation State
final navigationNotifier = ValueNotifier<PageType>(PageType.dashboard);

// Global Singleton for Policies Tab State ('shifts', 'geofencing', 'salary_packages', 'leave_policies')
final policiesTabNotifier = ValueNotifier<String>('shifts');

void navigateTo(PageType page) {
  if (page == PageType.policyEngine) {
    policiesTabNotifier.value = 'shifts';
    navigationNotifier.value = PageType.policies;
    return;
  }
  if (page == PageType.geoFencing) {
    policiesTabNotifier.value = 'geofencing';
    navigationNotifier.value = PageType.policies;
    return;
  }
  navigationNotifier.value = page;
}

void navigateToPolicies({String tab = 'shifts'}) {
  if (tab == 'leave_policies' || tab == 'leaves' || tab == 'leave' || tab == 'policies') {
    policiesTabNotifier.value = 'leave_policies';
  } else {
    policiesTabNotifier.value = tab;
  }
  navigationNotifier.value = PageType.policies;
}

// Global Singleton for Holidays & Leave Tab State ('holidays', 'leaves', 'policies')
final holidaysAndLeaveTabNotifier = ValueNotifier<String>('holidays');

void navigateToHolidaysAndLeave({String tab = 'holidays'}) {
  holidaysAndLeaveTabNotifier.value = tab;
  navigationNotifier.value = PageType.leavesAndHolidays;
}

// commit-marker: 2026-02-27T18:00:00+05:30

// [mod:2026-02-27T17:30:00+05:30]

// [upd:2026-04-27T14:00:00+05:30]

// [upd:2026-05-13T14:00:00+05:30]

// [rev:2026-08-24T18:00:00+05:30]
