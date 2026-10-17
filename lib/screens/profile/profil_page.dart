import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes/app_routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // =========================================================
  // WARNA TEMA DASHBOARD
  // =========================================================

  static const Color primaryColor = Color(0xFF1E4BAF);
  static const Color backgroundColor = Color(0xFFF5F7FB);
  static const Color textColor = Color(0xFF1E293B);

  // =========================================================
  // API
  // =========================================================

  static const String profileUrl =
      'https://sijala.biz.id/api/v1/profile';

  static const String updateProfileUrl =
      'https://sijala.biz.id/api/v1/profile/update';

  // =========================================================
  // DATA
  // =========================================================

  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingPhoto = false;

  String name = '-';
  String email = '-';
  String phone = '-';
  String gender = '-';

  String? photoName;

  Uint8List? profileImage;
  Uint8List? selectedPhoto;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    getProfile();
  }

  // =========================================================
  // TOKEN
  // =========================================================

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    debugPrint(
      'TOKEN ADA: ${token != null && token.isNotEmpty}',
    );

    return token;
  }

  // =========================================================
  // GET PROFILE
  // =========================================================

  Future<void> getProfile() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Token tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 20),
      );

      debugPrint('==============================');
      debugPrint('GET PROFILE');
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: ${response.body}');
      debugPrint('==============================');

      if (response.body.isEmpty) {
        throw Exception(
          'Response server kosong.',
        );
      }

      final data = jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Gagal mengambil profil',
        );
      }

      dynamic profile;

      if (data is Map && data['data'] is Map) {
        profile = data['data'];
      } else {
        profile = data;
      }

      if (profile is! Map) {
        throw Exception(
          'Format data profil tidak sesuai.',
        );
      }

      final profileName =
          profile['name']?.toString() ?? '-';

      final profileEmail =
          profile['email']?.toString() ?? '-';

      final profilePhone =
          profile['phone']?.toString() ?? '-';

      final profileGender =
          profile['gender']?.toString().trim() ?? '';

      final profilePhoto =
          profile['photo']?.toString().trim() ?? '';

      String genderResult = '-';

      if (profileGender.toUpperCase() == 'L') {
        genderResult = 'Laki Laki';
      } else if (profileGender.toUpperCase() == 'P') {
        genderResult = 'Perempuan';
      } else if (profileGender.isNotEmpty) {
        genderResult = profileGender;
      }

      if (!mounted) return;

      setState(() {
        name = profileName;
        email = profileEmail;
        phone = profilePhone;
        gender = genderResult;

        photoName =
            profilePhoto.isEmpty ? null : profilePhoto;

        isLoading = false;
      });

      if (profilePhoto.isNotEmpty) {
        await loadProfileImage(profilePhoto);
      } else {
        if (!mounted) return;

        setState(() {
          profileImage = null;
        });
      }
    } catch (e) {
      debugPrint(
        'GET PROFILE ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil profil:\n$e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // AMBIL GAMBAR DARI API
  // =========================================================

  Future<void> loadProfileImage(
    String fileName,
  ) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      final url =
          'https://sijala.biz.id/api/image/$fileName';

      debugPrint(
        'URL FOTO: $url',
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
      ).timeout(
        const Duration(seconds: 20),
      );

      debugPrint(
        'IMAGE STATUS: ${response.statusCode}',
      );

      debugPrint(
        'IMAGE SIZE: ${response.bodyBytes.length}',
      );

      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          profileImage = response.bodyBytes;
        });
      } else {
        debugPrint(
          'Gagal mengambil gambar.',
        );
      }
    } catch (e) {
      debugPrint(
        'IMAGE ERROR: $e',
      );
    }
  }

  // =========================================================
  // PILIH FOTO
  // =========================================================

  Future<void> pickPhoto() async {
    if (isUploadingPhoto) {
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();

      final XFile? pickedFile =
          await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        return;
      }

      final Uint8List bytes =
          await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception(
          'File gambar tidak bisa dibaca.',
        );
      }

      if (!mounted) return;

      setState(() {
        selectedPhoto = bytes;
      });

      debugPrint(
        'FOTO DIPILIH: ${pickedFile.name}',
      );

      debugPrint(
        'UKURAN: ${bytes.length}',
      );

      await uploadPhoto(
        bytes,
        pickedFile.name,
      );
    } catch (e) {
      debugPrint(
        'PICK PHOTO ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        selectedPhoto = null;
        isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memilih foto:\n$e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // UPLOAD FOTO
  // =========================================================

  Future<void> uploadPhoto(
    Uint8List bytes,
    String fileName,
  ) async {
    if (isUploadingPhoto) {
      return;
    }

    if (!mounted) return;

    setState(() {
      isUploadingPhoto = true;
    });

    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Token tidak ditemukan.',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      request.headers['Accept'] =
          'application/json';

      request.headers['Authorization'] =
          'Bearer $token';

      if (name != '-') {
        request.fields['name'] = name;
      }

      if (phone != '-') {
        request.fields['phone'] = phone;
      }

      if (gender == 'Laki Laki') {
        request.fields['gender'] = 'L';
      } else if (gender == 'Perempuan') {
        request.fields['gender'] = 'P';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: fileName,
        ),
      );

      debugPrint(
        '==============================',
      );

      debugPrint(
        'UPLOAD FOTO',
      );

      debugPrint(
        'URL: $updateProfileUrl',
      );

      debugPrint(
        'FILE: $fileName',
      );

      debugPrint(
        'SIZE: ${bytes.length}',
      );

      debugPrint(
        '==============================',
      );

      final streamedResponse =
          await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        'UPLOAD STATUS: ${response.statusCode}',
      );

      debugPrint(
        'UPLOAD BODY: ${response.body}',
      );

      if (response.body.isEmpty) {
        throw Exception(
          'Response upload kosong.',
        );
      }

      final data = jsonDecode(
        response.body,
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Gagal mengupload foto',
        );
      }

      if (!mounted) return;

      setState(() {
        isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Foto berhasil diperbarui',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await getProfile();

      if (!mounted) return;

      setState(() {
        selectedPhoto = null;
      });
    } catch (e) {
      debugPrint(
        'UPLOAD PHOTO ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        isUploadingPhoto = false;
        selectedPhoto = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal upload foto:\n$e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<bool> updateProfile({
    required String newName,
    required String newPhone,
    required String newGender,
  }) async {
    if (isSaving) {
      return false;
    }

    if (!mounted) return false;

    setState(() {
      isSaving = true;
    });

    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Token tidak ditemukan.',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      request.headers['Accept'] =
          'application/json';

      request.headers['Authorization'] =
          'Bearer $token';

      request.fields['name'] = newName;
      request.fields['phone'] = newPhone;
      request.fields['gender'] = newGender;

      final streamedResponse =
          await request.send().timeout(
        const Duration(seconds: 20),
      );

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        'UPDATE STATUS: ${response.statusCode}',
      );

      debugPrint(
        'UPDATE BODY: ${response.body}',
      );

      if (response.body.isEmpty) {
        throw Exception(
          'Response server kosong.',
        );
      }

      final data =
          jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Gagal menyimpan profil',
        );
      }

      if (!mounted) {
        return true;
      }

      setState(() {
        name = newName;
        phone = newPhone;

        if (newGender == 'L') {
          gender = 'Laki Laki';
        } else if (newGender == 'P') {
          gender = 'Perempuan';
        }
      });

      return true;
    } catch (e) {
      debugPrint(
        'UPDATE PROFILE ERROR: $e',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan:\n$e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  void showEditProfile() {
    final nameController =
        TextEditingController(
      text: name == '-' ? '' : name,
    );

    final phoneController =
        TextEditingController(
      text: phone == '-' ? '' : phone,
    );

    String selectedGender = '';

    final oldGender =
        gender.toLowerCase().trim();

    if (oldGender == 'laki laki' ||
        oldGender == 'laki-laki' ||
        oldGender == 'l') {
      selectedGender = 'L';
    } else if (oldGender == 'perempuan' ||
        oldGender == 'p') {
      selectedGender = 'P';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 25,
                bottom:
                    MediaQuery.of(context)
                            .viewInsets
                            .bottom +
                        25,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: 45,
                      height: 5,
                      decoration:
                          BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    const Text(
                      'Edit Profil',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    TextField(
                      controller:
                          nameController,
                      decoration:
                          _inputDecoration(
                        'Nama',
                        Icons
                            .person_outline,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    TextField(
                      controller:
                          phoneController,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          _inputDecoration(
                        'Phone',
                        Icons
                            .phone_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    DropdownButtonFormField<
                        String>(
                      value:
                          selectedGender
                                  .isEmpty
                              ? null
                              : selectedGender,
                      decoration:
                          _inputDecoration(
                        'Jenis Kelamin',
                        Icons.wc_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'L',
                          child: Text(
                            'Laki Laki',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'P',
                          child: Text(
                            'Perempuan',
                          ),
                        ),
                      ],
                      onChanged:
                          (value) {
                        if (value == null) {
                          return;
                        }

                        setModalState(
                          () {
                            selectedGender =
                                value;
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            isSaving
                                ? null
                                : () async {
                                    final newName =
                                        nameController
                                            .text
                                            .trim();

                                    final newPhone =
                                        phoneController
                                            .text
                                            .trim();

                                    if (newName
                                        .isEmpty) {
                                      ScaffoldMessenger
                                              .of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text(
                                            'Nama tidak boleh kosong',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    if (selectedGender
                                        .isEmpty) {
                                      ScaffoldMessenger
                                              .of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text(
                                            'Pilih jenis kelamin',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final berhasil =
                                        await updateProfile(
                                      newName:
                                          newName,
                                      newPhone:
                                          newPhone,
                                      newGender:
                                          selectedGender,
                                    );

                                    if (!context
                                        .mounted) {
                                      return;
                                    }

                                    if (berhasil) {
                                      Navigator.pop(
                                        sheetContext,
                                      );

                                      ScaffoldMessenger
                                              .of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text(
                                            'Profil berhasil diperbarui',
                                          ),
                                          backgroundColor:
                                              Colors.green,
                                        ),
                                      );
                                    }
                                  },
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              primaryColor,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Text(
                                'Simpan',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    final yakin =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          content: const Text(
            'Yakin ingin keluar dari akun?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Batal',
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryColor,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (yakin != true) {
      return;
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove('token');
    await prefs.remove('user');

    if (!mounted) return;

    context.go(
      AppRoutes.Login,
    );
  }

  // =========================================================
  // AVATAR
  // =========================================================

  Widget profilePhoto() {
    if (selectedPhoto != null) {
      return CircleAvatar(
        radius: 55,
        backgroundImage:
            MemoryImage(
          selectedPhoto!,
        ),
      );
    }

    if (profileImage != null) {
      return CircleAvatar(
        radius: 55,
        backgroundImage:
            MemoryImage(
          profileImage!,
        ),
      );
    }

    return const CircleAvatar(
      radius: 55,
      backgroundColor:
          Color(0xFFE8F0FE),
      child: Icon(
        Icons.person,
        size: 65,
        color: primaryColor,
      ),
    );
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: primaryColor,
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          backgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            primaryColor,
        foregroundColor:
            Colors.white,
        elevation: 0,
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh:
                  getProfile,
              child:
                  SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  children: [

                    const SizedBox(
                      height: 15,
                    ),

                    // =======================================
                    // FOTO
                    // =======================================

                    Stack(
                      children: [
                        profilePhoto(),

                        Positioned(
                          right: 0,
                          bottom: 0,
                          child:
                              GestureDetector(
                            onTap:
                                isUploadingPhoto
                                    ? null
                                    : pickPhoto,
                            child:
                                Container(
                              width: 36,
                              height: 36,
                              decoration:
                                  const BoxDecoration(
                                color:
                                    primaryColor,
                                shape:
                                    BoxShape.circle,
                              ),
                              child:
                                  isUploadingPhoto
                                      ? const Padding(
                                          padding:
                                              EdgeInsets.all(
                                            9,
                                          ),
                                          child:
                                              CircularProgressIndicator(
                                            color:
                                                Colors.white,
                                            strokeWidth:
                                                2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons
                                              .camera_alt_rounded,
                                          color:
                                              Colors.white,
                                          size:
                                              19,
                                        ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // =======================================
                    // NAMA
                    // =======================================

                    Text(
                      name,
                      style:
                          const TextStyle(
                        fontSize: 23,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            textColor,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      email,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    // =======================================
                    // DATA PROFIL
                    // =======================================

                    _profileCard(
                      Icons
                          .person_outline_rounded,
                      'Nama',
                      name,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _profileCard(
                      Icons
                          .email_outlined,
                      'Email',
                      email,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _profileCard(
                      Icons
                          .phone_outlined,
                      'Phone',
                      phone,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _profileCard(
                      Icons
                          .wc_outlined,
                      'Jenis Kelamin',
                      gender,
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // =======================================
                    // EDIT PROFILE
                    // =======================================

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          ElevatedButton
                              .icon(
                        onPressed:
                            showEditProfile,
                        icon:
                            const Icon(
                          Icons
                              .edit_rounded,
                        ),
                        label:
                            const Text(
                          'Edit Profil',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              primaryColor,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              13,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // =======================================
                    // LOGOUT
                    // =======================================

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          OutlinedButton
                              .icon(
                        onPressed:
                            logout,
                        icon:
                            const Icon(
                          Icons
                              .logout_rounded,
                          color:
                              primaryColor,
                        ),
                        label:
                            const Text(
                          'Logout',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                primaryColor,
                          ),
                        ),
                        style:
                            OutlinedButton
                                .styleFrom(
                          side:
                              const BorderSide(
                            color:
                                primaryColor,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              13,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================
  // PROFILE CARD
  // =========================================================

  Widget _profileCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.04,
            ),
            blurRadius:
                8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [

          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              color:
                  primaryColor.withOpacity(
                0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color:
                  primaryColor,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Colors.grey,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        textColor,
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
