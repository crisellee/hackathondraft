import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/audit_trail.dart';
import '../services/concern_service.dart';
import '../services/providers.dart';


class AuditTrailView extends ConsumerWidget {
  final String concernId;
  const AuditTrailView({super.key, required this.concernId});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // SECURITY CHECK: If student tries to access this view directly
    if (userRole != 'admin') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Access Denied', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('Only authorized staff can view the audit trail.'),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }


    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Audit Trail'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<AuditLog>>(
        stream: ref.watch(concernServiceProvider).getAuditTrail(concernId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No history found for this concern.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }


          final logs = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.red.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            log.action.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: isDark ? Colors.redAccent : Colors.red, 
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, HH:mm:ss').format(log.timestamp),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(log.details, 
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Performed by: ${log.actorId}',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white38 : Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
