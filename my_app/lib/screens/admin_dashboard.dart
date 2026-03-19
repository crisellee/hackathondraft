import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import '../services/report_service.dart';
import '../services/providers.dart';
import 'admin_concern_list.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SECURITY KICK-OUT LOGIC
    final role = ref.watch(userRoleProvider);
    
    if (role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)),
      );
    }

    if (role != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      });
      return const Scaffold(body: Center(child: Text('Unauthorized access. Redirecting...')));
    }

    final concernsAsync = ref.watch(allConcernsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Staff Console', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.red),
            onSelected: (value) async {
              if (value == 'pdf' && concernsAsync.hasValue) {
                ReportService().generateAndPrintReport(concernsAsync.value!);
              } else if (value == 'csv' && concernsAsync.hasValue) {
                ReportService().exportToCSV(concernsAsync.value!);
              } else if (value == 'mock') {
                final userId = ref.read(userIdProvider) ?? 'admin_test';
                final count = await ref.read(bulkUploadServiceProvider).generateMockData(userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully inserted $count mock concerns.')),
                  );
                }
              } else if (value == 'clear') {
                await ref.read(concernServiceProvider).clearAllConcerns();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All concerns cleared.')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export PDF Report')),
              const PopupMenuItem(value: 'csv', child: Text('Export CSV Data')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'mock', child: Text('Generate Mock Data (55)')),
              const PopupMenuItem(value: 'clear', child: Text('Clear All Data', style: TextStyle(color: Colors.red))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: concernsAsync.when(
        data: (concerns) => _buildAnalyticsContent(context, ref, concerns),
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
        error: (err, stack) => Center(child: Text('System Error: $err')),
      ),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context, WidgetRef ref, List<Concern> all) {
    final total = all.length;
    final resolved = all.where((c) => c.status == ConcernStatus.resolved).length;
    final escalated = all.where((c) => c.status == ConcernStatus.escalated).length;
    final newCases = all.where((c) => c.status == ConcernStatus.submitted || c.status == ConcernStatus.routed).length;

    final now = DateTime.now();
    
    double avgResponseDays = 0;
    final processed = all.where((c) => c.status != ConcernStatus.submitted && c.status != ConcernStatus.routed).toList();
    if (processed.isNotEmpty) {
      final totalDays = processed.fold(0, (sum, c) => sum + (c.lastUpdatedAt ?? now).difference(c.createdAt).inDays);
      avgResponseDays = totalDays / processed.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _metricTile(
                context, 'Total Cases', total.toString(), Icons.analytics_outlined, Colors.grey.shade700,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList())),
              ),
              _metricTile(
                context, 'Active Cases', (total - resolved).toString(), Icons.folder_open, Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(filterActiveOnly: true))),
              ),
              _metricTile(
                context, 'Resolved', resolved.toString(), Icons.check_circle_outline, Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(initialFilter: ConcernStatus.resolved))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricTile(
                context, 'New Routed', newCases.toString(), Icons.move_to_inbox, Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(initialFilter: ConcernStatus.routed))),
              ),
              _metricTile(
                context, 'Escalation', escalated.toString(), Icons.warning_amber, Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(initialFilter: ConcernStatus.escalated))),
              ),
              _metricTile(
                context, 'Avg Response', '${avgResponseDays.toStringAsFixed(1)} Days', Icons.timer_outlined, Colors.orange
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Analytics Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: Column(children: [
                        const Text('By Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 20),
                        SizedBox(height: 200, child: _buildCategoryChart(all)),
                      ])),
                      const VerticalDivider(width: 48),
                      Expanded(child: Column(children: [
                        const Text('By Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 20),
                        SizedBox(height: 200, child: _buildStatusChart(all)),
                      ])),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _buildLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _legendItem('Academic', Colors.red),
            _legendItem('Financial', Colors.orange),
            _legendItem('Welfare', Colors.pink),
            const SizedBox(width: 20), // Spacer
            _legendItem('New', Colors.blue),
            _legendItem('Read', Colors.orange),
            _legendItem('Resolved', Colors.green),
            _legendItem('Escalated', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _metricTile(BuildContext context, String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: onTap != null ? color.withOpacity(0.3) : Colors.grey.shade200),
            boxShadow: onTap != null ? [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 24),
                  if (onTap != null) Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 12),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChart(List<Concern> concerns) {
    final counts = <ConcernCategory, int>{};
    for (var cat in ConcernCategory.values) {
      counts[cat] = concerns.where((c) => c.category == cat).length;
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: counts.entries.map((e) {
          return PieChartSectionData(
            value: e.value.toDouble(),
            title: e.value > 0 ? '${e.value}' : '',
            color: _getCategoryColor(e.key),
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChart(List<Concern> concerns) {
    final counts = <ConcernStatus, int>{};
    for (var status in ConcernStatus.values) {
      counts[status] = concerns.where((c) => c.status == status).length;
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: counts.entries.where((e) => e.value > 0).map((e) {
          return PieChartSectionData(
            value: e.value.toDouble(),
            title: '${e.value}',
            color: _getStatusColor(e.key),
            radius: 50,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }

  Color _getCategoryColor(ConcernCategory category) {
    switch (category) {
      case ConcernCategory.academic: return Colors.red;
      case ConcernCategory.financial: return Colors.orange;
      case ConcernCategory.welfare: return Colors.pink;
    }
  }

  Color _getStatusColor(ConcernStatus status) {
    switch (status) {
      case ConcernStatus.submitted: return Colors.blue;
      case ConcernStatus.routed: return Colors.purple;
      case ConcernStatus.read: return Colors.orange;
      case ConcernStatus.screened: return Colors.teal;
      case ConcernStatus.resolved: return Colors.green;
      case ConcernStatus.escalated: return Colors.red;
    }
  }
}
