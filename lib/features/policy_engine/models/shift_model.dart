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

  final Map<String, dynamic> policyRules;

  bool get entrySelfie {
    final entry = policyRules['entry_requirements'] ?? policyRules['entryRequirements'];
    if (entry is Map && entry.containsKey('selfie')) return _asBool(entry['selfie']);
    return true;
  }
  bool get entryGeofence {
    final entry = policyRules['entry_requirements'] ?? policyRules['entryRequirements'];
    if (entry is Map && entry.containsKey('geofence')) return _asBool(entry['geofence']);
    return true;
  }
  bool get exitSelfie {
    final exit = policyRules['exit_requirements'] ?? policyRules['exitRequirements'];
    if (exit is Map && exit.containsKey('selfie')) return _asBool(exit['selfie']);
    return true;
  }
  bool get exitGeofence {
    final exit = policyRules['exit_requirements'] ?? policyRules['exitRequirements'];
    if (exit is Map) return _asBool(exit['geofence']);
    return false;
  }
  int get correctionDeadline => policyRules['correction_deadline'] is int 
      ? policyRules['correction_deadline'] 
      : (int.tryParse(policyRules['correction_deadline']?.toString() ?? '') ?? 2);

  Shift({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.gracePeriodMins, 
    required this.isOvertimeEnabled,
    required this.overtimeThresholdHours,
    this.policyRules = const {},
  });

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
      gracePeriodMins: data['grace_period_mins'] is int 
          ? data['grace_period_mins'] 
          : int.tryParse(data['grace_period_mins']?.toString() ?? rulesMap['grace_period']?['minutes']?.toString() ?? '0') ?? 0,
      isOvertimeEnabled: _asBool(data['is_overtime_enabled'] ?? rulesMap['overtime']?['enabled']),
      overtimeThresholdHours: double.tryParse(data['overtime_threshold_hours']?.toString() ?? rulesMap['overtime']?['threshold']?.toString() ?? '0') ?? 8.0,
      policyRules: rulesMap,
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
      'policy_rules': policyRules,
    };
  }
}

