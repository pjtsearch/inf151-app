import 'package:flutter/material.dart';

class _Tutorial {
  const _Tutorial(this.title, this.steps);

  final String title;
  final List<String> steps;
}

const _tutorials = [
  _Tutorial('Setting up as a Parent', [
    'Tap “I’m a parent”.',
    'Tap “Create a parent account”.',
    'Enter your account information, or tap “Continue with Google” to sign in with your Google account.',
    'Tap “Create account”.',
  ]),
  _Tutorial('Adding a goal', [
    'Tap “Add goal” at the bottom of the screen.',
    'Select the child you want the goal to be for.',
    'Enter the goal, the reward you want for your child, the frequency, the duration, and the starting date.',
    'The frequency is how often you want the goal to be done in the period starting from the starting date and lasting for the duration you specified.',
    'Tap “Save goal”.',
  ]),
  _Tutorial('Scanning a card', [
    'Tap the “Scan card” button at the bottom of the screen.',
    'Position the entire card in the camera viewfinder. It is best to place it on a dark background.',
    'Tap the “Scan” button.',
    'Verify the scanner reading, and adjust the number of hole punches detected if necessary.',
  ]),
  _Tutorial('Adding a child from another parent', [
    'Tap the children button at the top of the screen.',
    'Tap the “Add child” button.',
    'Tap “Link an existing child”.',
    'Ask the other parent to go to the children screen, tap the desired child, and show you the QR code.',
    'Position the QR code in the viewfinder and tap “Scan QR code”.',
  ]),
];

class TutorialsPage extends StatelessWidget {
  const TutorialsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _tutorials.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tutorial = _tutorials[index];
              return ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(tutorial.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _TutorialDetailPage(tutorial: tutorial),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _TutorialDetailPage extends StatelessWidget {
  const _TutorialDetailPage({required this.tutorial});

  final _Tutorial tutorial;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tutorial.title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: tutorial.steps.length,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final isFrequencyNote =
                  tutorial.title == 'Adding a goal' && index == 3;
              final stepLabel = tutorial.title == 'Adding a goal'
                  ? (isFrequencyNote ? '3.1' : '${index < 3 ? index + 1 : 4}.')
                  : '${index + 1}.';
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: isFrequencyNote ? 48 : 36,
                    child: Text(
                      stepLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tutorial.steps[index],
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
