/// Representation of the 4-tier context vector (e=1;s=15;o=4;u=88).
class ContextVector {
  final int epoch;
  final int system;
  final int org;
  final int user;

  const ContextVector({
    this.epoch = 0,
    this.system = 0,
    this.org = 0,
    this.user = 0,
  });

  /// Formats the vector as a wire-format header value (e.g. "e=1;s=15;o=4;u=88").
  String toHeaderValue() {
    return 'e=$epoch;s=$system;o=$org;u=$user';
  }

  /// Parses wire-format header value (e.g. "e=1;s=15;o=4;u=88").
  factory ContextVector.fromHeader(String? header) {
    if (header == null || header.trim().isEmpty) {
      return const ContextVector();
    }

    int epoch = 0;
    int system = 0;
    int org = 0;
    int user = 0;

    final parts = header.split(';');
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length == 2) {
        final key = kv[0].trim();
        final val = int.tryParse(kv[1].trim()) ?? 0;
        switch (key) {
          case 'e':
            epoch = val;
            break;
          case 's':
            system = val;
            break;
          case 'o':
            org = val;
            break;
          case 'u':
            user = val;
            break;
        }
      }
    }

    return ContextVector(
      epoch: epoch,
      system: system,
      org: org,
      user: user,
    );
  }

  ContextVector copyWith({
    int? epoch,
    int? system,
    int? org,
    int? user,
  }) {
    return ContextVector(
      epoch: epoch ?? this.epoch,
      system: system ?? this.system,
      org: org ?? this.org,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => {
        'e': epoch,
        's': system,
        'o': org,
        'u': user,
      };

  factory ContextVector.fromJson(Map<String, dynamic> json) {
    return ContextVector(
      epoch: json['e'] as int? ?? 0,
      system: json['s'] as int? ?? 0,
      org: json['o'] as int? ?? 0,
      user: json['u'] as int? ?? 0,
    );
  }
}

/// Global System ('s') context slice.
class SystemContext {
  final bool captchaEnabled;
  final bool maintenanceMode;
  final Map<String, String> minAppVersion;
  final Map<String, String> recommendedVersion;
  final Map<String, int?> updateGraceUntil;
  final Map<String, String?> storeUrls;

  const SystemContext({
    this.captchaEnabled = true,
    this.maintenanceMode = false,
    this.minAppVersion = const {'ios': '0.0.0', 'android': '0.0.0'},
    this.recommendedVersion = const {'ios': '0.0.0', 'android': '0.0.0'},
    this.updateGraceUntil = const {'ios': null, 'android': null},
    this.storeUrls = const {'ios': null, 'android': null},
  });

  factory SystemContext.fromJson(Map<String, dynamic> json) {
    return SystemContext(
      captchaEnabled: json['appCaptchaEnabled'] as bool? ?? json['captchaEnabled'] as bool? ?? true,
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      minAppVersion: (json['minAppVersion'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString() ?? '0.0.0'),
          ) ??
          const {'ios': '0.0.0', 'android': '0.0.0'},
      recommendedVersion: (json['recommendedVersion'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString() ?? '0.0.0'),
          ) ??
          const {'ios': '0.0.0', 'android': '0.0.0'},
      updateGraceUntil: (json['updateGraceUntil'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v is num ? v.toInt() : null),
          ) ??
          const {'ios': null, 'android': null},
      storeUrls: (json['storeUrls'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString()),
          ) ??
          const {'ios': null, 'android': null},
    );
  }

  Map<String, dynamic> toJson() => {
        'captchaEnabled': captchaEnabled,
        'maintenanceMode': maintenanceMode,
        'minAppVersion': minAppVersion,
        'recommendedVersion': recommendedVersion,
        'updateGraceUntil': updateGraceUntil,
        'storeUrls': storeUrls,
      };
}

/// Organization ('o') operational metadata slice.
class OrgContext {
  final int orgId;
  final String orgName;
  final String? orgCode;
  final String timezone;
  final String? country;
  final String? state;
  final String? city;

  const OrgContext({
    required this.orgId,
    required this.orgName,
    this.orgCode,
    this.timezone = 'Asia/Kolkata',
    this.country,
    this.state,
    this.city,
  });

  factory OrgContext.fromJson(Map<String, dynamic> json) {
    return OrgContext(
      orgId: json['orgId'] as int? ?? 0,
      orgName: json['orgName'] as String? ?? '',
      orgCode: json['orgCode'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      country: json['country'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'orgId': orgId,
        'orgName': orgName,
        'orgCode': orgCode,
        'timezone': timezone,
        'country': country,
        'state': state,
        'city': city,
      };
}

/// Pre-resolved shift metadata with R5 expiration timestamps.
class EffectiveShift {
  final int shiftId;
  final String name;
  final String date;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final bool crossesMidnight;
  final Map<String, dynamic> entryRequirements;
  final Map<String, dynamic> exitRequirements;

  const EffectiveShift({
    required this.shiftId,
    required this.name,
    required this.date,
    this.validFrom,
    this.validUntil,
    required this.startTime,
    required this.endTime,
    this.graceMinutes = 0,
    this.crossesMidnight = false,
    this.entryRequirements = const {'selfie': true, 'geofence': true},
    this.exitRequirements = const {'selfie': true, 'geofence': true},
  });

  /// Checks whether this pre-resolved shift has expired past its validity bound.
  bool get isExpired {
    if (validUntil == null) return false;
    return DateTime.now().toUtc().isAfter(validUntil!);
  }

  factory EffectiveShift.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString()).toUtc();
      } catch (_) {
        return null;
      }
    }

    return EffectiveShift(
      shiftId: json['shiftId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      validFrom: parseUtc(json['validFrom']),
      validUntil: parseUtc(json['validUntil']),
      startTime: json['startTime'] as String? ?? '09:00',
      endTime: json['endTime'] as String? ?? '18:00',
      graceMinutes: json['graceMinutes'] as int? ?? 0,
      crossesMidnight: json['crossesMidnight'] as bool? ?? false,
      entryRequirements: (json['entryRequirements'] as Map<String, dynamic>?) ??
          const {'selfie': true, 'geofence': true},
      exitRequirements: (json['exitRequirements'] as Map<String, dynamic>?) ??
          const {'selfie': true, 'geofence': true},
    );
  }

  Map<String, dynamic> toJson() => {
        'shiftId': shiftId,
        'name': name,
        'date': date,
        'validFrom': validFrom?.toIso8601String(),
        'validUntil': validUntil?.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
        'graceMinutes': graceMinutes,
        'crossesMidnight': crossesMidnight,
        'entryRequirements': entryRequirements,
        'exitRequirements': exitRequirements,
      };
}

/// Assigned work location geofence boundary.
class AssignedLocation {
  final int locationId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String timezone;

  const AssignedLocation({
    required this.locationId,
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 50.0,
    this.timezone = 'Asia/Kolkata',
  });

  factory AssignedLocation.fromJson(Map<String, dynamic> json) {
    return AssignedLocation(
      locationId: json['locationId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 50.0,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
    );
  }

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'timezone': timezone,
      };
}

/// User ('u') identity and policy context slice.
class UserContext {
  final int userId;
  final String userName;
  final String? userCode;
  final String? role;
  final String email;
  final String? phoneNo;
  final String? profileImageUrl;
  final int orgId;
  final bool isActive;
  final EffectiveShift? effectiveShift;
  final List<AssignedLocation> assignedLocations;

  const UserContext({
    required this.userId,
    required this.userName,
    this.userCode,
    this.role,
    required this.email,
    this.phoneNo,
    this.profileImageUrl,
    required this.orgId,
    this.isActive = true,
    this.effectiveShift,
    this.assignedLocations = const [],
  });

  factory UserContext.fromJson(Map<String, dynamic> json) {
    return UserContext(
      userId: json['userId'] as int? ?? 0,
      userName: json['userName'] as String? ?? '',
      userCode: json['userCode'] as String?,
      role: json['role'] as String?,
      email: json['email'] as String? ?? '',
      phoneNo: json['phoneNo'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      orgId: json['orgId'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      effectiveShift: json['effectiveShift'] != null
          ? EffectiveShift.fromJson(json['effectiveShift'] as Map<String, dynamic>)
          : null,
      assignedLocations: (json['assignedLocations'] as List<dynamic>?)
              ?.map((e) => AssignedLocation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'userCode': userCode,
        'role': role,
        'email': email,
        'phoneNo': phoneNo,
        'profileImageUrl': profileImageUrl,
        'orgId': orgId,
        'isActive': isActive,
        'effectiveShift': effectiveShift?.toJson(),
        'assignedLocations': assignedLocations.map((l) => l.toJson()).toList(),
      };
}
