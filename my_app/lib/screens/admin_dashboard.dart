import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import '../services/report_service.dart';
import '../services/providers.dart';
import 'admin_concern_list.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _refreshTimer;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
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
      appBar: _buildAppBar(context, ref, concernsAsync),
      body: concernsAsync.when(
        data: (concerns) {
          var displayData = concerns;
          if (_selectedDate != null) {
            displayData = concerns.where((c) => 
              c.createdAt.year == _selectedDate!.year && 
              c.createdAt.month == _selectedDate!.month && 
              c.createdAt.day == _selectedDate!.day
            ).toList();
          }
          return _buildProfessionalUI(context, displayData, isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref, AsyncValue<List<Concern>> concernsAsync) {
    return AppBar(
      title: Row(
        children: [
          const Text('Intelligence Dashboard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(width: 12),
          _buildLiveBadge(),
        ],
      ),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.calendar_month, color: _selectedDate != null ? Colors.red : Colors.grey),
          onPressed: _showFloatingCalendar,
        ),
        _buildSettingsMenu(concernsAsync),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return FadeTransition(
      opacity: _pulseController,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            CircleAvatar(radius: 3, backgroundColor: Colors.red),
            SizedBox(width: 4),
            Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalUI(BuildContext context, List<Concern> displayData, bool isDark) {
    final resolved = displayData.where((c) => c.status == ConcernStatus.resolved).length;
    final active = displayData.length - resolved;
    final escalated = displayData.where((c) => c.status == ConcernStatus.escalated).length;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(allConcernsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ActionChip(
                  label: Text('Filter: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}', style: const TextStyle(fontSize: 11)),
                  onPressed: () {}, 
                  backgroundColor: Colors.red.withOpacity(0.1),
                ),
              ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                _kpiCard(context, 'TOTAL', displayData.length.toString(), Icons.analytics, Colors.red, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList()));
                }),
                _kpiCard(context, 'ACTIVE', active.toString(), Icons.pending, Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(filterActiveOnly: true)));
                }),
                _kpiCard(context, 'ESCALATED', escalated.toString(), Icons.warning, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(initialFilter: ConcernStatus.escalated)));
                }),
                _kpiCard(context, 'RESOLVED', resolved.toString(), Icons.check_circle, Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(initialFilter: ConcernStatus.resolved)));
                }),
              ],
            ),
            const SizedBox(height: 24),

            _buildAIHub(context, displayData),
            const SizedBox(height: 24),

            _chartCard('SYSTEM ACTIVITY TRENDS', _buildTrendGraph(displayData, isDark), isDark),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(child: _chartCard('CATEGORY MIX', _buildCategoryChart(displayData), isDark)),
                const SizedBox(width: 16),
                Expanded(child: _chartCard('STATUS FLOW', _buildStatusChart(displayData), isDark)),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()).toUpperCase(),
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2),
        ),
        Text(
          'Operational Console',
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.w900, 
            color: isDark ? Colors.white : const Color(0xFF0F172A)
          ),
        ),
      ],
    );
  }

  Widget _buildAIHub(BuildContext context, List<Concern> concerns) {
    final now = DateTime.now();
    int critical = concerns.where((c) => c.status != ConcernStatus.resolved && now.difference(c.createdAt).inHours > 48).length;
    int high = concerns.where((c) => c.status != ConcernStatus.resolved && now.difference(c.createdAt).inHours > 24 && now.difference(c.createdAt).inHours <= 48).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark card background always
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text('AI HUB ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              const Spacer(),
              Text('Sync: ${DateFormat('HH:mm').format(now)}', style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _aiStat('HIGH RISK', '$critical', Colors.redAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(filterHighRiskOnly: true)));
              }),
              _aiStat('AT RISK', '$high', Colors.orangeAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList(filterAtRiskOnly: true)));
              }),
              _aiStat('CONFIDENCE', '94%', Colors.blueAccent, null),
            ],
          ),
          const Divider(height: 40, color: Colors.white12),
          Text(
            critical > 0 
              ? 'AI ADVICE: $critical tickets breached SLA. Click HIGH RISK to address them now.' 
              : 'AI ANALYSIS: System performance is nominal. Click any metric to view details.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _aiStat(String label, String value, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(BuildContext context, String title, String value, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartCard(String title, Widget chart, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white60 : const Color(0xFF64748B), letterSpacing: 1)),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: chart),
        ],
      ),
    );
  }

  Widget _buildTrendGraph(List<Concern> concerns, bool isDark) {
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final spots = last7Days.asMap().entries.map((e) {
      final count = concerns.where((c) => c.createdAt.day == e.value.day && c.createdAt.month == e.value.month).length;
      return FlSpot(e.key.toDouble(), count.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.05)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(List<Concern> concerns) {
    return PieChart(PieChartData(sectionsSpace: 0, centerSpaceRadius: 25, sections: [
       PieChartSectionData(color: Colors.red, value: concerns.where((c) => c.category == ConcernCategory.academic).length.toDouble(), radius: 30, showTitle: false),
       PieChartSectionData(color: Colors.orange, value: concerns.where((c) => c.category == ConcernCategory.financial).length.toDouble(), radius: 30, showTitle: false),
       PieChartSectionData(color: Colors.blue, value: concerns.where((c) => c.category == ConcernCategory.welfare).length.toDouble(), radius: 30, showTitle: false),
    ]));
  }

  Widget _buildStatusChart(List<Concern> concerns) {
    return PieChart(PieChartData(sectionsSpace: 0, centerSpaceRadius: 25, sections: [
       PieChartSectionData(color: Colors.blue, value: concerns.where((c) => c.status == ConcernStatus.submitted).length.toDouble(), radius: 30, showTitle: false),
       PieChartSectionData(color: Colors.green, value: concerns.where((c) => c.status == ConcernStatus.resolved).length.toDouble(), radius: 30, showTitle: false),
       PieChartSectionData(color: Colors.red, value: concerns.where((c) => c.status == ConcernStatus.escalated).length.toDouble(), radius: 30, showTitle: false),
    ]));
  }

  Widget _buildSettingsMenu(AsyncValue<List<Concern>> concernsAsync) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (val) async {
        if (val == 'mock') await ref.read(bulkUploadServiceProvider).generateMockData('admin');
        if (val == 'clear') await ref.read(concernServiceProvider).clearAllConcerns();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'mock', child: Text('Inject Mock Data')),
        const PopupMenuItem(value: 'clear', child: Text('Clear All Data', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}
