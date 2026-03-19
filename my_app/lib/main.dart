import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/student_form.dart';
import 'screens/student_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_concern_list.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/providers.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const ProviderScope(child: ConcernTrackApp()));
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
        appBarTheme: const AppBarTheme(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    final userId = ref.watch(userIdProvider) ?? '';
    final userDataAsync = ref.watch(userDataProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ConcernTrack'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            userDataAsync.when(
              data: (user) => UserAccountsDrawerHeader(
                accountName: Text(user?.name ?? 'User'),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: user?.profileImageUrl != null ? NetworkImage(user!.profileImageUrl!) : null,
                  child: user?.profileImageUrl == null ? const Icon(Icons.person, color: Colors.red) : null,
                ),
                decoration: const BoxDecoration(color: Colors.red),
              ),
              loading: () => const DrawerHeader(child: Center(child: CircularProgressIndicator(color: Colors.white))),
              error: (_, __) => const DrawerHeader(child: Text('Error loading user')),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(userRoleProvider.notifier).state = null;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              },
            ),
          ],
        ),
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
                const Icon(Icons.track_changes, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text('ConcernTrack', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.red)),
                Text(role == 'student' ? 'Student Portal' : 'Staff Administration', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                if (role == 'student') ...[
                  _NavCard(icon: Icons.add_comment, title: 'Submit Concern', subtitle: 'File a new concern', 
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentForm()))),
                  const SizedBox(height: 16),
                  _NavCard(icon: Icons.dashboard, title: 'My Tracked Concerns', subtitle: 'Check status', 
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentDashboard()))),
                ],
                if (role == 'admin') ...[
                  _NavCard(icon: Icons.analytics, title: 'Staff Dashboard', subtitle: 'View analytics', isPrimary: true,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboard()))),
                  const SizedBox(height: 16),
                  _NavCard(icon: Icons.list_alt, title: 'View Concerns', subtitle: 'Manage submissions', 
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConcernList()))),
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

  const _NavCard({required this.icon, required this.title, required this.subtitle, required this.onPressed, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.red : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: isPrimary ? Colors.white : Colors.red),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : Colors.black87)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: isPrimary ? Colors.white70 : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
