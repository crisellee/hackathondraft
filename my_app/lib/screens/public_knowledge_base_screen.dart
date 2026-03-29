import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import 'package:intl/intl.dart';

class PublicKnowledgeBaseScreen extends ConsumerStatefulWidget {
  const PublicKnowledgeBaseScreen({super.key});

  @override
  ConsumerState<PublicKnowledgeBaseScreen> createState() => _PublicKnowledgeBaseScreenState();
}

class _PublicKnowledgeBaseScreenState extends ConsumerState<PublicKnowledgeBaseScreen> {
  String _searchQuery = "";
  ConcernCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final publicConcernsAsync = ref.watch(publicConcernsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Community Knowledge Base', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(isDark),
          Expanded(
            child: publicConcernsAsync.when(
              data: (concerns) {
                final filtered = concerns.where((c) {
                  final matchesSearch = c.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                       c.description.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchesCategory = _filterCategory == null || c.category == _filterCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filtered.isEmpty) return _buildEmptyState(isDark);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildConcernCard(filtered[index], isDark),
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

  Widget _buildSearchAndFilter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search resolved concerns...',
              hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
              prefixIcon: const Icon(Icons.search, color: Colors.red),
              filled: true,
              fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterCategory == null,
                  onSelected: (s) => setState(() => _filterCategory = null),
                  selectedColor: Colors.red.withOpacity(0.2),
                  checkmarkColor: Colors.red,
                ),
                const SizedBox(width: 8),
                ...ConcernCategory.values.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat.name.toUpperCase()),
                    selected: _filterCategory == cat,
                    onSelected: (s) => setState(() => _filterCategory = s ? cat : null),
                    selectedColor: Colors.red.withOpacity(0.2),
                    checkmarkColor: Colors.red,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcernCard(Concern concern, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        iconColor: isDark ? Colors.white70 : Colors.black54,
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ),
        title: Text(concern.title, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87
          )
        ),
        subtitle: Text(
          'Category: ${concern.category.name.toUpperCase()} • ${DateFormat('MMM yyyy').format(concern.createdAt)}',
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STUDENT CONCERN:', 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey)
                ),
                const SizedBox(height: 4),
                Text(concern.description, 
                  style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.white70 : Colors.black87)
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                const Text('OFFICIAL RESOLUTION:', 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)
                ),
                const SizedBox(height: 8),
                Text(
                  'This concern was reviewed and resolved by the department. You may follow the steps above or contact the assigned office for further assistance.',
                  style: TextStyle(
                    fontSize: 13, 
                    fontStyle: FontStyle.italic, 
                    color: isDark ? Colors.white60 : Colors.black87
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: isDark ? Colors.white10 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No public records yet', 
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}

final publicConcernsProvider = StreamProvider<List<Concern>>((ref) {
  return ref.watch(concernServiceProvider).getPublicConcerns();
});
