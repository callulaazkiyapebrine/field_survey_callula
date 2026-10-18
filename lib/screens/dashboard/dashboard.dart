import 'dart:convert';

import 'package:field_survey/screens/auth/login.dart';
import 'package:field_survey/screens/daftar_survey.dart';
import 'package:field_survey/screens/profile/profil_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color primaryColor = Color(0xFF1E4BAF);

  int currentIndex = 0;

  String namaUser = 'User';

  bool isLoading = true;

  int totalSurvey = 0;
  int totalKategori = 0;

  List<dynamic> surveys = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  // =========================================================
  // AMBIL DATA DASHBOARD
  // =========================================================

  Future<void> loadDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');
      final userData = prefs.getString('user');

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );

        return;
      }

      // Ambil nama user
      if (userData != null && userData.isNotEmpty) {
        try {
          final dynamic user = jsonDecode(userData);

          if (user is Map) {
            final nama =
                user['name'] ??
                user['nama'] ??
                user['username'] ??
                user['nama_user'] ??
                user['full_name'] ??
                user['email'];

            if (nama != null && nama.toString().trim().isNotEmpty) {
              namaUser = nama.toString().trim();
            }
          }
        } catch (e) {
          debugPrint('ERROR MEMBACA USER: $e');
        }
      }

      if (mounted) {
        setState(() {});
      }

      // Request survey
      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/v1/surveys'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('DASHBOARD STATUS: ${response.statusCode}');

      debugPrint('DASHBOARD BODY: ${response.body}');

      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );

        return;
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        List<dynamic> data = [];

        if (result is Map && result['data'] is List) {
          data = result['data'];
        } else if (result is List) {
          data = result;
        }

        int selesai = 0;
        int pending = 0;

        for (final item in data) {
          if (item is Map) {
            final status = (item['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            if (status == 'selesai' ||
                status == 'completed' ||
                status == 'complete') {
              selesai++;
            } else if (status == 'pending' ||
                status == 'menunggu' ||
                status == 'diproses') {
              pending++;
            }
          }
        }

        if (!mounted) return;

        setState(() {
          surveys = data;
          totalSurvey = data.length;
          totalKategori = data
              .whereType<Map>()
              .map((item) {
                if (item['category_name'] != null &&
                    item['category_name'].toString().trim().isNotEmpty) {
                  return item['category_name'].toString().trim();
                }

                if (item['category'] is Map &&
                    item['category']['name'] != null &&
                    item['category']['name'].toString().trim().isNotEmpty) {
                  return item['category']['name'].toString().trim();
                }

                return '';
              })
              .where((nama) => nama.isNotEmpty)
              .toSet()
              .length;

          isLoading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR DASHBOARD: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  void changePage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      body: _buildBody(),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // =========================================================
  // BODY
  // =========================================================

  Widget _buildBody() {
    if (currentIndex == 1) {
      return const SurveyPage();
    }

    if (currentIndex == 2) {
      return const ProfilePage();
    }

    return _buildDashboard();
  }

  // =========================================================
  // DASHBOARD
  // =========================================================

  Widget _buildDashboard() {
    return SafeArea(
      child: RefreshIndicator(
        color: primaryColor,
        onRefresh: loadDashboard,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =======================================
                    // HEADER
                    // =======================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),

                            const SizedBox(height: 4),
                            Text(
                              'Halo, $namaUser 👋',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // =======================================
                    // WELCOME CARD
                    // =======================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 15),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kelola Survey',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 5),

                                Text(
                                  'Pantau dan kelola data survey kamu dengan mudah.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // =======================================
                    // STATISTIK
                    // =======================================
                    const Text(
                      'Ringkasan Survey',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            title: 'Total Survey',
                            value: totalSurvey.toString(),
                            icon: Icons.assignment_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            title: 'Total Kategori',
                            value: totalKategori.toString(),
                            icon: Icons.category_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // =======================================
                    // SURVEY TERBARU
                    // =======================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Survey Terbaru',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              currentIndex = 1;
                            });
                          },
                          child: const Text(
                            'Lihat semua',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    if (surveys.isEmpty)
                      _emptySurvey()
                    else
                      ...surveys.take(5).map((survey) => _surveyCard(survey)),
                  ],
                ),
              ),
      ),
    );
  }

  // =========================================================
  // STAT CARD
  // =========================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),

          const SizedBox(height: 12),

          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 3),

          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // =========================================================
  // SURVEY CARD
  // =========================================================

  Widget _surveyCard(dynamic survey) {
    final title =
        survey['title']?.toString() ??
        survey['nama']?.toString() ??
        survey['name']?.toString() ??
        'Survey';

    final lat = survey['latitude']?.toString() ?? '';
    final lng = survey['longitude']?.toString() ?? '';

    final lokasi = lat.isNotEmpty && lng.isNotEmpty
        ? '$lat, $lng'
        : 'Lokasi tidak tersedia';

    final status = survey['status']?.toString() ?? 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Pindah ke halaman Survey
            setState(() {
              currentIndex = 1;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),

                          const SizedBox(width: 4),

                          Expanded(
                            child: Text(
                              lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.toLowerCase() == 'selesai'
                        ? Colors.green.withOpacity(0.10)
                        : Colors.orange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: status.toLowerCase() == 'selesai'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _emptySurvey() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 50,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 10),

          const Text(
            'Belum ada survey',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          const Text(
            'Data survey akan muncul di sini.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,

        onTap: changePage,

        backgroundColor: Colors.white,

        elevation: 0,

        type: BottomNavigationBarType.fixed,

        selectedItemColor: primaryColor,

        unselectedItemColor: Colors.grey,

        selectedFontSize: 12,

        unselectedFontSize: 12,

        showUnselectedLabels: true,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Survey',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}