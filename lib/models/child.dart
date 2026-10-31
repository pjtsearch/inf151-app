import 'dart:convert';
import 'dart:typed_data';

import 'child_color.dart';

class Child {
  const Child({
    required this.id,
    required this.name,
    this.photoBytes,
    this.color = ChildColor.blue,
  });

  final String id;
  final String name;
  final Uint8List? photoBytes;
  final ChildColor color;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'photo': photoBytes == null ? null : base64Encode(photoBytes!),
    'color': color.name,
  };

  factory Child.fromJson(Map<String, dynamic> json) => Child(
    id: json['id'] as String,
    name: json['name'] as String,
    color: ChildColor.fromJson(json['color']),
    photoBytes: json['photo'] == null
        ? null
        : base64Decode(json['photo'] as String),
  );
}
