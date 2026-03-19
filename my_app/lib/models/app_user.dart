import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? department;
  final String? profileImageUrl;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.department,
    this.profileImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'department': department,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'student',
      department: map['department'],
      profileImageUrl: map['profileImageUrl'],
    );
  }

  AppUser copyWith({
    String? name,
    String? department,
    String? profileImageUrl,
  }) {
    return AppUser(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role,
      department: department ?? this.department,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
