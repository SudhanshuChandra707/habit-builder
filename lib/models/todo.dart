import 'package:uuid/uuid.dart';

class Todo {
  final String id;
  String title;
  String description;
  bool isCompleted;
  DateTime createdAt;
  DateTime? dueDate;

  /// True when [dueDate] carries a specific time of day; false means the
  /// to-do is due "some time that day" (all-day).
  bool hasDueTime;
  Priority priority;
  String category;

  Todo({
    String? id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    DateTime? createdAt,
    this.dueDate,
    this.hasDueTime = false,
    this.priority = Priority.medium,
    this.category = 'General',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Todo copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    bool? hasDueTime,
    bool clearDueDate = false,
    Priority? priority,
    String? category,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      hasDueTime: clearDueDate ? false : (hasDueTime ?? this.hasDueTime),
      priority: priority ?? this.priority,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'hasDueTime': hasDueTime,
      'priority': priority.index,
      'category': category,
    };
  }

  /// Overdue = not done and past its due time (timed) or due day (all-day).
  bool isOverdue([DateTime? now]) {
    if (isCompleted || dueDate == null) return false;
    final n = now ?? DateTime.now();
    if (hasDueTime) return dueDate!.isBefore(n);
    return dueDate!.isBefore(DateTime(n.year, n.month, n.day));
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      hasDueTime: json['hasDueTime'] as bool? ?? false,
      priority: Priority.values[json['priority'] as int? ?? 1],
      category: json['category'] as String? ?? 'General',
    );
  }
}

enum Priority {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
    }
  }
}
