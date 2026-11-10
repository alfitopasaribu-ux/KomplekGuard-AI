import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _picker = ImagePicker();
  Map<String, dynamic>? _user;
  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _loading = true;
  bool _saving = false;
  bool _picking = false;
  bool _saved = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _applyProfile(Map<String, dynamic> profile) {
    _user = profile;
    _nameCtrl.text = profile['name']?.toString() ?? '';
    _phoneCtrl.text = profile['phone']?.toString() ?? '';
    _addressCtrl.text = profile['address']?.toString() ?? '';
    _imageUrl = profile['image']?.toString();
    _imageBytes = null;
  }

  Future<void> _loadProfile() async {
    if (_saving || _picking) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    Map<String, dynamic>? cached;
    try {
      cached = await AuthService.getUser();
    } catch (_) {
      // A broken local cache must not prevent fetching the real profile.
    }
    try {
      final response = await ApiService.get('/users/profile')
          .timeout(const Duration(seconds: 20));
      if (response['success'] != true || response['data'] is! Map) {
        throw const FormatException('Profil belum tersedia.');
      }
      final profile = <String, dynamic>{
        ...?cached,
        ...Map<String, dynamic>.from(response['data'] as Map),
      };
      if (!mounted) return;
      setState(() {
        _applyProfile(profile);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_user == null && cached != null) _applyProfile(cached);
        _loading = false;
        _loadError = _user == null
            ? 'Profil belum dapat dimuat. Periksa koneksi lalu coba lagi.'
            : 'Pembaruan profil gagal. Informasi yang ditampilkan berasal dari data tersimpan.';
      });
    }
  }

  void _changed() {
    setState(() {
      _saved = false;
      _saveError = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _loading || _picking || _user == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
    });
    try {
      final image = _imageBytes == null ? _imageUrl : 'data:;base64,';
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (image != null) 'image': image,
      };
      final response = await ApiService.put('/users/profile', body)
          .timeout(const Duration(seconds: 25));
      if (response['success'] != true || response['data'] is! Map) {
        if (!mounted) return;
        setState(() => _saveError = response['message']?.toString() ??
            'Profil belum berhasil disimpan. Silakan coba lagi.');
        return;
      }
      final profile = <String, dynamic>{
        ...?_user,
        ...Map<String, dynamic>.from(response['data'] as Map),
      };
      String? cacheError;
      try {
        final token = await ApiService.getToken();
        if (token != null) await AuthService.saveToken(token, profile);
      } catch (_) {
        cacheError =
            'Profil tersimpan di server, tetapi data sesi lokal belum diperbarui.';
      }
      if (!mounted) return;
      setState(() {
        _applyProfile(profile);
        _loadError = null;
        _saveError = cacheError;
        _saved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError =
          'Belum dapat memastikan profil tersimpan. Periksa koneksi dan coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSourcePicker() {
    if (_saving || _loading || _picking || _user == null) return;
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NexusGuard.panel,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Ganti foto profil',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey('profile-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => _pick(ImageSource.gallery),
            ),
            ListTile(
              key: const ValueKey('profile-photo-front'),
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Kamera depan'),
              onTap: () => _pick(ImageSource.camera, front: true),
            ),
            ListTile(
              key: const ValueKey('profile-photo-rear'),
              leading: const Icon(Icons.camera_rear_outlined),
              title: const Text('Kamera belakang'),
              onTap: () => _pick(ImageSource.camera, front: false),
            ),
            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                    'Pilihan kamera mengikuti dukungan browser dan perangkat.'),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source, {bool front = true}) async {
    Navigator.pop(context);
    if (_picking || _saving) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (file == null || !mounted) return;
      Uint8List bytes = await file.readAsBytes();
      if (!kIsWeb) {
        bytes = await FlutterImageCompress.compressWithList(bytes,
            minWidth: 400,
            minHeight: 400,
            quality: 75,
            format: CompressFormat.jpeg);
      }
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 2500000) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Pilih foto yang valid dengan ukuran maksimal 2,5 MB.')));
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageUrl = null;
        _saved = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Foto belum dapat dipilih. Periksa izin kamera atau galeri.')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  ImageProvider? _imageProvider() {
    if (_imageBytes != null) return MemoryImage(_imageBytes!);
    final image = _imageUrl?.trim() ?? '';
    if (image.isEmpty) return null;
    try {
      if (image.startsWith('data:image/')) {
        final bytes = Uri.parse(image).data?.contentAsBytes();
        return bytes == null ? null : MemoryImage(bytes);
      }
      final uri = Uri.tryParse(image);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        return NetworkImage(image);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String get _role {
    switch (_user?['role']) {
      case 'WARGA':
        return 'Warga';
      case 'SATPAM':
        return 'Petugas keamanan';
      case 'KETUA_RT':
        return 'Ketua RT';
      case 'ADMIN':
        return 'Admin';
      default:
        return 'Pengguna';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('profile-screen'),
      backgroundColor: NexusGuard.slate,
      appBar: AppBar(
        backgroundColor: NexusGuard.slate,
        foregroundColor: Colors.white,
        title: const Text('Profil Saya'),
        actions: [
          IconButton(
            key: const ValueKey('profile-save-top'),
            tooltip: 'Simpan perubahan profil',
            onPressed:
                _loading || _saving || _picking || _user == null ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: NexusGuard.ivory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _loading
            ? const Center(
                key: ValueKey('profile-loading'),
                child: CircularProgressIndicator())
            : SingleChildScrollView(
                key: const ValueKey('profile-scroll'),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loadError != null) ...[
                            _notice(_loadError!,
                                keyName: 'profile-load-error', retry: true),
                            const SizedBox(height: 16),
                          ],
                          if (_user != null)
                            LayoutBuilder(builder: (context, constraints) {
                              final summary = _identityCard();
                              final form = _profileForm();
                              if (constraints.maxWidth >= 800) {
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 2, child: summary),
                                      const SizedBox(width: 22),
                                      Expanded(flex: 3, child: form),
                                    ]);
                              }
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    summary,
                                    const SizedBox(height: 18),
                                    form,
                                  ]);
                            }),
                        ]),
                  ),
                ),
              ),
      ),
    );
  }

  BoxDecoration get _card => BoxDecoration(
        color: NexusGuard.panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: NexusGuard.border),
      );

  Widget _notice(String message,
      {required String keyName, bool retry = false}) {
    return Semantics(
        liveRegion: true,
        child: Container(
          key: ValueKey(keyName),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: NexusGuard.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (retry)
              TextButton.icon(
                key: const ValueKey('profile-retry'),
                onPressed: _saving || _picking ? null : _loadProfile,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
          ]),
        ));
  }

  Widget _identityCard() {
    final provider = _imageProvider();
    final name = _user?['name']?.toString().trim() ?? '';
    final email = _user?['email']?.toString().trim() ?? '';
    final neighborhood = _user?['neighborhood'];
    final neighborhoodName =
        neighborhood is Map ? neighborhood['name']?.toString() : null;
    return Container(
      key: const ValueKey('profile-identity'),
      padding: const EdgeInsets.all(22),
      decoration: _card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              button: true,
              label: 'Ganti foto profil',
              child: InkWell(
                key: const ValueKey('profile-photo'),
                onTap: _saving || _picking ? null : _showSourcePicker,
                borderRadius: BorderRadius.circular(48),
                child: Stack(children: [
                  ClipOval(
                      child: Container(
                    width: 82,
                    height: 82,
                    color: const Color(0xFFDCEDE5),
                    child: _picking
                        ? const Center(child: CircularProgressIndicator())
                        : provider == null
                            ? const Icon(Icons.person_outline_rounded,
                                size: 45, color: NexusGuard.emerald)
                            : Image(
                                image: provider,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_outline_rounded,
                                    size: 45,
                                    color: NexusGuard.emerald)),
                  )),
                  const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: NexusGuard.emerald,
                        child: Icon(Icons.camera_alt_outlined,
                            size: 16, color: Colors.white),
                      )),
                ]),
              )),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  name.isEmpty ? 'Nama belum diisi' : name,
                  key: const ValueKey('profile-display-name'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: NexusGuard.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18)),
                      child: Text(_role,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: NexusGuard.emerald)),
                    )),
              ])),
        ]),
        const SizedBox(height: 18),
        TextButton.icon(
          key: const ValueKey('profile-change-photo'),
          onPressed: _saving || _picking ? null : _showSourcePicker,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(_picking ? 'Memproses foto...' : 'Ganti foto profil'),
        ),
        const Divider(height: 28),
        _info(Icons.phone_outlined, _user?['phone']?.toString(),
            'Nomor telepon belum diisi'),
        const SizedBox(height: 16),
        _info(Icons.home_outlined, _user?['address']?.toString(),
            'Alamat belum diisi'),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 16),
          _info(Icons.mail_outline_rounded, email, '')
        ],
        if (neighborhoodName != null && neighborhoodName.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _info(Icons.location_city_outlined, neighborhoodName, ''),
        ],
      ]),
    );
  }

  Widget _info(IconData icon, String? value, String fallback) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: NexusGuard.emerald),
      const SizedBox(width: 12),
      Expanded(
          child: Text(value == null || value.trim().isEmpty ? fallback : value,
              style: Theme.of(context).textTheme.bodyMedium)),
    ]);
  }

  Widget _profileForm() {
    final disabled = _saving || _picking;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _card,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Informasi pribadi',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text('Perbarui informasi agar warga dapat menghubungi Anda.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: NexusGuard.muted)),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('profile-name'),
            controller: _nameCtrl,
            enabled: !disabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => _changed(),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama lengkap wajib diisi.'
                : null,
            decoration: const InputDecoration(
                labelText: 'Nama lengkap',
                prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('profile-phone'),
            controller: _phoneCtrl,
            enabled: !disabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => _changed(),
            decoration: const InputDecoration(
                labelText: 'Nomor telepon',
                helperText: 'Opsional',
                prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('profile-address'),
            controller: _addressCtrl,
            enabled: !disabled,
            maxLines: 3,
            keyboardType: TextInputType.streetAddress,
            autofillHints: const [AutofillHints.fullStreetAddress],
            onChanged: (_) => _changed(),
            decoration: const InputDecoration(
                labelText: 'Alamat',
                helperText: 'Opsional',
                prefixIcon: Icon(Icons.home_outlined)),
          ),
          const SizedBox(height: 24),
          if (_saveError != null) ...[
            _notice(_saveError!, keyName: 'profile-save-error'),
            const SizedBox(height: 16),
          ],
          if (_saved) ...[
            Semantics(
                liveRegion: true,
                child: Row(key: const ValueKey('profile-saved'), children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: NexusGuard.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Profil berhasil disimpan.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: NexusGuard.emerald))),
                ])),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            key: const ValueKey('profile-save'),
            onPressed: disabled ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan perubahan'),
          ),
        ]),
      ),
    );
  }
}
