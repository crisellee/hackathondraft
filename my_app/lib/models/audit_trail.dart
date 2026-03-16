import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLog {
  final String id;
  final String concernId;
  final String actorId;
  final String action;
  final String details;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.concernId,
    required this.actorId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'concernId': concernId,
      'actorId': actorId,
      'action': action,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map, String id) {
    return AuditLog(
      id: id,
      concernId: map['concernId'] ?? '',
      actorId: map['actorId'] ?? '',
      action: map['action'] ?? '',
      details: map['details'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
