import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../services/ai_service.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';

class CreateAlertScreen extends StatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _customCtrl = TextEditingController();

  List<dynamic> _categories = [];

  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _isLainnya = false;
  bool _loading = false;
  bool _gettingLocation = false;

  double? _lat;
  double? _lng;

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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kategori: $e')),
      );
    }
  }

  Future<void> _getLocation() async {
    if (!mounted) return;

    setState(() {
      _gettingLocation = true;
    });

    try {
      final permission = await Geolocator.requestPermission();

      if (!mounted) return;

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _lat = AppConstants.defaultLat;
          _lng = AppConstants.defaultLng;
          _gettingLocation = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _gettingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _lat = AppConstants.defaultLat;
        _lng = AppConstants.defaultLng;
        _gettingLocation = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori alert wajib dipilih')),
      );
      return;
    }

    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi wajib diisi')),
      );
      return;
    }

    if (_isLainnya && _customCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi jenis kejadian untuk kategori Lainnya'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final res = await AlertService.createAlert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'categoryId': _selectedCategoryId,
        'customCategory': _isLainnya ? _customCtrl.text.trim() : null,
        'latitude': _lat ?? AppConstants.defaultLat,
        'longitude': _lng ?? AppConstants.defaultLng,
      });

      if (!mounted) return;

      if (res['success'] == true) {
        final alertId = res['data']?['id'];

        if (alertId != null) {
          await AiService.fullAnalysis(
            alertId: alertId,
            category: _selectedCategoryName ?? '',
            customCategory: _isLainnya ? _customCtrl.text.trim() : null,
            description: _descCtrl.text.trim(),
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert berhasil dikirim!')),
        );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal mengirim alert')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _onCategoryChanged(String? val) {
    final dynamic selectedCat = _categories
        .where((category) => category['id'] == val)
        .cast<dynamic>()
        .firstOrNull;

    setState(() {
      _selectedCategoryId = val;
      _selectedCategoryName = selectedCat?['name'];
      _isLainnya = selectedCat?['name'] == 'Lainnya';

      if (!_isLainnya) {
        _customCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kirim Alert'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationInfo(),
            const SizedBox(height: 16),
            const Text(
              'Kategori Alert',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Pilih kategori',
              ),
              items: _categories.map<DropdownMenuItem<String>>((cat) {
                return DropdownMenuItem<String>(
                  value: cat['id'],
                  child: Text('${cat['icon'] ?? ''} ${cat['name'] ?? ''}'),
                );
              }).toList(),
              onChanged: _onCategoryChanged,
            ),
            if (_isLainnya) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCtrl,
                decoration: const InputDecoration(
                  labelText: 'Jenis Kejadian',
                  hintText: 'Contoh: Suara ledakan dari rumah warga',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Alert',
                hintText: 'Contoh: Kebakaran rumah warga',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Kejadian',
                hintText: 'Jelaskan kejadian dengan singkat dan jelas',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send),
                label: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'KIRIM ALERT',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: _gettingLocation
                ? const Text('Mendapatkan lokasi...')
                : Text(
                    _lat != null && _lng != null
                        ? 'Lokasi: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                        : 'Lokasi tidak tersedia',
                  ),
          ),
          IconButton(
            onPressed: _gettingLocation ? null : _getLocation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}