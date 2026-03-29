import 'package:flutter/foundation.dart';

class NotificationService {
  // Para sa Student Push Notifications
  Future<void> sendStatusUpdateNotification(String studentId, String concernTitle, String newStatus) async {
    if (studentId == 'anonymous') {
      debugPrint('Notification suppressed for anonymous submission: $concernTitle');
      return;
    }
    debugPrint('📱 [PUSH] Student ($studentId): Your concern "$concernTitle" is now $newStatus');
    
    // Awtomatikong magpapadala rin ng Email
    await sendEmail(
      to: 'student_$studentId@gmail.com', // Simulation ng student email
      subject: '[GRC ConcernTrack] Status Update: $concernTitle',
      body: 'Hi Student,\n\nYour concern "$concernTitle" has been updated to: $newStatus.\n\nPlease check your dashboard for more details.\n\nBest regards,\nGRC Support Team',
    );
  }

  // Para sa Staff/Admin In-App Alerts
  Future<void> sendAdminAlert({required String title, required String body}) async {
    debugPrint('🔔 [IN-APP] Admin Alert: $title - $body');
  }

  // Email Notification Logic
  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    // Para sa Presentation/Demo, lalabas ito sa Debug Console mo.
    // Sa production, dito ilalagay ang SendGrid, Mailer, o Firebase Functions logic.
    debugPrint('--------------------------------------------------');
    debugPrint('📧 GMAIL SYSTEM: Sending Notification to Student...');
    debugPrint('TO: $to');
    debugPrint('SUBJECT: $subject');
    debugPrint('CONTENT: $body');
    debugPrint('--------------------------------------------------');
  }
}
