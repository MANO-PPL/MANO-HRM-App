import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Base URL
  static const String baseUrl = 'https://attendance.mano.co.in/api';
  
  // Auth Endpoints
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String profile = '/profile'; // POST to update avatar
  static const String profileMe = '/profile/me';
  static const String captchaGenerate = '/auth/captcha/generate';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';


  // Admin - Users
  static const String users = '/admin/users';
  static const String user = '/admin/user'; // Append /:id for GET/PUT/DELETE
  static const String userBulkUpload = '/admin/users/bulk';
  static const String userBulkValidate = '/admin/users/bulk-validate';
  static const String userBulkCreate = '/admin/users/bulk-json';

  // Admin - Departments & Designations
  static const String departments = '/admin/departments';
  static const String designations = '/admin/designations';
  // Note: /admin/shifts exists in Postman under Admin but also under Policies. 
  // Using /admin/shifts for dropdowns if different? Postman shows:
  // Admin -> Get Shifts: /admin/shifts
  // Policies -> Get All Shifts: /policies/shifts
  // They might be the same or different. Let's keep both for now or check if one is enough.
  // The Admin one seems to be for dropdowns?
  static const String adminShifts = '/admin/shifts';

  // Attendance
  static const String attendanceTimeIn = '/attendance/timein';
  static const String attendanceTimeOut = '/attendance/timeout';
  static const String attendanceRecords = '/attendance/records';
  static const String adminAttendanceRecords = '/attendance/records/admin';
  static const String attendanceCorrectionRequest = '/attendance/correction-request'; // GET /:id, POST
  static const String attendanceCorrectionRequests = '/attendance/correction-requests'; // GET All
  static const String attendanceRecordExport = '/attendance/records/export';
  static const String attendanceCorrectRequestUpdate = '/attendance/correct-request'; // PATCH /:id
  
  // Attendance Simulation (Dev Only)
  static const String simulateTimeIn = '/attendance/simulate/timein';
  static const String simulateTimeOut = '/attendance/simulate/timeout';

  // Work Locations (GeoFencing)
  static const String locations = '/locations'; // GET, POST, PUT /:id, DELETE /:id
  static const String locationAssignments = '/locations/assignments';
  
  // Employee
  static const String employeeLocations = '/employee/locations';

  // Holidays
  static const String holidays = '/holiday'; // GET, POST (Single/Bulk), PUT /:id, DELETE (Bulk)

  // Policies & Shifts
  static const String policyConfig = '/policies/config';
  static const String policyShifts = '/policies/shifts'; // GET, POST, PUT /:id, DELETE /:id
  static const String policyAutomation = '/policies/automation'; // GET, POST
  static const String myShift = '/employee/my-shift'; // GET - employee's assigned shift policy

  // Leave Management
  static const String leavesMyHistory = '/leaves/my-history';
  static const String leavesRequest = '/leaves/request'; // POST, DELETE /:id
  static const String leavesAdminPending = '/leaves/admin/pending';
  static const String leavesAdminHistory = '/leaves/admin/history';
  static const String leavesAdminStatus = '/leaves/admin/status'; // PUT /:id

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationMarkRead = '/notifications/:id/read'; // PUT
  static const String notificationsReadAll = '/notifications/read-all'; // PUT
  static const String notificationRegisterFCM = '/notifications/register-token';
  static const String notificationUnregisterFCM = '/notifications/unregister-token';

  // Feedback & Bug Reports
  static const String feedback = '/feedback'; // POST, GET (Admin)
  static const String feedbackStatus = '/feedback/:id/status'; // PATCH

  // Admin - Reports & Dashboard
  static const String dashboardStats = '/admin/dashboard-stats';
  static const String reportsPreview = '/admin/reports/preview';
  static const String reportsDownload = '/admin/reports/download';

  // DAR (Daily Activity Report)
  static const String darEventsList = '/dar/events/list';
  static const String darActivitiesList = '/dar/activities/list';
  static const String darActivitiesCreate = '/dar/activities/create';
  static const String darActivitiesUpdate = '/dar/activities/update'; // append /:id
  static const String darActivitiesDelete = '/dar/activities/delete'; // append /:id
  static const String darEventsCreate = '/dar/events/create';
  static const String darEventsUpdate = '/dar/events/update'; // append /:id
  static const String darEventsDelete = '/dar/events/delete'; // append /:id
  static const String darSettingsList = '/dar/settings/list';
  static const String darRequestsCreate = '/dar/requests/create';

  // Chatbot
  static const String chatbotAskInternal = '/website-chatbot/ask-internal';

  // Keys
  static String get recaptchaSiteKey => dotenv.env['RECAPTCHA_SITE_KEY'] ?? '';
}
