import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';

final userServiceProvider = Provider((ref) => UserService());

final userDataProvider = StreamProvider.family<AppUser?, String>((ref, userId) {
  return ref.watch(userServiceProvider).getUserData(userId);
});

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<AppUser?> getUserData(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> updateProfile(AppUser user) async {
    await _db.collection('users').doc(user.id).update(user.toMap());
  }
}
