import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/alert_service.dart';
import '../../services/auth_service.dart';

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
  Map<String, dynamic>? _currentUser;
  bool _loading = true;
  bool _actionLoading = false;
  Timer? _pollingTimer;

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

      final user = await AuthService.getUser();
      final res = await AlertService.getAlertDetail(widget.alertId);

      if (!mounted) return;

      setState(() {
        _currentUser = user == null ? null : Map<String, dynamic>.from(user);

        if (res['success'] == true) {
          _alert = Map<String, dynamic>.from(res['data']);
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      if (!silent) {
        _showSnack('Gagal memuat detail alert: $e');
      }
    }
  }

  bool get _isOwner {
    final reporterId = _alert?['user']?['id']?.toString();
    final currentId = _currentUser?['id']?.toString();

    return reporterId != null && currentId != null && reporterId == currentId;
  }

  Future<void> _respond(String status) async {
    try {
      final res = await AlertService.respondToAlert(widget.alertId, status);

      if (!mounted) return;

      _showSnack(
        res['success'] == true
            ? 'Respons terkirim. Pelapor dapat melihat bantuanmu.'
            : (res['message'] ?? 'Gagal mengirim respons'),
      );

      await _load(silent: true);
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _updateStatus(String status) async {
    if (!_isOwner) {
      _showSnack('Hanya pelapor yang dapat mengubah status alert ini.');
      return;
    }

    final confirm = await _confirmDialog(
      title: 'Ubah Status Alert',
      message: 'Yakin ingin mengubah status alert menjadi $status?',
      actionText: 'UBAH',
      danger: false,
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);

    try {
      final res = await AlertService.updateStatus(
        widget.alertId,
        status,
        note: 'Status diubah oleh pelapor',
      );

      if (!mounted) return;

      _showSnack(
        res['success'] == true
            ? 'Status alert berhasil diubah menjadi $status.'
            : (res['message'] ?? 'Gagal mengubah status'),
      );

      await _load(silent: true);
    } catch (e) {
      _showSnack('Error: $e');
    }

    if (mounted) {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _deleteAlert() async {
    if (!_isOwner) {
      _showSnack('Hanya pelapor yang dapat menghapus alert ini.');
      return;
    }

    final confirm = await _confirmDialog(
      title: 'Hapus Alert',
      message:
          'Yakin ingin menghapus alert ini? Data alert, respons warga, dan analisis AI terkait akan dihapus.',
      actionText: 'HAPUS',
      danger: true,
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);

    try {
      final res = await AlertService.deleteAlert(widget.alertId);

      if (!mounted) return;

      if (res['success'] == true) {
        _showSnack('Alert berhasil dihapus.');
        Navigator.pop(context);
      } else {
        _showSnack(res['message'] ?? 'Gagal menghapus alert');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }

    if (mounted) {
      setState(() => _actionLoading = false);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String actionText,
    required bool danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: NexusGuard.panel,
          title: Text(
            title,
            style: NexusGuard.orbitron(
              size: 16,
              color: danger ? NexusGuard.red : NexusGuard.cyan,
            ),
          ),
          content: Text(
            message,
            style: NexusGuard.rajdhani(color: NexusGuard.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'BATAL',
                style: NexusGuard.mono(color: NexusGuard.muted),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? NexusGuard.red : NexusGuard.cyan,
                foregroundColor: danger ? Colors.white : NexusGuard.bg,
              ),
              child: Text(actionText),
            ),
          ],
        );
      },
    );
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

  Color _riskColor(String risk) {
    switch (risk) {
      case 'RENDAH':
        return NexusGuard.green;
      case 'SEDANG':
        return NexusGuard.amber;
      case 'TINGGI':
        return Colors.deepOrange;
      case 'KRITIS':
        return NexusGuard.red;
      default:
        return NexusGuard.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: NexusGuard.bg,
        body: Center(
          child: CircularProgressIndicator(color: NexusGuard.cyan),
        ),
      );
    }

    if (_alert == null) {
      return Scaffold(
        backgroundColor: NexusGuard.bg,
        appBar: _appBar(),
        body: Center(
          child: Text(
            'Data alert tidak ditemukan',
            style: NexusGuard.rajdhani(),
          ),
        ),
      );
    }

    final alert = _alert!;
    final aiSummaries = alert['aiSummaries'] as List? ?? [];
    final ai = aiSummaries.isNotEmpty ? aiSummaries.first : null;
    final risk = _riskLevel(alert);
    final riskColor = _riskColor(risk);

    return Scaffold(
      backgroundColor: NexusGuard.bg,
      appBar: _appBar(),
      body: NexusBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          color: NexusGuard.cyan,
          backgroundColor: NexusGuard.panel,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hero(alert, risk, riskColor),
                    const SizedBox(height: 14),
                    if (_isOwner) _ownerCrudPanel(alert),
                    if (_isOwner) const SizedBox(height: 14),
                    _reporter(alert['user']),
                    const SizedBox(height: 14),
                    _coordinate(alert),
                    const SizedBox(height: 14),
                    if (ai != null) _aiAnalysis(ai, riskColor),
                    const SizedBox(height: 14),
                    _responsePanel(),
                    const SizedBox(height: 14),
                    _responders(alert),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: NexusGuard.bg.withValues(alpha: 0.96),
      elevation: 0,
      foregroundColor: NexusGuard.text,
      title: Text(
        'INCIDENT DETAIL',
        style: NexusGuard.orbitron(size: 16, color: NexusGuard.cyan),
      ),
    );
  }

  Widget _hero(Map<String, dynamic> alert, String risk, Color riskColor) {
    return NexusHudCard(
      glowColor: riskColor,
      active: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NexusBadge(
                text: alert['status']?.toString() ?? '-',
                color: NexusGuard.red,
                icon: Icons.warning_rounded,
              ),
              NexusBadge(text: 'RISK $risk', color: riskColor),
              NexusBadge(text: _categoryName(alert), color: NexusGuard.cyan),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            alert['title']?.toString() ?? 'ALERT',
            style: NexusGuard.orbitron(
              size: 26,
              color: NexusGuard.text,
              weight: FontWeight.w900,
              spacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            alert['description']?.toString() ?? '-',
            style: NexusGuard.rajdhani(
              size: 16,
              color: NexusGuard.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownerCrudPanel(Map<String, dynamic> alert) {
    final status = alert['status']?.toString() ?? '-';

    return NexusHudCard(
      glowColor: NexusGuard.amber,
      active: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'CRUD CONTROL PELAPOR',
            subtitle:
                'Panel ini hanya muncul untuk akun pelapor. Warga lain tidak bisa update atau hapus.',
            icon: Icons.admin_panel_settings_rounded,
            color: NexusGuard.amber,
          ),
          const SizedBox(height: 14),
          Text(
            'Status sekarang: $status',
            style: NexusGuard.rajdhani(
              color: NexusGuard.text,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _crudButton(
                label: 'DIPROSES',
                icon: Icons.sync_rounded,
                color: NexusGuard.cyan,
                onTap: _actionLoading ? null : () => _updateStatus('DIPROSES'),
              ),
              _crudButton(
                label: 'SELESAI',
                icon: Icons.check_circle_rounded,
                color: NexusGuard.green,
                onTap: _actionLoading ? null : () => _updateStatus('SELESAI'),
              ),
              _crudButton(
                label: 'DIBATALKAN',
                icon: Icons.cancel_rounded,
                color: NexusGuard.amber,
                onTap:
                    _actionLoading ? null : () => _updateStatus('DIBATALKAN'),
              ),
              _crudButton(
                label: 'HAPUS ALERT',
                icon: Icons.delete_forever_rounded,
                color: NexusGuard.red,
                onTap: _actionLoading ? null : _deleteAlert,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crudButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.55)),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: NexusGuard.mono(color: color)),
    );
  }

  Widget _reporter(dynamic user) {
    return NexusHudCard(
      glowColor: NexusGuard.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'PELAPOR ALERT',
            subtitle: 'Identitas warga yang mengirim laporan',
            icon: Icons.person_pin_circle_rounded,
            color: NexusGuard.cyan,
          ),
          const SizedBox(height: 14),
          _info('Nama', user?['name']?.toString() ?? '-'),
          _info('Role', user?['role']?.toString() ?? '-'),
          _info('No. HP', user?['phone']?.toString() ?? '-'),
          _info('Alamat', user?['address']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _coordinate(Map<String, dynamic> alert) {
    return NexusHudCard(
      glowColor: NexusGuard.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'OPENSTREETMAP COORDINATE',
            subtitle: 'Titik kejadian untuk ditampilkan pada peta',
            icon: Icons.map_rounded,
            color: NexusGuard.green,
          ),
          const SizedBox(height: 14),
          _info('Latitude', alert['latitude']?.toString() ?? '-'),
          _info('Longitude', alert['longitude']?.toString() ?? '-'),
          _info('Alamat', alert['address']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _aiAnalysis(dynamic ai, Color riskColor) {
    return NexusHudCard(
      glowColor: NexusGuard.purple,
      active: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'AI EMERGENCY ANALYSIS',
            subtitle: 'Ringkasan, tingkat risiko, dan panduan awal',
            icon: Icons.auto_awesome_rounded,
            color: NexusGuard.purple,
          ),
          const SizedBox(height: 14),
          NexusBadge(
            text: ai['riskLevel']?.toString() ?? '-',
            color: riskColor,
            icon: Icons.speed_rounded,
          ),
          const SizedBox(height: 14),
          Text(
            'RINGKASAN',
            style: NexusGuard.mono(color: NexusGuard.cyan),
          ),
          const SizedBox(height: 6),
          Text(
            ai['summary']?.toString() ?? '-',
            style: NexusGuard.rajdhani(size: 16, color: NexusGuard.text),
          ),
          const SizedBox(height: 14),
          Text(
            'PANDUAN AWAL',
            style: NexusGuard.mono(color: NexusGuard.green),
          ),
          const SizedBox(height: 6),
          Text(
            ai['recommendedAction']?.toString() ?? '-',
            style: NexusGuard.rajdhani(size: 16, color: NexusGuard.muted),
          ),
        ],
      ),
    );
  }

  Widget _responsePanel() {
    return NexusHudCard(
      glowColor: NexusGuard.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'RESPON ALERT',
            subtitle: 'Respons kamu akan terlihat oleh pelapor agar tidak panik',
            icon: Icons.groups_rounded,
            color: NexusGuard.red,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _responseButton(
                'SAYA_BISA_BANTU',
                'BISA BANTU',
                Icons.volunteer_activism_rounded,
              ),
              _responseButton(
                'MENUJU_LOKASI',
                'MENUJU LOKASI',
                Icons.directions_run_rounded,
              ),
              _responseButton(
                'SUDAH_DI_LOKASI',
                'SUDAH DI LOKASI',
                Icons.check_circle_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _responders(Map<String, dynamic> alert) {
    final responses = alert['responses'] as List? ?? [];

    return NexusHudCard(
      glowColor: NexusGuard.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexusSectionTitle(
            title: 'RESPONDER NETWORK',
            subtitle: 'Warga yang sudah merespons alert ini',
            icon: Icons.people_alt_rounded,
            color: NexusGuard.cyan,
          ),
          const SizedBox(height: 14),
          if (responses.isEmpty)
            Text(
              'Belum ada warga yang merespons alert ini.',
              style: NexusGuard.rajdhani(color: NexusGuard.muted),
            )
          else
            ...responses.map((response) {
              final user = response['user'];
              final status =
                  response['responseStatus']?.toString().replaceAll('_', ' ') ??
                      '-';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NexusGuard.bg.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: NexusGuard.cyan.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x2214B8A6),
                      child: Icon(Icons.person_rounded, color: NexusGuard.cyan),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?['name']?.toString() ?? 'Warga',
                            style: NexusGuard.rajdhani(
                              size: 17,
                              color: NexusGuard.text,
                              weight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${user?['role'] ?? '-'} • HP: ${user?['phone'] ?? '-'}',
                            style: NexusGuard.mono(size: 12),
                          ),
                        ],
                      ),
                    ),
                    NexusBadge(text: status, color: NexusGuard.green),
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
        backgroundColor: NexusGuard.red.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: NexusGuard.red.withValues(alpha: 0.65)),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: NexusGuard.mono(color: Colors.white)),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label.toUpperCase(),
              style: NexusGuard.mono(size: 12, color: NexusGuard.muted2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: NexusGuard.rajdhani(
                size: 16,
                color: NexusGuard.text,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
