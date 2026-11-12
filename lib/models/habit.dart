import 'package:uuid/uuid.dart';

enum HabitDurationType {
  days,
  hours;

  String get label {
    switch (this) {
      case HabitDurationType.days:
        return 'Days';
      case HabitDurationType.hours:
        return 'Hours';
    }
  }
}

class Habit {
  final String id;
  String title;
  String description;
  int targetCount; // Number of days or hours
  HabitDurationType durationType;
  List<bool> completionStatus; // Track which day/hour is completed
  DateTime createdAt;
  DateTime? startDate;

  Habit({
    String? id,
    required this.title,
    this.description = '',
    required this.targetCount,
    this.durationType = HabitDurationType.days,
    List<bool>? completionStatus,
    DateTime? createdAt,
    DateTime? startDate,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        startDate = startDate ?? DateTime.now(),
        completionStatus = completionStatus ?? List.filled(targetCount, false);

  // Helper to determine the current interval index
  int getCurrentIntervalIndex() {
    final now = DateTime.now();

    // Fallback if startDate is somehow null
    final start = startDate ?? createdAt;

    if (durationType == HabitDurationType.days) {
      // Midnight to midnight comparison
      final startDay = DateTime(start.year, start.month, start.day);
      final currentDay = DateTime(now.year, now.month, now.day);
      return currentDay.difference(startDay).inDays;
    } else {
      // Exact hours comparison
      return now.difference(start).inHours;
    }
  }

  // Determine the state of a specific interval
  bool isMissed(int index) {
    if (index >= completionStatus.length) return false;
    // It's missed if it's in the past AND not completed
    return index < getCurrentIntervalIndex() && !completionStatus[index];
  }

  bool isCurrent(int index) {
    return index == getCurrentIntervalIndex();
  }

  bool isLockedFuture(int index) {
    return index > getCurrentIntervalIndex();
  }

  // Calculate progress
  int get completedCount => completionStatus.where((status) => status).length;
  double get progressPercentage =>
      targetCount > 0 ? (completedCount / targetCount) * 100 : 0;
  bool get isCompleted => completedCount == targetCount;

  Habit copyWith({
    String? title,
    String? description,
    int? targetCount,
    HabitDurationType? durationType,
    List<bool>? completionStatus,
    DateTime? startDate,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetCount: targetCount ?? this.targetCount,
      durationType: durationType ?? this.durationType,
      completionStatus: completionStatus ?? List.from(this.completionStatus),
      createdAt: createdAt,
      startDate: startDate ?? this.startDate,
    );
  }

  // Toggle completion status for specific index
  void toggleCompletion(int index) {
    if (index >= 0 && index < completionStatus.length) {
      completionStatus[index] = !completionStatus[index];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetCount': targetCount,
      'durationType': durationType.index,
      'completionStatus': completionStatus,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      targetCount: json['targetCount'] as int,
      durationType: HabitDurationType.values[json['durationType'] as int? ?? 0],
      completionStatus: (json['completionStatus'] as List<dynamic>?)
          ?.map((e) => e as bool)
          .toList() ?? List.filled(json['targetCount'] as int, false),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
    );
  }
}
