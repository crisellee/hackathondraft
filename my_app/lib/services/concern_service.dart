import 'package:cloud_firestore/cloud_firestore.dart';
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
      // Step 1: Save the original concern from student form
      await docRef.set(concern.toMap());
    } catch (e) {
      print("Firestore Error: \$e");
    }


    _logAction(
      concernId: concern.id,
      actorId: concern.studentId,
      action: 'Submitted',
      details: 'Concern submitted in category: \${concern.category.name} for department: \${concern.department}',
    );


    _notifications.sendStatusUpdateNotification(
        concern.studentId,
        concern.title,
        'Submitted successfully'
    );


    // Step 2: Update status to ROUTED without overwriting the student's department choice
    _routeConcern(concern.id, concern.department);
  }


  Future<void> addComment(Comment comment) async {
    try {
      await _db.collection('comments').doc(comment.id).set(comment.toMap());
    } catch (e) {
      print("Comment error: \$e");
    }

    _logAction(
      concernId: comment.concernId,
      actorId: comment.senderId,
      action: 'Comment',
      details: 'New comment from \${comment.senderName}',
    );
  }


  Stream<List<Comment>> getComments(String concernId) {
    return _db.collection('comments')
        .where('concernId', isEqualTo: concernId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Comment.fromMap(doc.data(), doc.id)).toList());
  }


  Future<void> _routeConcern(String id, String chosenDepartment) async {
    try {
      await _db.collection('concerns').doc(id).update({
        'status': ConcernStatus.routed.name,
        'assignedTo': chosenDepartment, // Use the department chosen in the form
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Routing error: \$e");
    }


    _logAction(
      concernId: id,
      actorId: 'system',
      action: 'Routed',
      details: 'Concern routed to \$chosenDepartment department as requested',
    );
  }


  Future<void> updateAssignedDepartment(String id, String department, String actorId) async {
    try {
      await _db.collection('concerns').doc(id).update({
        'assignedTo': department,
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Update department error: \$e");
    }


    _logAction(
      concernId: id,
      actorId: actorId,
      action: 'Department Update',
      details: 'Concern re-assigned to \$department department',
    );
  }


  Future<void> updateStatus(String id, ConcernStatus status, String actorId) async {
    String details = 'Status changed to \${status.name}';

    try {
      await _db.collection('concerns').doc(id).update({
        'status': status.name,
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Status update error: \$e");
    }


    _logAction(
      concernId: id,
      actorId: actorId,
      action: 'Status Update',
      details: details,
    );
  }


  Future<void> checkSLAEnforcement() async {
    final now = DateTime.now();

    final routedSnapshot = await _db.collection('concerns')
        .where('status', isEqualTo: ConcernStatus.routed.name)
        .get();


    for (var doc in routedSnapshot.docs) {
      final concern = Concern.fromMap(doc.data(), doc.id);
      if (now.difference(concern.createdAt).inDays >= 2) {
        _escalateSLA(concern, 'Auto-escalated due to >2 days in Routed status.');
      }
    }
  }


  Future<void> _escalateSLA(Concern concern, String reason) async {
    try {
      await _db.collection('concerns').doc(concern.id).update({
        'status': ConcernStatus.escalated.name,
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Escalation error: \$e");
    }


    _logAction(
      concernId: concern.id,
      actorId: 'system_sla',
      action: 'SLA Escalation',
      details: reason,
    );
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
    try {
      await _db.collection('audit_logs').doc(logId).set(log.toMap());
    } catch (e) {
      print("Log action error: \$e");
    }
  }


  Stream<List<Concern>> getConcerns() {
    return _db.collection('concerns').orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Concern.fromMap(doc.data(), doc.id)).toList(),
    );
  }


  Stream<List<Concern>> getConcernsByStudent(String studentId) {
    return _db.collection('concerns')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Concern.fromMap(doc.data(), doc.id)).toList());
  }


  Stream<List<AuditLog>> getAuditTrail(String concernId) {
    return _db.collection('audit_logs')
        .where('concernId', isEqualTo: concernId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AuditLog.fromMap(doc.data(), doc.id)).toList());
  }
}

