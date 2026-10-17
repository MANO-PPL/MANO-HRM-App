/// Authentication and Authorization error code constants.
/// Mirrors backend `AUTH_ERROR_CODES` from `backend/src/modules/auth/authErrorCodes.js`.
abstract class AuthErrorCodes {
  // Refresh Token & Session Lifecycle
  static const String invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const String noRefreshToken = 'NO_REFRESH_TOKEN';
  static const String sessionRevoked = 'SESSION_REVOKED';
  static const String sessionExpired = 'SESSION_EXPIRED';
  static const String sessionNotFound = 'SESSION_NOT_FOUND';

  // Access Token & JWT Validation
  static const String tokenInvalid = 'TOKEN_INVALID';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String noToken = 'NO_TOKEN';
  static const String invalidUser = 'INVALID_USER';

  // User Credentials & Account Status
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String accountInactive = 'ACCOUNT_INACTIVE';
  static const String accountDeleted = 'ACCOUNT_DELETED';
  static const String adminInactive = 'ADMIN_INACTIVE';

  // Organization Status
  static const String orgDeleted = 'ORG_DELETED';
  static const String orgInactive = 'ORG_INACTIVE';

  // Password Management & OTP
  static const String invalidOtp = 'INVALID_OTP';
  static const String resetTokenExpired = 'RESET_TOKEN_EXPIRED';
  static const String resetTokenInvalid = 'RESET_TOKEN_INVALID';
  static const String resetTokenUsed = 'RESET_TOKEN_USED';
  static const String passwordTooShort = 'PASSWORD_TOO_SHORT';

  // Request Validation
  static const String requiredFieldsMissing = 'REQUIRED_FIELDS_MISSING';
}
