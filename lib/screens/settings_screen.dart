import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _avatarPath;
  String? _avatarUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('user');
    if (rawUser == null) return;

    final user = Map<String, dynamic>.from(jsonDecode(rawUser));
    if (!mounted) return;

    setState(() {
      nameController.text = user['name']?.toString() ?? 'User';
      emailController.text = user['email']?.toString() ?? 'user@gmail.com';
      _avatarUrl = user['avatar']?.toString();
      if ((_avatarUrl == null || _avatarUrl!.isEmpty) && user['profile_photo_url'] != null) {
        _avatarUrl = user['profile_photo_url'].toString();
      }
    });
  }

  Future<void> _pickAvatar() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Pilih dari galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Ambil foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (file == null || !mounted) return;

      setState(() {
        _avatarPath = file.path;
        _avatarUrl = null;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Tidak bisa membuka kamera atau galeri: $e', Colors.red);
      }
    }
  }

  Future<String> _saveAvatarLocally(String sourcePath) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final avatarDirectory = Directory('${appDirectory.path}/profile_images');
    await avatarDirectory.create(recursive: true);

    final sourceFile = File(sourcePath);
    final extension = sourcePath.contains('.')
        ? sourcePath.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension = const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
    final destinationPath =
        '${avatarDirectory.path}/avatar_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    return (await sourceFile.copy(destinationPath)).path;
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Nama tidak boleh kosong.', Colors.red);
      return;
    }

    if (email.isEmpty) {
      _showSnackBar('Email tidak boleh kosong.', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString('user');
      final user = rawUser == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(rawUser));

        final avatarValue = _avatarPath != null
          ? await _saveAvatarLocally(_avatarPath!)
          : _avatarUrl ?? user['avatar'] ?? user['profile_photo_url'];

      await LocalAuthService.updateCurrentUser({
        'name': name,
        'email': email.toLowerCase(),
        'avatar': avatarValue,
        'profile_photo_url': avatarValue,
      });

      await prefs.setString('user_name', name);
      _showSnackBar('Profil berhasil diperbarui.', const Color(0xFF00A32A));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Gagal menyimpan profil: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ImageProvider? _avatarImageProvider() {
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      return FileImage(File(_avatarPath!));
    }

    final avatar = _avatarUrl ?? '';
    if (avatar.startsWith('http')) {
      return NetworkImage(avatar);
    }
    if (avatar.startsWith('/')) {
      return FileImage(File(avatar));
    }

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = nameController.text.trim().isEmpty
        ? 'U'
        : nameController.text.trim().split(RegExp(r'\s+')).take(2).map((e) => e[0]).join().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Edit Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: const Color(0xFFE6F5EA),
                          backgroundImage: _avatarImageProvider(),
                          child: _avatarImageProvider() == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Color(0xFF00A32A),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF00A32A),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _pickAvatar,
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Foto profil',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A32A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
