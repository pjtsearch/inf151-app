import 'package:flutter/material.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final _requests = <_ChildRequest>[
    const _ChildRequest(
      name: 'Jordan Lee',
      child: 'Mia',
      icon: Icons.person,
      color: Color(0xFFB9D8C2),
    ),
    const _ChildRequest(
      name: 'Taylor Morgan',
      child: 'Ethan',
      icon: Icons.face_rounded,
      color: Color(0xFFF2D2A9),
    ),
  ];

  void _respond(_ChildRequest request, bool accepted) {
    setState(() => _requests.remove(request));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Request from ${request.name} accepted.'
              : 'Request from ${request.name} denied.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _requests.isEmpty
                ? const Center(child: Text('No requests right now.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: request.color,
                                child: Icon(request.icon, color: Colors.black87),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(request.name,
                                        style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 3),
                                    Text('Wants to add ${request.child}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filled(
                                    tooltip: 'Accept request',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _respond(request, true),
                                    icon: const Icon(Icons.check),
                                  ),
                                  IconButton(
                                    tooltip: 'Deny request',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _respond(request, false),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ],
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
}

class _ChildRequest {
  const _ChildRequest({
    required this.name,
    required this.child,
    required this.icon,
    required this.color,
  });

  final String name;
  final String child;
  final IconData icon;
  final Color color;
}
