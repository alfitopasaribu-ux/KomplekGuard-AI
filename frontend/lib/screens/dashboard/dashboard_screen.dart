import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
import '../ai/ai_chat_screen.dart';
import '../alerts/alert_detail_screen.dart';
import '../alerts/alert_list_screen.dart';
import '../alerts/create_alert_screen.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  List<dynamic> _activeAlerts = [];
  bool _loading = true;
  Timer? _pollingTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.97, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(silent: true);
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      if (!silent && mounted) setState(() => _loading = true);

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

      setState(() => _loading = false);

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat dashboard: $e')),
        );
      }
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

  void _openAiChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiChatScreen()),
    );
  }

  void _openAlertList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlertListScreen()),
    );
  }

  void _openDetail(dynamic alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(alertId: alert['id'].toString()),
      ),
    ).then((_) => _loadData(silent: true));
  }

  String _reporterName(dynamic alert) {
    final user = alert['user'];
    return user?['name']?.toString() ?? 'Tidak diketahui';
  }

  String _categoryName(dynamic alert) {
    final custom = alert['customCategory'];
    if (custom != null && custom.toString().trim().isNotEmpty) {
      return custom.toString();
    }

    final category = alert['category'];
    if (category != null && category['name'] != null) {
      return category['name'].toString();
    }

    return 'Alert';
  }

  String _riskLevel(dynamic alert) {
    final summaries = alert['aiSummaries'] as List? ?? [];
    if (summaries.isNotEmpty && summaries.first['riskLevel'] != null) {
      return summaries.first['riskLevel'].toString();
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
    final name = _user?['name']?.toString() ?? 'Warga';
    final activeCount = _activeAlerts.length;
    final responderCount = _activeAlerts.fold<int>(
      0,
      (value, alert) => value + ((alert['responses'] as List?)?.length ?? 0),
    );

    return Scaffold(
      backgroundColor: NexusGuard.bg,
      appBar: AppBar(
        backgroundColor: NexusGuard.bg.withValues(alpha: 0.96),
        elevation: 0,
        foregroundColor: NexusGuard.text,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KOMPLEKGUARD',
              style: NexusGuard.orbitron(
                size: 18,
                color: NexusGuard.cyan2,
                spacing: 2.2,
              ),
            ),
            Text(
              'AI EMERGENCY RESPONSE',
              style: NexusGuard.mono(size: 11, color: NexusGuard.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI Safety Chat',
            onPressed: _openAiChat,
            icon: const Icon(
              Icons.smart_toy_rounded,
              color: NexusGuard.purple,
            ),
          ),
          IconButton(
            tooltip: 'Tactical Map',
            onPressed: _openMap,
            icon: const Icon(Icons.map_rounded, color: NexusGuard.cyan),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: NexusGuard.red),
          ),
        ],
      ),
      body: NexusBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: NexusGuard.cyan),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: NexusGuard.cyan,
                backgroundColor: NexusGuard.panel,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _systemStatusBar(),
                          const SizedBox(height: 16),
                          _welcomePanel(name, activeCount, responderCount),
                          const SizedBox(height: 16),
                          ScaleTransition(
                            scale: _pulse,
                            child: NexusPrimaryButton(
                              text: 'AKTIFKAN MODE DARURAT',
                              icon: Icons.notification_important_rounded,
                              color: NexusGuard.red,
                              onPressed: _openCreateAlert,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_activeAlerts.isNotEmpty)
                            _activeIncidentPanel(_activeAlerts.first)
                          else
                            _safePanel(),
                          const SizedBox(height: 16),
                          _aiPanel(),
                          const SizedBox(height: 22),
                          _sectionHeader(),
                          const SizedBox(height: 12),
                          if (_activeAlerts.isEmpty)
                            _emptyPanel()
                          else
                            ..._activeAlerts.map(_incidentCard),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _systemStatusBar() {
    return NexusHudCard(
      glowColor: NexusGuard.green,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: NexusGuard.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NexusGuard.green,
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI AKTIF — GROQ EMERGENCY ANALYSIS ONLINE',
              style: NexusGuard.mono(color: NexusGuard.green, size: 13),
            ),
          ),
          Text(
            'v1.0',
            style: NexusGuard.mono(color: NexusGuard.cyan, size: 12),
          ),
        ],
      ),
    );
  }

  Widget _welcomePanel(String name, int activeCount, int responderCount) {
    return NexusHudCard(
      glowColor: NexusGuard.cyan,
      active: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELAMAT DATANG',
            style: NexusGuard.orbitron(
              size: 25,
              color: NexusGuard.cyan2,
              spacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name.toUpperCase(),
            style: NexusGuard.rajdhani(
              size: 22,
              color: NexusGuard.text,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Platform keamanan lingkungan berbasis AI. Pantau alert warga, lihat titik koordinat OpenStreetMap, dan koordinasikan responder secara cepat.',
            style: NexusGuard.rajdhani(
              size: 15,
              color: NexusGuard.muted,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  value: activeCount.toString(),
                  label: 'ALERT',
                  color: activeCount > 0 ? NexusGuard.red : NexusGuard.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  value: responderCount.toString(),
                  label: 'RESPONDER',
                  color: NexusGuard.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  value: activeCount > 0 ? 'ON' : 'SAFE',
                  label: 'STATUS',
                  color: activeCount > 0 ? NexusGuard.amber : NexusGuard.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: NexusGuard.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: NexusGuard.orbitron(
              size: 20,
              color: color,
              weight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: NexusGuard.mono(size: 11, color: NexusGuard.muted),
          ),
        ],
      ),
    );
  }

  Widget _safePanel() {
    return NexusHudCard(
      glowColor: NexusGuard.green,
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: NexusGuard.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AREA AMAN — tidak ada alert aktif. Sistem melakukan sinkronisasi setiap 10 detik.',
              style: NexusGuard.rajdhani(size: 15, color: NexusGuard.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeIncidentPanel(dynamic alert) {
    final risk = _riskLevel(alert);
    final riskColor = _riskColor(risk);

    return NexusHudCard(
      glowColor: NexusGuard.red,
      active: true,
      onTap: () => _openDetail(alert),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: NexusGuard.red.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NexusGuard.red.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: NexusGuard.red,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE INCIDENT DETECTED',
                  style: NexusGuard.mono(color: NexusGuard.red, size: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['title']?.toString() ?? '-',
                  style: NexusGuard.rajdhani(
                    size: 21,
                    color: NexusGuard.text,
                    weight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Pelapor: ${_reporterName(alert)} • Risk: $risk',
                  style: NexusGuard.rajdhani(
                    size: 14,
                    color: riskColor,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: NexusGuard.cyan),
        ],
      ),
    );
  }

  Widget _aiPanel() {
    return NexusHudCard(
      glowColor: NexusGuard.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: NexusGuard.purple.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: NexusGuard.purple.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: NexusGuard.purple,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI EMERGENCY ASSISTANT',
                      style: NexusGuard.orbitron(
                        size: 16,
                        color: NexusGuard.purple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI menganalisis laporan warga, menentukan risk level, membuat panduan tindakan awal, dan bisa diajak ngobrol tentang risiko keamanan lingkungan.',
                      style: NexusGuard.rajdhani(
                        size: 15,
                        color: NexusGuard.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openAiChat,
              icon: const Icon(Icons.smart_toy_rounded),
              label: Text(
                'BUKA AI SAFETY CHAT',
                style: NexusGuard.mono(
                  color: NexusGuard.bg,
                  size: 13,
                  weight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: NexusGuard.purple,
                foregroundColor: NexusGuard.bg,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'INCIDENT FEED',
            style: NexusGuard.orbitron(size: 18, color: NexusGuard.cyan),
          ),
        ),
        TextButton.icon(
          onPressed: _openAlertList,
          icon: const Icon(Icons.list_alt_rounded, color: NexusGuard.cyan),
          label: Text(
            'LIHAT SEMUA',
            style: NexusGuard.mono(color: NexusGuard.cyan),
          ),
        ),
      ],
    );
  }

  Widget _emptyPanel() {
    return NexusHudCard(
      glowColor: NexusGuard.green,
      child: Column(
        children: [
          const Icon(
            Icons.security_rounded,
            color: NexusGuard.green,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'NO ACTIVE INCIDENT',
            style: NexusGuard.orbitron(size: 16, color: NexusGuard.green),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada alert aktif di lingkungan saat ini.',
            textAlign: TextAlign.center,
            style: NexusGuard.rajdhani(color: NexusGuard.muted),
          ),
        ],
      ),
    );
  }

  Widget _incidentCard(dynamic alert) {
    final risk = _riskLevel(alert);
    final riskColor = _riskColor(risk);
    final responses = alert['responses'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NexusHudCard(
        glowColor: riskColor,
        onTap: () => _openDetail(alert),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: NexusGuard.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.report_rounded,
                color: NexusGuard.red,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const NexusBadge(text: 'AKTIF', color: NexusGuard.red),
                      NexusBadge(text: 'RISK $risk', color: riskColor),
                      NexusBadge(
                        text: _categoryName(alert),
                        color: NexusGuard.cyan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    alert['title']?.toString() ?? '-',
                    style: NexusGuard.rajdhani(
                      size: 20,
                      color: NexusGuard.text,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert['description']?.toString() ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusGuard.rajdhani(
                      size: 14,
                      color: NexusGuard.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pelapor: ${_reporterName(alert)} • Responder: ${responses.length} • ${alert['latitude']}, ${alert['longitude']}',
                    style: NexusGuard.mono(size: 12, color: NexusGuard.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: NexusGuard.cyan,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}