class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
  }) : assert(hour >= 0 && hour < 24),
       assert(minute >= 0 && minute < 60);

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  static ReminderSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const ReminderSettings();
    final hour = value['hour'];
    final minute = value['minute'];
    if (hour is! int ||
        minute is! int ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return const ReminderSettings();
    }
    return ReminderSettings(
      enabled: value['enabled'] == true,
      hour: hour,
      minute: minute,
    );
  }
}
