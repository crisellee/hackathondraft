import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';


final userRoleProvider = StateProvider<String?>((ref) => null);
final userIdProvider = StateProvider<String?>((ref) => null);


class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.track_changes, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'ConcernTrack Login',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const Text(
                'Sign in to continue',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              _LoginButton(
                label: 'Login as Student',
                icon: Icons.school,
                onPressed: () {
                  ref.read(userRoleProvider.notifier).state = 'student';
                  ref.read(userIdProvider.notifier).state = 'student_123';
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavigation()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _LoginButton(
                label: 'Login as Staff/Admin',
                icon: Icons.admin_panel_settings,
                onPressed: () {
                  ref.read(userRoleProvider.notifier).state = 'admin';
                  ref.read(userIdProvider.notifier).state = 'admin_user';
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavigation()),
                  );
                },
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _LoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;


  const _LoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });


  @override
  Widget build(BuildContext context) {
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
          elevation: 0,
          side: BorderSide(color: Colors.red.shade100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

