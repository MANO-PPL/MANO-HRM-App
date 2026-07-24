import 'dart:convert';

bool _asBool(dynamic val, {bool defaultValue = false}) {
  if (val == null) return defaultValue;
  if (val is bool) return val;
  if (val is num) return val != 0;
  if (val is String) {
    final s = val.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'on' || s == 'active') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'off') return false;
  }
  return defaultValue;
}

dynamic _parseJson(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  return raw;
}

class Shift {
  final int? id;
  final String name;
  final String startTime; // "HH:MM"
  final String endTime;   // "HH:MM"
  final int gracePeriodMins;
  final bool isOvertimeEnabled;
  final double overtimeThresholdHours;
  final List<String> workingDays;
  final AlternateSaturdays alternateSaturdays;
  final PolicyRules policyRules;

  Shift({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.gracePeriodMins, 
    required this.isOvertimeEnabled,
    required this.overtimeThresholdHours,
    required this.workingDays,
    required this.alternateSaturdays,
    required this.policyRules,
  });

  int get correctionDeadline => policyRules.correctionDeadline;
  bool get entrySelfie => policyRules.entryRequirements.selfie;
  bool get entryGeofence => policyRules.entryRequirements.geofence;
  bool get exitSelfie => policyRules.exitRequirements.selfie;
  bool get exitGeofence => policyRules.exitRequirements.geofence;

  factory Shift.defaultShift() {
    return Shift(
      name: '',
      startTime: '09:00',
      endTime: '18:00',
      gracePeriodMins: 15,
      isOvertimeEnabled: false,
      overtimeThresholdHours: 8.0,
      workingDays: const ["Mon", "Tue", "Wed", "Thu", "Fri"],
      alternateSaturdays: AlternateSaturdays(enabled: false, off: []),
      policyRules: PolicyRules(
        shiftTiming: ShiftTiming(startTime: '09:00', endTime: '18:00'),
        gracePeriod: GracePeriod(minutes: 15),
        overtime: Overtime(enabled: false, threshold: 8.0),
        entryRequirements: EntryRequirements(selfie: true, geofence: true),
        exitRequirements: ExitRequirements(selfie: true, geofence: true),
        correctionDeadline: 2,
      ),
    );
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (data['shift'] is Map) {
      data = Map<String, dynamic>.from(data['shift']);
    } else if (data['data'] is Map) {
      data = Map<String, dynamic>.from(data['data']);
    }

    final rawRules = _parseJson(data['rules'] ?? data['policy_rules']);
    final Map<String, dynamic> rulesMap = rawRules is Map
        ? Map<String, dynamic>.from(rawRules)
        : <String, dynamic>{};

    if (!rulesMap.containsKey('entry_requirements') && (data.containsKey('entry_requirements') || data.containsKey('entryRequirements'))) {
      rulesMap['entry_requirements'] = data['entry_requirements'] ?? data['entryRequirements'];
    }
    if (!rulesMap.containsKey('exit_requirements') && (data.containsKey('exit_requirements') || data.containsKey('exitRequirements'))) {
      rulesMap['exit_requirements'] = data['exit_requirements'] ?? data['exitRequirements'];
    }

    return Shift(
      id: data['shift_id'] ?? data['id'],
      name: data['shift_name'] ?? data['name'] ?? '',
      startTime: data['start_time'] ?? rulesMap['shift_timing']?['start_time'] ?? '09:00',
      endTime: data['end_time'] ?? rulesMap['shift_timing']?['end_time'] ?? '18:00',
      gracePeriodMins: data['grace_period_mins'] ?? rulesMap['grace_period']?['minutes'] ?? 0,
      isOvertimeEnabled: _asBool(data['is_overtime_enabled'] ?? rulesMap['overtime']?['enabled']),
      overtimeThresholdHours: double.tryParse(data['overtime_threshold_hours']?.toString() ?? rulesMap['overtime']?['threshold']?.toString() ?? '') ?? 8.0,
      workingDays: List<String>.from(data['working_days'] ?? rulesMap['working_days'] ?? rulesMap['workingDays'] ?? []),
      alternateSaturdays: AlternateSaturdays.fromJson(_parseJson(data['alternate_saturdays'] ?? rulesMap['alternate_saturdays']) ?? {}),
      policyRules: PolicyRules.fromJson(rulesMap),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_name': name,
      'start_time': startTime,
      'end_time': endTime,
      'grace_period_mins': gracePeriodMins,
      'is_overtime_enabled': isOvertimeEnabled,
      'overtime_threshold_hours': overtimeThresholdHours,
      'working_days': workingDays,
      'alternate_saturdays': alternateSaturdays.toJson(),
      'policy_rules': policyRules.toJson(),
    };
  }
}

