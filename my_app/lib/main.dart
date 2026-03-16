import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/student_form.dart';
import 'screens/student_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializing Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: ConcernTrackApp(),
    ),
  );
}

class ConcernTrackApp extends StatelessWidget {
  const ConcernTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConcernTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, primary: Colors.red),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ConcernTrack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(userRoleProvider.notifier).state = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.track_changes, size: 100, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'ConcernTrack',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                Text(
                  role == 'student' ? 'Student Portal' : 'Staff Administration',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 60),
                if (role == 'student') ...[
                  _NavCard(
                    icon: Icons.add_comment,
                    title: 'Submit Concern',
                    subtitle: 'File a new academic or welfare concern',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentForm())
                    ),
                  ),
                  const SizedBox(height: 20),
                  _NavCard(
                    icon: Icons.dashboard,
                    title: 'My Tracked Concerns',
                    subtitle: 'Check the status of your submissions',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentDashboard())
                    ),
                  ),
                ],
                if (role == 'admin') ...[
                  _NavCard(
                    icon: Icons.admin_panel_settings,
                    title: 'Staff Dashboard',
                    subtitle: 'Manage, route, and resolve concerns',
                    isPrimary: true,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminDashboard())
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.red : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).toInt()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: isPrimary ? Colors.white : Colors.red),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isPrimary ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
