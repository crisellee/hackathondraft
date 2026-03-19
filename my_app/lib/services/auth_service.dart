import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>?> login(String email, String password, String expectedRole) async {
    try {
      // For real Firebase Auth integration:
      // UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      // But keeping your custom Firestore-based login logic for consistency with your previous data
      
      final query = await _db.collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .where('role', isEqualTo: expectedRole)
          .get();
      
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (data['password'] == password) {
          return {
            'id': query.docs.first.id,
            'role': data['role'],
            'name': data['name'] ?? 'User',
          };
        }
      }
      
      // Demo Fallback Accounts (Para sa Defense)
      if (expectedRole == 'admin' && email == 'admin@test.com' && password == 'admin123') {
        return {'id': 'admin_user', 'role': 'admin', 'name': 'Admin Staff'};
      }
      if (expectedRole == 'student' && email == 'student@test.com' && password == 'student123') {
        return {'id': 'student_123', 'role': 'student', 'name': 'Juan Dela Cruz'};
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<bool> registerStudent({
    required String email,
    required String password,
    required String name,
    required String studentId,
  }) async {
    try {
      // 1. Create in Firestore users collection
      await _db.collection('users').doc(studentId).set({
        'email': email.toLowerCase(),
        'password': password, // Note: In production, never store plain text passwords
        'name': name,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      // This sends a real Firebase password reset email if the user exists in Firebase Auth
      // For your custom Firestore setup, we can just simulate it or check if email exists
      final query = await _db.collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
