import 'package:field_survey/screens/profile/profil_page.dart';
import 'package:field_survey/screens/daftar_survey.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login.dart';
import '../screens/dashboard/dashboard.dart';
import '../screens/auth/register.dart';
import 'app_routes.dart';

class AppPages {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.Login,
        builder: (context, state) => LoginPage()),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => DashboardPage(),
      ),
       GoRoute(
        path: AppRoutes.profil,
        builder: (context, state) => ProfilePage(),
      ),
        GoRoute(
        path: AppRoutes.survey,
        builder: (context, state) => SurveyPage(),
      ),
    ],
  );
}
