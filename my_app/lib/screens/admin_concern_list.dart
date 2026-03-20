import 'dart:async';
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
  final bool? filterHighRiskOnly; 
  final bool? filterAtRiskOnly;

  const AdminConcernList({
    super.key, 
    this.initialFilter, 
    this.filterActiveOnly,
    this.filterHighRiskOnly,
    this.filterAtRiskOnly,
  });

  @override
  ConsumerState<AdminConcernList> createState() => _AdminConcernListState();
}

class _AdminConcernListState extends ConsumerState<AdminConcernList> {
  // Filter States
  String? _filterDept;
  String? _filterOffice;
  ConcernStatus? _filterStatus;
  DateTime? _selectedDate;
  String _searchQuery = "";
  bool _showActiveOnly = false;
  bool _showHighRiskOnly = false;
  bool _showAtRiskOnly = false;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter;
    _showActiveOnly = widget.filterActiveOnly ?? false;
    _showHighRiskOnly = widget.filterHighRiskOnly ?? false;
    _showAtRiskOnly = widget.filterAtRiskOnly ?? false;
  }

  void _showFloatingCalendar() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Activity Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              CalendarDatePicker(
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                  Navigator.pop(context);
                },
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedDate = null);
                  Navigator.pop(context);
                },
                child: const Text('Clear Filter', style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final concernsAsync = ref.watch(allConcernsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Request Registry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTopFilterSection(concernsAsync.value ?? []),
          Expanded(
            child: concernsAsync.when(
              data: (concerns) {
                var filtered = _applyFilters(concerns);
                if (filtered.isEmpty) return _buildEmptyState();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Text('Showing ${filtered.length} records', 
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          if (_showHighRiskOnly) ...[
                            const SizedBox(width: 8),
                            _riskChip('HIGH RISK (SLA)', Colors.red, () => setState(() => _showHighRiskOnly = false)),
                          ],
                          if (_showAtRiskOnly) ...[
                            const SizedBox(width: 8),
                            _riskChip('AT RISK (SLA)', Colors.orange, () => setState(() => _showAtRiskOnly = false)),
                          ],
                          if (_selectedDate != null) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(DateFormat('MMM dd').format(_selectedDate!), style: const TextStyle(fontSize: 10)),
                              onDeleted: () => setState(() => _selectedDate = null),
                              backgroundColor: Colors.indigo.withOpacity(0.1),
                              deleteIcon: const Icon(Icons.close, size: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            child: _buildProfessionalTable(filtered),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskChip(String label, Color color, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  List<Concern> _applyFilters(List<Concern> list) {
    var filtered = list;
    final now = DateTime.now();

    if (_showHighRiskOnly) {
      filtered = filtered.where((c) => 
        c.status != ConcernStatus.resolved && now.difference(c.createdAt).inHours > 48
      ).toList();
    } else if (_showAtRiskOnly) {
      filtered = filtered.where((c) => 
        c.status != ConcernStatus.resolved && 
        now.difference(c.createdAt).inHours > 24 && 
        now.difference(c.createdAt).inHours <= 48
      ).toList();
    }

    if (_selectedDate != null) {
      filtered = filtered.where((c) => 
        c.createdAt.year == _selectedDate!.year && 
        c.createdAt.month == _selectedDate!.month && 
        c.createdAt.day == _selectedDate!.day
      ).toList();
    }
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
    return filtered;
  }

  Widget _buildTopFilterSection(List<Concern> allConcerns) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('REGISTRY FILTERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
              ElevatedButton.icon(
                onPressed: () => ReportService().generateAndPrintReport(_applyFilters(allConcerns)),
                icon: const Icon(Icons.picture_as_pdf, size: 14),
                label: const Text('EXPORT PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search student...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.indigo),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _showFloatingCalendar,
                icon: Icon(Icons.calendar_month, color: _selectedDate != null ? Colors.indigo : Colors.grey),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: _buildRegistryDropdown('Office', _filterOffice, ["DEAN'S OFFICE", "FINANCE OFFICE", "STUDENT AFFAIRS"], (v) => setState(() => _filterOffice = v))),
              const SizedBox(width: 8),
              Expanded(child: _buildRegistryDropdown('Section', _filterDept, ['CCS', 'COA', 'COE', 'CBAE'], (v) => setState(() => _filterDept = v))),
              const SizedBox(width: 8),
              Expanded(child: _buildRegistryDropdown('Status', _filterStatus?.name, ConcernStatus.values.map((e) => e.name).toList(), (v) {
                setState(() => _filterStatus = v != null ? ConcernStatus.values.firstWhere((e) => e.name == v) : null);
              })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTable(List<Concern> concerns) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        columnSpacing: 24,
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('REFERENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('STUDENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('OFFICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('SUBMITTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ],
        rows: concerns.asMap().entries.map((e) => _buildDataRow(e.key + 1, e.value)).toList(),
      ),
    );
  }

  DataRow _buildDataRow(int index, Concern c) {
    return DataRow(cells: [
      DataCell(Text('$index', style: const TextStyle(fontSize: 11))),
      DataCell(Text(c.id.substring(0, 8).toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 11))),
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E293B))),
          Text(c.department, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      )),
      DataCell(Text(c.assignedTo ?? 'UNASSIGNED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
      DataCell(Text(DateFormat('MMM dd').format(c.createdAt), style: const TextStyle(fontSize: 10, color: Colors.blueGrey))),
      DataCell(_statusBadge(c.status)),
      DataCell(IconButton(
        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.indigo, size: 18),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConcernDetailScreen(concern: c, isAdmin: true))),
      )),
    ]);
  }

  Widget _buildRegistryDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('All $label', style: const TextStyle(fontSize: 9)),
              style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w600),
              items: [
                DropdownMenuItem(value: null, child: Text('All $label')),
                ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(ConcernStatus status) {
    Color color = Colors.blue;
    if (status == ConcernStatus.resolved) color = Colors.green;
    if (status == ConcernStatus.escalated) color = Colors.red;
    if (status == ConcernStatus.read) color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No matching records found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
