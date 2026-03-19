import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../services/providers.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regIdController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _view = 'selection'; // 'selection', 'login', 'register', 'forgot'
  String _selectedRole = 'student';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regNameController.dispose();
    _regIdController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);
    final user = await ref.read(authServiceProvider).login(email, password, _selectedRole);

    if (mounted) {
      setState(() => _isLoading = false);
      if (user != null) {
        ref.read(userRoleProvider.notifier).state = user['role'];
        ref.read(userIdProvider.notifier).state = user['id'];
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
      } else {
        _showError('Invalid credentials');
      }
    }
  }

  void _handleRegister() async {
    if (_regEmailController.text.isEmpty || _regPasswordController.text.isEmpty || _regIdController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(authServiceProvider).registerStudent(
      email: _regEmailController.text.trim(),
      password: _regPasswordController.text.trim(),
      name: _regNameController.text.trim(),
      studentId: _regIdController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please login.')));
        setState(() => _view = 'login');
      } else {
        _showError('Registration failed');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _buildCurrentView(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case 'selection': return _buildSelectionView();
      case 'login': return _buildLoginView();
      case 'register': return _buildRegisterView();
      case 'forgot': return _buildForgotView();
      default: return _buildSelectionView();
    }
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        const Icon(Icons.track_changes, size: 80, color: Colors.red),
        const SizedBox(height: 24),
        const Text('ConcernTrack Login', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
        const Text('Sign in to continue', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 48),
        _selectionButton(label: 'Login as Student', icon: Icons.school, isPrimary: false, 
          onPressed: () => setState(() { _selectedRole = 'student'; _view = 'login'; })),
        const SizedBox(height: 16),
        _selectionButton(label: 'Login as Staff/Admin', icon: Icons.admin_panel_settings, isPrimary: true, 
          onPressed: () => setState(() { _selectedRole = 'admin'; _view = 'login'; })),
      ],
    );
  }

  Widget _buildLoginView() {
    return Column(
      children: [
        Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _view = 'selection'))),
        const Icon(Icons.lock_person, size: 60, color: Colors.red),
        const SizedBox(height: 16),
        Text('Login as ${_selectedRole.toUpperCase()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        _textField(_emailController, 'Email Address', Icons.email_outlined),
        const SizedBox(height: 16),
        _textField(_passwordController, 'Password', Icons.lock_outline, isPassword: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => setState(() => _view = 'forgot'), child: const Text('Forgot Password?', style: TextStyle(fontSize: 12))),
        ),
        const SizedBox(height: 24),
        _actionButton('SIGN IN', _handleLogin),
        
        if (_selectedRole == 'student') ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _view = 'register'),
            child: const Text('New Student? Create Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],

        const SizedBox(height: 24),
        const Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        _googleButton(),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      children: [
        Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _view = 'login'))),
        const Text('Student Registration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 24),
        _textField(_regIdController, 'Student ID', Icons.badge_outlined),
        const SizedBox(height: 12),
        _textField(_regNameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 12),
        _textField(_regEmailController, 'Email Address', Icons.email_outlined),
        const SizedBox(height: 12),
        _textField(_regPasswordController, 'Create Password', Icons.lock_outline, isPassword: true),
        const SizedBox(height: 32),
        _actionButton('CREATE ACCOUNT', _handleRegister),
      ],
    );
  }

  Widget _buildForgotView() {
    return Column(
      children: [
        Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _view = 'login'))),
        const Icon(Icons.mark_email_unread_outlined, size: 60, color: Colors.red),
        const SizedBox(height: 16),
        const Text('Reset Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Enter your email to receive a reset link.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        _textField(_emailController, 'Email Address', Icons.email_outlined),
        const SizedBox(height: 32),
        _actionButton('SEND RESET LINK', () {
          _showError('Reset link sent to your email!');
          setState(() => _view = 'login');
        }),
      ],
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: () => _showError('Google Sign-In coming soon!'),
        icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_\"G\"_Logo.svg', height: 24, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 30)),
        label: const Text('Continue with Google', style: TextStyle(color: Colors.black87)),
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Colors.grey)),
      ),
    );
  }

  Widget _selectionButton({required String label, required IconData icon, required bool isPrimary, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.red : Colors.white,
          foregroundColor: isPrimary ? Colors.white : Colors.red,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
