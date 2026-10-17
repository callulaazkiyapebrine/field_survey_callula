import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color primaryColor = Color(0xFF1E4BAF);

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      context.go(AppRoutes.Login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ==========================================
            // LOGO
            // ==========================================

            Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // Lingkaran transparan
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),

                  // Icon utama
                  const Icon(
                    Icons.assignment_rounded,
                    size: 58,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ==========================================
            // NAMA APLIKASI
            // ==========================================

            const Text(
              'Field Survey',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 8),

            // ==========================================
            // DESKRIPSI
            // ==========================================

            const Text(
              'Aplikasi Mobile Berbasis Flutter',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 45),

            // ==========================================
            // LOADING
            // ==========================================

            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'Memuat aplikasi...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
