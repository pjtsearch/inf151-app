import 'package:flutter/material.dart';

import 'screens/goals_page.dart';

class GoalApp extends StatelessWidget {
  const GoalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoalPunch',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const GoalsPage(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const brandColor = Color(0xFFF5EF9F);
  final isLight = brightness == Brightness.light;
  final colors = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
    primaryContainer: isLight ? brandColor : null,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
    ),
    scaffoldBackgroundColor: isLight ? const Color(0xFFF7F8F5) : colors.surface,
    cardTheme: CardThemeData(
      color: isLight
          ? colors.surfaceContainerLowest
          : colors.surfaceContainerLow,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        side: BorderSide(
          color: isLight ? const Color(0xFFDDE3DC) : colors.outlineVariant,
        ),
      ),
    ),
  );
}
