import 'dart:convert';
import '../constants/timetable_prompt.dart';

/// A saved timetable snapshot in the user's timetable library.
class SavedTimetable {
  final String id;
  String name;
  DateTime createdAt;
  DateTime updatedAt;
  Map<String, dynamic> data;

  SavedTimetable({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.data,
  });

  String get teacher {
    final t = data['teacher'];
    if (t is String && t.trim().isNotEmpty) {
      return t.trim();
    }
    return 'Teacher';
  }

  int get totalClasses {
    int total = 0;
    final tt = data['timetable'];
    if (tt is Map) {
      for (final day in tt.values) {
        if (day is List) total += day.length;
      }
    }
    return total;
  }

  List<String> get activeDays {
    final List<String> days = [];
    final tt = data['timetable'];
    if (tt is Map) {
      for (final dayKey in kDayKeys) {
        final list = tt[dayKey];
        if (list is List && list.isNotEmpty) {
          days.add(dayKey[0].toUpperCase() + dayKey.substring(1, 3));
        }
      }
    }
    return days;
  }

  String? get timeSpan {
    final tt = data['timetable'];
    if (tt is! Map) return null;

    String? firstStart;
    String? lastEnd;

    for (final dayKey in kDayKeys) {
      final list = tt[dayKey];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            firstStart ??= item['start']?.toString();
            lastEnd = item['end']?.toString() ?? lastEnd;
          }
        }
      }
    }

    if (firstStart != null && lastEnd != null) {
      return '$firstStart – $lastEnd';
    }
    return null;
  }

  /// Exports this timetable as a human-readable, formatted JSON string for `.jadwal` files.
  String toFileContent() {
    final exportMap = <String, dynamic>{
      'app': 'jadwal',
      'format_version': 1,
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'teacher': teacher,
      'timetable': data['timetable'],
    };
    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'data': data,
      };

  factory SavedTimetable.fromJson(Map<String, dynamic> json) {
    return SavedTimetable(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Untitled Schedule',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : <String, dynamic>{
              'teacher': json['teacher'] ?? 'Teacher',
              'timetable': json['timetable'] ?? {},
            },
    );
  }

  SavedTimetable copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? data,
  }) {
    return SavedTimetable(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data ?? this.data,
    );
  }
}
