import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/auth_cubit.dart';
import 'bloc/points_cubit.dart';
import 'pages/challenge_page.dart';
import 'pages/handwriting_page.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/points_page.dart';
import 'pages/practice_page.dart';
import 'pages/review_page.dart';
import 'pages/timed_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MathFunApp());
}

class MathFunApp extends StatelessWidget {
  const MathFunApp({super.key});

  static const _primary = Color(0xFFFF7A59);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit()..init(),
      child: const _AppShell(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PointsCubit(),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return MaterialApp(
            title: '数学乐园',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: MathFunApp._primary,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFFFF6F0),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A3E36),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 54),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // 根据登录状态自动切换首页，登录/退出无需手动导航
            home: state.user != null ? const HomePage() : const LoginPage(),
            routes: {
              PracticePage.routeName: (_) => const PracticePage(),
              ChallengePage.routeName: (_) => const ChallengePage(),
              TimedPage.routeName: (_) => const TimedPage(),
              HandwritingPage.routeName: (_) => const HandwritingPage(),
              ReviewPage.routeName: (_) => const ReviewPage(),
              PointsPage.routeName: (_) => const PointsPage(),
              HistoryPage.routeName: (_) => const HistoryPage(),
            },
          );
        },
      ),
    );
  }
}
