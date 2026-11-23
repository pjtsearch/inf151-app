import '../services/punch_card_background.dart';

enum PunchCardDesign {
  classic('Classic stars', punchCardBackgroundSvg),
  ocean('Ocean waves', oceanPunchCardBackgroundSvg),
  sunset('Sunset hills', sunsetPunchCardBackgroundSvg),
  inkSaver('Ink saver', inkSaverPunchCardBackgroundSvg);

  const PunchCardDesign(this.label, this.backgroundSvg);

  final String label;
  final String backgroundSvg;
  static PunchCardDesign fromJson(Object? value) => values.firstWhere(
    (design) => design.name == value,
    orElse: () => classic,
  );
}
