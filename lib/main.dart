import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
// Chris Roldan P Perez

// Global theme mode notifier — lets any widget toggle dark mode
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kptcqhdiszsjzqyxszjg.supabase.co',
    anonKey: 'sb_publishable_l8T-n4Ro0ChubQx5ExIIqw_mSeTqCGi',
  );

  // Sign out stale sessions on fresh loads so users must always log in.
  // Exception: skip sign-out when this IS an OAuth redirect callback —
  // the URL will contain the auth tokens/code that Supabase just processed.
  final uri = Uri.base;
  final isOAuthCallback = uri.fragment.contains('access_token') ||
      uri.queryParameters.containsKey('code');
  if (!isOAuthCallback) {
    await Supabase.instance.client.auth.signOut();
  }

  runApp(const UniFindApp());
}

final supabase = Supabase.instance.client;

class UniFindApp extends StatelessWidget {
  const UniFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'UniFind — University Lost & Found',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}
