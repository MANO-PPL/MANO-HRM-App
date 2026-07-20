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
        exitRequirements: ExitRequirements(selfie: false, geofence: true),
        correctionDeadline: 2,
      ),
    );
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['shift_id'],
      name: json['shift_name'] ?? '',
      startTime: json['start_time'] ?? '09:00',
      endTime: json['end_time'] ?? '18:00',
      gracePeriodMins: json['grace_period_mins'] ?? 0,
      isOvertimeEnabled: json['is_overtime_enabled'] == true || json['is_overtime_enabled'] == 1,
      overtimeThresholdHours: double.tryParse(json['overtime_threshold_hours'].toString()) ?? 8.0,
      workingDays: List<String>.from(json['working_days'] ?? []),
      alternateSaturdays: AlternateSaturdays.fromJson(json['alternate_saturdays'] ?? {}),
      policyRules: PolicyRules.fromJson(json['policy_rules'] ?? {}),
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

  factory AlternateSaturdays.fromJson(Map<String, dynamic> json) {
    return AlternateSaturdays(
      enabled: json['enabled'] == true,
      off: List<int>.from(json['off'] ?? []),
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

  factory PolicyRules.fromJson(Map<String, dynamic> json) {
    return PolicyRules(
      shiftTiming: ShiftTiming.fromJson(json['shift_timing'] ?? {}),
      gracePeriod: GracePeriod.fromJson(json['grace_period'] ?? {}),
      overtime: Overtime.fromJson(json['overtime'] ?? {}),
      entryRequirements: EntryRequirements.fromJson(json['entry_requirements'] ?? {}),
      exitRequirements: ExitRequirements.fromJson(json['exit_requirements'] ?? {}),
      correctionDeadline: json['correction_deadline'] is int 
          ? json['correction_deadline'] 
          : (int.tryParse(json['correction_deadline']?.toString() ?? '') ?? 2),
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
  factory ShiftTiming.fromJson(Map<String, dynamic> json) => ShiftTiming(startTime: json['start_time'] ?? '09:00', endTime: json['end_time'] ?? '18:00');
  Map<String, dynamic> toJson() => {'start_time': startTime, 'end_time': endTime};
}

class GracePeriod {
  final int minutes;
  GracePeriod({required this.minutes});
  factory GracePeriod.fromJson(Map<String, dynamic> json) => GracePeriod(minutes: json['minutes'] ?? 15);
  Map<String, dynamic> toJson() => {'minutes': minutes};
}

class Overtime {
  final bool enabled;
  final double threshold;
  Overtime({required this.enabled, required this.threshold});
  factory Overtime.fromJson(Map<String, dynamic> json) => Overtime(enabled: json['enabled'] == true, threshold: double.tryParse(json['threshold'].toString()) ?? 8.0);
  Map<String, dynamic> toJson() => {'enabled': enabled, 'threshold': threshold};
}

class EntryRequirements {
  final bool selfie;
  final bool geofence;
  EntryRequirements({required this.selfie, required this.geofence});
  factory EntryRequirements.fromJson(Map<String, dynamic> json) => EntryRequirements(selfie: json['selfie'] == true, geofence: json['geofence'] == true);
  Map<String, dynamic> toJson() => {'selfie': selfie, 'geofence': geofence};
}

class ExitRequirements {
  final bool selfie;
  final bool geofence;
  ExitRequirements({required this.selfie, required this.geofence});
  factory ExitRequirements.fromJson(Map<String, dynamic> json) => ExitRequirements(selfie: json['selfie'] == true, geofence: json['geofence'] == true);
  Map<String, dynamic> toJson() => {'selfie': selfie, 'geofence': geofence};
}
