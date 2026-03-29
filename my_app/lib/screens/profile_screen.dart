import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/providers.dart';
import '../services/user_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _profileLinkController = TextEditingController();
  
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _showPasswordFields = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _profileLinkController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(AppUser user) async {
    if (_showPasswordFields) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final updatedUser = user.copyWith(
        name: _nameController.text.trim(),
        profileImageUrl: _profileLinkController.text.trim(),
      );
      await ref.read(userServiceProvider).updateProfile(updatedUser);
      setState(() {
        _isEditing = false;
        _showPasswordFields = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider) ?? '';
    final userDataAsync = ref.watch(userDataProvider(userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              if (userDataAsync.hasValue) {
                final user = userDataAsync.value!;
                _nameController.text = user.name;
                _usernameController.text = user.id;
                _emailController.text = user.email;
                _profileLinkController.text = user.profileImageUrl ?? '';
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
                _buildAvatar(user.profileImageUrl),
                const SizedBox(height: 32),
                if (!_isEditing) _buildViewMode(user, isDark) else _buildEditMode(user, isDark),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.red.withOpacity(0.1),
      backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty) ? const Icon(Icons.person, size: 60, color: Colors.red) : null,
    );
  }

  Widget _buildViewMode(AppUser user, bool isDark) {
    return Column(
      children: [
        _infoTile(Icons.person, 'Full Name', user.name, isDark),
        _infoTile(Icons.account_circle, 'Username', user.id, isDark),
        _infoTile(Icons.email, 'Email', user.email, isDark),
        _infoTile(Icons.link, 'Profile Image Link', user.profileImageUrl ?? 'Not set', isDark),
      ],
    );
  }

  Widget _buildEditMode(AppUser user, bool isDark) {
    return Column(
      children: [
        _editField(_nameController, 'Full Name', Icons.person, isDark),
        const SizedBox(height: 16),
        _editField(_usernameController, 'Username', Icons.account_circle, isDark, enabled: false),
        const SizedBox(height: 16),
        _editField(_emailController, 'Email', Icons.email, isDark, enabled: false),
        const SizedBox(height: 16),
        _editField(_profileLinkController, 'Profile Image URL', Icons.link, isDark),
        const SizedBox(height: 24),
        
        TextButton.icon(
          onPressed: () => setState(() => _showPasswordFields = !_showPasswordFields),
          icon: Icon(_showPasswordFields ? Icons.keyboard_arrow_up : Icons.lock_reset, color: Colors.red),
          label: Text(_showPasswordFields ? 'Hide Password Change' : 'Change Password', style: const TextStyle(color: Colors.red)),
        ),
        
        if (_showPasswordFields) ...[
          const SizedBox(height: 16),
          _editField(_oldPasswordController, 'Old Password', Icons.lock_outline, isDark, obscure: true),
          const SizedBox(height: 12),
          _editField(_newPasswordController, 'New Password', Icons.lock, isDark, obscure: true),
          const SizedBox(height: 12),
          _editField(_confirmPasswordController, 'Confirm New Password', Icons.lock_clock, isDark, obscure: true),
        ],
        
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
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
    );
  }

  Widget _editField(TextEditingController controller, String label, IconData icon, bool isDark, {bool enabled = true, bool obscure = false}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
        prefixIcon: Icon(icon, color: Colors.red),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        filled: !enabled || isDark,
        fillColor: !enabled ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100) : (isDark ? Colors.white.withOpacity(0.05) : null),
      ),
    );
  }
}
