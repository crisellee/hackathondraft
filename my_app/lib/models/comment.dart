import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String concernId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isInternal; // NEW: To identify private admin notes

  Comment({
    required this.id,
    required this.concernId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isInternal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'concernId': concernId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isInternal': isInternal,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map, String id) {
    return Comment(
      id: id,
      concernId: map['concernId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isInternal: map['isInternal'] ?? false,
    );
  }
}
