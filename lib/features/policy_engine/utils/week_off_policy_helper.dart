import 'dart:convert';

class WeekOffRule {
  final String day;
  final List<int> weeks; // Weeks of the month, e.g. [1, 2, 3, 4, 5]

  WeekOffRule({required this.day, required this.weeks});
}

class HalfDayRule {
  final String day;
  final List<int> weeks; // Weeks of the month, e.g. [1, 2, 3, 4, 5]
  final Map<String, String>? timing; // e.g. {'start_time': '09:00', 'end_time': '13:00'}

  HalfDayRule({required this.day, required this.weeks, this.timing});
}

class ParsedPolicy {
  final List<String> workingDays;
  final List<WeekOffRule> weekOffRules;
  final List<HalfDayRule> halfDayRules;

  ParsedPolicy({
    required this.workingDays,
    required this.weekOffRules,
    required this.halfDayRules,
  });
}

class WeekOffPolicyHelper {
  static const List<String> dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// Reconstruct the three configurator inputs from a stored policy.
  static ParsedPolicy parsePolicy(dynamic rawPolicy) {
    List<dynamic> entries = [];
    if (rawPolicy != null) {
      if (rawPolicy is String) {
        try {
          final parsed = jsonDecode(rawPolicy);
          if (parsed is List) {
            entries = parsed;
          } else if (parsed is Map && parsed['rules'] is List) {
            entries = parsed['rules'];
          }
        } catch (_) {}
      } else if (rawPolicy is List) {
        entries = rawPolicy;
      } else if (rawPolicy is Map && rawPolicy['rules'] is List) {
        entries = rawPolicy['rules'];
      }
    }

    final Set<int> workingDaysIndices = {0, 1, 2, 3, 4, 5, 6};
    final Map<String, WeekOffRule> weekOffMap = {};
    final Map<String, HalfDayRule> halfDayMap = {};

    for (final entry in entries) {
      if (entry is! Map) continue;
      
      final rawDay = entry['day'];
      String? resolvedDay;
      if (rawDay is String) {
        resolvedDay = rawDay;
      } else if (rawDay is int && rawDay >= 0 && rawDay < 7) {
        resolvedDay = dayNames[rawDay];
      }
      if (resolvedDay == null || !dayNames.contains(resolvedDay)) continue;
      
      final resolvedDayIdx = dayNames.indexOf(resolvedDay);
      final type = (entry['type']?.toString() ?? 'full').toLowerCase();
      
      // Normalise frequency
      final rawFreq = entry['frequency'];
      List<int> freq = [];
      if (rawFreq == null || rawFreq == 'every') {
        freq = [1, 2, 3, 4, 5];
      } else if (rawFreq is List) {
        freq = rawFreq
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      } else {
        final parsedVal = int.tryParse(rawFreq.toString());
        if (parsedVal != null) {
          freq = [parsedVal];
        } else {
          freq = [1, 2, 3, 4, 5];
        }
      }

      if (type == 'full') {
        workingDaysIndices.remove(resolvedDayIdx);
        final isEvery = rawFreq == null || rawFreq == 'every' || freq.length >= 5;
        if (!isEvery) {
          if (!weekOffMap.containsKey(resolvedDay)) {
            weekOffMap[resolvedDay] = WeekOffRule(day: resolvedDay, weeks: []);
          }
          for (final w in freq) {
            if (!weekOffMap[resolvedDay]!.weeks.contains(w)) {
              weekOffMap[resolvedDay]!.weeks.add(w);
            }
          }
        }
        continue;
      }

      if (type == 'half') {
        Map<String, String>? timing;
        if (entry['timing'] is Map) {
          final t = entry['timing'] as Map;
          timing = {
            'start_time': t['start_time']?.toString() ?? '',
            'end_time': t['end_time']?.toString() ?? '',
          };
        }
        
        if (!halfDayMap.containsKey(resolvedDay)) {
          halfDayMap[resolvedDay] = HalfDayRule(day: resolvedDay, weeks: [], timing: timing);
        }
        for (final w in freq) {
          if (!halfDayMap[resolvedDay]!.weeks.contains(w)) {
            halfDayMap[resolvedDay]!.weeks.add(w);
          }
        }
      }
    }

    final workingDays = workingDaysIndices.toList()..sort();
    final workingDaysNames = workingDays.map((idx) => dayNames[idx]).toList();

    return ParsedPolicy(
      workingDays: workingDaysNames.isEmpty ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] : workingDaysNames,
      weekOffRules: weekOffMap.values.toList(),
      halfDayRules: halfDayMap.values.toList(),
    );
  }

  /// Build a week_off_policy array from three UI configurator inputs.
  static List<Map<String, dynamic>> buildPolicy({
    required List<String> workingDays,
    required List<WeekOffRule> weekOffRules,
    required List<HalfDayRule> halfDayRules,
  }) {
    final List<Map<String, dynamic>> policy = [];

    for (int d = 0; d < 7; d++) {
      final dayName = dayNames[d];
      final isWorking = workingDays.contains(dayName);

      final woRule = weekOffRules.firstWhere((r) => r.day == dayName, orElse: () => WeekOffRule(day: dayName, weeks: []));
      final hdRule = halfDayRules.firstWhere((r) => r.day == dayName, orElse: () => HalfDayRule(day: dayName, weeks: []));
      final hdWeeks = hdRule.weeks;

      if (isWorking) {
        if (hdWeeks.isNotEmpty) {
          final Map<String, dynamic> entry = {
            'day': dayName,
            'type': 'half',
            'frequency': hdWeeks.length >= 5 ? 'every' : hdWeeks,
          };
          if (hdRule.timing != null && hdRule.timing!['start_time'] != null) {
            entry['timing'] = hdRule.timing;
          }
          policy.add(entry);
        }
      } else {
        List<int> offWeeks = [1, 2, 3, 4, 5];
        if (woRule.weeks.isNotEmpty) {
          offWeeks = woRule.weeks;
        } else if (hdWeeks.isNotEmpty) {
          offWeeks = [1, 2, 3, 4, 5].where((w) => !hdWeeks.contains(w)).toList();
        }

        if (offWeeks.isNotEmpty) {
          policy.add({
            'day': dayName,
            'type': 'full',
            'frequency': offWeeks.length >= 5 ? 'every' : offWeeks,
          });
        }

        if (hdWeeks.isNotEmpty) {
          final Map<String, dynamic> entry = {
            'day': dayName,
            'type': 'half',
            'frequency': hdWeeks.length >= 5 ? 'every' : hdWeeks,
          };
          if (hdRule.timing != null && hdRule.timing!['start_time'] != null) {
            entry['timing'] = hdRule.timing;
          }
          policy.add(entry);
        }
      }
    }

    return policy;
  }
}
