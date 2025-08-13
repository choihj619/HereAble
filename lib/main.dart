import 'package:flutter/material.dart';
// Firebase 준비되면 아래 주석을 해제
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) 파이어베이스 준비되면 주석 해제
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const AppRoot());
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

      // 2) 전역 라우트: 이후 파일 분리 시 이름만 유지하면 됨
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/onboarding': (_) => const PersonalSettingsScreen(),
      },

      // 3) 시작 화면: 스플래시 → 분기
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
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // TODO: Firebase Auth 붙이면 아래 isLoggedIn을 실제 인증 상태로 교체
    // final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    const isLoggedIn = false; // 임시: 아직 로그인 안 된 상태라고 가정

    // TODO: Firestore에서 사용자 프로필(개인 설정 완료 여부) 불러오면 교체
    const isProfileComplete = false; // 임시: 온보딩 필요하다고 가정

    await Future.delayed(const Duration(milliseconds: 600)); // 로고 살짝 보여주기

    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else if (!isProfileComplete) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 로그인 화면 (임시 버전)
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: ElevatedButton(
          child: const Text('로그인 성공 가정 → 홈으로'),
          onPressed: () {
            // TODO: FirebaseAuth 로그인 성공 시 로직으로 교체
            Navigator.pushReplacementNamed(context, '/onboarding');
          },
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
              // TODO: FirebaseAuth.signOut()로 교체
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
    // TODO: 라디오/체크/드롭다운 등으로 실제 옵션 구성
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
                // TODO: Firestore에 설정 저장 후 홈으로
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

