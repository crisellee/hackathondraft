import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concern.dart';

final aiServiceProvider = Provider((ref) => AIService());

class AIService {
  /// Simulates AI-powered Auto-Routing / Categorization
  Future<Map<String, dynamic>> analyzeConcern(String description) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final text = description.toLowerCase();
    
    ConcernCategory category = ConcernCategory.academic;
    String targetOffice = "DEAN'S OFFICE";
    int score = 0;

    // Keywords (expanded + Tagalog support)
    final financialKeywords = [
      'tuition', 'refund', 'payment', 'balance', 'fee', 'bayad', 'pondo'
    ];

    final welfareKeywords = [
      'mental', 'health', 'bullying', 'guidance', 'stress', 'harassment', 'uniform', 'id', 'scholar', 'scholarship'
    ];

    final academicKeywords = [
      'grade', 'subject', 'professor', 'exam', 'schedule', 'class', 'marka', 'guro', 'dean\'s lister', 'dl', 'lister'
    ];

    // Priority system (Financial > Welfare > Academic)
    for (var word in financialKeywords) {
      if (text.contains(word)) {
        category = ConcernCategory.financial;
        targetOffice = "FINANCE OFFICE";
        score++;
      }
    }

    for (var word in welfareKeywords) {
      if (text.contains(word)) {
        category = ConcernCategory.welfare;
        targetOffice = "STUDENT AFFAIRS";
        score++;
      }
    }

    for (var word in academicKeywords) {
      if (text.contains(word)) {
        category = ConcernCategory.academic;
        targetOffice = "DEAN'S OFFICE";
        score++;
      }
    }

    // Dynamic confidence
    String confidence = "${70 + (score * 5)}%";

    return {
      'category': category,
      'department': targetOffice, // This maps to assignedTo in concern_service
      'confidence': confidence,
      'ai_summary': 'Automatically identified as ${category.name.toUpperCase()} for $targetOffice based on detected keywords.'
    };
  }

  /// Simulates AI Status Prediction / SLA Assistance
  String predictSLARisk(Concern concern) {
    final now = DateTime.now();
    final hoursOpen = now.difference(concern.createdAt).inHours;

    if (concern.status == ConcernStatus.resolved) return 'Low (Resolved)';

    if (hoursOpen > 48 && concern.status == ConcernStatus.submitted) {
      return 'Critical (Overdue for Routing)';
    } else if (hoursOpen > 24 && concern.status == ConcernStatus.submitted) {
      return 'High (At risk of breaching SLA)';
    } else if (hoursOpen > 72 && concern.status != ConcernStatus.resolved) {
      return 'High (Stagnant ticket)';
    }

    return 'Low (Within timeframe)';
  }

  /// Simple Chatbot logic for student support
  String getChatbotResponse(String message) {
    final text = message.toLowerCase();
    
    if (text.contains('status') || text.contains('track')) {
      return "You can track your concern in the 'My Tracked Concerns' section. Most concerns are processed within 2-3 business days.";
    } else if (text.contains('hello') || text.contains('hi')) {
      return "Hello! I am ConcernTrack AI. How can I help you with your academic or campus concerns today?";
    } else if (text.contains('how long')) {
      return "Our standard processing time (SLA) is 48 hours for initial response and 5 days for resolution.";
    } else if (text.contains('dean\'s lister') || text.contains('dl')) {
      return "To check your Dean's Lister status, please submit an Academic concern. The Dean's Office will verify your grades and requirements.";
    }
    
    return "I've noted your message. A staff member will also review this and get back to you shortly.";
  }
}
