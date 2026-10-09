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
  });

  final String id;
  final String title;
  final int frequency;
  final FrequencyUnit frequencyUnit;
  final int duration;
  final DurationUnit durationUnit;
  final DateTime startDate;
  final String reward;

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

  bool isPastOn(DateTime date) => !date.isBefore(endDate);

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
  }) => Goal(
    id: id ?? this.id,
    title: title ?? this.title,
    frequency: frequency ?? this.frequency,
    frequencyUnit: frequencyUnit ?? this.frequencyUnit,
    duration: duration ?? this.duration,
    durationUnit: durationUnit ?? this.durationUnit,
    startDate: startDate ?? this.startDate,
    reward: reward ?? this.reward,
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
  );
}
