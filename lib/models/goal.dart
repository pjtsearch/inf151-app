enum FrequencyUnit { day, week, month }

enum DurationUnit { day, week, month }

sealed class GoalReward {
  const GoalReward();
  String get label;
  Map<String, Object?> toJson();

  factory GoalReward.fromJson(Object? value) {
    if (value is Map<String, dynamic>) {
      if (value['type'] == 'etsy') return EtsyProductReward.fromJson(value);
      return FreeTextReward(value['text'] as String? ?? '');
    }
    return FreeTextReward(value as String? ?? '');
  }
}

class FreeTextReward extends GoalReward {
  const FreeTextReward(this.text);
  final String text;
  @override
  String get label => text;
  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};
}

class EtsyProductReward extends GoalReward {
  const EtsyProductReward({required this.listingId, required this.title, required this.url, this.price = '', this.imageUrl = ''});
  final String listingId;
  final String title;
  final String url;
  final String price;
  final String imageUrl;
  @override
  String get label => title;
  @override
  Map<String, Object?> toJson() => {'type': 'etsy', 'listingId': listingId, 'title': title, 'url': url, 'price': price, 'imageUrl': imageUrl};
  factory EtsyProductReward.fromJson(Map<String, dynamic> json) => EtsyProductReward(
    listingId: json['listingId'] as String? ?? '', title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '', price: json['price'] as String? ?? '', imageUrl: json['imageUrl'] as String? ?? '',
  );
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.frequency,
    required this.frequencyUnit,
    required this.duration,
    required this.durationUnit,
    required this.startDate,
    this.reward = const FreeTextReward(''),
    this.completedTasks = 0,
  });

  final String id;
  final String title;
  final int frequency;
  final FrequencyUnit frequencyUnit;
  final int duration;
  final DurationUnit durationUnit;
  final DateTime startDate;
  final GoalReward reward;
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
    GoalReward? reward,
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
    'reward': reward.toJson(),
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
    reward: GoalReward.fromJson(json['reward']),
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
