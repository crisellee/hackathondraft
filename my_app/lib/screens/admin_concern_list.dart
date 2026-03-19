import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import '../services/report_service.dart';
import '../services/providers.dart';
import 'concern_detail_screen.dart';
import 'package:intl/intl.dart';

class AdminConcernList extends ConsumerStatefulWidget {
  final ConcernStatus? initialFilter;
  final bool? filterActiveOnly;

  const AdminConcernList({super.key, this.initialFilter, this.filterActiveOnly});

  @override
  ConsumerState<AdminConcernList> createState() => _AdminConcernListState();
}

class _AdminConcernListState extends ConsumerState<AdminConcernList> {
  String? _filterDept;
  String? _filterOffice;
  ConcernStatus? _filterStatus;
  bool _showActiveOnly = false;
  String _searchQuery = "";
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter;
    _showActiveOnly = widget.filterActiveOnly ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final concernsAsync = ref.watch(allConcernsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Request Registry', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildFilterBar(concernsAsync.value ?? []),
          Expanded(
            child: concernsAsync.when(
              data: (concerns) {
                var filtered = concerns;
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((c) => 
                    c.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                    c.id.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();
                }
                if (_filterDept != null) filtered = filtered.where((c) => c.department == _filterDept).toList();
                if (_filterOffice != null) filtered = filtered.where((c) => c.assignedTo == _filterOffice).toList();
                if (_filterStatus != null) filtered = filtered.where((c) => c.status == _filterStatus).toList();
                if (_showActiveOnly) filtered = filtered.where((c) => c.status != ConcernStatus.resolved).toList();
                
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matching records found.'));
                }

                return Scrollbar(
                  thumbVisibility: true,
                  thickness: 8,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
                      child: _buildTable(filtered),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<Concern> filteredData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Student Name or REF ID...',
              prefixIcon: const Icon(Icons.search, color: Colors.red),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownButton<ConcernStatus>(
                        value: _filterStatus,
                        hint: const Text('All Status'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Status')),
                          ...ConcernStatus.values.where((e) => e != ConcernStatus.submitted).map((e) {
                            String label = e.name.toUpperCase();
                            if (e == ConcernStatus.routed) label = "NEW / ROUTED";
                            return DropdownMenuItem(value: e, child: Text(label));
                          }),
                        ],
                        onChanged: (v) => setState(() => _filterStatus = v),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _filterDept,
                        hint: const Text('All Sections'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Sections')),
                          ...['CCS', 'COA', 'COE', 'CBAE'].map((e) => DropdownMenuItem(value: e, child: Text(e))),
                        ],
                        onChanged: (v) => setState(() => _filterDept = v),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _filterOffice,
                        hint: const Text('All Offices'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Offices')),
                          ...["DEAN'S OFFICE", "FINANCE OFFICE", "STUDENT AFFAIRS"].map((e) => DropdownMenuItem(value: e, child: Text(e))),
                        ],
                        onChanged: (v) => setState(() => _filterOffice = v),
                      ),
                      const SizedBox(width: 16),
                      FilterChip(
                        label: const Text('Active Only', style: TextStyle(fontSize: 12)),
                        selected: _showActiveOnly,
                        onSelected: (v) => setState(() => _showActiveOnly = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => ReportService().generateAndPrintReport(filteredData),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Concern> concerns) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('REF ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('STUDENT', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('SECTION', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('OFFICE', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: concerns.asMap().entries.map((entry) => _buildDataRow(entry.key + 1, entry.value)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(int index, Concern c) {
    final refId = c.id.length > 8 ? c.id.substring(0, 8).toUpperCase() : c.id.toUpperCase();
    return DataRow(
      cells: [
        DataCell(Text('$index', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        DataCell(Text(refId, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12))),
        DataCell(Text(c.studentName, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Center(child: Text(c.department, style: const TextStyle(fontSize: 11)))),
        DataCell(Center(child: Text(c.assignedTo ?? 'PENDING', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)))),
        DataCell(Center(child: _statusBadge(c.status))),
        DataCell(Center(child: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.red),
          onPressed: () => _handleConcernTap(c),
        ))),
      ],
    );
  }

  Widget _statusBadge(ConcernStatus status) {
    Color color;
    String label = status.name.toUpperCase();
    switch (status) {
      case ConcernStatus.submitted: 
        color = Colors.blue; 
        label = "ROUTED";
        break;
      case ConcernStatus.routed: 
        color = Colors.purple; 
        label = "ROUTED";
        break;
      case ConcernStatus.read: color = Colors.orange; break;
      case ConcernStatus.resolved: color = Colors.green; break;
      case ConcernStatus.escalated: color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _handleConcernTap(Concern concern) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ConcernDetailScreen(concern: concern, isAdmin: true),
    ));
  }
}
