enum TaskType { memorize, revision }

enum TaskStatus { notStarted, inProgress, completed }

enum PlanUnitType { surah, juz, page, custom }

enum NoteType { note, doubt, mistake }

// Helper for UI display logic later
extension PlanUnitTypeExtension on PlanUnitType {
  String get displayName {
    switch (this) {
      case PlanUnitType.surah:
        return 'Surah';
      case PlanUnitType.juz:
        return 'Juz';
      case PlanUnitType.page:
        return 'Page';
      case PlanUnitType.custom:
        return 'Custom';
    }
  }
}

class PlanTask {
  final int? id;
  // Core Identifiers
  final PlanUnitType unitType;
  final int unitId; // Stores Surah No, Juz No, or Start Page
  final int? endUnitId; // Stores End Page (if page/custom)
  final String title; // "Al-Baqarah", "Juz 1", "Pages 5-10"
  final String? subtitle; // "Ayah 1-5" or "Hizb 1"

  // Quran Specifics
  final int? startAyah; // For Surah mode
  final int? endAyah; // For Surah mode

  final TaskType type;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime? completedAt;
  final TaskStatus status;

  // Latest Note for quick access
  final String? note;

  PlanTask({
    this.id,
    required this.unitType,
    required this.unitId,
    this.endUnitId,
    required this.title,
    this.subtitle,
    this.startAyah,
    this.endAyah,
    required this.type,
    required this.deadline,
    required this.createdAt,
    this.completedAt,
    this.status = TaskStatus.notStarted,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unitType': unitType.index,
      'unitId': unitId,
      'endUnitId': endUnitId,
      'title': title,
      'subtitle': subtitle,
      'startAyah': startAyah,
      'endAyah': endAyah,
      'type': type.index,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status.index,
      'note': note,
    };
  }

  factory PlanTask.fromMap(Map<String, dynamic> map) {
    return PlanTask(
      id: map['id'],
      unitType: PlanUnitType.values[map['unitType'] ?? 0],
      unitId: map['unitId'] ?? map['surahNumber'] ?? 1,
      endUnitId: map['endUnitId'],
      title: map['title'] ?? map['surahName'] ?? 'Unknown',
      subtitle: map['subtitle'],
      startAyah: map['startAyah'],
      endAyah: map['endAyah'],
      type: TaskType.values[map['type']],
      deadline: DateTime.parse(map['deadline']),
      createdAt: DateTime.parse(map['createdAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      status: TaskStatus.values[map['status']],
      note: map['note'],
    );
  }
}

class TaskNote {
  final int? id;
  final int taskId;
  final String content;
  final NoteType type;
  final DateTime createdAt;

  TaskNote({
    this.id,
    required this.taskId,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'content': content,
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskNote.fromMap(Map<String, dynamic> map) {
    return TaskNote(
      id: map['id'],
      taskId: map['taskId'],
      content: map['content'],
      type: NoteType.values[map['type'] ?? 0],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

class QuranProgress {
  final int unitId; // Surah Number (1-114)
  final bool isMemorized;
  final int revisionCount;
  final DateTime? lastRevisedAt;

  QuranProgress({
    required this.unitId,
    required this.isMemorized,
    required this.revisionCount,
    this.lastRevisedAt,
  });

  factory QuranProgress.fromMap(Map<String, dynamic> map) {
    return QuranProgress(
      unitId: map['unitId'],
      isMemorized: (map['isMemorized'] ?? 0) == 1,
      revisionCount: map['revisionCount'] ?? 0,
      lastRevisedAt: map['lastRevisedAt'] != null
          ? DateTime.parse(map['lastRevisedAt'])
          : null,
    );
  }
}
