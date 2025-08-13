// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Provider
import 'providers/user_provider.dart';

// Screens (분리 파일)
import 'screens/personal_settings_screen.dart'; // 온보딩(개인 설정)
import 'screens/login_screen.dart';             // 로그인 화면

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

      // 📍 라우트 테이블 (파일 분리해도 이름만 유지하면 됨)
      routes: {
        '/splash':     (_) => const SplashGate(),
        '/login':      (_) => const LoginScreen(),             // ← 분리 파일 사용
        '/onboarding': (_) => const PersonalSettingsScreen(),  // ← 분리 파일 사용
        '/home':       (_) => const HomeScreen(),              // (현재 파일 내 임시 화면)
        '/settings':   (_) => const SettingsScreen(),          // (현재 파일 내 임시 화면)
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

/// 첫 화면(홈) – 이후 장소 리스트/지도 등 붙일 곳
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

/// 마이페이지/설정 화면 (임시)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: UserProvider.profile과 연동해서 닉네임/이메일/설정 바인딩
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지 & 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(title: Text('닉네임'), subtitle: Text('예: 준영')),
          const ListTile(title: Text('이메일'), subtitle: Text('you@example.com')),
          const Divider(),
          SwitchListTile(
            value: true,
            onChanged: (v) {},
            title: const Text('다크 모드(예시)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // TODO: AuthService().signOut() 호출로 교체
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
