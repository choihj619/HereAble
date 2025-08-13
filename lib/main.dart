// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider
import 'providers/user_provider.dart';

// Screens (분리 파일)
import 'screens/login_screen.dart';               // 로그인 화면
import 'screens/personal_settings_screen.dart';   // 온보딩(개인 설정)
import 'screens/settings_screen.dart';            // 마이페이지·환경설정 (분리 파일로 사용)

// Firebase 준비되면 아래 주석 해제
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 나중에 Firebase 붙일 때 주석 해제
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(
    MultiProvider(
      providers: [
        // UserProvider가 Auth 상태/유저 문서를 구독하고 분기 판단에 쓰임
        ChangeNotifierProvider(create: (_) => UserProvider()..initialize()),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // 📍 라우트 테이블
      routes: {
        '/splash':     (_) => const SplashGate(),
        '/login':      (_) => const LoginScreen(),
        '/onboarding': (_) => const PersonalSettingsScreen(),
        '/home':       (_) => const HomeScreen(),     // (지금은 이 파일 안 임시 화면)
        '/settings':   (_) => const SettingsScreen(), // (분리 파일)
      },

      // 시작 화면: 스플래시 → (로그인/온보딩/홈) 자동 분기
      home: const SplashGate(),
    );
  }
}

/// 앱 시작 시 잠깐 보여주는 화면 + 분기 로직
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
    _decideNext();
  }

  Future<void> _decideNext() async {
    if (_navigated) return;

    // 🔎 Provider에서 로그인/프로필 상태 읽기
    final userProv = context.read<UserProvider>();

    // 로고/스플래시를 잠깐 보여주고 분기
    await Future.delayed(const Duration(milliseconds: 600));

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
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    // 심플 스플래시 UI
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

/// 첫 화면(홈) – 이후 장소 리스트/지도 등 붙일 곳 (임시)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 예시: 마이페이지로 이동
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hereable 홈'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: const Center(child: Text('홈 컨텐츠 영역')),
    );
  }
}
