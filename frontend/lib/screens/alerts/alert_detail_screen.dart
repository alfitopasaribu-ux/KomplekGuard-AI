import 'package:flutter/material.dart';
import '../../services/alert_service.dart';

class AlertDetailScreen extends StatefulWidget {
  final String alertId;
  const AlertDetailScreen({super.key, required this.alertId});

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
    final res = await AlertService.getAlertDetail(widget.alertId);
    if (res['success'] == true) setState(() { _alert = res['data']; _loading = false; });
  }

  Future<void> _respond(String status) async {
    final res = await AlertService.respondToAlert(widget.alertId, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['success'] == true ? 'Respons terkirim' : (res['message'] ?? 'Gagal'))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final alert = _alert!;
    final aiSummaries = alert['aiSummaries'] as List? ?? [];
    final ai = aiSummaries.isNotEmpty ? aiSummaries.last : null;

    final riskColors = {'RENDAH': Colors.green, 'SEDANG': Colors.orange, 'TINGGI': Colors.deepOrange, 'KRITIS': Colors.red};

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Alert'), backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(alert['description'] ?? ''),
            const SizedBox(height: 16),

            if (ai != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text('Analisis AI', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: (riskColors[ai['riskLevel']] ?? Colors.grey).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(ai['riskLevel'] ?? '', style: TextStyle(color: riskColors[ai['riskLevel']] ?? Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(ai['summary'] ?? ''),
                    const SizedBox(height: 8),
                    const Text('Panduan Awal:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(ai['recommendedAction'] ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text('Respons', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['SAYA_BISA_BANTU', 'MENUJU_LOKASI', 'SUDAH_DI_LOKASI'].map((s) {
                final labels = {'SAYA_BISA_BANTU': 'Saya Bisa Bantu', 'MENUJU_LOKASI': 'Menuju Lokasi', 'SUDAH_DI_LOKASI': 'Sudah di Lokasi'};
                return ElevatedButton(onPressed: () => _respond(s), child: Text(labels[s] ?? s));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}