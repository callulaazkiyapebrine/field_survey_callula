import 'dart:convert';
import 'package:field_survey/screens/detail_survey.dart';
import 'package:field_survey/screens/tambah_edit_survey.dart';
import 'package:flutter/material.dart';
import 'package:field_survey/screens/auth/login.dart';
import 'package:field_survey/screens/daftar_survey.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  // ============================================================
  // 1. STATE / VARIABEL HALAMAN
  // ============================================================

  // Menyimpan daftar survey dalam bentuk List Map
  List<Map<String, dynamic>> surveys = [];

  // Menandai status loading saat mengambil data dari server
  bool isLoading = true;

  // Menyimpan pesan kesalahan jika gagal terhubung ke server
  String? errorMessage;

  // Endpoint API untuk mengambil daftar survey
  final String apiUrl = 'https://sijala.biz.id/api/v1/surveys';

  // Warna utama aplikasi
  static const Color primaryColor = Color(0xFF1E4CAF);

  // ============================================================
  // 2. LIFECYCLE (Dijalankan saat halaman pertama kali dibuka)
  // ============================================================

  @override
  void initState() {
    super.initState();
    fetchSurveys();
  }

  // ============================================================
  // 3. REST API: MENGAMBIL DAFTAR SURVEY (GET)
  // ============================================================

  Future<void> fetchSurveys() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Mengambil token login dari penyimpanan lokal
      // (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Jika token kosong, arahkan user ke halaman login
      if (token.isEmpty) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        return;
      }

      // Mengirim request GET ke API dengan menyertakan Bearer token
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Jika token sudah tidak valid / kedaluwarsa
      // (401 Unauthorized)
      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        return;
      }

      // Jika request berhasil (200 OK)
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        if (data['status'] == true && data['data'] is List) {
          final List rawList = data['data'];

          setState(() {
            surveys = rawList
                .whereType<Map>()
                .map(
                  (item) =>
                      Map<String, dynamic>.from(item),
                )
                .toList();

            isLoading = false;
          });

          return;
        }
      }

      // Jika server mengembalikan kode status selain 200
      throw Exception(
        'Gagal memuat data (Kode: ${response.statusCode})',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
      });
    }
  }

  // ============================================================
  // 4. NAVIGASI
  // ============================================================

  // Membuka halaman detail survey
  Future<void> openDetail(int surveyId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SurveyDetailPage(surveyId: surveyId),
      ),
    );

    // Jika ada perubahan (edit/hapus), muat ulang daftar survey
    if (result == true && mounted) {
      fetchSurveys();
    }
  }

  // Membuka form tambah survey
  Future<void> openAddSurvey() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SurveyFormPage(),
      ),
    );

    // Jika survey baru berhasil disimpan,
    // muat ulang daftar survey
    if (result == true && mounted) {
      fetchSurveys();
    }
  }

  // ============================================================
  // 5. HELPER FORMAT DATA
  // ============================================================

  // Mengambil nama kategori dari data survey
  String getCategoryName(Map<String, dynamic> survey) {
    if (survey['category_name'] != null &&
        survey['category_name'].toString().isNotEmpty) {
      return survey['category_name'].toString();
    }

    if (survey['category'] is Map &&
        survey['category']['name'] != null) {
      return survey['category']['name'].toString();
    }

    return 'Tanpa Kategori';
  }

  // Memformat tampilan tanggal (YYYY-MM-DD)
  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';

    try {
      final date = DateTime.parse(
        dateStr.replaceFirst(' ', 'T'),
      );

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ============================================================
  // 6. BUILD TAMPILAN WIDGET (UI)
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text('Daftar Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: fetchSurveys,
        child: buildBody(),
      ),

      // Tombol Tambah Survey (+) di pojok kanan bawah
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddSurvey,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Survey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Konten utama halaman
  // (Loading, Error, Kosong, atau Daftar Survey)
  // ============================================================

  Widget buildBody() {
    // ------------------------------------------------------------
    // 1. Kondisi Loading
    // ------------------------------------------------------------

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              'Memuat data survey...',
              style: TextStyle(
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    // ------------------------------------------------------------
    // 2. Kondisi Error
    // ------------------------------------------------------------

    if (errorMessage != null && surveys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Color(0xFFEF4444),
              ),

              const SizedBox(height: 16),

              const Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: fetchSurveys,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // ------------------------------------------------------------
    // 3. Kondisi Data Kosong
    // ------------------------------------------------------------

    if (surveys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: Color(0xFF94A3B8),
              ),

              const SizedBox(height: 16),

              const Text(
                'Belum Ada Data Survey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Tekan tombol di bawah untuk menambah survey baru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: openAddSurvey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Survey Baru'),
              ),
            ],
          ),
        ),
      );
    }

    // ------------------------------------------------------------
    // 4. Kondisi Ada Data:
    // Tampilkan Daftar Kartu Survey
    // ------------------------------------------------------------

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        88,
      ),
      itemCount: surveys.length,

      itemBuilder: (context, index) {
        final survey = surveys[index];

        final id =
            int.tryParse(
              survey['id']?.toString() ?? '',
            ) ??
            0;

        final title =
            survey['title']?.toString() ?? '-';

        final description =
            survey['description']?.toString() ?? '-';

        final category = getCategoryName(survey);

        final date = formatDate(
          survey['created_at']?.toString(),
        );

        final lat =
            survey['latitude']?.toString() ?? '';

        final lng =
            survey['longitude']?.toString() ?? '';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(
              color: Color(0xFFE2E8F0),
            ),
          ),

          child: InkWell(
            borderRadius: BorderRadius.circular(14),

            onTap: () => openDetail(id),

            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  // ------------------------------------------------
                  // Baris Atas: Judul & Kategori
                  // ------------------------------------------------

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFFEFF6FF,
                                ),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),

                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ------------------------------------------------
                  // Deskripsi Survey
                  // ------------------------------------------------

                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 1,
                  ),

                  const SizedBox(height: 10),

                  // ------------------------------------------------
                  // Baris Bawah: Lokasi & Tanggal
                  // ------------------------------------------------

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: primaryColor,
                      ),

                      const SizedBox(width: 4),

                      Expanded(
                        child: Text(
                          (lat.isNotEmpty &&
                                  lng.isNotEmpty)
                              ? '$lat, $lng'
                              : 'Lokasi tidak tersedia',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),

                      const SizedBox(width: 4),

                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}