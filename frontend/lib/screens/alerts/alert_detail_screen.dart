import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/alert_service.dart';

class AlertDetailScreen extends StatefulWidget {
  final String alertId;

  const AlertDetailScreen({
    super.key,
    required this.alertId,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  Map<String, dynamic>? _alert;
  bool _loading = true;
  Timer? _pollingTimer;

  static const Color darkNavy = Color(0xFF0F172A);
  static const Color navy2 = Color(0xFF1E293B);
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color softBg = Color(0xFFF8FAFC);
  static const Color textGray = Color(0xFF64748B);
  static const Color teal = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _load();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      if (!silent && mounted) setState(() => _loading = true);

      final res = await AlertService.getAlertDetail(widget.alertId);

      if (!mounted) return;

      setState(() {
        if (res['success'] == true) {
          _alert = Map<String, dynamic>.from(res['data']);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat detail alert: $e')),
        );
      }
    }
  }

  Future<void> _respond(String status) async {
    try {
      final res = await AlertService.respondToAlert(widget.alertId, status);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['success'] == true
                ? 'Respons terkirim. Pelapor bisa melihat bantuanmu.'
                : (res['message'] ?? 'Gagal mengirim respons'),
          ),
        ),
      );

      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Color _riskColor(String? riskLevel) {
    switch (riskLevel) {
      case 'RENDAH':
        return Colors.green;
      case 'SEDANG':
        return Colors.orange;
      case 'TINGGI':
        return Colors.deepOrange;
      case 'KRITIS':
        return emergencyRed;
      default:
        return Colors.blueGrey;
    }
  }

  String _categoryName(Map<String, dynamic> alert) {
    final custom = alert['customCategory'];
    if (custom != null && custom.toString().trim().isNotEmpty) {
      return custom.toString();
    }

    final category = alert['category'];
    if (category != null && category['name'] != null) {
      return category['name'].toString();
    }

    return 'Alert Lingkungan';
  }

  String _riskLevel(Map<String, dynamic> alert) {
    final aiSummaries = alert['aiSummaries'] as List? ?? [];
    if (aiSummaries.isNotEmpty && aiSummaries.first['riskLevel'] != null) {
      return aiSummaries.first['riskLevel'].toString();
    }

    return alert['riskLevel']?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: softBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_alert == null) {
      return Scaffold(
        backgroundColor: softBg,
        appBar: _appBar(),
        body: const Center(child: Text('Data alert tidak ditemukan')),
      );
    }

    final alert = _alert!;
    final aiSummaries = alert['aiSummaries'] as List? ?? [];
    final ai = aiSummaries.isNotEmpty ? aiSummaries.first : null;
    final risk = _riskLevel(alert);
    final riskColor = _riskColor(risk);

    return Scaffold(
      backgroundColor: softBg,
      appBar: _appBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroCard(alert, risk, riskColor),
                  const SizedBox(height: 16),
                  _reporterCard(alert['user']),
                  const SizedBox(height: 16),
                  _locationCard(alert),
                  const SizedBox(height: 16),
                  if (ai != null) _aiCard(ai, riskColor),
                  const SizedBox(height: 16),
                  _responseCard(),
                  const SizedBox(height: 16),
                  _responderList(alert),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: darkNavy,
      foregroundColor: Colors.white,
      title: const Text(
        'Detail Alert',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _heroCard(Map<String, dynamic> alert, String risk, Color riskColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [darkNavy, navy2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: darkNavy.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _whiteBadge('🚨 ${alert['status'] ?? '-'}'),
                _coloredBadge('Risk $risk', riskColor),
                _coloredBadge(_categoryName(alert), teal),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              alert['title']?.toString() ?? 'Alert',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              alert['description']?.toString() ?? '-',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                height: 1.45,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reporterCard(dynamic reporter) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.person_pin_circle_rounded, 'Siapa yang Mengirim Alert?'),
          const SizedBox(height: 14),
          _info('Nama Pelapor', reporter?['name']?.toString() ?? '-'),
          _info('Role', reporter?['role']?.toString() ?? '-'),
          _info('No. HP', reporter?['phone']?.toString() ?? '-'),
          _info('Alamat', reporter?['address']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _locationCard(Map<String, dynamic> alert) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.map_rounded, 'Titik Koordinat OpenStreetMap'),
          const SizedBox(height: 14),
          _info('Latitude', alert['latitude']?.toString() ?? '-'),
          _info('Longitude', alert['longitude']?.toString() ?? '-'),
          _info('Alamat', alert['address']?.toString() ?? '-'),
          const SizedBox(height: 10),
          Text(
            'Koordinat ini digunakan untuk menampilkan titik kejadian pada peta OpenStreetMap.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _aiCard(dynamic ai, Color riskColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.purple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Analisis AI',
                  style: TextStyle(
                    color: darkNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _riskPill(ai['riskLevel']?.toString() ?? '-', riskColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ai['summary']?.toString() ?? '-',
            style: const TextStyle(color: darkNavy, height: 1.45),
          ),
          const SizedBox(height: 14),
          const Text(
            'Panduan Awal',
            style: TextStyle(
              color: darkNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ai['recommendedAction']?.toString() ?? '-',
            style: const TextStyle(color: textGray, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _responseCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.groups_rounded, 'Respons Alert Ini'),
          const SizedBox(height: 8),
          const Text(
            'Saat kamu menekan tombol respons, pengirim alert dapat melihat bahwa ada warga yang membantu sehingga tidak panik.',
            style: TextStyle(color: textGray, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _responseButton(
                'SAYA_BISA_BANTU',
                'Saya Bisa Bantu',
                Icons.volunteer_activism_rounded,
              ),
              _responseButton(
                'MENUJU_LOKASI',
                'Menuju Lokasi',
                Icons.directions_run_rounded,
              ),
              _responseButton(
                'SUDAH_DI_LOKASI',
                'Sudah di Lokasi',
                Icons.check_circle_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _responderList(Map<String, dynamic> alert) {
    final responses = alert['responses'] as List? ?? [];

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.people_alt_rounded, 'Warga yang Sudah Merespons'),
          const SizedBox(height: 14),
          if (responses.isEmpty)
            const Text(
              'Belum ada warga yang merespons alert ini.',
              style: TextStyle(color: textGray),
            )
          else
            ...responses.map((response) {
              final user = response['user'];
              final name = user?['name']?.toString() ?? 'Warga';
              final phone = user?['phone']?.toString() ?? '-';
              final role = user?['role']?.toString() ?? '-';
              final status =
                  response['responseStatus']?.toString().replaceAll('_', ' ') ??
                      '-';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: softBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: emergencyRed.withValues(alpha: 0.12),
                      child: const Icon(Icons.person_rounded, color: emergencyRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: darkNavy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$role • HP: $phone',
                            style: const TextStyle(color: textGray),
                          ),
                        ],
                      ),
                    ),
                    _riskPill(status, teal),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _responseButton(String status, String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _respond(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: emergencyRed,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _title(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: emergencyRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: darkNavy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: textGray,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: darkNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _whiteBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _coloredBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == teal ? teal : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}