import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../main.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              // ── UniFind Branding ─────────────────────────────
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.travel_explore_rounded,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'UniFind',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'University Lost & Found Admin Portal',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 36),
              
              // Pre-built Email/Password Login Form
              SupaEmailAuth(
                redirectTo: null,
                onSignInComplete: (response) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                onSignUpComplete: (response) async {
                  final user = response.user;
                  if (user != null) {
                    try {
                      await supabase.from('users').upsert({
                        'id': user.id,
                        'email': user.email,
                        'role': 'admin',
                      });
                    } catch (_) {}
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  }
                },
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Pre-built Google Sign-In Button
              SupaSocialsAuth(
                socialProviders: const [OAuthProvider.google],
                colored: true,
                showSuccessSnackBar: false,
                // CRITICAL FOR WEB: Explicitly define your local testing port
                redirectUrl: 'http://localhost:3000',
                onSuccess: (response) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully signed in!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                onError: (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Auth Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}