import 'package:cloud_firestore/cloud_firestore.dart';


enum ConcernCategory { academic, financial, welfare }


enum ConcernStatus { submitted, routed, read, screened, resolved, escalated }


class Concern {
  final String id;
  final String studentId;
  final String studentName;
  final String department;
  final String title;
  final String description;
  final ConcernCategory category;
  final ConcernStatus status;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;
  final bool isAnonymous;
  final List<String> attachments;
  final String? assignedTo;
  final String program;


  Concern({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.department,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    this.lastUpdatedAt,
    required this.isAnonymous,
    required this.attachments,
    this.assignedTo,
    required this.program,
  });


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': isAnonymous ? 'Anonymous' : studentName,
      'department': department,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': lastUpdatedAt != null ? Timestamp.fromDate(lastUpdatedAt!) : null,
      'isAnonymous': isAnonymous,
      'attachments': attachments,
      'assignedTo': assignedTo,
      'program': program,
    };
  }


  factory Concern.fromMap(Map<String, dynamic> map, String id) {
    return Concern(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      department: map['department'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: ConcernCategory.values.firstWhere((e) => e.name == map['category']),
      status: ConcernStatus.values.firstWhere((e) => e.name == map['status']),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdatedAt: (map['lastUpdatedAt'] as Timestamp?)?.toDate(),
      isAnonymous: map['isAnonymous'] ?? false,
      attachments: List<String>.from(map['attachments'] ?? []),
      assignedTo: map['assignedTo'],
      program: map['program'] ?? '',
    );
  }


  Concern copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? department,
    String? title,
    String? description,
    ConcernCategory? category,
    ConcernStatus? status,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    bool? isAnonymous,
    List<String>? attachments,
    String? assignedTo,
    String? program,
  }) {
    return Concern(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      department: department ?? this.department,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      attachments: attachments ?? this.attachments,
      assignedTo: assignedTo ?? this.assignedTo,
      program: program ?? this.program,
    );
  }
}
