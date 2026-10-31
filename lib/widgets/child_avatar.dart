import 'package:flutter/material.dart';

import '../models/child.dart';

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.child, this.radius = 14});

  final Child child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = child.photoBytes;
    final placeholder = Text(
      child.name.characters.firstOrNull?.toUpperCase() ?? '?',
      style: TextStyle(fontSize: radius),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: child.color.background,
      foregroundColor: child.color.foreground,
      child: photo == null
          ? placeholder
          : ClipOval(
              child: Image.memory(
                photo,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
