import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_user.dart';
import '../services/providers.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedDept;
  bool _isEditing = false;
  bool _isSaving = false;

  final List<String> _departments = ['COA', 'COE', 'CCS', 'CBAE'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(AppUser user) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _isSaving = true);
      try {
        final urls = await ref.read(storageServiceProvider).uploadFiles([result.files.first], 'profile_pics');
        if (urls.isNotEmpty) {
          final updatedUser = user.copyWith(profileImageUrl: urls.first);
          await ref.read(userServiceProvider).updateProfile(updatedUser);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveProfile(AppUser user) async {
    setState(() => _isSaving = true);
    try {
      final updatedUser = user.copyWith(
        name: _nameController.text.trim(),
        department: _selectedDept,
      );
      await ref.read(userServiceProvider).updateProfile(updatedUser);
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider) ?? '';
    final userDataAsync = ref.watch(userDataProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              if (userDataAsync.hasValue && userDataAsync.value != null) {
                if (!_isEditing) {
                  _nameController.text = userDataAsync.value!.name;
                  _selectedDept = userDataAsync.value!.department;
                }
                setState(() => _isEditing = !_isEditing);
              }
            },
          )
        ],
      ),
      body: userDataAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.red.shade100,
                      backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
                      child: user.profileImageUrl == null ? const Icon(Icons.person, size: 60, color: Colors.red) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.red,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: () => _pickAndUploadImage(user),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                if (!_isEditing) ...[
                  _profileItem('Full Name', user.name, Icons.person_outline),
                  _profileItem('Email', user.email, Icons.email_outlined),
                  _profileItem('Student ID', user.id, Icons.badge_outlined),
                  _profileItem('Department', user.department ?? 'Not Set', Icons.business_outlined),
                ] else ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedDept,
                    decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setState(() => _selectedDept = val),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _saveProfile(user),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE CHANGES'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _profileItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
