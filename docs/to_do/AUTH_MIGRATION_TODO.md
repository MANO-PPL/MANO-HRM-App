# Authentication & Token Transport Migration Roadmap

This document tracks the phased rollout of the mobile explicit JSON-body authentication transport, per-device session isolation, and subsequent cleanup.

---

## Phase 1: Mobile App Modernization (v1.2.0) — [IMPLEMENTED & VERIFIED]

- [x] **Dependencies**: Add `device_info_plus`, `package_info_plus`, and `uuid` to `pubspec.yaml`.
- [x] **Error Contract**: Create `lib/shared/constants/auth_error_codes.dart` mirroring backend `AUTH_ERROR_CODES`.
- [x] **Device & App Info**: Create `lib/shared/services/device_info_service.dart` to provide `X-Device-Id`, `X-Device-Name`, and `X-App-Version`.
- [x] **Auth Storage**: Create `lib/shared/services/auth_storage_service.dart` with seamless migration from legacy `PersistCookieJar` and hardcoded `rememberMe = true`.
- [x] **Queued Interceptor**: Create `lib/shared/network/auth_interceptor.dart` using Dio `QueuedInterceptor` for serialized token refresh and retry.
- [x] **AuthService Integration**: Update `lib/shared/services/auth_service.dart`:
  - Attach transport headers (`X-Client-Type: mobile`, `X-App-Version`, `X-Device-Id`, `X-Device-Name`).
  - Update `login()` to parse `accessToken`, `refreshToken`, and `sessionId` from JSON body.
  - Update `refreshToken()` to send `{"refreshToken": "..."}` in JSON body (no `x-refresh-token` header).
  - Update `logout()` to send `{"refreshToken": "..."}` in JSON body.
  - Implement non-destructive error handling for `ACCOUNT_INACTIVE` and `ORG_INACTIVE`.
- [x] **Verification**: Run `flutter analyze` to ensure zero compilation or lint errors (Passed: `No issues found!`).
- [ ] **Release**: Publish build v1.2.0 to Play Store & App Store.

---

## Phase 2: Monitoring & 30-Day Quiet Period — [PENDING PHASE 1 RELEASE]

- [ ] Verify production rollout reaches 100% of active mobile users.
- [ ] Enforce minimum app version (v1.2.0) via in-app update (`in_app_update_service.dart`).
- [ ] Query backend logs for structured `[AUTH_TRANSPORT]` audit lines:
  ```text
  [AUTH_TRANSPORT] endpoint=<path> clientType=<mobile|other> transport=<body|cookie|header> appVersion=<version> sessionId=<id>
  ```
- [ ] Confirm `transport=header` and mobile `transport=cookie` requests reach **0** for 30 consecutive calendar days.

---

## Phase 3: Mobile Codebase Cleanup (v1.3.0) — [PENDING PHASE 2]

- [ ] Remove legacy migration bridge code in `auth_storage_service.dart` (reading from `PersistCookieJar`).
- [ ] Remove `cookie_jar` and `dio_cookie_manager` from `pubspec.yaml`.
- [ ] Clean up legacy `.cookies/` directory in app sandbox on first run of v1.3.0.

---

## Phase 4: Backend Contract Decommissioning (`MANO-HRM-Web`) — [PENDING PHASE 2 & 3]

- [ ] Follow `TEMP/auth-transport-contract.md`:
  - In `backend/src/modules/auth/authController.js`, remove `req.headers['x-refresh-token']` fallback from `readRefreshToken`.
  - In `backend/src/modules/auth/authController.js`, remove `'header'` detection from `getTransportFromReq`.
  - Update integration tests in `backend/test/db/authTransport.db.test.js` to ensure legacy headers are rejected with 401 `NO_REFRESH_TOKEN`.
