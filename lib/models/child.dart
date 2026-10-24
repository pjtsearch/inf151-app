import 'dart:convert';
import 'dart:typed_data';

class Child {
  const Child({required this.id, required this.name, this.photoBytes});

  final String id;
  final String name;
  final Uint8List? photoBytes;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'photo': photoBytes == null ? null : base64Encode(photoBytes!),
  };

  factory Child.fromJson(Map<String, dynamic> json) => Child(
    id: json['id'] as String,
    name: json['name'] as String,
    photoBytes: json['photo'] == null
        ? null
        : base64Decode(json['photo'] as String),
  );
}
