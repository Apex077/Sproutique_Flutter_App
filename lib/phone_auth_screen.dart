import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as firebase_ui_auth;

class PhoneAuthScreen extends StatelessWidget {
  const PhoneAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // User is signed in, navigate to the dashboard.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        });
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 145, 225, 113), // Pastel green background
        ),
        child: firebase_ui_auth.SignInScreen(
          providers: [
            firebase_ui_auth.PhoneAuthProvider(),
          ],
          headerBuilder: (context, constraints, _) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Welcome to Sproutique",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 50, 131, 54), // Dark green text
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
          subtitleBuilder: (context, action) {
            return const SizedBox(); // Empty widget to hide subtitle
          },
          footerBuilder: (context, action) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  // Handle hyperlink action
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Contact support at help@sproutique.com")),
                  );
                },
                child: Text(
                  "Need help? Contact us.",
                  style: const TextStyle(
                    color: Color.fromARGB(
                        255, 50, 131, 54), // Dark green hyperlink
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
