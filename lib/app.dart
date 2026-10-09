import 'package:flutter/material.dart';

import 'screens/goals_page.dart';

class GoalApp extends StatelessWidget {
  const GoalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Goals',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B5B)),
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
