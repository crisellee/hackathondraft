import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'screens/student_form.dart';
import 'screens/student_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_concern_list.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/public_knowledge_base_screen.dart';
import 'services/providers.dart';
import 'services/user_service.dart';

void main() async {
  // Preserve splash screen while initializing
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const ProviderScope(child: ConcernTrackApp()));

  // Hide splash screen after initialization
  FlutterNativeSplash.remove();
}

class ConcernTrackApp extends ConsumerWidget {
  const ConcernTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final userId = ref.watch(userIdProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'ConcernTrack',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, primary: Colors.red),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.red, foregroundColor: Colors.white),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red, 
          primary: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E293B), foregroundColor: Colors.white),
        cardTheme: const CardThemeData(color: Color(0xFF1E293B)),
      ),
      home: (role == null || userId == null) 
          ? const LoginScreen() 
          : const MainNavigation(),
    );
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final userId = ref.watch(userIdProvider) ?? '';
    final userDataAsync = ref.watch(userDataProvider(userId));
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final List<Widget> studentScreens = [
      const StudentForm(),
      const StudentDashboard(),
      const PublicKnowledgeBaseScreen(),
      const AIChatScreen(),
    ];

    final List<Widget> adminScreens = [
      const AdminDashboard(),
      const AdminConcernList(),
      const PublicKnowledgeBaseScreen(),
      const AIChatScreen(),
    ];

    Widget currentBody;
    if (role == 'student') {
      currentBody = studentScreens[_selectedIndex < studentScreens.length ? _selectedIndex : 0];
    } else {
      currentBody = adminScreens[_selectedIndex < adminScreens.length ? _selectedIndex : 0];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'student' ? 'Student Portal' : 'Admin Console'),
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
                  backgroundImage: user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty 
                      ? NetworkImage(user.profileImageUrl!) : null,
                  child: user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty 
                      ? const Icon(Icons.person, color: Colors.red) : null,
                ),
                decoration: const BoxDecoration(color: Colors.red),
              ),
              loading: () => const DrawerHeader(child: Center(child: CircularProgressIndicator(color: Colors.white))),
              error: (_, __) => const DrawerHeader(child: Text('Error loading user')),
            ),
            
            // DARK MODE TOGGLE SA DRAWER
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.amber : Colors.grey),
              title: const Text('Dark Mode'),
              value: isDark,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
              },
            ),
            const Divider(),

            if (role == 'student') ...[
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.red),
                title: const Text('Submit New Concern'),
                selected: _selectedIndex == 0,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: Colors.red),
                title: const Text('My Tracked Concerns'),
                selected: _selectedIndex == 1,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books, color: Colors.red),
                title: const Text('Community Knowledge Base'),
                selected: _selectedIndex == 2,
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.amber),
                title: const Text('GRC AI Assistant'),
                selected: _selectedIndex == 3,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
            ],

            if (role == 'admin') ...[
              ListTile(
                leading: const Icon(Icons.analytics, color: Colors.red),
                title: const Text('Staff Dashboard'),
                selected: _selectedIndex == 0,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.red),
                title: const Text('View Concerns Registry'),
                selected: _selectedIndex == 1,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books, color: Colors.red),
                title: const Text('Community Knowledge Base'),
                selected: _selectedIndex == 2,
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.amber),
                title: const Text('GRC AI Assistant'),
                subtitle: const Text('Admin Support Tool'),
                selected: _selectedIndex == 3,
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(userRoleProvider.notifier).state = null;
                ref.read(userIdProvider.notifier).state = null;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: currentBody,
    );
  }
}
