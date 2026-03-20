import 'package:flutter/foundation.dart';

class NotificationService {
  // Para sa Student Push Notifications
  Future<void> sendStatusUpdateNotification(String studentId, String concernTitle, String newStatus) async {
    if (studentId == 'anonymous') {
      debugPrint('Notification suppressed for anonymous submission: $concernTitle');
      return;
    }
    debugPrint('📱 [PUSH] Student ($studentId): Your concern "$concernTitle" is now $newStatus');
  }

  // Para sa Staff/Admin In-App Alerts
  Future<void> sendAdminAlert({required String title, required String body}) async {
    debugPrint('🔔 [IN-APP] Admin Alert: $title - $body');
  }

  // NEW: Para sa Admin Email Notifications
  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    // Dito pwedeng ilagay ang integration sa Mailer package o SendGrid API sa future.
    // Para sa presentation, ito ang magpapatunay na nag-trigger ang email logic.
    debugPrint('--------------------------------------------------');
    debugPrint('📧 EMAIL SYSTEM: Sending Message...');
    debugPrint('TO: $to');
    debugPrint('SUBJECT: $subject');
    debugPrint('BODY: $body');
    debugPrint('--------------------------------------------------');
  }
}
