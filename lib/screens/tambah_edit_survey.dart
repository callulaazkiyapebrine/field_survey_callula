import 'dart:convert';
import 'dart:typed_data';

import 'package:field_survey/screens/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurveyFormPage extends StatefulWidget {
  final Map<String, dynamic>? survey;

  const SurveyFormPage({super.key, this.survey});

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  // ============================================================
  // 1. STATE DAN CONTROLLER
  // ============================================================

  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  static const Color primaryColor = Color(0xFF1E40AF);

  // Pusat awal peta di sekitar Tasikmalaya.
  // Ini bukan koordinat survey yang dipilih.
  static const LatLng defaultMapCenter = LatLng(-7.3274, 108.2207);

  // Lokasi yang dipilih pada peta.
  LatLng? selectedLocation;

  // Kategori
  int? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;

  // Foto
  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Uint8List? existingImageBytes;

  // Status
  bool isSubmitting = false;

  bool get isEdit => widget.survey != null;

  // ============================================================
  // 2. INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();

    if (isEdit) {
      final data = widget.survey!;

      titleController.text = data['title']?.toString() ?? '';

      descriptionController.text = data['description']?.toString() ?? '';

      latitudeController.text = data['latitude']?.toString() ?? '';

      longitudeController.text = data['longitude']?.toString() ?? '';

      selectedCategoryId = int.tryParse(data['category_id']?.toString() ?? '');

      // Tampilkan pin lokasi lama jika koordinat valid.
      final lat = double.tryParse(latitudeController.text.trim());

      final lng = double.tryParse(longitudeController.text.trim());

      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        selectedLocation = LatLng(lat, lng);
      }

      // Ambil foto lama.
      final photoName = data['photo']?.toString();

      if (photoName != null &&
          photoName.isNotEmpty &&
          photoName != 'placeholder.jpg') {
        fetchExistingImage(photoName);
      }
    }

    fetchCategories();
  }

  // ============================================================
  // 3. DISPOSE
  // ============================================================

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();

    super.dispose();
  }

  // ============================================================
  // 4. AMBIL KATEGORI
  // ============================================================

  Future<void> fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/v1/categories'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded['data'] is List) {
          final List rawList = decoded['data'];

          if (!mounted) return;

          setState(() {
            categories = rawList
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

            isLoadingCategories = false;
          });

          return;
        }
      }
    } catch (e) {
      debugPrint('Gagal mengambil kategori: $e');
    }

    if (mounted) {
      setState(() {
        isLoadingCategories = false;
      });
    }
  }

  // ============================================================
  // 5. AMBIL FOTO LAMA
  // ============================================================

  Future<void> fetchExistingImage(String photoName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;

      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/image/$fileName'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty &&
          mounted) {
        setState(() {
          existingImageBytes = response.bodyBytes;
        });
      }
    } catch (e) {
      debugPrint('Gagal mengambil foto lama: $e');
    }
  }

  // ============================================================
  // 6. PILIH FOTO
  // ============================================================

  Future<void> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          selectedImage = pickedFile;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      showErrorSnackBar('Gagal memilih foto.');
    }
  }

  // ============================================================
  // 7. HAPUS / GANTI FOTO
  // ============================================================

  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      existingImageBytes = null;
    });
  }

  // ============================================================
  // 8. DIALOG SUMBER FOTO
  // ============================================================

  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: primaryColor),
                  title: const Text('Galeri'),
                  onTap: () {
                    Navigator.pop(ctx);
                    pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: primaryColor),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 9. PILIH LOKASI DARI PETA
  // ============================================================

  void selectMapLocation(LatLng point) {
    setState(() {
      selectedLocation = point;

      latitudeController.text = point.latitude.toStringAsFixed(7);

      longitudeController.text = point.longitude.toStringAsFixed(7);
    });
  }

  // ============================================================
  // 10. SIMPAN / UPDATE SURVEY
  // ============================================================

  Future<void> saveSurvey() async {
    if (!formKey.currentState!.validate()) {
      showErrorSnackBar('Lengkapi data yang wajib diisi.');
      return;
    }

    if (selectedCategoryId == null || selectedCategoryId == 0) {
      showErrorSnackBar('Kategori survey wajib dipilih.');
      return;
    }

    // Pastikan koordinat yang dikirim valid.
    final lat = double.tryParse(latitudeController.text.trim());

    final lng = double.tryParse(longitudeController.text.trim());

    if (lat != null || lng != null) {
      if (lat == null ||
          lng == null ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        showErrorSnackBar('Koordinat latitude atau longitude tidak valid.');
        return;
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );

        return;
      }

      final uri = Uri.parse('https://sijala.biz.id/api/v1/surveys/save');

      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      // Data survey.
      request.fields['title'] = titleController.text.trim();

      request.fields['category_id'] = selectedCategoryId.toString();

      request.fields['description'] = descriptionController.text.trim();

      // Koordinat dari peta atau input koordinat.
      if (latitudeController.text.trim().isNotEmpty) {
        request.fields['latitude'] = latitudeController.text.trim();
      }

      if (longitudeController.text.trim().isNotEmpty) {
        request.fields['longitude'] = longitudeController.text.trim();
      }

      // Mode edit.
      if (isEdit) {
        request.fields['id'] = widget.survey!['id'].toString();

        request.fields['_method'] = 'PUT';
      }

      // Foto baru.
      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('SAVE STATUS: ${response.statusCode}');
      debugPrint('SAVE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Survey berhasil diperbarui!'
                  : 'Survey berhasil disimpan!',
            ),
            backgroundColor: const Color(0xFF108981),
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      // Tampilkan pesan validasi dari API.
      String message =
          'Gagal menyimpan survey '
          '(Kode: ${response.statusCode})';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }

        if (decoded is Map && decoded['errors'] is Map) {
          final errors = decoded['errors'] as Map;
          final details = errors.values
              .expand((value) => value is List ? value : [value])
              .join('\n');

          if (details.isNotEmpty) {
            message = '$message\n$details';
          }
        }
      } catch (_) {}

      throw Exception(message);
    } catch (e) {
      if (!mounted) return;

      showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // 11. SNACKBAR ERROR
  // ============================================================

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  // ============================================================
  // 12. BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mapCenter = selectedLocation ?? defaultMapCenter;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: Text(isEdit ? 'Edit Survey' : 'Tambah Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // DATA UTAMA
              // ==================================================
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
                        'Data Utama Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Judul Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan judul survey',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul wajib diisi';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Kategori Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (isLoadingCategories)
                        const LinearProgressIndicator(color: primaryColor)
                      else
                        DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(
                            hintText: 'Pilih Kategori',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categories.map((cat) {
                            final id =
                                int.tryParse(cat['id']?.toString() ?? '') ?? 0;

                            final name = cat['name']?.toString() ?? '';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategoryId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value == 0) {
                              return 'Kategori wajib dipilih';
                            }
                            return null;
                          },
                        ),

                      const SizedBox(height: 16),

                      const Text(
                        'Deskripsi Survey',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Keterangan atau catatan survey...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // FOTO SURVEY
              // ==================================================
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
                        'Foto Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (selectedImageBytes != null ||
                          existingImageBytes != null)
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                selectedImageBytes ?? existingImageBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: showImageSourceDialog,
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Ganti Foto'),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                OutlinedButton.icon(
                                  onPressed: removeSelectedImage,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                  ),
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: showImageSourceDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 36,
                                  color: primaryColor,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Ketuk untuk memilih foto',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // LOKASI SURVEY
              // ==================================================
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
                        'Lokasi Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Ketuk titik pada peta untuk mengisi '
                        'latitude dan longitude secara otomatis.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // PETA INTERAKTIF
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: mapCenter,
                              initialZoom: selectedLocation != null ? 16 : 13,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.pinchZoom |
                                    InteractiveFlag.doubleTapZoom,
                              ),
                              onTap: (tapPosition, point) {
                                selectMapLocation(point);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/'
                                    '{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'id.biz.sijala.field_survey',
                              ),

                              // Pin hanya muncul setelah ada lokasi
                              // yang dipilih atau koordinat lama valid.
                              if (selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: selectedLocation!,
                                      width: 48,
                                      height: 48,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 44,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // STATUS LOKASI
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedLocation != null
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selectedLocation != null
                                  ? Icons.check_circle
                                  : Icons.touch_app,
                              color: selectedLocation != null
                                  ? primaryColor
                                  : const Color(0xFF64748B),
                              size: 20,
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                selectedLocation != null
                                    ? 'Lokasi telah dipilih. '
                                          'Kamu bisa mengetuk titik lain '
                                          'untuk mengubahnya.'
                                    : 'Belum ada lokasi dipilih. '
                                          'Ketuk titik pada peta.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // LATITUDE
                      TextFormField(
                        controller: latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '-7.3274000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.my_location),
                        ),
                        onChanged: (value) {
                          final lat = double.tryParse(value);
                          final lng = double.tryParse(longitudeController.text);

                          if (lat != null &&
                              lng != null &&
                              lat >= -90 &&
                              lat <= 90 &&
                              lng >= -180 &&
                              lng <= 180) {
                            setState(() {
                              selectedLocation = LatLng(lat, lng);
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // LONGITUDE
                      TextFormField(
                        controller: longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '108.2207000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.explore),
                        ),
                        onChanged: (value) {
                          final lat = double.tryParse(latitudeController.text);

                          final lng = double.tryParse(value);

                          if (lat != null &&
                              lng != null &&
                              lat >= -90 &&
                              lat <= 90 &&
                              lng >= -180 &&
                              lng <= 180) {
                            setState(() {
                              selectedLocation = LatLng(lat, lng);
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 8),

                      // HAPUS PILIHAN LOKASI
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: selectedLocation == null
                              ? null
                              : () {
                                  setState(() {
                                    selectedLocation = null;
                                    latitudeController.clear();
                                    longitudeController.clear();
                                  });
                                },
                          icon: const Icon(Icons.location_off),
                          label: const Text('Hapus Lokasi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // TOMBOL SIMPAN
              // ==================================================
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : saveSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Simpan Survey',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}