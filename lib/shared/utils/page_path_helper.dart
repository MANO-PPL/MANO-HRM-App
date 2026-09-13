import 'package:flutter_application/shared/navigation/navigation_controller.dart';

/// Helper to map App [PageType] to backend route paths and provide suggested context-aware questions.
class PagePathHelper {
  /// Maps a [PageType] to the exact route path expected by the backend chatbot API.
  static String getBackendPath(PageType pageType) {
    switch (pageType) {
      case PageType.dashboard:
        return '/dashboard';
      case PageType.employees:
        return '/employees';
      case PageType.labourManagement:
        return '/labour-management';
      case PageType.myAttendance:
        return '/attendance';
      case PageType.liveAttendance:
        return '/attendance-monitoring';
      case PageType.reports:
        return '/reports';
      case PageType.payroll:
        return '/payroll';
      case PageType.dailyActivity:
        return '/daily-activity';
      case PageType.policies:
        return '/policies';
      case PageType.leavesAndHolidays:
        return '/holidays';
      case PageType.feedback:
        return '/feedback';
      case PageType.collaboration:
        return '/collaboration';
      case PageType.profile:
        return '/profile';
      case PageType.policyEngine:
        return '/policies?tab=shifts';
      case PageType.geoFencing:
        return '/policies?tab=geofencing';
    }
  }

  /// Provides context-aware suggested questions for a given [PageType].
  static List<String> getSuggestedQuestions(PageType pageType) {
    switch (pageType) {
      case PageType.dashboard:
        return [
          'How do I check in or out?',
          'What stats are on my dashboard?',
          'How do I view recent activity logs?',
        ];
      case PageType.employees:
        return [
          'How do I add a new employee?',
          'How do I bulk import staff with Excel?',
          'How do I search the staff directory?',
        ];
      case PageType.myAttendance:
        return [
          'How do I request a correction?',
          'What is facial camera verification?',
          'Where do I see my check-in history?',
        ];
      case PageType.liveAttendance:
        return [
          'What is the Live Command Center?',
          'How do I view employee GPS locations?',
          'How does real-time monitoring work?',
        ];
      case PageType.dailyActivity:
        return [
          'What is a Daily Activity Report?',
          'How do I log a daily task or meeting?',
          'How does AI analyze vague DAR entries?',
        ];
      case PageType.leavesAndHolidays:
        return [
          'How do I apply for casual/sick leave?',
          'Where is the holiday calendar list?',
          'How do I check my remaining leave balances?',
        ];
      case PageType.payroll:
        return [
          'How is basic salary and HRA calculated?',
          'How do I process pay period runs?',
          'How do I view or download PDF payslips?',
        ];
      case PageType.reports:
        return [
          'What report formats are supported?',
          'How do I export lateness or overtime?',
          'Can I generate a payroll matrix report?',
        ];
      case PageType.labourManagement:
        return [
          'How do I register a site worker?',
          'How do I mark daily site check-in?',
          'How are daily wages and payouts calculated?',
        ];
      case PageType.policies:
      case PageType.policyEngine:
      case PageType.geoFencing:
        return [
          'How do I create or edit a work shift?',
          'How do I configure site geo-fencing radius?',
          'How do salary package groups and overtime rates work?',
        ];
      case PageType.profile:
        return [
          'How do I change my profile avatar?',
          'Where do I see my assigned branch?',
          'How do I change my account password?',
        ];
      case PageType.feedback:
        return [
          'How do I report a bug or issue?',
          'Where do I submit feature suggestions?',
        ];
      case PageType.collaboration:
        return [
          'How do I message team members?',
          'Can I create project group channels?',
          'How do channel mentions and attachments work?',
        ];
    }
  }
}
