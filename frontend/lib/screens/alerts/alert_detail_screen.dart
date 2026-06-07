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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
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

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail alert: $e')),
      );
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
                ? 'Respons terkirim'
                : (res['message'] ?? 'Gagal mengirim respons'),
          ),
        ),
      );
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
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_alert == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Alert'),
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Data alert tidak ditemukan'),
        ),
      );
    }

    final alert = _alert!;
    final aiSummaries = alert['aiSummaries'] as List? ?? [];
    final ai = aiSummaries.isNotEmpty ? aiSummaries.last : null;
    final riskLevel = ai?['riskLevel']?.toString();
    final riskColor = _riskColor(riskLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Alert'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert['title']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(alert['description']?.toString() ?? ''),
              const SizedBox(height: 16),
              _buildAlertInfo(alert),
              const SizedBox(height: 16),
              if (ai != null) ...[
                _buildAiAnalysis(ai, riskColor),
                const SizedBox(height: 16),
              ],
              const Text(
                'Respons',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _responseButton('SAYA_BISA_BANTU', 'Saya Bisa Bantu'),
                  _responseButton('MENUJU_LOKASI', 'Menuju Lokasi'),
                  _responseButton('SUDAH_DI_LOKASI', 'Sudah di Lokasi'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertInfo(Map<String, dynamic> alert) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _infoRow('Status', alert['status']?.toString() ?? '-'),
            _infoRow('Lokasi', '${alert['latitude']}, ${alert['longitude']}'),
            if (alert['address'] != null)
              _infoRow('Alamat', alert['address'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysis(dynamic ai, Color riskColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                'Analisis AI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ai['riskLevel']?.toString() ?? '',
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(ai['summary']?.toString() ?? ''),
          const SizedBox(height: 8),
          const Text(
            'Panduan Awal:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(ai['recommendedAction']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _responseButton(String status, String label) {
    return ElevatedButton(
      onPressed: () => _respond(status),
      child: Text(label),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}