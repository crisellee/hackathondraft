import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/concern.dart';
import '../models/audit_trail.dart';
import '../models/comment.dart';
import 'notification_service.dart';

final concernServiceProvider = Provider((ref) => ConcernService());

class ConcernService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService();
  final _uuid = const Uuid();

  Future<void> submitConcern(Concern concern) async {
    final docRef = _db.collection('concerns').doc(concern.id);

    try {
      await docRef.set(concern.toMap());
      
      await _logAction(
        concernId: concern.id,
        actorId: concern.studentId,
        action: 'SUBMITTED',
        details: 'Concern submitted in category: ${concern.category.name.toUpperCase()}',
      );

      _notifications.sendStatusUpdateNotification(
          concern.studentId,
          concern.title,
          'Your concern has been submitted successfully.'
      );

      await _executeAutoRouting(concern);
    } catch (e) {
      debugPrint("Firestore Submit Error: $e");
    }
  }

  Future<void> addComment(Comment comment) async {
    try {
      await _db.collection('comments').doc(comment.id).set(comment.toMap());
      await _logAction(
        concernId: comment.concernId,
        actorId: comment.senderId,
        action: 'MESSAGE',
        details: 'New message from ${comment.senderName}',
      );
    } catch (e) {
      debugPrint("Comment error: $e");
    }
  }

  Stream<List<Comment>> getComments(String concernId) {
    return _db.collection('comments')
        .where('concernId', isEqualTo: concernId)
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs.map((doc) => Comment.fromMap(doc.data(), doc.id)).toList();
          comments.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return comments;
        });
  }

  Future<void> _executeAutoRouting(Concern concern) async {
    String targetDept = 'GENERAL ADMINISTRATION';
    switch (concern.category) {
      case ConcernCategory.academic:
        targetDept = "DEAN'S OFFICE";
        break;
      case ConcernCategory.financial:
        targetDept = "BURSAR OFFICE";
        break;
      case ConcernCategory.welfare:
        targetDept = "STUDENT SERVICES";
        break;
    }

    try {
      await _db.collection('concerns').doc(concern.id).update({
        'status': ConcernStatus.routed.name,
        'assignedTo': targetDept,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      await _logAction(
        concernId: concern.id,
        actorId: 'SYSTEM',
        action: 'ROUTED',
        details: 'Automatically routed to $targetDept based on category.',
      );
    } catch (e) {
      debugPrint("Routing error: $e");
    }
  }

  Future<void> updateStatus(String id, ConcernStatus status, String actorId) async {
    try {
      final doc = await _db.collection('concerns').doc(id).get();
      if (!doc.exists) return;
      final concern = Concern.fromMap(doc.data()!, doc.id);

      final updates = {
        'status': status.name,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      
      if (status == ConcernStatus.read) updates['readAt'] = FieldValue.serverTimestamp();
      if (status == ConcernStatus.resolved) updates['resolvedAt'] = FieldValue.serverTimestamp();

      await _db.collection('concerns').doc(id).update(updates);

      await _logAction(
        concernId: id,
        actorId: actorId,
        action: 'STATUS_UPDATE',
        details: 'Status changed to ${status.name.toUpperCase()}',
      );

      _notifications.sendStatusUpdateNotification(
          concern.studentId,
          concern.title,
          'Your concern status has been updated to: ${status.name.toUpperCase()}'
      );
    } catch (e) {
      debugPrint("Status update error: $e");
    }
  }

  Future<void> enforceSLA() async {
    final now = DateTime.now();
    try {
      final routedSnapshot = await _db.collection('concerns').get();

      for (var doc in routedSnapshot.docs) {
        final concern = Concern.fromMap(doc.data(), doc.id);
        if (concern.status == ConcernStatus.resolved || concern.status == ConcernStatus.escalated) continue;

        if ((concern.status == ConcernStatus.submitted || concern.status == ConcernStatus.routed) && 
            now.difference(concern.createdAt).inDays >= 2) {
          await _escalateSLA(concern, 'SLA BREACH: Not read by department for > 2 days.');
          continue;
        }

        if (concern.status == ConcernStatus.read) {
          final lastUpdate = concern.lastUpdatedAt ?? concern.createdAt;
          if (now.difference(lastUpdate).inDays >= 5) {
            await _escalateSLA(concern, 'SLA BREACH: No screening action for > 5 days after reading.');
          }
        }
      }
    } catch (e) {
      debugPrint("SLA Audit Error: $e");
    }
  }

  Future<void> _escalateSLA(Concern concern, String reason) async {
    if (concern.status == ConcernStatus.escalated) return;

    try {
      await _db.collection('concerns').doc(concern.id).update({
        'status': ConcernStatus.escalated.name,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      await _logAction(
        concernId: concern.id,
        actorId: 'SYSTEM_SLA',
        action: 'ESCALATION',
        details: reason,
      );

      _notifications.sendStatusUpdateNotification(
          concern.studentId,
          concern.title,
          'URGENT: Your concern has been auto-escalated due to delayed processing.'
      );
    } catch (e) {
      debugPrint("Escalation error: $e");
    }
  }

  Future<void> _logAction({
    required String concernId,
    required String actorId,
    required String action,
    required String details,
  }) async {
    final logId = _uuid.v4();
    final log = AuditLog(
      id: logId,
      concernId: concernId,
      actorId: actorId,
      action: action,
      timestamp: DateTime.now(),
      details: details,
    );
    await _db.collection('audit_logs').doc(logId).set(log.toMap());
  }

  Stream<List<Concern>> getConcerns() {
    return _db.collection('concerns').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => Concern.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Concern>> getConcernsByStudent(String studentId) {
    return _db.collection('concerns')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final concerns = snapshot.docs.map((doc) => Concern.fromMap(doc.data(), doc.id)).toList();
          concerns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return concerns;
        });
  }

  Stream<List<AuditLog>> getAuditTrail(String concernId) {
    return _db.collection('audit_logs')
        .where('concernId', isEqualTo: concernId)
        .snapshots()
        .map((snapshot) {
          final logs = snapshot.docs.map((doc) => AuditLog.fromMap(doc.data(), doc.id)).toList();
          logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return logs;
        });
  }

  Future<void> updateAssignedDepartment(String id, String department, String actorId) async {
    try {
      await _db.collection('concerns').doc(id).update({
        'assignedTo': department,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      await _logAction(
        concernId: id,
        actorId: actorId,
        action: 'DEPARTMENT_UPDATE',
        details: 'Concern re-assigned to $department department',
      );
    } catch (e) {
      debugPrint("Update department error: $e");
    }
  }

  /// NEW: Clear all concerns (Clean up data)
  Future<void> clearAllConcerns() async {
    try {
      final concerns = await _db.collection('concerns').get();
      final comments = await _db.collection('comments').get();
      final logs = await _db.collection('audit_logs').get();

      WriteBatch batch = _db.batch();
      
      for (var doc in concerns.docs) batch.delete(doc.reference);
      for (var doc in comments.docs) batch.delete(doc.reference);
      for (var doc in logs.docs) batch.delete(doc.reference);

      await batch.commit();
    } catch (e) {
      debugPrint("Error clearing concerns: $e");
    }
  }
}
