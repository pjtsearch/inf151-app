import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _startingChildSession = false;

  Future<void> _startChildSession() async {
    if (_startingChildSession) return;
    setState(() => _startingChildSession = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'operation-not-allowed'
          ? 'Child access is not enabled yet. Please ask a parent for help.'
          : 'Could not start child access. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start child access. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _startingChildSession = false);
    }
  }

  Future<void> _openParentSignIn() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const LoginPage()),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                Text('Welcome to GoalPunch', style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Little wins, together.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.eco_outlined, size: 72, color: colors.onTertiaryContainer),
                      const SizedBox(width: 22),
                      Icon(Icons.auto_awesome, size: 34, color: colors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Who’s using GoalPunch today?', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _startingChildSession ? null : _openParentSignIn,
                    child: const Text('I’m a parent'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: FilledButton.tonal(
                    onPressed: _startingChildSession ? null : _startChildSession,
                    child: _startingChildSession
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('I’m a child'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
