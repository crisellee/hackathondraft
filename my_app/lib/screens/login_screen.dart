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
  String? _view = 'selection'; 
  String _selectedRole = 'student';

  // Back to official Logo look
  static const String _grcLogoUrl = 'https://grc.edu.ph/wp-content/uploads/2021/03/GRC-Logo-1.png';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _buildCurrentView(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(bool isDark) {
    switch (_view) {
      case 'selection': return _buildSelectionView(isDark);
      case 'login': return _buildLoginView(isDark);
      case 'register': return _buildRegisterView(isDark);
      case 'forgot': return _buildForgotView(isDark);
      default: return _buildSelectionView(isDark);
    }
  }

  Widget _buildSelectionView(bool isDark) {
    return Column(
      children: [
        Image.network(_grcLogoUrl, height: 120, fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const Icon(Icons.school, size: 80, color: Colors.red)),
        const SizedBox(height: 24),
        Text('ConcernTrack Login', 
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.w900, 
            color: isDark ? Colors.redAccent : const Color(0xFF8B0000)
          )
        ),
        Text('Global Reciprocal Colleges', 
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)
        ),
        const SizedBox(height: 48),
        _selectionButton(
          label: 'Login as Student', 
          icon: Icons.person, 
          isPrimary: false, 
          isDark: isDark,
          onPressed: () => setState(() { _selectedRole = 'student'; _view = 'login'; })
        ),
        const SizedBox(height: 16),
        _selectionButton(
          label: 'Login as Staff/Admin', 
          icon: Icons.admin_panel_settings, 
          isPrimary: true, 
          isDark: isDark,
          onPressed: () => setState(() { _selectedRole = 'admin'; _view = 'login'; })
        ),
      ],
    );
  }

  Widget _buildLoginView(bool isDark) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft, 
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87), 
            onPressed: () => setState(() => _view = 'selection')
          )
        ),
        Image.network(_grcLogoUrl, height: 80, fit: BoxFit.contain),
        const SizedBox(height: 24),
        Text('Login as ${_selectedRole.toUpperCase()}', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
        ),
        const SizedBox(height: 32),
        _textField(_emailController, 'Email Address', Icons.email_outlined, isDark),
        const SizedBox(height: 16),
        _textField(_passwordController, 'Password', Icons.lock_outline, isDark, isPassword: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _view = 'forgot'), 
            child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, color: Colors.redAccent))
          ),
        ),
        const SizedBox(height: 24),
        _actionButton('SIGN IN', _handleLogin),
        if (_selectedRole == 'student') ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _view = 'register'),
            child: const Text('New Student? Create Account', 
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterView(bool isDark) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft, 
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87), 
            onPressed: () => setState(() => _view = 'login')
          )
        ),
        Image.network(_grcLogoUrl, height: 80, fit: BoxFit.contain),
        const SizedBox(height: 16),
        Text('Student Registration', 
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.redAccent : const Color(0xFF8B0000)
          )
        ),
        const SizedBox(height: 24),
        _textField(_regIdController, 'Student ID', Icons.badge_outlined, isDark),
        const SizedBox(height: 12),
        _textField(_regNameController, 'Full Name', Icons.person_outline, isDark),
        const SizedBox(height: 12),
        _textField(_regEmailController, 'Email Address', Icons.email_outlined, isDark),
        const SizedBox(height: 12),
        _textField(_regPasswordController, 'Create Password', Icons.lock_outline, isDark, isPassword: true),
        const SizedBox(height: 32),
        _actionButton('CREATE ACCOUNT', _handleRegister),
      ],
    );
  }

  Widget _buildForgotView(bool isDark) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft, 
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87), 
            onPressed: () => setState(() => _view = 'login')
          )
        ),
        const Icon(Icons.mark_email_unread_outlined, size: 60, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text('Reset Password', 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
        ),
        const SizedBox(height: 12),
        Text('Enter your email to receive a reset link.', 
          textAlign: TextAlign.center, 
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)
        ),
        const SizedBox(height: 32),
        _textField(_emailController, 'Email Address', Icons.email_outlined, isDark),
        const SizedBox(height: 32),
        _actionButton('SEND RESET LINK', () {
          _showError('Reset link sent to your email!');
          setState(() => _view = 'login');
        }),
      ],
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon, bool isDark, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, color: Colors.redAccent),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: isDark ? Colors.white60 : Colors.grey), 
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword)
        ) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Widget _selectionButton({required String label, required IconData icon, required bool isPrimary, required bool isDark, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.redAccent : (isDark ? const Color(0xFF1E293B) : Colors.white),
          foregroundColor: isPrimary ? Colors.white : Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary ? BorderSide.none : BorderSide(color: isDark ? Colors.white10 : Colors.redAccent.withOpacity(0.2)),
          ),
          elevation: isPrimary ? 2 : 0,
        ),
      ),
    );
  }
}
