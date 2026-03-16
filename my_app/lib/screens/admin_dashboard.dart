import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import '../services/report_service.dart';
import 'audit_trail_view.dart';
import 'package:intl/intl.dart';


final concernsStreamProvider = StreamProvider<List<Concern>>((ref) {
  return ref.watch(concernServiceProvider).getConcerns();
});


class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});


  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}


class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  ConcernCategory? _filterCategory;
  String? _filterDept;


  @override
  Widget build(BuildContext context) {
    final concernsAsync = ref.watch(concernsStreamProvider);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard - ConcernTrack'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Trigger SLA Check',
            onPressed: () => ref.read(concernServiceProvider).checkSLAEnforcement(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Report',
            onPressed: () => _exportPDF(context, concernsAsync.value ?? []),
          ),
        ],
      ),
      body: concernsAsync.when(
        data: (concerns) {
          var filteredConcerns = concerns;
          if (_filterCategory != null) {
            filteredConcerns = filteredConcerns.where((c) => c.category == _filterCategory).toList();
          }
          if (_filterDept != null) {
            filteredConcerns = filteredConcerns.where((c) => c.assignedTo == _filterDept).toList();
          }
          return _buildDashboard(context, filteredConcerns, concerns, ref);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }


  Widget _buildDashboard(BuildContext context, List<Concern> filtered, List<Concern> allConcerns, WidgetRef ref) {
    final total = allConcerns.length;
    final resolved = allConcerns.where((c) => c.status == ConcernStatus.resolved).length;
    final escalated = allConcerns.where((c) => c.status == ConcernStatus.escalated).length;

    final now = DateTime.now();
    final slaBreaches = allConcerns.where((c) =>
    (c.status == ConcernStatus.routed && now.difference(c.createdAt).inDays >= 2) ||
        (c.status == ConcernStatus.read && c.lastUpdatedAt != null && now.difference(c.lastUpdatedAt!).inDays >= 5)
    ).length;


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsCards(total, resolved, escalated, slaBreaches),
          const SizedBox(height: 24),
          _buildFilterBar(),
          const SizedBox(height: 24),
          const Text('Category Distribution (All)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _buildCategoryChart(allConcerns)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Concerns (${filtered.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _exportCSV(context, filtered),
                icon: const Icon(Icons.table_view, color: Colors.red),
                label: const Text('Export CSV', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Text('No concerns match the current filters.', style: TextStyle(color: Colors.grey)),
            ))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final concern = filtered[index];
                final isSlaBreached = (concern.status == ConcernStatus.routed && now.difference(concern.createdAt).inDays >= 2) ||
                    (concern.status == ConcernStatus.read && concern.lastUpdatedAt != null && now.difference(concern.lastUpdatedAt!).inDays >= 5);

                return Card(
                  elevation: isSlaBreached ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSlaBreached ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(concern.status).withOpacity(0.2),
                      child: Icon(
                          isSlaBreached ? Icons.priority_high : _getStatusIcon(concern.status),
                          color: isSlaBreached ? Colors.red : _getStatusColor(concern.status)
                      ),
                    ),
                    title: Text(concern.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${concern.category.name.toUpperCase()} • ${concern.status.name.toUpperCase()}\n'
                            'Dept: ${concern.assignedTo ?? "Pending"}'
                    ),
                    isThreeLine: true,
                    trailing: _buildStatusAction(context, concern, ref),
                    onTap: () => _handleConcernTap(context, concern, ref),
                  ),
                );
              },
            ),
        ],
      ),
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


  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ConcernCategory>(
                    decoration: const InputDecoration(labelText: 'Category', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    value: _filterCategory,
                    onChanged: (val) => setState(() => _filterCategory = val),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Categories')),
                      ...ConcernCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Department', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    value: _filterDept,
                    onChanged: (val) => setState(() => _filterDept = val),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Departments')),
                      DropdownMenuItem(value: 'COA', child: Text('COA')),
                      DropdownMenuItem(value: 'COE', child: Text('COE')),
                      DropdownMenuItem(value: 'CCS', child: Text('CCS')),
                      DropdownMenuItem(value: 'CBAE', child: Text('CBAE')),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all, color: Colors.red),
                  tooltip: 'Clear All Filters',
                  onPressed: () => setState(() {
                    _filterCategory = null;
                    _filterDept = null;
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _handleConcernTap(BuildContext context, Concern concern, WidgetRef ref) {
    if (concern.status == ConcernStatus.routed) {
      ref.read(concernServiceProvider).updateStatus(concern.id, ConcernStatus.read, 'admin_user');
    }
    _showDetails(context, concern);
  }


  Widget _buildMetricsCards(int total, int resolved, int escalated, int slaBreaches) {
    return Column(
      children: [
        Row(
          children: [
            _metricCard('Total', total.toString(), Colors.red, Icons.list_alt),
            _metricCard('Resolved', resolved.toString(), Colors.green, Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _metricCard('Escalated', escalated.toString(), Colors.orange, Icons.trending_up),
            _metricCard('SLA Breaches', slaBreaches.toString(), Colors.red, Icons.report_problem),
          ],
        ),
      ],
    );
  }


  Widget _metricCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
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


    if (concerns.isEmpty) return const Center(child: Text('No data for chart'));


    return PieChart(
      PieChartData(
        sections: counts.entries.map((e) {
          return PieChartSectionData(
            value: e.value.toDouble(),
            title: '${e.key.name}\n${e.value}',
            color: _getCategoryColor(e.key),
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
      case ConcernStatus.submitted: return Colors.grey;
      case ConcernStatus.routed: return Colors.red;
      case ConcernStatus.read: return Colors.orange;
      case ConcernStatus.screened: return Colors.cyan;
      case ConcernStatus.resolved: return Colors.green;
      case ConcernStatus.escalated: return Colors.red;
    }
  }


  Widget _buildStatusAction(BuildContext context, Concern concern, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'history') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AuditTrailView(concernId: concern.id)));
        } else {
          final status = ConcernStatus.values.firstWhere((e) => e.name == value);
          ref.read(concernServiceProvider).updateStatus(concern.id, status, 'admin_user');
        }
      },
      itemBuilder: (context) {
        // Filter out 'escalated' as requested
        final filteredStatuses = ConcernStatus.values.where((s) => s != ConcernStatus.escalated).toList();
        return [
          ...filteredStatuses.map((s) => PopupMenuItem(value: s.name, child: Text('Mark as ${s.name.toUpperCase()}'))),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'history', child: Text('Full Audit History')),
        ];
      },
      child: const Icon(Icons.more_vert),
    );
  }


  void _showDetails(BuildContext context, Concern concern) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(concern.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _detailRow('Status', concern.status.name.toUpperCase(), _getStatusColor(concern.status)),
                    _detailRow('Category', concern.category.name.toUpperCase(), Colors.black87),
                    _detailRow('Student', concern.isAnonymous ? "Anonymous Submission" : "ID: ${concern.studentId}", Colors.black87),
                    _detailRow('Program', concern.program, Colors.black87),
                    _detailRow('Department', concern.assignedTo ?? 'Unassigned', Colors.red),
                    const SizedBox(height: 20),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Text(concern.description, style: const TextStyle(fontSize: 16, height: 1.5)),
                    ),
                    const SizedBox(height: 24),
                    const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (concern.attachments.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No files attached.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                    else
                      ...concern.attachments.map((a) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.file_present, color: Colors.red),
                          title: Text(a.split('/').last),
                          trailing: const Icon(Icons.download_rounded),
                        ),
                      )),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AuditTrailView(concernId: concern.id)));
                      },
                      icon: const Icon(Icons.history_edu),
                      label: const Text('View Action Log (Audit Trail)'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }


  void _exportPDF(BuildContext context, List<Concern> concerns) async {
    final reportService = ReportService();
    await reportService.generateAndPrintReport(concerns, category: _filterCategory?.name, department: _filterDept);
  }


  void _exportCSV(BuildContext context, List<Concern> concerns) async {
    final reportService = ReportService();
    await reportService.exportToCSV(concerns);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV Data logged to console (Exported)')));
  }
}

