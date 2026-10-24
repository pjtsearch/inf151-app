import 'package:flutter/material.dart';

import 'screens/goals_page.dart';

class GoalApp extends StatelessWidget {
  const GoalApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF5EF9F);
    final palette = ColorScheme.fromSeed(seedColor: primary);
    final colors = palette.copyWith(
      primary: primary,
      onPrimary: palette.onPrimaryContainer,
    );

    return MaterialApp(
      title: 'GoalPunch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
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
