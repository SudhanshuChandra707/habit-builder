import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

class DailyTask {
  final String id;
  String title;
  String description;
  bool isCompletedToday;
  DateTime createdAt;
  TimeOfDay reminderTime;
  bool reminderEnabled;
  DateTime? lastCompletedDate;

  DailyTask({
    String? id,
    required this.title,
    this.description = '',
    this.isCompletedToday = false,
    DateTime? createdAt,
    required this.reminderTime,
    this.reminderEnabled = true,
    this.lastCompletedDate,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  DailyTask copyWith({
    String? title,
    String? description,
    bool? isCompletedToday,
    TimeOfDay? reminderTime,
    bool? reminderEnabled,
    DateTime? lastCompletedDate,
  }) {
    return DailyTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      createdAt: createdAt,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompletedToday': isCompletedToday,
      'createdAt': createdAt.toIso8601String(),
      'reminderTimeHour': reminderTime.hour,
      'reminderTimeMinute': reminderTime.minute,
      'reminderEnabled': reminderEnabled,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
    };
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      isCompletedToday: json['isCompletedToday'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reminderTime: TimeOfDay(
        hour: json['reminderTimeHour'] as int,
        minute: json['reminderTimeMinute'] as int,
      ),
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.parse(json['lastCompletedDate'] as String)
          : null,
    );
  }

  // Check if task was completed today
  bool wasCompletedToday() {
    if (lastCompletedDate == null) return false;
    final now = DateTime.now();
    return lastCompletedDate!.year == now.year &&
        lastCompletedDate!.month == now.month &&
        lastCompletedDate!.day == now.day;
  }

  // Reset completion if it's a new day
  void checkAndResetDaily() {
    if (!wasCompletedToday()) {
      isCompletedToday = false;
    }
  }
}
