import 'package:flutter/material.dart';

import '../../services/alert_service.dart';
import 'alert_detail_screen.dart';

class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key});

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<dynamic> _active = [];
  List<dynamic> _history = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final activeResponse = await AlertService.getActiveAlerts();
      final historyResponse = await AlertService.getAlertHistory();

      if (!mounted) return;

      setState(() {
        if (activeResponse['success'] == true) {
          _active = activeResponse['data'] ?? [];
        }

        if (historyResponse['success'] == true) {
          _history = historyResponse['data'] ?? [];
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat daftar alert: $e')),
      );
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'AKTIF':
        return Colors.red;
      case 'DIPROSES':
        return Colors.orange;
      case 'SELESAI':
        return Colors.green;
      case 'DIBATALKAN':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildList(List<dynamic> alerts) {
    if (alerts.isEmpty) {
      return const Center(child: Text('Tidak ada data'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: alerts.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final status = alert['status']?.toString() ?? '';
          final color = _statusColor(status);

          return Card(
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlertDetailScreen(
                      alertId: alert['id'].toString(),
                    ),
                  ),
                );
              },
              leading: const Icon(
                Icons.warning_rounded,
                color: Color(0xFFD32F2F),
              ),
              title: Text(alert['title']?.toString() ?? ''),
              subtitle: Text(
                alert['description']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Chip(
                label: Text(
                  status,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Alert'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_active),
                _buildList(_history),
              ],
            ),
    );
  }
}