import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import '../services/providers.dart';
import '../services/ai_service.dart';

class StudentForm extends ConsumerStatefulWidget {
  const StudentForm({super.key});

  @override
  ConsumerState<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<StudentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(); 
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _linkController = TextEditingController();
  
  String? _selectedDept;
  bool _isAnonymous = false;
  List<String> _attachmentLinks = []; 
  bool _isSubmitting = false;

  ConcernCategory? _predictedCategory;
  String? _predictedOffice;
  bool _isAnalyzingRealtime = false;

  final List<String> _departments = ['COA', 'COE', 'CCS', 'CBAE'];

  @override
  void initState() {
    super.initState();
    _descController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    final text = _descController.text.trim();
    if (text.length > 5) { // Trigger analyze starting from 5 characters
      _debounceAnalysis(text);
    } else {
      setState(() {
        _predictedCategory = null;
        _predictedOffice = null;
      });
    }
  }

  DateTime? _lastAnalysisTime;
  void _debounceAnalysis(String text) async {
    final now = DateTime.now();
    _lastAnalysisTime = now;
    
    // Check if analyzing already, or wait for debounce
    await Future.delayed(const Duration(milliseconds: 800));
    if (_lastAnalysisTime != now) return;

    if (mounted) {
      setState(() => _isAnalyzingRealtime = true);
      try {
        final result = await ref.read(aiServiceProvider).analyzeConcern(text);
        if (mounted && _lastAnalysisTime == now) {
          setState(() {
            _predictedCategory = result['category'];
            _predictedOffice = result['department'];
            _isAnalyzingRealtime = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isAnalyzingRealtime = false);
      }
    }
  }

  void _showAddLinkDialog() {
    _linkController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Image/File Link'),
        content: TextField(
          controller: _linkController,
          decoration: const InputDecoration(
            hintText: 'Paste image URL here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (_linkController.text.isNotEmpty) {
                setState(() => _attachmentLinks.add(_linkController.text.trim()));
                Navigator.pop(context);
              }
            },
            child: const Text('ADD LINK'),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDept == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your department')));
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final currentStudentId = ref.read(userIdProvider) ?? 'anonymous';
        final aiResult = await ref.read(aiServiceProvider).analyzeConcern(_descController.text);
        
        final concern = Concern(
          id: const Uuid().v4(),
          studentId: currentStudentId, 
          studentName: _isAnonymous ? 'Anonymous' : (_nameController.text.isEmpty ? 'Student' : _nameController.text.trim()),
          program: _selectedDept!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: aiResult['category'] as ConcernCategory,
          department: _selectedDept!,
          status: ConcernStatus.submitted,
          createdAt: DateTime.now(),
          isAnonymous: _isAnonymous,
          attachments: _attachmentLinks, 
          assignedTo: aiResult['department'] as String,
        );

        await ref.read(concernServiceProvider).submitConcern(concern);
        
        if (mounted) {
          _showSuccessDialog(concern.category.name.toUpperCase(), concern.assignedTo!);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showSuccessDialog(String categoryName, String office) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('Concern Submitted!', textAlign: TextAlign.center),
          ],
        ),
        content: Text('Your request has been categorized as $categoryName and routed to $office.'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _nameController.clear();
                  _titleController.clear();
                  _descController.clear();
                  setState(() {
                    _attachmentLinks = [];
                    _isSubmitting = false;
                    _predictedCategory = null;
                    _predictedOffice = null;
                  });
                },
                child: const Text('OKAY')
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('STUDENT IDENTITY', Icons.person_outline),
                        _buildIdentityCard(isDark),
                        const SizedBox(height: 24),
                        _buildSectionHeader('CONCERN CONTENT', Icons.edit_note_outlined),
                        _buildConcernCard(isDark),
                        // FIXED: Show card IF analyzing OR IF category is already predicted
                        if (_isAnalyzingRealtime || _predictedCategory != null) 
                          _buildAIInsightCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('ATTACHMENT LINKS', Icons.link),
                        _buildLinkPickerSection(isDark),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSubmitButton(isDark),
            ],
          ),
          if (_isSubmitting) 
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 24),
                    Text('AI Processing & Routing...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDept,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              decoration: const InputDecoration(labelText: 'Your College/Section', prefixIcon: Icon(Icons.school_outlined)),
              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDept = val),
              validator: (value) => value == null ? 'Selection required' : null,
            ),
            const SizedBox(height: 16),
            if (!_isAnonymous)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Submit Anonymously', style: TextStyle(fontSize: 14)),
              value: _isAnonymous,
              onChanged: (val) => setState(() => _isAnonymous = val),
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcernCard(bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.title)),
              validator: (v) => v == null || v.isEmpty ? 'Subject required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Detailed Description', alignLabelWithHint: true),
              validator: (v) => v == null || v.isEmpty ? 'Description required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIInsightCard() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.orange.withOpacity(0.2))
      ),
      child: Row(
        children: [
          if (_isAnalyzingRealtime) 
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)) 
          else 
            const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI LIVE INSIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                Text(
                  _isAnalyzingRealtime 
                    ? 'AI is analyzing your routing...' 
                    : 'This will be routed to the ${_predictedOffice ?? "correct department"}.',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPickerSection(bool isDark) {
    return Column(
      children: [
        InkWell(
          onTap: _showAddLinkDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.link, color: Colors.grey[400], size: 32),
                const SizedBox(height: 8),
                const Text('Click to add image/file link', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ),
        if (_attachmentLinks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._attachmentLinks.asMap().entries.map((entry) => Card(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.link, color: Colors.red, size: 18),
              title: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () {
                setState(() => _attachmentLinks.removeAt(entry.key));
              }),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('SUBMIT REQUEST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}
