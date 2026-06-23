import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/theme/nexus_guard_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _picker      = ImagePicker();

  Uint8List? _imageBytes;
  String?    _imageUrl;
  bool _loading = true;
  bool _saving  = false;
  bool _saved   = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.get('/users/profile');
      if (!mounted) return;
      final user = res['data'] ?? res;
      setState(() {
        _nameCtrl.text    = user['name']    ?? '';
        _phoneCtrl.text   = user['phone']   ?? '';
        _addressCtrl.text = user['address'] ?? '';
        _imageUrl         = user['image'];
        _loading          = false;
      });
    } catch (e) {
      final user = await AuthService.getUser();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text    = user?['name']    ?? '';
        _phoneCtrl.text   = user?['phone']   ?? '';
        _addressCtrl.text = user?['address'] ?? '';
        _imageUrl         = user?['image'];
        _loading          = false;
      });
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NexusGuard.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PILIH SUMBER FOTO',
                style: NexusGuard.mono(color: NexusGuard.cyan, size: 13)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sourceBtn(Icons.photo_library_rounded, 'GALERI',
                    () => _pick(ImageSource.gallery)),
                  if (!kIsWeb) ...[
                    _sourceBtn(Icons.camera_front_rounded, 'KAMERA\nDEPAN',
                      () => _pick(ImageSource.camera, front: true)),
                    _sourceBtn(Icons.camera_rear_rounded, 'KAMERA\nBELAKANG',
                      () => _pick(ImageSource.camera, front: false)),
                  ] else
                    _sourceBtn(Icons.camera_alt_rounded, 'KAMERA\n(MOBILE)', () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kamera langsung hanya di aplikasi mobile'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source, {bool front = true}) async {
    Navigator.pop(context);
    try {
      final xfile = await _picker.pickImage(
        source: source,
        preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (xfile == null) return;

      Uint8List bytes = await xfile.readAsBytes();

      if (!kIsWeb) {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 400,
          minHeight: 400,
          quality: 75,
          format: CompressFormat.jpeg,
        );
        bytes = compressed;
      }

      if (bytes.length > 2500000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto terlalu besar. Pilih foto yang lebih kecil.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageUrl   = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e'), backgroundColor: NexusGuard.red),
      );
    }
  }

  String? _imageToBase64() {
    if (_imageBytes == null) return null;
    return 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}';
  }

  ImageProvider? _buildImageProvider() {
    if (_imageBytes != null) return MemoryImage(_imageBytes!);
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      if (_imageUrl!.startsWith('data:')) {
        final base64Str = _imageUrl!.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      }
      return NetworkImage(_imageUrl!);
    }
    return null;
  }

  Future<void> _save() async {
    final name    = _nameCtrl.text.trim();
    final phone   = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tidak boleh kosong'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final imageData = _imageToBase64() ?? _imageUrl;
      final body = <String, dynamic>{
        'name': name,
        'phone': phone,
        'address': address,
        if (imageData != null) 'image': imageData,
      };

      final res = await ApiService.put('/users/profile', body);
      if (!mounted) return;

      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Gagal menyimpan profil');
      }

      final user = await AuthService.getUser();
      if (user != null) {
        user['name']    = name;
        user['phone']   = phone;
        user['address'] = address;
        if (imageData != null) user['image'] = imageData;
        final token = await ApiService.getToken();
        if (token != null) await AuthService.saveToken(token, user);
      }

      setState(() { _saved = true; _saving = false; });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: NexusGuard.red),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusGuard.bg,
      appBar: AppBar(
        backgroundColor: NexusGuard.bg,
        elevation: 0,
        foregroundColor: NexusGuard.text,
        title: Text('PROFILE',
          style: NexusGuard.orbitron(size: 18, color: NexusGuard.cyan, spacing: 3)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '...' : _saved ? '✓ TERSIMPAN' : 'SIMPAN',
              style: NexusGuard.mono(
                color: _saved ? NexusGuard.green : NexusGuard.cyan, size: 13)),
          ),
        ],
      ),
      body: NexusBackground(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: NexusGuard.cyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showSourcePicker,
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: NexusGuard.panel,
                            backgroundImage: _buildImageProvider(),
                            child: _buildImageProvider() == null
                              ? const Icon(Icons.person_rounded, size: 56, color: NexusGuard.cyan)
                              : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _showSourcePicker,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: NexusGuard.cyan, shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 18, color: NexusGuard.bg),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showSourcePicker,
                    child: Text('GANTI FOTO PROFIL',
                      style: NexusGuard.mono(color: NexusGuard.cyan, size: 12)),
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('* Kamera hanya tersedia di aplikasi mobile',
                        style: NexusGuard.mono(color: NexusGuard.muted, size: 11)),
                    ),
                  const SizedBox(height: 20),
                  _field('NAMA LENGKAP', _nameCtrl, Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _field('NO. TELEPON', _phoneCtrl, Icons.phone_outlined, keyboard: TextInputType.phone),
                  const SizedBox(height: 16),
                  _field('ALAMAT', _addressCtrl, Icons.home_outlined, maxLines: 3),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NexusGuard.cyan,
                        foregroundColor: NexusGuard.bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _saving ? 'MENYIMPAN...' : _saved ? '✓ TERSIMPAN' : 'SIMPAN PROFILE',
                        style: NexusGuard.mono(color: NexusGuard.bg, size: 14, weight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: NexusGuard.cyan.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(14),
              color: NexusGuard.bg,
            ),
            child: Icon(icon, color: NexusGuard.cyan, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
            style: NexusGuard.mono(color: NexusGuard.muted, size: 11)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NexusGuard.mono(color: NexusGuard.cyan, size: 11)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: NexusGuard.rajdhani(size: 16, color: NexusGuard.text),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: NexusGuard.cyan, size: 20),
            filled: true,
            fillColor: NexusGuard.panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: NexusGuard.cyan.withValues(alpha: 0.6)),
            ),
            hintText: 'Masukkan ${label.toLowerCase()}',
            hintStyle: NexusGuard.rajdhani(size: 15, color: NexusGuard.muted),
          ),
        ),
      ],
    );
  }
}