class AlternateSaturdays {
  final bool enabled;
  final List<int> off; // [1, 3, 5]

  AlternateSaturdays({required this.enabled, required this.off});

  factory AlternateSaturdays.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    return AlternateSaturdays(
      enabled: _asBool(map['enabled']),
      off: List<int>.from(map['off'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'off': off};
}

class PolicyRules {
  final ShiftTiming shiftTiming;
  final GracePeriod gracePeriod;
  final Overtime overtime;
  final EntryRequirements entryRequirements;
  final ExitRequirements exitRequirements;
  final int correctionDeadline;

  PolicyRules({
    required this.shiftTiming,
    required this.gracePeriod,
    required this.overtime,
    required this.entryRequirements,
    required this.exitRequirements,
    required this.correctionDeadline,
  });

  factory PolicyRules.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};

    return PolicyRules(
      shiftTiming: ShiftTiming.fromJson(map['shift_timing'] ?? {}),
      gracePeriod: GracePeriod.fromJson(map['grace_period'] ?? {}),
      overtime: Overtime.fromJson(map['overtime'] ?? {}),
      entryRequirements: EntryRequirements.fromJson(map['entry_requirements'] ?? map['entryRequirements'] ?? {}),
      exitRequirements: ExitRequirements.fromJson(map['exit_requirements'] ?? map['exitRequirements'] ?? {}),
      correctionDeadline: map['correction_deadline'] is int 
          ? map['correction_deadline'] 
          : (int.tryParse(map['correction_deadline']?.toString() ?? '') ?? 2),
    );
  }

  Map<String, dynamic> toJson() => {
    'shift_timing': shiftTiming.toJson(),
    'grace_period': gracePeriod.toJson(),
    'overtime': overtime.toJson(),
    'entry_requirements': entryRequirements.toJson(),
    'exit_requirements': exitRequirements.toJson(),
    'correction_deadline': correctionDeadline,
  };
}

class ShiftTiming {
  final String startTime;
  final String endTime;
  ShiftTiming({required this.startTime, required this.endTime});
  factory ShiftTiming.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    return ShiftTiming(startTime: map['start_time'] ?? '09:00', endTime: map['end_time'] ?? '18:00');
  }
  Map<String, dynamic> toJson() => {'start_time': startTime, 'end_time': endTime};
}

class GracePeriod {
  final int minutes;
  GracePeriod({required this.minutes});
  factory GracePeriod.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    return GracePeriod(minutes: map['minutes'] ?? 15);
  }
  Map<String, dynamic> toJson() => {'minutes': minutes};
}

class Overtime {
  final bool enabled;
  final double threshold;
  Overtime({required this.enabled, required this.threshold});
  factory Overtime.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    return Overtime(
      enabled: _asBool(map['enabled']),
      threshold: double.tryParse(map['threshold']?.toString() ?? '') ?? 8.0,
    );
  }
  Map<String, dynamic> toJson() => {'enabled': enabled, 'threshold': threshold};
}

class EntryRequirements {
  final bool selfie;
  final bool geofence;
  EntryRequirements({required this.selfie, required this.geofence});
  factory EntryRequirements.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    return EntryRequirements(
      selfie: map.containsKey('selfie') ? _asBool(map['selfie']) : true,
      geofence: map.containsKey('geofence') ? _asBool(map['geofence']) : true,
    );
  }
  Map<String, dynamic> toJson() => {'selfie': selfie, 'geofence': geofence};
}

class ExitRequirements {
  final bool selfie;
  final bool geofence;
  ExitRequirements({required this.selfie, required this.geofence});
  factory ExitRequirements.fromJson(dynamic json) {
    final parsed = _parseJson(json);
    final Map<String, dynamic> map = parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    return ExitRequirements(
      selfie: map.containsKey('selfie') ? _asBool(map['selfie']) : true,
      geofence: map.containsKey('geofence') ? _asBool(map['geofence']) : true,
    );
  }
  Map<String, dynamic> toJson() => {'selfie': selfie, 'geofence': geofence};
}
