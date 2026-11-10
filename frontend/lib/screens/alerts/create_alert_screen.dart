import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/ai_service.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';
import '../../services/safety_ai_service.dart';
import '../../services/voice_service.dart';

class CreateAlertScreen extends StatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  State<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends State<CreateAlertScreen> {
  static const _white = Colors.white;
  static const _softGreen = Color(0xFFEAF5ED);
  static const _softRed = Color(0xFFFDEDEC);

  final _detailKey = GlobalKey<FormState>();
  final _locationKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _picker = ImagePicker();

  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  bool _isLainnya = false;
  int _step = 0;
  bool _categoryLoading = true;
  bool _gettingLocation = false;
  bool _locationConfirmed = false;
  String _locationSource = 'Koordinat manual';
  String? _categoryError;
  String? _locationError;
  String? _locationValidation;
  String? _error;
  String? _draftError;
  String? _photoError;
  bool _loading = false;
  bool _analyzing = false;
  bool _voiceListening = false;
  bool _aiDraftLoading = false;
  bool _photoPicking = false;
  Uint8List? _photoBytes;
  String? _photoDataUrl;
  String _descriptionBeforeVoice = '';

  // Laporan yang sudah tersimpan tidak boleh dikirim ulang.
  bool _creationAcknowledged = false;
  Map<String, dynamic>? _createdAlert;
  String? _createdAlertId;
  String? _analysisError;

