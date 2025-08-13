// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Firebase 준비되면 아래 주석을 해제
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'firebase_options.dart';

import 'providers/user_provider.dart';
// 스플래시를 별도 파일로 만들었다면 아래처럼 import:
// import 'screens/splash_screen.dart';  // (지금 예시는 내부 클래스로 작성)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔧 나중에 Firebase 붙일 때 주석 해제
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
        '/splash': (_) => const SplashGate(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/onboarding': (_) => const PersonalSettingsScreen(),
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

    // TODO: Firebase Auth 붙인 뒤엔 userProv.isSignedIn이 실제 인증 상태를 의미함
    if (!userProv.isSignedIn) {
      _go('/login');
      return;
    }

    // 로그인은 됐는데 온보딩(개인 설정) 미완료라면
    if (!userProv.isProfileComplete) {
      _go('/onboarding');
      return;
    }

    // 모두 완료 → 홈
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

/// 로그인 화면 (임시 버전)
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 실제 AuthService().signInWithEmail / signInWithGoogle 등으로 교체
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 임시: 로그인 성공 가정 → 온보딩으로
            Navigator.pushReplacementNamed(context, '/onboarding');
          },
          child: const Text('로그인 성공 가정 → 온보딩으로'),
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

/// 마이페이지/설정 화면
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

/// 개인 설정(온보딩) – 장애유형/우선순위 등 최초 1회 입력
class PersonalSettingsScreen extends StatelessWidget {
  const PersonalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 실제 옵션 위젯(라디오/체크/드롭다운) + UserProvider.markOnboardingComplete 연결
    return Scaffold(
      appBar: AppBar(title: const Text('개인 설정(온보딩)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('장애유형, 우선순위(맞춤/별점/거리) 등을 선택하세요.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Firestore 저장 후 완료 처리
                // context.read<UserProvider>().markOnboardingComplete(...);
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('완료하고 시작하기'),
            ),
          ],
        ),
      ),
    );
  }
}

