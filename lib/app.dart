import 'package:flutter/material.dart';

import 'screens/goals_page.dart';

class GoalApp extends StatelessWidget {
  const GoalApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFF5EF9F);
    final colors = ColorScheme.fromSeed(
      seedColor: brandColor,
      primaryContainer: brandColor,
    );

    return MaterialApp(
      title: 'GoalPunch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: Color(0xFFDDE3DC)),
          ),
        ),
      ),
      home: const GoalsPage(),
    );
  }
}
