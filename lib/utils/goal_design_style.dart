import 'package:flutter/material.dart';

import '../models/punch_card_design.dart';

extension GoalDesignStyle on PunchCardDesign {
  Color get seedColor => switch (this) {
    PunchCardDesign.classic => const Color(0xFF006F64),
    PunchCardDesign.ocean => const Color(0xFF174978),
    PunchCardDesign.sunset => const Color(0xFF9D432B),
    PunchCardDesign.inkSaver => const Color(0xFF444444),
  };

  Color get cardBackgroundColor => switch (this) {
    PunchCardDesign.classic => const Color(0xFFDFF2E9),
    PunchCardDesign.ocean => const Color(0xFFE9F7FC),
    PunchCardDesign.sunset => const Color(0xFFFFF4DF),
    PunchCardDesign.inkSaver => Colors.white,
  };

  Color get cardBorderColor => switch (this) {
    PunchCardDesign.classic => const Color(0xFF006F64),
    PunchCardDesign.ocean => const Color(0xFF174978),
    PunchCardDesign.sunset => const Color(0xFF9D432B),
    PunchCardDesign.inkSaver => const Color(0xFF444444),
  };

  IconData get icon => switch (this) {
    PunchCardDesign.classic => Icons.auto_awesome,
    PunchCardDesign.ocean => Icons.waves,
    PunchCardDesign.sunset => Icons.wb_twilight,
    PunchCardDesign.inkSaver => Icons.draw_outlined,
  };

  ColorScheme colorScheme(Brightness brightness) => ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: this == PunchCardDesign.inkSaver
        ? DynamicSchemeVariant.monochrome
        : DynamicSchemeVariant.tonalSpot,
  );
}
