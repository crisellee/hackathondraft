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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Request Registry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTopFilterSection(concernsAsync.value ?? [], isDark),
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
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.blueGrey)),
                          if (_showHighRiskOnly) ...[
                            const SizedBox(width: 8),
                            _riskChip('HIGH RISK', Colors.red, () => setState(() => _showHighRiskOnly = false)),
                          ],
                          if (_showAtRiskOnly) ...[
                            const SizedBox(width: 8),
                            _riskChip('AT RISK', Colors.orange, () => setState(() => _showAtRiskOnly = false)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildProfessionalTable(filtered, isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
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
    );
  }

  List<Concern> _applyFilters(List<Concern> list) {
    var filtered = list;
    final now = DateTime.now();
    if (_showHighRiskOnly) filtered = filtered.where((c) => c.status != ConcernStatus.resolved && now.difference(c.createdAt).inHours > 48).toList();
    else if (_showAtRiskOnly) filtered = filtered.where((c) => c.status != ConcernStatus.resolved && now.difference(c.createdAt).inHours > 24 && now.difference(c.createdAt).inHours <= 48).toList();
    if (_selectedDate != null) filtered = filtered.where((c) => c.createdAt.day == _selectedDate!.day).toList();
    if (_searchQuery.isNotEmpty) filtered = filtered.where((c) => c.studentName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    if (_filterDept != null) filtered = filtered.where((c) => c.department == _filterDept).toList();
    if (_filterOffice != null) filtered = filtered.where((c) => c.assignedTo == _filterOffice).toList();
    if (_filterStatus != null) filtered = filtered.where((c) => c.status == _filterStatus).toList();
    return filtered;
  }

  Widget _buildTopFilterSection(List<Concern> allConcerns, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('REGISTRY FILTERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white30 : Colors.blueGrey, letterSpacing: 1)),
              ElevatedButton.icon(
                onPressed: () => ReportService().generateAndPrintReport(_applyFilters(allConcerns)),
                icon: const Icon(Icons.picture_as_pdf, size: 14),
                label: const Text('EXPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search student...',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.red),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildRegistryDropdown('Office', _filterOffice, ["DEAN'S OFFICE", "FINANCE OFFICE", "STUDENT AFFAIRS"], (v) => setState(() => _filterOffice = v), isDark)),
              const SizedBox(width: 8),
              Expanded(child: _buildRegistryDropdown('Status', _filterStatus?.name, ConcernStatus.values.map((e) => e.name).toList(), (v) {
                setState(() => _filterStatus = v != null ? ConcernStatus.values.firstWhere((e) => e.name == v) : null);
              }, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTable(List<Concern> concerns, bool isDark) {
    return DataTable(
      headingRowHeight: 40,
      columns: [
        DataColumn(label: Text('REFERENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black))),
        DataColumn(label: Text('STUDENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black))),
        DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black))),
        DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black))),
      ],
      rows: concerns.map((c) => DataRow(cells: [
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.id.substring(0, 8).toUpperCase(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
            if (c.isPublic) ...[
              const SizedBox(width: 4),
              const Icon(Icons.public, size: 12, color: Colors.green),
            ]
          ],
        )),
        DataCell(Text(c.studentName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12))),
        DataCell(_statusBadge(c.status)),
        DataCell(IconButton(
          icon: Icon(Icons.visibility, size: 18, color: isDark ? Colors.white70 : Colors.black54), 
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConcernDetailScreen(concern: c, isAdmin: true)))
        )),
      ])).toList(),
    );
  }

  Widget _buildRegistryDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          hint: Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.grey)),
          items: [
            DropdownMenuItem(value: null, child: Text('All $label', style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black87)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _statusBadge(ConcernStatus status) {
    Color color = status == ConcernStatus.resolved ? Colors.green : (status == ConcernStatus.escalated ? Colors.orange : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No records found'));
  }
}
