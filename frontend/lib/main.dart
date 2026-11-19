import 'package:flutter/material.dart';

import 'pages/challenge_page.dart';
import 'pages/handwriting_page.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/points_page.dart';
import 'pages/practice_page.dart';
import 'pages/review_page.dart';
import 'pages/timed_page.dart';
import 'services/session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.init();
  runApp(const MathFunApp());
}

class MathFunApp extends StatelessWidget {
  const MathFunApp({super.key});

  static const _primary = Color(0xFFFF7A59);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数学乐园',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _primary,
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
        cardTheme: const CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        buttonTheme: ButtonThemeData(
          buttonStyle: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size(double.infinity, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      initialRoute:
          Session.isLoggedIn ? HomePage.routeName : LoginPage.routeName,
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        HomePage.routeName: (_) => const HomePage(),
        PracticePage.routeName: (_) => const PracticePage(),
        ChallengePage.routeName: (_) => const ChallengePage(),
        TimedPage.routeName: (_) => const TimedPage(),
        HandwritingPage.routeName: (_) => const HandwritingPage(),
        ReviewPage.routeName: (_) => const ReviewPage(),
        PointsPage.routeName: (_) => const PointsPage(),
        HistoryPage.routeName: (_) => const HistoryPage(),
      },
    );
  }
}
