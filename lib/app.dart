import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'screens/goals_page.dart';
import 'screens/login_page.dart';
import 'services/goal_reminder_service.dart';

class GoalApp extends StatelessWidget {
  const GoalApp({super.key, this.reminderService, this.firebaseError});

  final GoalReminderService? reminderService;
  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoalPunch',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: firebaseError != null
          ? FirebaseSetupPage(error: firebaseError!)
          : AuthGate(
              signedIn: GoalsPage(reminderService: reminderService),
              signedOut: const LoginPage(),
            ),
    );
  }
}

class FirebaseSetupPage extends StatelessWidget {
  const FirebaseSetupPage({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connect Firebase', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text('Run `flutterfire configure` for this project, then restart the app.'),
              const SizedBox(height: 12),
              Text('$error', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );
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
