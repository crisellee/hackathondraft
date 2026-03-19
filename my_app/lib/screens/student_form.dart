import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import '../services/providers.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import 'student_dashboard.dart';

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
  
  String? _selectedDept;
  bool _isAnonymous = false;
  List<PlatformFile> _files = [];
  bool _isSubmitting = false;

  // Real-time AI Insight
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
    _descController.removeListener(_onDescriptionChanged);
    _nameController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    final text = _descController.text.trim();
    if (text.length > 10) {
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
    
    await Future.delayed(const Duration(milliseconds: 800));
    if (_lastAnalysisTime != now) return;

    if (mounted) {
      setState(() => _isAnalyzingRealtime = true);
      final result = await ref.read(aiServiceProvider).analyzeConcern(text);
      if (mounted && _lastAnalysisTime == now) {
        setState(() {
          _predictedCategory = result['category'];
          _predictedOffice = result['department'];
          _isAnalyzingRealtime = false;
        });
      }
    }
  }

  void _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _files.addAll(result.files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDept == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your department')),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final currentStudentId = ref.read(userIdProvider) ?? 'anonymous';
        
        final aiResult = await ref.read(aiServiceProvider).analyzeConcern(_descController.text);
        final determinedCategory = aiResult['category'] as ConcernCategory;
        final targetOffice = aiResult['department'] as String;

        List<String> fileUrls = [];
        if (_files.isNotEmpty) {
          fileUrls = await ref.read(storageServiceProvider).uploadFiles(_files, 'student_attachments');
        }

        final concern = Concern(
          id: const Uuid().v4(),
          studentId: currentStudentId, 
          studentName: _isAnonymous ? 'Anonymous' : (_nameController.text.isEmpty ? 'Student' : _nameController.text.trim()),
          program: _selectedDept!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: determinedCategory,
          department: _selectedDept!,
          status: ConcernStatus.submitted,
          createdAt: DateTime.now(),
          isAnonymous: _isAnonymous,
          attachments: fileUrls,
          assignedTo: targetOffice,
        );

        await ref.read(concernServiceProvider).submitConcern(concern);
        
        if (mounted) {
          _showSuccessDialog(determinedCategory.name.toUpperCase(), targetOffice);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
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
        content: Text(
          'Our AI has categorized this as $categoryName and routed it to the $office.\n\nYou can track its progress in your dashboard.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const StudentDashboard())
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('GO TO DASHBOARD')
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Submit a Concern', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
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
                        _buildIdentityCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('CONCERN CONTENT', Icons.edit_note_outlined),
                        _buildConcernCard(),
                        if (_predictedCategory != null || _isAnalyzingRealtime) 
                          _buildAIInsightCard(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('ATTACHMENTS', Icons.attach_file_outlined),
                        _buildFilePickerSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSubmitButton(),
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
                    Text('AI Processing & Routing...', 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDept,
              decoration: const InputDecoration(
                labelText: 'Your College/Section',
                prefixIcon: Icon(Icons.school_outlined),
                border: OutlineInputBorder(),
              ),
              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDept = val),
              validator: (value) => value == null ? 'Selection required' : null,
            ),
            const SizedBox(height: 16),
            if (!_isAnonymous)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Submit Anonymously', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Hide your name from staff reviews', style: TextStyle(fontSize: 11)),
              value: _isAnonymous,
              onChanged: (val) => setState(() => _isAnonymous = val),
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcernCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Missing grade in IT 101',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Subject required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Detailed Description',
                hintText: 'Please provide as much detail as possible...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
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
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _isAnalyzingRealtime 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
            : const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI LIVE INSIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                Text(
                  _isAnalyzingRealtime 
                    ? 'Analyzing your concern...' 
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

  Widget _buildFilePickerSection() {
    return Column(
      children: [
        InkWell(
          onTap: _pickFiles,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, color: Colors.grey[400], size: 32),
                const SizedBox(height: 8),
                const Text('Click to upload documents/images', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ),
        if (_files.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._files.asMap().entries.map((entry) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: Colors.grey[100],
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.red),
              title: Text(entry.value.name, style: const TextStyle(fontSize: 12)),
              subtitle: Text('${(entry.value.size / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 10)),
              trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeFile(entry.key)),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Text('SUBMIT REQUEST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
      ),
    );
  }
}
