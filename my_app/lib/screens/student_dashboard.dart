import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import 'login_screen.dart';


final studentConcernsProvider = StreamProvider.family<List<Concern>, String>((ref, studentId) {
  return ref.watch(concernServiceProvider).getConcernsByStudent(studentId);
});


class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStudentId = ref.watch(userIdProvider) ?? 'anonymous';
    final concernsAsync = ref.watch(studentConcernsProvider(currentStudentId));


    return Scaffold(
      appBar: AppBar(
        title: const Text('My Concerns'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: concernsAsync.when(
        data: (concerns) => concerns.isEmpty
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('You haven\'t submitted any concerns yet.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: concerns.length,
          itemBuilder: (context, index) {
            final concern = concerns[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: Icon(_getStatusIcon(concern.status), color: Colors.red),
                title: Text(concern.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: ${concern.status.name.toUpperCase()}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: ${concern.category.name.toUpperCase()}'),
                        const SizedBox(height: 8),
                        Text('Description: ${concern.description}'),
                        const SizedBox(height: 8),
                        Text('Submitted on: ${DateFormat('MMM dd, yyyy HH:mm').format(concern.createdAt)}'),
                        const Divider(),
                        const Text('Progress Timeline:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildTimeline(concern.status),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }


  Widget _buildTimeline(ConcernStatus currentStatus) {
    // Filter out 'escalated' status from the timeline
    final statuses = ConcernStatus.values.where((s) => s != ConcernStatus.escalated).toList();


    return Column(
      children: statuses.map((s) {
        final isCompleted = statuses.indexOf(s) <= statuses.indexOf(currentStatus);
        final isLast = s == statuses.last;

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.red : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 20,
                    color: isCompleted ? Colors.red : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              s.name.toUpperCase(),
              style: TextStyle(
                color: isCompleted ? Colors.red : Colors.grey,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }


  IconData _getStatusIcon(ConcernStatus status) {
    switch (status) {
      case ConcernStatus.submitted: return Icons.send;
      case ConcernStatus.routed: return Icons.alt_route;
      case ConcernStatus.read: return Icons.mark_email_read;
      case ConcernStatus.screened: return Icons.fact_check;
      case ConcernStatus.resolved: return Icons.check_circle;
      case ConcernStatus.escalated: return Icons.warning;
    }
  }
}

