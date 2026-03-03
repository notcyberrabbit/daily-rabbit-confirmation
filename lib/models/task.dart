/// Task priority levels.
enum TaskPriority {
  low,
  normal,
  urgent;

  static TaskPriority fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'urgent':
        return TaskPriority.urgent;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.normal;
    }
  }

  String get value => name;
}

/// One task: id, text, completed, priority, optional link (URL or app on Android), estimated minutes.
class TaskItem {
  TaskItem({
    required this.id,
    required this.text,
    this.completed = false,
    this.priority = TaskPriority.normal,
    this.linkedPackage,
    this.linkedAppName,
    this.linkedUrl,
    this.createdAt,
    this.estimatedMinutes,
  });

  final String id;
  final String text;
  final bool completed;
  final TaskPriority priority;
  final String? linkedPackage;
  final String? linkedAppName;
  final String? linkedUrl;
  final DateTime? createdAt;
  /// Estimated duration in minutes (e.g. 10 for "10 min").
  final int? estimatedMinutes;

  bool get hasLinkedApp => linkedPackage != null && linkedPackage!.isNotEmpty;
  bool get hasLinkedUrl => linkedUrl != null && linkedUrl!.trim().isNotEmpty;
  bool get hasLink => hasLinkedUrl || hasLinkedApp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'completed': completed,
        'priority': priority.value,
        if (linkedPackage != null) 'linkedPackage': linkedPackage,
        if (linkedAppName != null) 'linkedAppName': linkedAppName,
        if (linkedUrl != null && linkedUrl!.isNotEmpty) 'linkedUrl': linkedUrl,
        if (createdAt != null) 'createdAt': createdAt!.millisecondsSinceEpoch,
        if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      };

  static TaskItem fromJson(Map<String, dynamic> m) {
    final createdAtMs = m['createdAt'] as int?;
    return TaskItem(
      id: m['id'] as String? ?? '',
      text: m['text'] as String? ?? '',
      completed: m['completed'] as bool? ?? false,
      priority: TaskPriority.fromString(m['priority'] as String?),
      linkedPackage: m['linkedPackage'] as String?,
      linkedAppName: m['linkedAppName'] as String?,
      linkedUrl: m['linkedUrl'] as String?,
      createdAt: createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : null,
      estimatedMinutes: m['estimatedMinutes'] as int?,
    );
  }

  TaskItem copyWith({
    String? id,
    String? text,
    bool? completed,
    TaskPriority? priority,
    String? linkedPackage,
    String? linkedAppName,
    String? linkedUrl,
    DateTime? createdAt,
    int? estimatedMinutes,
  }) {
    return TaskItem(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      linkedPackage: linkedPackage ?? this.linkedPackage,
      linkedAppName: linkedAppName ?? this.linkedAppName,
      linkedUrl: linkedUrl ?? this.linkedUrl,
      createdAt: createdAt ?? this.createdAt,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }
}

/// One day's task stats for the streak log.
class TaskDayLog {
  final String date; // YYYY-MM-DD
  final int completedCount;
  final int totalCount;
  final int completedMinutes;
  final int totalMinutes;

  const TaskDayLog({
    required this.date,
    required this.completedCount,
    required this.totalCount,
    required this.completedMinutes,
    required this.totalMinutes,
  });

  bool get allDone => totalCount > 0 && completedCount == totalCount;

  Map<String, dynamic> toJson() => {
        'date': date,
        'completedCount': completedCount,
        'totalCount': totalCount,
        'completedMinutes': completedMinutes,
        'totalMinutes': totalMinutes,
      };

  static TaskDayLog fromJson(Map<String, dynamic> m) => TaskDayLog(
        date: m['date'] as String? ?? '',
        completedCount: m['completedCount'] as int? ?? 0,
        totalCount: m['totalCount'] as int? ?? 0,
        completedMinutes: m['completedMinutes'] as int? ?? 0,
        totalMinutes: m['totalMinutes'] as int? ?? 0,
      );
}
