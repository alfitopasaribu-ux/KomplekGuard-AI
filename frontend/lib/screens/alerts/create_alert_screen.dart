import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/alert_service.dart';
import '../../services/ai_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_constants.dart';
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
  double? _lat, _lng;
  bool _loading = false;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _getLocation();
  }

  Future<void> _loadCategories() async {
    final res = await ApiService.get('/categories');
    if (res['success'] == true) setState(() => _categories = res['data']);
  }

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() { _lat = AppConstants.defaultLat; _lng = AppConstants.defaultLng; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
    } catch (_) {
      setState(() { _lat = AppConstants.defaultLat; _lng = AppConstants.defaultLng; });
    }
    setState(() => _gettingLocation = false);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan deskripsi wajib diisi')));
      return;
    }
    if (_isLainnya && _customCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi jenis kejadian untuk kategori Lainnya')));
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
        // Trigger AI analysis
        await AiService.fullAnalysis(
          alertId: alertId,
          category: _selectedCategoryName ?? '',
          customCategory: _isLainnya ? _customCtrl.text.trim() : null,
          description: _descCtrl.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert berhasil dikirim!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Gagal')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Alert'), backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lokasi info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  _gettingLocation
                      ? const Text('Mendapatkan lokasi...')
                      : Text(_lat != null ? 'Lokasi: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}' : 'Lokasi tidak tersedia'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kategori
            const Text('Kategori Alert', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Pilih kategori'),
              items: _categories.map<DropdownMenuItem<String>>((cat) {
                return DropdownMenuItem(value: cat['id'], child: Text('${cat['icon'] ?? ''} ${cat['name']}'));
              }).toList(),
              onChanged: (val) {
                final cat = _categories.firstWhere((c) => c['id'] == val, orElse: () => null);
                setState(() {
                  _selectedCategoryId = val;
                  _selectedCategoryName = cat?['name'];
                  _isLainnya = cat?['name'] == 'Lainnya';
                });
              },
            ),
            if (_isLainnya) ...[
              const SizedBox(height: 12),
              TextField(controller: _customCtrl, decoration: const InputDecoration(labelText: 'Jenis Kejadian (isi sendiri)', border: OutlineInputBorder())),
            ],
            const SizedBox(height: 16),

            // Judul
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Judul Alert', border: OutlineInputBorder())),
            const SizedBox(height: 16),

            // Deskripsi
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi Kejadian', border: OutlineInputBorder()), maxLines: 4),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
                icon: const Icon(Icons.send),
                label: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('KIRIM ALERT', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}