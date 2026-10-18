import 'dart:convert';
import 'dart:typed_data';

import 'package:field_survey/screens/auth/login.dart';
import 'package:field_survey/screens/tambah_edit_survey.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SurveyDetailPage extends StatefulWidget {
  final int surveyId;

  const SurveyDetailPage({super.key, required this.surveyId});

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  // ============================================================
  // KONFIGURASI
  // ============================================================

  static const Color primaryColor = Color(0xFF1E4BAF);

  static const String apiBaseUrl = 'https://sijala.biz.id/api/v1';

  // ============================================================
  // STATE
  // ============================================================

  Map<String, dynamic>? survey;

  bool isLoading = true;
  bool isLoadingImage = false;
  bool isDeleting = false;

  String? errorMessage;

  Uint8List? imageBytes;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      return null;
    }

    return token;
  }

  // ============================================================
  // LOGIN ULANG
  // ============================================================

  Future<void> goToLogin() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('token');
    await prefs.remove('user');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ============================================================
  // AMBIL DETAIL SURVEY
  // ============================================================

  Future<void> fetchDetail() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      imageBytes = null;
    });

    try {
      final token = await getToken();

      // ----------------------------------------------------------
      // TOKEN KOSONG
      // ----------------------------------------------------------

      if (token == null) {
        await goToLogin();
        return;
      }

      // ----------------------------------------------------------
      // URL DETAIL
      // ----------------------------------------------------------

      final url = Uri.parse('$apiBaseUrl/surveys/${widget.surveyId}');

      debugPrint('');
      debugPrint('========== GET DETAIL ==========');
      debugPrint('ID      : ${widget.surveyId}');
      debugPrint('URL     : $url');
      debugPrint('================================');

      // ----------------------------------------------------------
      // REQUEST
      // ----------------------------------------------------------

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('GET STATUS : ${response.statusCode}');

      debugPrint('GET BODY   : ${response.body}');

      // ----------------------------------------------------------
      // TOKEN EXPIRED
      // ----------------------------------------------------------

      if (response.statusCode == 401) {
        await goToLogin();
        return;
      }

      // ----------------------------------------------------------
      // BERHASIL
      // ----------------------------------------------------------

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result is Map &&
            result['status'] == true &&
            result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data']);

          if (!mounted) return;

          setState(() {
            survey = data;
            isLoading = false;
          });

          // ------------------------------------------------------
          // FOTO
          // ------------------------------------------------------

          final photo = data['photo']?.toString();

          if (photo != null && photo.isNotEmpty && photo != 'placeholder.jpg') {
            await fetchImage(photo, token);
          }

          return;
        }
      }

      String message = 'Gagal mengambil data survey.';

      try {
        final result = jsonDecode(response.body);

        if (result is Map && result['message'] != null) {
          message = result['message'].toString();
        }
      } catch (_) {}

      throw Exception('$message\nKode: ${response.statusCode}');
    } catch (e) {
      debugPrint('GET DETAIL ERROR: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Gagal memuat detail survey.\n'
            'Periksa koneksi internet Anda.';
      });
    }
  }

  // ============================================================
  // AMBIL FOTO
  // ============================================================

  Future<void> fetchImage(String photoName, String token) async {
    if (!mounted) return;

    setState(() {
      isLoadingImage = true;
    });

    try {
      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;

      final url = Uri.parse('https://sijala.biz.id/api/image/$fileName');

      debugPrint('');
      debugPrint('========== GET IMAGE ==========');
      debugPrint('URL: $url');
      debugPrint('================================');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('IMAGE STATUS: ${response.statusCode}');

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          imageBytes = response.bodyBytes;
          isLoadingImage = false;
        });

        return;
      }
    } catch (e) {
      debugPrint('IMAGE ERROR: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoadingImage = false;
    });
  }

  // ============================================================
  // DELETE SURVEY
  // ============================================================

  Future<void> deleteSurvey() async {
    // Tampilkan dialog konfirmasi hapus

    final confirm = await showDialog<bool>(
      context: context,

      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Survey'),
        content: const Text('Apakah Anda yakin ingin menghapus survey ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.post(
        Uri.parse(
          'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}/delete',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Survey berhasil dihapus'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        // Kembali ke halaman daftar survey dengan membawa nilat true

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus survey (Kode: ${response.statusCode})',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menghapus survey.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
  // ============================================================
  // EDIT SURVEY
  // ============================================================

  Future<void> editSurvey() async {
    if (survey == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return SurveyFormPage(survey: survey);
        },
      ),
    );

    if (result == true && mounted) {
      await fetchDetail();
    }
  }

  // ============================================================
  // GOOGLE MAPS
  // ============================================================
  Future<void> openGoogleMaps(double lat, double lng) async {
    final googleMapsApp = Uri.parse('google.navigation:q=$lat,$lng');

    final googleMapsWeb = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(googleMapsApp)) {
        await launchUrl(googleMapsApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
      );
    }
  }

  // ============================================================
  // COPY KOORDINAT
  // ============================================================

  void copyCoordinates(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Koordinat berhasil disalin!')),
    );
  }

  // ============================================================
  // FULL IMAGE
  // ============================================================

  void showFullImageDialog(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text('Detail Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,

        actions: [
          if (survey != null) ...[
            // EDIT
            IconButton(
              onPressed: isDeleting ? null : editSurvey,
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Survey',
            ),

            // DELETE
            IconButton(
              onPressed: isDeleting ? null : deleteSurvey,
              icon: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete),
              tooltip: 'Hapus Survey',
            ),
          ],
        ],
      ),

      body: buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget buildBody() {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text(
              'Memuat detail survey...',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (errorMessage != null || survey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFEF4444),
              ),

              const SizedBox(height: 16),

              Text(
                errorMessage ?? 'Survey tidak ditemukan',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: fetchDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // DATA
    // ----------------------------------------------------------

    final title = survey!['title']?.toString() ?? '';

    final description = survey!['description']?.toString() ?? '';

    final category =
        survey!['category_name']?.toString() ??
        survey!['category']?['name']?.toString() ??
        'Tanpa Kategori';

    final date = survey!['created_at']?.toString() ?? '';
    final lat = double.tryParse(survey!['latitude']?.toString() ?? '');

    final lng = double.tryParse(survey!['longitude']?.toString() ?? '');

    final hasValidCoords =
        lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
    // ----------------------------------------------------------
    // TAMPILAN
    // ----------------------------------------------------------

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: fetchDetail,

      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // INFORMASI SURVEY
          // ======================================================
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Waktu: $date',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ======================================================
          // FOTO
          // ======================================================
          Card(
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Foto Survey',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

                if (isLoadingImage)
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                else if (imageBytes != null)
                  GestureDetector(
                    onTap: () {
                      showFullImageDialog(imageBytes!);
                    },
                    child: Image.memory(
                      imageBytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Text(
                        'Tidak ada foto survey',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ======================================================
          // DESKRIPSI
          // ======================================================
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    description.isEmpty ? 'Tidak ada deskripsi.' : description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ======================================================
          // LOKASI
          // ======================================================
          Card(
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi Survey',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasValidCoords
                            ? 'Latitude: $lat\nLongitude: $lng'
                            : 'Koordinat lokasi belum tersedia.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                if (hasValidCoords) ...[
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat!, lng!),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'id.biz.sijala.field_survey',
                          errorTileCallback: (tile, error, stackTrace) {
                            debugPrint('Gagal memuat peta: $error');
                          },
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 48,
                              height: 48,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => copyCoordinates(lat, lng),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Salin Koordinat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: const BorderSide(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => openGoogleMaps(lat, lng),
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Buka Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    color: const Color(0xFFF1F5F9),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lokasi survey belum ditentukan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: editSurvey,
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Pilih Lokasi di Peta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}