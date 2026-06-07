import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/nexus_guard_theme.dart';
import '../../services/ai_service.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';

class CreateAlertScreen extends StatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _customCtrl = TextEditingController();

  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  bool _isLainnya = false;

  double? _lat;
  double? _lng;

  bool _loading = false;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _getLocation();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ApiService.get('/categories');

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _categories = res['data'] ?? [];
        });
      }
    } catch (e) {
      _showSnack('Gagal memuat kategori: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);

    try {
      final permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _lat = AppConstants.defaultLat;
          _lng = AppConstants.defaultLng;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _lat = AppConstants.defaultLat;
        _lng = AppConstants.defaultLng;
      });
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      _showSnack('Pilih kategori alert terlebih dahulu.');
      return;
    }

    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      _showSnack('Judul dan deskripsi wajib diisi.');
      return;
    }

    if (_isLainnya && _customCtrl.text.trim().isEmpty) {
      _showSnack('Isi jenis kejadian untuk kategori Lainnya.');
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await AlertService.createAlert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'categoryId': _selectedCategoryId,
        'customCategory': _isLainnya ? _customCtrl.text.trim() : null,
        'latitude': _lat ?? AppConstants.defaultLat,
        'longitude': _lng ?? AppConstants.defaultLng,
      });

      if (res['success'] == true) {
        final alertId = res['data']['id'];

        await AiService.fullAnalysis(
          alertId: alertId,
          category: _selectedCategoryName ?? '',
          customCategory: _isLainnya ? _customCtrl.text.trim() : null,
          description: _descCtrl.text.trim(),
        );

        if (!mounted) return;

        _showSnack('Alert berhasil dikirim dan dianalisis AI.');
        Navigator.pop(context);
      } else {
        _showSnack(res['message'] ?? 'Gagal mengirim alert.');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NexusGuard.panel,
        content: Text(message, style: NexusGuard.rajdhani()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusGuard.bg,
      appBar: AppBar(
        backgroundColor: NexusGuard.bg.withValues(alpha: 0.96),
        foregroundColor: NexusGuard.text,
        elevation: 0,
        title: Text(
          'CREATE INCIDENT',
          style: NexusGuard.orbitron(size: 16, color: NexusGuard.cyan),
        ),
      ),
      body: NexusBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NexusHudCard(
                    glowColor: NexusGuard.red,
                    active: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NexusSectionTitle(
                          title: 'AKTIFKAN ALERT DARURAT',
                          subtitle:
                              'Kirim laporan cepat agar warga lain dapat melihat, merespons, dan membantu.',
                          icon: Icons.notification_important_rounded,
                          color: NexusGuard.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI akan membaca deskripsi kejadian, menentukan risk level, dan membuat panduan awal untuk pelapor.',
                          style: NexusGuard.rajdhani(
                            color: NexusGuard.muted,
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _locationPanel(),
                  const SizedBox(height: 14),
                  _formPanel(),
                  const SizedBox(height: 18),
                  NexusPrimaryButton(
                    text: _loading ? 'MENGIRIM ALERT...' : 'KIRIM ALERT DARURAT',
                    icon: Icons.send_rounded,
                    color: NexusGuard.red,
                    onPressed: _loading ? () {} : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationPanel() {
    return NexusHudCard(
      glowColor: NexusGuard.green,
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, color: NexusGuard.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _gettingLocation
                  ? 'Mengambil titik koordinat...'
                  : 'Lokasi: ${(_lat ?? AppConstants.defaultLat).toStringAsFixed(6)}, ${(_lng ?? AppConstants.defaultLng).toStringAsFixed(6)}',
              style: NexusGuard.mono(color: NexusGuard.green),
            ),
          ),
          IconButton(
            onPressed: _getLocation,
            icon: const Icon(Icons.refresh_rounded, color: NexusGuard.cyan),
          ),
        ],
      ),
    );
  }

  Widget _formPanel() {
    return NexusHudCard(
      glowColor: NexusGuard.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'DATA INCIDENT',
            subtitle: 'Isi detail kejadian agar warga dan AI memahami situasi.',
            icon: Icons.edit_note_rounded,
            color: NexusGuard.cyan,
          ),
          const SizedBox(height: 18),
          _categoryDropdown(),
          if (_isLainnya) ...[
            const SizedBox(height: 12),
            _input(
              controller: _customCtrl,
              label: 'Jenis kejadian lainnya',
              icon: Icons.drive_file_rename_outline_rounded,
            ),
          ],
          const SizedBox(height: 12),
          _input(
            controller: _titleCtrl,
            label: 'Judul alert',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 12),
          _input(
            controller: _descCtrl,
            label: 'Deskripsi kejadian',
            icon: Icons.description_rounded,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      dropdownColor: NexusGuard.panel,
      iconEnabledColor: NexusGuard.cyan,
      style: NexusGuard.rajdhani(color: NexusGuard.text, size: 16),
      decoration: _decoration(
        label: 'Kategori alert',
        icon: Icons.category_rounded,
      ),
      items: _categories.map<DropdownMenuItem<String>>((cat) {
        return DropdownMenuItem<String>(
          value: cat['id']?.toString(),
          child: Text(
            '${cat['icon'] ?? ''} ${cat['name'] ?? ''}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        dynamic selected;

        for (final item in _categories) {
          if (item['id']?.toString() == val) {
            selected = item;
            break;
          }
        }

        setState(() {
          _selectedCategoryId = val;
          _selectedCategoryName = selected?['name']?.toString();
          _isLainnya = selected?['name']?.toString() == 'Lainnya';
        });
      },
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: NexusGuard.rajdhani(color: NexusGuard.text, size: 16),
      decoration: _decoration(label: label, icon: icon),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: NexusGuard.rajdhani(color: NexusGuard.muted),
      prefixIcon: Icon(icon, color: NexusGuard.cyan),
      filled: true,
      fillColor: NexusGuard.bg.withValues(alpha: 0.58),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: NexusGuard.border.withValues(alpha: 0.9),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: NexusGuard.cyan,
          width: 1.4,
        ),
      ),
    );
  }
}
