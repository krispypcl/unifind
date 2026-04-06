import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400, // Keeps the form from stretching too wide on web
          padding: const EdgeInsets.all(32.0),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Admin Portal',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Pre-built Email/Password Login Form
              SupaEmailAuth(
                redirectTo: null,
                onSignInComplete: (response) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                onSignUpComplete: (response) {
                  // Optional: Handle what happens if they create a new account
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Pre-built Google Sign-In Button
              SupaSocialsAuth(
                socialProviders: const [OAuthProvider.google],
                colored: true,
                // CRITICAL FOR WEB: Explicitly define your local testing port
                redirectUrl: 'http://localhost:3000', 
                onSuccess: (response) {
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