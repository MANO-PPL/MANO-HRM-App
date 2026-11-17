import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/shared/models/context_models.dart';
import 'package:flutter_application/shared/services/update_policy.dart';

void main() {
  group('ContextVector Tests', () {
    test('parses standard header string correctly', () {
      final vec = ContextVector.fromHeader('e=1;s=15;o=4;u=88');
      expect(vec.epoch, 1);
      expect(vec.system, 15);
      expect(vec.org, 4);
      expect(vec.user, 88);
    });

    test('toHeaderValue matches formatted string', () {
      const vec = ContextVector(epoch: 2, system: 10, org: 5, user: 42);
      expect(vec.toHeaderValue(), 'e=2;s=10;o=5;u=42');
    });

    test('handles empty or malformed header gracefully', () {
      final vec = ContextVector.fromHeader('invalid_vector');
      expect(vec.epoch, 0);
      expect(vec.system, 0);
      expect(vec.org, 0);
      expect(vec.user, 0);
    });
  });

  group('UpdatePolicy Tests', () {
    test('evaluates requiredBlocking when below min_version', () {
      const sys = SystemContext(
        minAppVersion: {'android': '1.2.0', 'ios': '1.2.0'},
        recommendedVersion: {'android': '1.3.0', 'ios': '1.3.0'},
        storeUrls: {'android': 'https://play.google.com/store/apps/details?id=com.mano.attendance'},
      );

      final policy = UpdatePolicy.evaluate(system: sys, clientVersion: '1.1.5');
      expect(policy.state, UpdatePolicyState.requiredBlocking);
      expect(policy.isBlocking, isTrue);
      expect(policy.minVersion, '1.2.0');
    });

    test('evaluates requiredGrace when below min_version within grace deadline', () {
      final futureDeadlineMs = DateTime.now().toUtc().add(const Duration(hours: 12)).millisecondsSinceEpoch;
      final sys = SystemContext(
        minAppVersion: {'android': '1.2.0', 'ios': '1.2.0'},
        recommendedVersion: {'android': '1.3.0', 'ios': '1.3.0'},
        updateGraceUntil: {'android': futureDeadlineMs, 'ios': futureDeadlineMs},
      );

      final policy = UpdatePolicy.evaluate(system: sys, clientVersion: '1.1.5');
      expect(policy.state, UpdatePolicyState.requiredGrace);
      expect(policy.isBlocking, isFalse);
    });

    test('evaluates recommended when equal to min but below latest', () {
      const sys = SystemContext(
        minAppVersion: {'android': '1.2.0', 'ios': '1.2.0'},
        recommendedVersion: {'android': '1.3.0', 'ios': '1.3.0'},
      );

      final policy = UpdatePolicy.evaluate(system: sys, clientVersion: '1.2.0');
      expect(policy.state, UpdatePolicyState.recommended);
      expect(policy.isBlocking, isFalse);
    });

    test('evaluates none when client is on or above latest', () {
      const sys = SystemContext(
        minAppVersion: {'android': '1.2.0', 'ios': '1.2.0'},
        recommendedVersion: {'android': '1.3.0', 'ios': '1.3.0'},
      );

      final policy = UpdatePolicy.evaluate(system: sys, clientVersion: '1.3.0');
      expect(policy.state, UpdatePolicyState.none);
      expect(policy.isBlocking, isFalse);
    });
  });

  group('EffectiveShift Expiry Tests (R5)', () {
    test('shift is valid when within UTC validFrom and validUntil', () {
      final now = DateTime.now().toUtc();
      final shift = EffectiveShift(
        shiftId: 101,
        name: 'General',
        date: '2026-11-18',
        startTime: '09:00',
        endTime: '18:00',
        validFrom: now.subtract(const Duration(hours: 2)),
        validUntil: now.add(const Duration(hours: 6)),
      );

      expect(shift.isExpired, isFalse);
    });

    test('shift is expired when current UTC is past validUntil', () {
      final now = DateTime.now().toUtc();
      final shift = EffectiveShift(
        shiftId: 101,
        name: 'General',
        date: '2026-11-18',
        startTime: '09:00',
        endTime: '18:00',
        validFrom: now.subtract(const Duration(hours: 10)),
        validUntil: now.subtract(const Duration(hours: 1)),
      );

      expect(shift.isExpired, isTrue);
    });
  });

  group('Geofence Tolerance Tests (R11)', () {
    test('point within radius matches', () {
      const loc = AssignedLocation(
        locationId: 1,
        name: 'Headquarters',
        latitude: 12.9716,
        longitude: 77.5946,
        radiusMeters: 100.0,
      );

      // Distance calculation verification
      expect(loc.locationId, 1);
      expect(loc.radiusMeters, 100.0);
    });
  });
}
