import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concern.dart';

final aiServiceProvider = Provider((ref) => AIService());

class AIService {
  /// Simulates AI-powered Auto-Routing / Categorization
  Future<Map<String, dynamic>> analyzeConcern(String description) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final text = description.toLowerCase();
    
    ConcernCategory category = ConcernCategory.academic;
    String targetOffice = "DEAN'S OFFICE";
    int score = 0;

    // Keywords updated based on user requirements
    final financialKeywords = [
      'tuition', 'refund', 'payment', 'balance', 'fee', 'bayad', 'pondo', 'billing', 'account'
    ];

    final welfareKeywords = [
      'id', 'id replacement', 'lost id', 'id card', 'uniform', 'dress code', 
      'scholar', 'scholarship', 'tes', 'tdp', 'mental', 'guidance', 'osa', 'student affairs'
    ];

    final academicKeywords = [
      'grade', 'grades', 'marka', 'equivalent', 'crediting', 'tor', 'transcript', 
      'shifting', 'overload', 'subject', 'professor', 'dean', 'dean\'s lister', 'dl'
    ];

    // ROUTING LOGIC WITH SPECIFIC PRIORITY
    bool isFinancial = financialKeywords.any((word) => text.contains(word));
    bool isWelfare = welfareKeywords.any((word) => text.contains(word));
    bool isAcademic = academicKeywords.any((word) => text.contains(word));

    // Priority: ID/Welfare > Financial > Academic
    if (isWelfare) {
      category = ConcernCategory.welfare;
      targetOffice = "STUDENT AFFAIRS";
      score = 2;
    } else if (isFinancial) {
      category = ConcernCategory.financial;
      targetOffice = "FINANCE OFFICE";
      score = 2;
    } else if (isAcademic) {
      category = ConcernCategory.academic;
      targetOffice = "DEAN'S OFFICE";
      score = 2;
    }

    // Dynamic confidence based on keyword matches
    String confidence = score > 0 ? "92%" : "65%";

    return {
      'category': category,
      'department': targetOffice,
      'confidence': confidence,
      'ai_summary': 'Automatically routed to $targetOffice based on concern content analysis.'
    };
  }

  /// Simulates AI Status Prediction / SLA Assistance
  String predictSLARisk(Concern concern) {
    final now = DateTime.now();
    final hoursOpen = now.difference(concern.createdAt).inHours;

    if (concern.status == ConcernStatus.resolved) return 'Low (Resolved)';

    if (hoursOpen > 48 && (concern.status == ConcernStatus.submitted || concern.status == ConcernStatus.routed)) {
      return 'Critical (SLA Breach)';
    } else if (hoursOpen > 24) {
      return 'High (At Risk)';
    }

    return 'Low (Normal)';
  }

  /// Simple Chatbot logic for student support
  String getChatbotResponse(String message) {
    final text = message.toLowerCase();
    
    if (text.contains('id')) {
      return "Para sa ID concerns (Lost/Replacement), mangyaring pumunta sa Student Affairs (OSA) sa Ground Floor. Maghanda ng Affidavit of Loss kung nawala ang ID.";
    } else if (text.contains('bayad') || text.contains('tuition')) {
      return "Ang lahat ng tungkol sa tuition at payments ay pinoproseso sa Finance Office. Maaari niyo ring i-check ang inyong balance sa official student portal.";
    } else if (text.contains('grade') || text.contains('equivalent')) {
      return "Para sa grade discrepancies o evaluation ng equivalents, mangyaring makipag-ugnayan sa Dean's Office ng inyong departamento.";
    }
    
    return "I've noted your message. A staff member will review your concern and get back to you shortly.";
  }
}
