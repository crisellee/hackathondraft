import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../models/concern.dart';
import '../services/concern_service.dart';
import 'student_dashboard.dart';
import 'login_screen.dart';


class StudentForm extends ConsumerStatefulWidget {
  const StudentForm({super.key});


  @override
  ConsumerState<StudentForm> createState() => _StudentFormState();
}


class _StudentFormState extends ConsumerState<StudentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();


  String? _selectedDepartment;
  ConcernCategory _selectedCategory = ConcernCategory.academic;
  bool _isAnonymous = false;
  String _program = 'Computer Science';
  List<PlatformFile> _files = [];
  bool _isSubmitting = false;


  final List<String> _departments = ['COA', 'COE', 'CCS', 'CBAE'];


  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _files = result.files;
      });
    }
  }


  void _resetForm() {
    _nameController.clear();
    _studentIdController.clear();
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDepartment = null;
      _selectedCategory = ConcernCategory.academic;
      _isAnonymous = false;
      _files = [];
      _isSubmitting = false;
    });
  }


  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit a Concern'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text('Student Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (!_isAnonymous) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentIdController,
                      decoration: const InputDecoration(labelText: 'Student ID', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    value: _selectedDepartment,
                    hint: const Text('Select Department'),
                    items: _departments.map((dept) {
                      return DropdownMenuItem(value: dept, child: Text(dept));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedDepartment = value),
                    decoration: const InputDecoration(labelText: 'Department/College', border: OutlineInputBorder()),
                    validator: (value) => value == null ? 'Please select a department' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Submit Anonymously'),
                    subtitle: const Text('Your name and ID will be hidden from staff'),
                    value: _isAnonymous,
                    onChanged: (value) => setState(() => _isAnonymous = value),
                    activeColor: Colors.red,
                  ),
                  const Divider(height: 32),
                  const Text('Concern Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ConcernCategory>(
                    value: _selectedCategory,
                    items: ConcernCategory.values.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat.name.toUpperCase()));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 5,
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.attach_file, color: Colors.red),
                      title: const Text('Attachments'),
                      subtitle: Text(_files.isEmpty ? 'Optional files' : '\${_files.length} files selected'),
                      trailing: TextButton(onPressed: _pickFiles, child: const Text('SELECT', style: TextStyle(color: Colors.red))),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SUBMIT CONCERN', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.red))),
        ],
      ),
    );
  }


  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);


      try {
        final currentStudentId = ref.read(userIdProvider) ?? 'anonymous';

        final concern = Concern(
          id: const Uuid().v4(),
          studentId: _isAnonymous ? 'anonymous' : currentStudentId,
          studentName: _isAnonymous ? 'Anonymous' : _nameController.text,
          department: _selectedDepartment ?? 'Unknown',
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          status: ConcernStatus.submitted,
          createdAt: DateTime.now(),
          isAnonymous: _isAnonymous,
          attachments: _files.map((f) => 'fake_url/\${f.name}').toList(),
          program: _program,
        );


        await ref.read(concernServiceProvider).submitConcern(concern);


        if (mounted) {
          _showSuccessDialog();
          _resetForm();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
        }
      }
    }
  }


  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: const Text('Your concern has been submitted successfully. Please wait for our response.'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const StudentDashboard())
                );
              },
              child: const Text('VIEW TRACKED CONCERNS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}