  bool get _busy => _loading || _aiDraftLoading || _photoPicking;
  bool get _locked => _busy || _creationAcknowledged;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _getLocation();
  }

  @override
  void dispose() {
    unawaited(VoiceService.instance.cancel().catchError((Object _) {}));
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _customCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _categoryLoading = true;
        _categoryError = null;
      });
    }
    try {
      final res = await ApiService.get('/categories');
      if (!mounted) return;
      if (res['success'] != true || res['data'] is! List) {
        setState(() => _categoryError =
            res['message']?.toString() ?? 'Kategori belum dapat dimuat.');
        return;
      }
      setState(() {
        _categories = res['data'] as List;
        if (_categories.isEmpty) {
          _categoryError = 'Belum ada kategori yang tersedia.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _categoryError =
            'Gagal memuat kategori. Periksa internet lalu coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _categoryLoading = false);
    }
  }

  Future<void> _getLocation() async {
    if (_gettingLocation || _locked) return;
    setState(() {
      _gettingLocation = true;
      _locationConfirmed = false;
      _locationError = null;
      _locationValidation = null;
    });
    try {
      final permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationError =
            'Izin lokasi tidak diberikan. Izinkan GPS atau isi koordinat kejadian secara manual.');
        return;
      }
      final position = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        throw const FormatException('Koordinat tidak valid');
      }
      setState(() {
        _latitudeCtrl.text = position.latitude.toStringAsFixed(7);
        _longitudeCtrl.text = position.longitude.toStringAsFixed(7);
        _locationSource = 'GPS perangkat';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _locationError =
            'GPS belum tersedia. Coba lagi atau isi koordinat kejadian secara manual.');
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  double? _coordinate(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateCoordinate(String? text, {required bool latitude}) {
    final value = _coordinate(text ?? '');
    if (value == null || !value.isFinite) {
      return 'Masukkan koordinat yang valid.';
    }
    final limit = latitude ? 90 : 180;
    if (value < -limit || value > limit) {
      return 'Nilai harus antara -$limit dan $limit.';
    }
    return null;
  }

  bool get _coordinatesValid =>
      _validateCoordinate(_latitudeCtrl.text, latitude: true) == null &&
      _validateCoordinate(_longitudeCtrl.text, latitude: false) == null;

  void _locationChanged(String _) {
    setState(() {
      _locationConfirmed = false;
      _locationValidation = null;
      _locationSource = 'Koordinat manual';
    });
  }

  Future<void> _stopVoice() async {
    try {
      await VoiceService.instance.cancel();
    } catch (_) {
      // Penutupan suara tidak boleh menghalangi pelaporan.
    }
    if (mounted) setState(() => _voiceListening = false);
  }

  Future<void> _next() async {
    if (_busy || _creationAcknowledged) return;
    setState(() => _error = null);
    if (_step == 0) {
      if (!(_detailKey.currentState?.validate() ?? false)) return;
      if (_selectedCategoryId == null || _categoryLoading) return;
      await _stopVoice();
      if (mounted) setState(() => _step = 1);
    } else if (_step == 1) {
      if (_gettingLocation) return;
      final valid = _locationKey.currentState?.validate() ?? false;
      if (!valid || !_locationConfirmed) {
        setState(() => _locationValidation = valid
            ? 'Centang konfirmasi bahwa lokasi sesuai kejadian.'
            : 'Periksa koordinat lokasi kejadian.');
        return;
      }
      setState(() {
        _locationValidation = null;
        _step = 2;
      });
    }
  }

  void _back() {
    if (_busy) return;
    if (_creationAcknowledged) {
      _finish();
    } else if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  void _finish() {
    if (_busy) return;
    Navigator.pop(
        context,
        _createdAlert ??
            <String, dynamic>{'saved': true, 'id': _createdAlertId});
  }

  Future<void> _submit() async {
    if (_busy || _creationAcknowledged) return;
    if (_selectedCategoryId == null ||
        _titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        (_isLainnya && _customCtrl.text.trim().isEmpty)) {
      setState(() {
        _step = 0;
        _error = 'Lengkapi detail kejadian terlebih dahulu.';
      });
      return;
    }
    if (!_coordinatesValid || !_locationConfirmed || _gettingLocation) {
      setState(() {
        _step = 1;
        _locationValidation = 'Pastikan lokasi kejadian sudah dikonfirmasi.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    await _stopVoice();
    if (!mounted) return;
    try {
      // Mempertahankan kontrak lama AlertService.createAlert.
      final res = await AlertService.createAlert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'categoryId': _selectedCategoryId,
        'customCategory': _isLainnya ? _customCtrl.text.trim() : null,
        'latitude': _coordinate(_latitudeCtrl.text)!,
        'longitude': _coordinate(_longitudeCtrl.text)!,
        if (_photoDataUrl != null) 'photoUrl': _photoDataUrl,
      });
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() {
          _error = res['message']?.toString() ??
              'Laporan belum berhasil dikirim. Coba lagi.';
          _loading = false;
        });
        return;
      }

      final data = res['data'];
      final created =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final id = created['id']?.toString();
      setState(() {
        _creationAcknowledged = true;
        _createdAlert = created;
        _createdAlertId = id == null || id.isEmpty ? null : id;
      });

      if (_createdAlertId == null) {
        setState(() {
          _loading = false;
          _analysisError =
              'Laporan sudah tersimpan, tetapi ID laporan belum diterima. Periksa daftar laporan.';
        });
        return;
      }
      await _analyzeSavedAlert();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Koneksi terputus. Periksa daftar laporan sebelum '
              'mencoba mengirim ulang untuk menghindari duplikasi.';
        });
      }
    }
  }

  Future<void> _analyzeSavedAlert() async {
    if (_analyzing || _createdAlertId == null) return;
    setState(() {
      _loading = true;
      _analyzing = true;
      _analysisError = null;
    });
    try {
      // API ini menganalisis deskripsi. Vision harus didukung backend.
      final res = await AiService.fullAnalysis(
        alertId: _createdAlertId!,
        category: _selectedCategoryName ?? '',
        customCategory: _isLainnya ? _customCtrl.text.trim() : null,
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() => _analysisError =
            'Laporan tersimpan, tetapi analisis AI belum tersedia. '
                'Coba analisis lagi atau lanjutkan tanpa mengirim ulang.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan berhasil dikirim.')),
        );
        Navigator.pop(context, _createdAlert);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _analysisError =
            'Analisis AI belum berhasil. Laporan tetap tersimpan '
                'dan tidak perlu dikirim ulang.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _toggleVoiceDescription() async {
    if (_locked) return;
    try {
      if (_voiceListening) {
        await _stopVoice();
        return;
      }
      _descriptionBeforeVoice = _descCtrl.text.trim();
      setState(() {
        _voiceListening = true;
        _draftError = null;
      });
      await VoiceService.instance.startListening(
        onResult: (text) {
          if (!mounted || _creationAcknowledged) return;
          final spoken = text.trim();
          if (spoken.isEmpty) return;
          final combined = [
            _descriptionBeforeVoice,
            spoken,
          ].where((part) => part.isNotEmpty).join(' ');
          setState(() {
            _descCtrl.value = TextEditingValue(
              text: combined,
              selection: TextSelection.collapsed(offset: combined.length),
            );
          });
        },
        onDone: () {
          if (mounted) setState(() => _voiceListening = false);
        },
      );
      if (!mounted) await VoiceService.instance.cancel();
    } catch (_) {
      if (mounted) {
        setState(() {
          _voiceListening = false;
          _draftError = 'Mikrofon belum tersedia. '
              'Periksa izin atau ketik deskripsi secara manual.';
        });
      }
    }
  }

  Future<void> _generateAiDraftFromVoice() async {
    if (_locked) return;
    final transcript = _descCtrl.text.trim();
    if (transcript.isEmpty) {
      setState(
          () => _draftError = 'Ceritakan atau ketik kejadian terlebih dahulu.');
      return;
    }
    setState(() {
      _aiDraftLoading = true;
      _draftError = null;
    });
    await _stopVoice();
    if (!mounted) return;
    try {
      final res = await SafetyAiService.createVoiceAlertDraft(
        transcript: transcript,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map;
        setState(() {
          if (data['title'] != null) {
            _titleCtrl.text = data['title'].toString();
          }
          if (data['description'] != null) {
            _descCtrl.text = data['description'].toString();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Draft dirapikan. Periksa kembali isi laporan.')),
        );
      } else {
        setState(() => _draftError = res['message']?.toString() ??
            'Draft belum dapat dirapikan. Teks asli tetap tersedia.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _draftError =
            'AI belum dapat merapikan deskripsi. Anda tetap bisa mengirim laporan.');
      }
    } finally {
      if (mounted) setState(() => _aiDraftLoading = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_locked) return;
    setState(() {
      _photoPicking = true;
      _photoError = null;
    });
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2000000) {
        setState(() => _photoError = 'Ukuran foto maksimal 2 MB.');
        return;
      }
      String? mime;
      if (bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff) {
        mime = 'image/jpeg';
      } else if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47) {
        mime = 'image/png';
      } else if (bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
        mime = 'image/webp';
      }
      if (mime == null) {
        setState(() => _photoError = 'Format foto harus JPEG, PNG, atau WebP.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _photoError =
            'Gagal memilih foto. Periksa izin kamera atau galeri.');
      }
    } finally {
      if (mounted) setState(() => _photoPicking = false);
    }
  }

  // ===================== TAMPILAN V3 =====================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: NexusGuard.ivory,
        appBar: AppBar(
          backgroundColor: NexusGuard.slate,
          foregroundColor: _white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            key: const Key('create_back'),
            tooltip: 'Kembali',
            onPressed: _busy ? null : _back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'Buat Laporan',
            style: TextStyle(
              color: _white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            key: const Key('create_scroll'),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepIndicator(),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      _notice(_error!, key: const Key('create_error')),
                      const SizedBox(height: 14),
                    ],
                    if (_creationAcknowledged)
                      _savedCard()
                    else if (_step == 0)
                      _detailPanel()
                    else if (_step == 1)
                      _locationPanel()
                    else
                      _confirmationPanel(),
                    const SizedBox(height: 20),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            color: NexusGuard.emerald, size: 18),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Keselamatan Anda lebih penting daripada kelengkapan laporan. '
                            'Jangan mendekati sumber bahaya untuk mengambil foto.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: NexusGuard.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: _bottomActions(),
      ),
    );
  }

  Widget _stepIndicator() {
    const labels = ['Detail', 'Lokasi', 'Konfirmasi'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      decoration: _panelDecoration(),
      child: Row(
        children: List.generate(3, (index) {
          final done = _creationAcknowledged || index < _step;
          final active = !_creationAcknowledged && index == _step;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index <= _step
                              ? NexusGuard.emerald
                              : NexusGuard.border,
                        ),
                      ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: done || active
                            ? NexusGuard.emerald
                            : const Color(0xFFB9C5C2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                                color: _white, size: 19)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: _white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < _step
                              ? NexusGuard.emerald
                              : NexusGuard.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? NexusGuard.emerald : NexusGuard.muted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  BoxDecoration _panelDecoration({Color color = _white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: NexusGuard.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D0B4236),
          blurRadius: 24,
          offset: Offset(0, 7),
        ),
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: NexusGuard.emerald, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: NexusGuard.slate,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            subtitle,
            style: const TextStyle(
              color: NexusGuard.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _notice(String message, {Key? key, bool success = false}) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: key,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: success ? _softGreen : _softRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 19,
              color: success ? NexusGuard.emerald : NexusGuard.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: success ? NexusGuard.emerald : NexusGuard.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    IconData? icon,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      alignLabelWithHint: true,
      prefixIcon:
          icon == null ? null : Icon(icon, size: 20, color: NexusGuard.emerald),
      filled: true,
      fillColor: const Color(0xFFFBFDFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: NexusGuard.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: NexusGuard.emerald, width: 1.7),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _detailPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          icon: Icons.assignment_outlined,
          title: 'Detail Kejadian',
          subtitle:
              'Ceritakan apa yang terjadi agar warga lain dapat membantu.',
          child: Form(
            key: _detailKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_categoryLoading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text('Memuat kategori...'),
                  const SizedBox(height: 12),
                ],
                if (_categoryError != null) ...[
                  _notice(_categoryError!,
                      key: const Key('create_category_error')),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('create_category_retry'),
                      onPressed: _categoryLoading ? null : _loadCategories,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Muat ulang kategori'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  key: const Key('create_category'),
                  initialValue: _selectedCategoryId,
                  isExpanded: true,
                  decoration: _fieldDecoration(
                    label: 'Kategori bahaya *',
                    icon: Icons.category_outlined,
                  ),
                  items: _categories.map<DropdownMenuItem<String>>((category) {
                    return DropdownMenuItem<String>(
                      value: category['id']?.toString(),
                      child: Text(
                        category['name']?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  validator: (value) =>
                      value == null ? 'Pilih kategori kejadian.' : null,
                  onChanged: _locked || _categoryLoading
                      ? null
                      : (value) {
                          dynamic selected;
                          for (final category in _categories) {
                            if (category['id']?.toString() == value) {
                              selected = category;
                              break;
                            }
                          }
                          setState(() {
                            _selectedCategoryId = value;
                            _selectedCategoryName =
                                selected?['name']?.toString();
                            _isLainnya = _selectedCategoryName == 'Lainnya';
                          });
                        },
                ),
                if (_isLainnya) ...[
                  const SizedBox(height: 17),
                  TextFormField(
                    key: const Key('create_custom_category'),
                    controller: _customCtrl,
                    enabled: !_locked,
                    maxLength: 100,
                    decoration:
                        _fieldDecoration(label: 'Jenis kejadian lainnya *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Isi jenis kejadian lainnya.'
                        : null,
                  ),
                ],
                const SizedBox(height: 17),
                TextFormField(
                  key: const Key('create_title'),
                  controller: _titleCtrl,
                  enabled: !_locked,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    label: 'Judul laporan *',
                    icon: Icons.title_rounded,
                  ).copyWith(hintText: 'Contoh: Pohon tumbang di depan rumah'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Isi judul laporan.'
                      : null,
                ),
                const SizedBox(height: 17),
                TextFormField(
                  key: const Key('create_description'),
                  controller: _descCtrl,
                  enabled: !_locked,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: 1500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    label: 'Deskripsi kejadian *',
                    icon: Icons.notes_rounded,
                  ).copyWith(
                    hintText:
                        'Apa yang terjadi? Ada bahaya atau bantuan yang dibutuhkan?',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: IconButton(
                        key: const Key('create_voice'),
                        tooltip: _voiceListening
                            ? 'Hentikan dikte'
                            : 'Isi deskripsi dengan suara',
                        onPressed: _locked ? null : _toggleVoiceDescription,
                        icon: Icon(
                          _voiceListening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_rounded,
                          color: _voiceListening
                              ? NexusGuard.red
                              : NexusGuard.emerald,
                        ),
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Isi deskripsi kejadian.'
                      : null,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('create_ai_draft'),
                    onPressed: _locked || _aiDraftLoading
                        ? null
                        : _generateAiDraftFromVoice,
                    icon: _aiDraftLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome_outlined,
                            size: 20,
                          ),
                    label: Text(
                      _aiDraftLoading
                          ? 'Merapikan deskripsi...'
                          : 'Rapikan dengan AI',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (_voiceListening) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _softRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          color: NexusGuard.red,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Mendengarkan... ketuk mikrofon untuk berhenti.',
                            style: TextStyle(
                              color: NexusGuard.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Gunakan mikrofon untuk mengisi deskripsi dengan suara. '
                  'Periksa transkripsi sebelum mengirim. Audio tidak disimpan.',
                  style: TextStyle(
                    color: NexusGuard.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                if (_draftError != null) ...[
                  const SizedBox(height: 12),
                  _notice(
                    _draftError!,
                    key: const Key('create_draft_error'),
                  ),
                ],
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softGreen,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          color: NexusGuard.emerald, size: 19),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'AI dapat membantu memahami isi laporan, tetapi bukan '
                          'pengganti penilaian petugas di lapangan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: NexusGuard.slate,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _photoPanel(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _removePhoto() {
    if (_locked) return;
    setState(() {
      _photoBytes = null;
      _photoDataUrl = null;
      _photoError = null;
    });
  }

  Widget _photoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Kejadian (Opsional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: NexusGuard.slate,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tambahkan foto jika aman untuk diambil. Maksimal 2 MB.',
          style: TextStyle(fontSize: 12, color: NexusGuard.muted),
        ),
        const SizedBox(height: 13),
        if (_photoBytes != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NexusGuard.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _photoBytes!,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 90,
                      height: 90,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Foto siap dilampirkan',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        key: const Key('create_photo_remove'),
                        onPressed: _locked ? null : _removePhoto,
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text('Hapus foto'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
        ],
        if (_photoPicking) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 13),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const Key('create_photo_gallery'),
              onPressed: _locked ? null : () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 19),
              label: const Text('Galeri'),
            ),
            OutlinedButton.icon(
              key: const Key('create_photo_camera'),
              onPressed: _locked ? null : () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 19),
              label: const Text('Kamera'),
            ),
          ],
        ),
        if (_photoError != null) ...[
          const SizedBox(height: 12),
          _notice(_photoError!),
        ],
      ],
    );
  }

  Widget _locationPanel() {
    return _section(
      icon: Icons.location_on_outlined,
      title: 'Lokasi Kejadian',
      subtitle: 'Gunakan GPS jika berada di lokasi. Jika tidak, isi koordinat '
          'lokasi kejadian yang sebenarnya.',
      child: Form(
        key: _locationKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded,
                      color: NexusGuard.emerald, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _coordinatesValid
                          ? '${_latitudeCtrl.text}, ${_longitudeCtrl.text}'
                          : 'Belum ada koordinat yang valid',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: NexusGuard.slate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('create_location_retry'),
              onPressed: _gettingLocation || _locked ? null : _getLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_rounded, size: 20),
              label: Text(_gettingLocation
                  ? 'Mengambil lokasi...'
                  : 'Gunakan Lokasi Perangkat'),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 12),
              _notice(_locationError!, key: const Key('create_location_error')),
            ],
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('create_latitude'),
              controller: _latitudeCtrl,
              enabled: !_locked && !_gettingLocation,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: _fieldDecoration(
                label: 'Latitude *',
                icon: Icons.place_outlined,
                helper: 'Nilai -90 hingga 90',
              ),
              validator: (value) => _validateCoordinate(value, latitude: true),
              onChanged: _locationChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('create_longitude'),
              controller: _longitudeCtrl,
              enabled: !_locked && !_gettingLocation,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: _fieldDecoration(
                label: 'Longitude *',
                icon: Icons.place_outlined,
                helper: 'Nilai -180 hingga 180',
              ),
              validator: (value) => _validateCoordinate(value, latitude: false),
              onChanged: _locationChanged,
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              key: const Key('create_location_confirm'),
              value: _locationConfirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: NexusGuard.emerald,
              title: const Text(
                'Lokasi ini sesuai dengan titik kejadian.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Sumber: $_locationSource',
                style: const TextStyle(fontSize: 11, color: NexusGuard.muted),
              ),
              onChanged: _locked || _gettingLocation
                  ? null
                  : (value) => setState(() {
                        _locationConfirmed = value ?? false;
                        _locationValidation = null;
                      }),
            ),
            if (_locationValidation != null) ...[
              const SizedBox(height: 8),
              _notice(_locationValidation!,
                  key: const Key('create_location_validation')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _confirmationPanel() {
    return _section(
      icon: Icons.fact_check_outlined,
      title: 'Periksa Laporan',
      subtitle: 'Pastikan informasi yang akan dibagikan sudah benar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewItem(
              'Kategori',
              _isLainnya
                  ? _customCtrl.text.trim()
                  : _selectedCategoryName ?? ''),
          _reviewItem('Judul laporan', _titleCtrl.text.trim()),
          _reviewItem('Deskripsi', _descCtrl.text.trim()),
          _reviewItem('Lokasi terkonfirmasi',
              '${_latitudeCtrl.text.trim()}, ${_longitudeCtrl.text.trim()}'),
          if (_photoBytes != null) ...[
            const Text('Foto kejadian',
                style: TextStyle(color: NexusGuard.muted, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _photoBytes!,
                height: 175,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
          ],
          _notice(
            'Laporan akan disimpan terlebih dahulu. Jika AI belum selesai, '
            'laporan tetap dapat dilihat dan ditindaklanjuti.',
            success: true,
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: NexusGuard.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                fontSize: 14,
                color: NexusGuard.slate,
                fontWeight: FontWeight.w600,
                height: 1.5,
              )),
        ],
      ),
    );
  }

  Widget _savedCard() {
    return Container(
      key: const Key('create_saved'),
      padding: const EdgeInsets.fromLTRB(20, 27, 20, 25),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 105,
            height: 105,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _softGreen,
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 53,
              color: NexusGuard.emerald,
            ),
          ),
          const SizedBox(height: 21),
          const Text(
            'Laporan Berhasil Disimpan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: NexusGuard.slate,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _titleCtrl.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NexusGuard.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (_analyzing) ...[
            const LinearProgressIndicator(color: NexusGuard.emerald),
            const SizedBox(height: 15),
            Semantics(
              liveRegion: true,
              child: const Text(
                'AI sedang menganalisis deskripsi laporan...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: NexusGuard.slate,
                ),
              ),
            ),
          ] else if (_analysisError != null) ...[
            _notice(_analysisError!, key: const Key('create_analysis_error')),
          ] else ...[
            const Text('Memproses laporan...',
                style: TextStyle(color: NexusGuard.muted)),
          ],
          const SizedBox(height: 12),
          const Text(
            'Tidak perlu mengirim laporan kedua kali.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: NexusGuard.muted),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
      decoration: const BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: NexusGuard.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _creationAcknowledged
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        key: const Key('create_finish'),
                        onPressed: _busy ? null : _finish,
                        child: const Text('Selesai'),
                      ),
                      if (_analysisError != null && _createdAlertId != null)
                        FilledButton.icon(
                          key: const Key('create_ai_retry'),
                          onPressed: _busy ? null : _analyzeSavedAlert,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Analisis Lagi'),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      if (_step > 0) ...[
                        OutlinedButton(
                          onPressed: _busy ? null : _back,
                          child: const Text('Kembali'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            key: Key(
                                _step < 2 ? 'create_next' : 'create_submit'),
                            onPressed: _busy || (_step == 1 && _gettingLocation)
                                ? null
                                : _step < 2
                                    ? _next
                                    : _submit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: _white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _step < 2
                                        ? Icons.arrow_forward_rounded
                                        : Icons.send_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                              _loading
                                  ? 'Mengirim...'
                                  : _step < 2
                                      ? 'Lanjutkan'
                                      : 'Kirim Laporan',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: NexusGuard.emerald,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
