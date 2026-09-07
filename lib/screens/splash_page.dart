import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'home_page.dart'; // <-- This is the only import you need!

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// THIS FUNCTION CHECKS IF A USER IS ALREADY LOGGED IN.
  /// IF YES, IT SENDS THEM TO THE HOMEPAGE (WHICH HANDLES ROLE-BASED UI).
  /// IF NO, IT SENDS THEM TO THE LOGIN PAGE.
  Future<void> _checkLoginStatus() async {
    // WAIT 2 SECONDS TO SHOW THE SPLASH LOGO (LOOKS PROFESSIONAL)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // CHECK IF FIREBASE REMEMBERS A LOGGED-IN USER
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // NO USER LOGGED IN -> GO TO LOGIN PAGE
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      // USER IS LOGGED IN -> GO TO HOMEPAGE
      // (The HomePage already has the logic to fetch their role and show the correct dashboard)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // SIMPLE SPLASH SCREEN WITH APP LOGO
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.recycling, size: 100, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'KalaKalApp',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.green),
          ],
        ),
      ),
    );
  }
}