import 'dart:ui';

enum ChildColor {
  red('Red', Color(0xFFFFCDD2), Color(0xFF7F1D1D)),
  orange('Orange', Color(0xFFFFE0B2), Color(0xFF78350F)),
  yellow('Yellow', Color(0xFFFFF59D), Color(0xFF624B00)),
  green('Green', Color(0xFFC8E6C9), Color(0xFF1B5E20)),
  teal('Teal', Color(0xFFB2DFDB), Color(0xFF004D40)),
  blue('Blue', Color(0xFFBBDEFB), Color(0xFF0D47A1)),
  purple('Purple', Color(0xFFE1BEE7), Color(0xFF4A148C)),
  pink('Pink', Color(0xFFF8BBD0), Color(0xFF880E4F));

  const ChildColor(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  static ChildColor fromJson(Object? value) =>
      values.firstWhere((color) => color.name == value, orElse: () => blue);
}
