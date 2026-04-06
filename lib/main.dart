import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://kptcqhdiszsjzqyxszjg.supabase.co',
    anonKey: 'sb_publishable_l8T-n4Ro0ChubQx5ExIIqw_mSeTqCGi',
  );

  runApp(const LostAndFoundAdminApp());
}

final supabase = Supabase.instance.client;

class LostAndFoundAdminApp extends StatelessWidget {
  const LostAndFoundAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      // Check auth state to determine the starting screen
      home: supabase.auth.currentSession == null
          ? const LoginScreen()
          : const DashboardScreen(),
    );
  }
}