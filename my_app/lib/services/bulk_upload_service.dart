import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/concern.dart';

class BulkUploadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates mock concerns with specific status distribution:
  /// 55 Total: 20 Resolved, 25 Routed, 10 Escalated
  Future<int> generateMockData(String currentUserId) async {
    int count = 0;
    WriteBatch batch = _db.batch();
    final random = Random();

    final studentNames = [
      'Juan Dela Cruz', 'Maria Clara', 'Jose Rizal', 'Andres Bonifacio', 
      'Emilio Aguinaldo', 'Apolinario Mabini', 'Melchora Aquino', 'Gabriela Silang'
    ];
    
    final titles = [
      'Tuition Fee Discrepancy', 'Missing Grade in Math', 'Request for ID Replacement',
      'Scholarship Application Status', 'Library Fines Inquiry', 'Class Schedule Conflict',
      'Mental Health Support Request', 'Internet Connection in Dorm', 'Laboratory Equipment Damage',
      'Dean\'s Lister Verification', 'DL Requirements Inquiry'
    ];

    final depts = ['COA', 'COE', 'CCS', 'CBAE'];

    // 20 Resolved
    for (int i = 0; i < 20; i++) {
      await _addMockConcern(batch, currentUserId, ConcernStatus.resolved, studentNames, titles, depts, random);
      count++;
    }

    // 25 Routed
    for (int i = 0; i < 25; i++) {
      await _addMockConcern(batch, currentUserId, ConcernStatus.routed, studentNames, titles, depts, random);
      count++;
    }

    // 10 Escalated
    for (int i = 0; i < 10; i++) {
      await _addMockConcern(batch, currentUserId, ConcernStatus.escalated, studentNames, titles, depts, random);
      count++;
    }

    await batch.commit();
    return count;
  }

  Future<void> _addMockConcern(
    WriteBatch batch, 
    String userId, 
    ConcernStatus status, 
    List<String> names, 
    List<String> titles, 
    List<String> depts,
    Random random
  ) async {
    final id = const Uuid().v4();
    final dept = depts[random.nextInt(depts.length)];
    final date = DateTime.now().subtract(Duration(days: random.nextInt(15)));

    // Determine target office based on random category for mock data
    final category = ConcernCategory.values[random.nextInt(ConcernCategory.values.length)];
    String assignedTo = "DEAN'S OFFICE";
    if (category == ConcernCategory.financial) assignedTo = "FINANCE OFFICE";
    if (category == ConcernCategory.welfare) assignedTo = "STUDENT AFFAIRS";

    final concern = Concern(
      id: id,
      studentId: userId,
      studentName: names[random.nextInt(names.length)],
      department: dept,
      title: titles[random.nextInt(titles.length)],
      description: 'Automated sample concern for testing distribution.',
      category: category,
      status: status,
      createdAt: date,
      lastUpdatedAt: date.add(const Duration(hours: 5)),
      isAnonymous: false,
      attachments: [],
      program: dept,
      assignedTo: assignedTo,
    );

    final docRef = _db.collection('concerns').doc(id);
    batch.set(docRef, concern.toMap());

    // Add Audit Logs for professional look in mock data
    _addMockAuditLog(batch, id, userId, 'SUBMITTED', 'Concern submitted by student.', date);
    _addMockAuditLog(batch, id, 'SYSTEM', 'ROUTED', 'Automatically routed to $assignedTo based on category.', date.add(const Duration(seconds: 10)));

    if (status == ConcernStatus.escalated) {
      _addMockAuditLog(batch, id, 'SYSTEM_SLA', 'ESCALATION', 'Auto-escalated due to SLA breach (Overdue).', date.add(const Duration(days: 3)));
    }
  }

  void _addMockAuditLog(WriteBatch batch, String concernId, String actorId, String action, String details, DateTime timestamp) {
    final logId = const Uuid().v4();
    final logRef = _db.collection('audit_logs').doc(logId);
    batch.set(logRef, {
      'id': logId,
      'concernId': concernId,
      'actorId': actorId,
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    });
  }

  Future<int> importConcernsFromCSV() async {
    return 0; // Not used
  }
}
