import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/personal_settings_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Firebase 연결 시 주석 해제
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider()..initialize(),
        ),
      ],
      child: const AppRoot(),
    ),
  );
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hereable',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/login':      (_) => const LoginScreen(),
        '/onboarding': (_) => const PersonalSettingsScreen(),
        '/settings':   (_) => const SettingsScreen(),
        '/home':       (_) => const HomeScreen(),
      },
      home: const SplashGate(),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    if (_navigated) return;

    final userProv = context.read<UserProvider>();

    // 초기화가 안됐으면 잠시 대기
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    if (!userProv.isSignedIn) {
      _go('/login');
      return;
    }
    if (!userProv.isProfileComplete) {
      _go('/onboarding');
      return;
    }
    _go('/home');
  }

  void _go(String route) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlutterLogo(size: 96),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hereable 홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: const Center(
        child: Text('홈 컨텐츠 영역'),
      ),
    );
  }
}
