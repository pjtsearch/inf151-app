enum FrequencyUnit { day, week, month }

enum DurationUnit { day, week, month }

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.frequency,
    required this.frequencyUnit,
    required this.duration,
    required this.durationUnit,
    required this.startDate,
    this.reward = '',
    this.completedTasks = 0,
  });

  final String id;
  final String title;
  final int frequency;
  final FrequencyUnit frequencyUnit;
  final int duration;
  final DurationUnit durationUnit;
  final DateTime startDate;
  final String reward;
  final int completedTasks;

  int get totalTasks {
    if (frequency <= 0 || duration <= 0) return 0;
    final periods = switch (frequencyUnit) {
      FrequencyUnit.day => switch (durationUnit) {
        DurationUnit.day => duration,
        DurationUnit.week => duration * 7,
        DurationUnit.month => endDate.difference(startDate).inDays + 1,
      },
      FrequencyUnit.week => switch (durationUnit) {
        DurationUnit.day => (duration / 7).ceil(),
        DurationUnit.week => duration,
        DurationUnit.month => duration * 4,
      },
      FrequencyUnit.month => switch (durationUnit) {
        DurationUnit.day => (duration / 30).ceil(),
        DurationUnit.week => (duration / 4).ceil(),
        DurationUnit.month => duration,
      },
    };
    return periods * frequency;
  }

  DateTime get endDate {
    switch (durationUnit) {
      case DurationUnit.day:
        return startDate.add(Duration(days: duration));
      case DurationUnit.week:
        return startDate.add(Duration(days: duration * 7));
      case DurationUnit.month:
        final month = startDate.month + duration;
        final lastDay = DateTime(startDate.year, month + 1, 0).day;
        return DateTime(startDate.year, month, startDate.day.clamp(1, lastDay));
    }
  }

  bool get hasCompletedAllTasks =>
      totalTasks > 0 && completedTasks >= totalTasks;

  bool isPastOn(DateTime date) =>
      hasCompletedAllTasks ||
      !date.isBefore(endDate.add(const Duration(days: 1)));

  String get frequencyDescription {
    final unit = switch (frequencyUnit) {
      FrequencyUnit.day => 'day',
      FrequencyUnit.week => 'week',
      FrequencyUnit.month => 'month',
    };
    return '$frequency time${frequency == 1 ? '' : 's'} per $unit';
  }

  Goal copyWith({
    String? id,
    String? title,
    int? frequency,
    FrequencyUnit? frequencyUnit,
    int? duration,
    DurationUnit? durationUnit,
    DateTime? startDate,
    String? reward,
    int? completedTasks,
  }) => Goal(
    id: id ?? this.id,
    title: title ?? this.title,
    frequency: frequency ?? this.frequency,
    frequencyUnit: frequencyUnit ?? this.frequencyUnit,
    duration: duration ?? this.duration,
    durationUnit: durationUnit ?? this.durationUnit,
    startDate: startDate ?? this.startDate,
    reward: reward ?? this.reward,
    completedTasks: completedTasks ?? this.completedTasks,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'frequency': frequency,
    'frequencyUnit': frequencyUnit.name,
    'duration': duration,
    'durationUnit': durationUnit.name,
    'startDate': startDate.toIso8601String(),
    'reward': reward,
    'completedTasks': completedTasks,
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    title: json['title'] as String,
    frequency: json['frequency'] as int,
    frequencyUnit: FrequencyUnit.values.byName(json['frequencyUnit'] as String),
    duration: json['duration'] as int,
    durationUnit: DurationUnit.values.byName(json['durationUnit'] as String),
    startDate: DateTime.parse(json['startDate'] as String),
    reward: json['reward'] as String? ?? '',
    completedTasks: json['completedTasks'] as int? ??
        ((json['isCompleted'] as bool? ?? false) ? _legacyCompletedTaskCount(json) : 0),
  );
}

int _legacyCompletedTaskCount(Map<String, dynamic> json) {
  final goal = Goal(
    id: json['id'] as String,
    title: json['title'] as String,
    frequency: json['frequency'] as int,
    frequencyUnit: FrequencyUnit.values.byName(json['frequencyUnit'] as String),
    duration: json['duration'] as int,
    durationUnit: DurationUnit.values.byName(json['durationUnit'] as String),
    startDate: DateTime.parse(json['startDate'] as String),
  );
  return goal.totalTasks;
}
