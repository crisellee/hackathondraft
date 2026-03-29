import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>?> login(String email, String password, String expectedRole) async {
    try {
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
      
      // Fallback for Demo Accounts: Auto-create in Firestore if they don't exist
      if (expectedRole == 'admin' && email == 'admin@test.com' && password == 'admin123') {
        await _ensureUserExists('admin_user', email, 'Admin Staff', 'admin');
        return {'id': 'admin_user', 'role': 'admin', 'name': 'Admin Staff'};
      }
      if (expectedRole == 'student' && email == 'student@test.com' && password == 'student123') {
        await _ensureUserExists('student_123', email, 'Juan Dela Cruz', 'student');
        return {'id': 'student_123', 'role': 'student', 'name': 'Juan Dela Cruz'};
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _ensureUserExists(String id, String email, String name, String role) async {
    final doc = await _db.collection('users').doc(id).get();
    if (!doc.exists) {
      await _db.collection('users').doc(id).set({
        'email': email.toLowerCase(),
        'password': role == 'admin' ? 'admin123' : 'student123',
        'name': name,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> registerStudent({
    required String email,
    required String password,
    required String name,
    required String studentId,
  }) async {
    try {
      await _db.collection('users').doc(studentId).set({
        'email': email.toLowerCase(),
        'password': password,
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
      final query = await _db.collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
