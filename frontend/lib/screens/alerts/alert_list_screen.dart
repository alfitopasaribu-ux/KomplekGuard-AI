import 'package:flutter/material.dart';
import '../../services/alert_service.dart';
import 'alert_detail_screen.dart';

class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key});

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _active = [], _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final a = await AlertService.getActiveAlerts();
    final h = await AlertService.getAlertHistory();
    setState(() {
      if (a['success'] == true) _active = a['data'] ?? [];
      if (h['success'] == true) _history = h['data'] ?? [];
      _loading = false;
    });
  }

  Widget _buildList(List<dynamic> alerts) {
    if (alerts.isEmpty) return const Center(child: Text('Tidak ada data'));
    return ListView.builder(
      itemCount: alerts.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (ctx, i) {
        final a = alerts[i];
        final colors = {'AKTIF': Colors.red, 'DIPROSES': Colors.orange, 'SELESAI': Colors.green, 'DIBATALKAN': Colors.grey};
        return Card(
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertDetailScreen(alertId: a['id']))),
            leading: const Icon(Icons.warning_rounded, color: Color(0xFFD32F2F)),
            title: Text(a['title'] ?? ''),
            subtitle: Text(a['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Chip(
              label: Text(a['status'] ?? '', style: const TextStyle(fontSize: 11)),
              backgroundColor: (colors[a['status']] ?? Colors.grey).withOpacity(0.15),
            ),
          ),
        );
      },
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
          tabs: const [Tab(text: 'Aktif'), Tab(text: 'Riwayat')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController, children: [_buildList(_active), _buildList(_history)]),
    );
  }
}