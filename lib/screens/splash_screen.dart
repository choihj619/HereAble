// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

/// SplashScreen is the first screen shown after app start.
/// It listens to UserProvider and decides which screen to go next.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkNavigation();
  }

  /// Checks the login/profile state and navigates accordingly.
  Future<void> _checkNavigation() async {
    if (_navigated) return; // Prevent double navigation
    final userProv = context.watch<UserProvider>();

    // Wait a short moment to show splash (optional)
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    if (!userProv.isSignedIn) {
      // Not signed in → go to login
      _goNext('/login');
    } else if (!userProv.isProfileComplete) {
      // Signed in but onboarding not done
      _goNext('/onboarding');
    } else {
      // Signed in & profile complete
      _goNext('/home');
    }
  }

  void _goNext(String routeName) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    // Simple splash UI with logo and loading indicator
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: Replace with your logo image
            const FlutterLogo(size: 100),
            const SizedBox(height: 24),
            const Text(
              'Hereable',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

