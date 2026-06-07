import 'package:flutter/material.dart';

import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
import '../alerts/alert_list_screen.dart';
import '../alerts/create_alert_screen.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _activeAlerts = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthService.getUser();
      final res = await AlertService.getActiveAlerts();

      if (!mounted) return;

      setState(() {
        _user = user == null ? null : Map<String, dynamic>.from(user);

        if (res['success'] == true) {
          _activeAlerts = res['data'] ?? [];
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat dashboard: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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

  Future<void> _openCreateAlert() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateAlertScreen()),
    );

    if (!mounted) return;

    await _loadData();
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  void _openAlertList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlertListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KomplekGuard AI'),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _openMap,
            icon: const Icon(Icons.map),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${_user?['name'] ?? 'Warga'}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Tetap aman dan waspada',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _buildActiveAlertSummary(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Alert Terkini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _openAlertList,
                          child: const Text('Lihat Semua'),
                        ),
                      ],
                    ),
                    if (_activeAlerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Tidak ada alert aktif saat ini',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ..._activeAlerts.take(3).map(
                            (alert) => _alertCard(alert),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateAlert,
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert),
        label: const Text('KIRIM ALERT'),
      ),
    );
  }

  Widget _buildActiveAlertSummary() {
    final bool isSafe = _activeAlerts.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSafe ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isSafe ? Icons.check_circle : Icons.warning_rounded,
            color: isSafe ? Colors.green : Colors.red,
            size: 40,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_activeAlerts.length} Alert Aktif',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isSafe ? 'Lingkungan aman' : 'Perlu perhatian',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertCard(dynamic alert) {
    final status = alert['status']?.toString() ?? '';
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(
          Icons.warning_rounded,
          color: Color(0xFFD32F2F),
        ),
        title: Text(
          alert['title']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          alert['description']?.toString() ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}