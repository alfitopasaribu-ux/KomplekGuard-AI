import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
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
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  List<dynamic> _activeAlerts = [];
  bool _loading = true;
  Timer? _pollingTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const Color darkNavy = Color(0xFF0F172A);
  static const Color navy2 = Color(0xFF1E293B);
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color softBg = Color(0xFFF8FAFC);
  static const Color textGray = Color(0xFF64748B);
  static const Color teal = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
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
      if (!silent && mounted) {
        setState(() => _loading = true);
      }

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

  Color _statusColor(String? status) {
    switch (status) {
      case 'AKTIF':
        return emergencyRed;
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

  Color _riskColor(String? risk) {
    switch (risk) {
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

  String _categoryName(dynamic alert) {
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

  String _riskLevel(dynamic alert) {
    final summaries = alert['aiSummaries'] as List? ?? [];
    if (summaries.isNotEmpty && summaries.first['riskLevel'] != null) {
      return summaries.first['riskLevel'].toString();
    }

    return alert['riskLevel']?.toString() ?? '-';
  }

  String _reporterName(dynamic alert) {
    final user = alert['user'];
    if (user != null && user['name'] != null) return user['name'].toString();
    return 'Tidak diketahui';
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['name'] ?? 'Warga';

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: darkNavy,
        foregroundColor: Colors.white,
        title: const Text(
          'KomplekGuard AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Peta Alert',
            onPressed: _openMap,
            icon: const Icon(Icons.map_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heroHeader(name),
                        const SizedBox(height: 18),
                        _emergencyButton(),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: _activeAlerts.isEmpty
                              ? _safeStatusCard()
                              : _dangerBanner(_activeAlerts.first),
                        ),
                        const SizedBox(height: 18),
                        _aiAssistantCard(),
                        const SizedBox(height: 22),
                        _sectionHeader(),
                        const SizedBox(height: 12),
                        if (_activeAlerts.isEmpty)
                          _emptyState()
                        else
                          ..._activeAlerts.map((alert) => _alertCard(alert)),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _heroHeader(String name) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
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
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, $name 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pantau keamanan lingkungan, kirim alert, dan koordinasi warga dengan bantuan AI.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyButton() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 66,
        child: ElevatedButton.icon(
          onPressed: _openCreateAlert,
          style: ElevatedButton.styleFrom(
            backgroundColor: emergencyRed,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: emergencyRed.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: const Icon(Icons.notification_important_rounded, size: 28),
          label: const Text(
            'KIRIM ALERT DARURAT',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _safeStatusCard() {
    return _glassCard(
      // ignore: prefer_const_constructors
      child: Row(
        // ignore: prefer_const_literals_to_create_immutables
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.green,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lingkungan Aman',
                  style: TextStyle(
                    color: darkNavy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tidak ada alert aktif saat ini. Sistem tetap memantau setiap 10 detik.',
                  style: TextStyle(color: textGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerBanner(dynamic alert) {
    final risk = _riskLevel(alert);
    final riskColor = _riskColor(risk);

    return Container(
      key: const ValueKey('danger'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEBEE), Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: emergencyRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: emergencyRed.withValues(alpha: 0.12),
            child: const Icon(
              Icons.warning_rounded,
              color: emergencyRed,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADA ALERT AKTIF!',
                  style: TextStyle(
                    color: emergencyRed,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['title']?.toString() ?? '-',
                  style: const TextStyle(
                    color: darkNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pelapor: ${_reporterName(alert)} • Risk: $risk',
                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openDetail(alert),
            child: const Text('Lihat'),
          ),
        ],
      ),
    );
  }

  Widget _aiAssistantCard() {
    return _glassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.purple,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Emergency Assistant',
                  style: TextStyle(
                    color: darkNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Setiap alert dianalisis AI untuk membuat ringkasan, menentukan tingkat risiko, dan memberi panduan tindakan awal yang aman.',
                  style: TextStyle(
                    color: textGray,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Alert Terkini',
          style: TextStyle(
            color: darkNavy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextButton.icon(
          onPressed: _openAlertList,
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('Lihat Semua'),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return _glassCard(
      child: const Column(
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.green, size: 48),
          SizedBox(height: 12),
          Text(
            'Belum ada alert aktif',
            style: TextStyle(
              color: darkNavy,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Jika ada kejadian darurat, tekan tombol Kirim Alert Darurat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textGray),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(dynamic alert) {
    final status = alert['status']?.toString() ?? '-';
    final statusColor = _statusColor(status);
    final risk = _riskLevel(alert);
    final riskColor = _riskColor(risk);
    final responses = alert['responses'] as List? ?? [];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _openDetail(alert),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: emergencyRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: emergencyRed,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip(status, statusColor),
                        _chip('Risk $risk', riskColor),
                        _chip(_categoryName(alert), teal),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      alert['title']?.toString() ?? '-',
                      style: const TextStyle(
                        color: darkNavy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert['description']?.toString() ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textGray),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pelapor: ${_reporterName(alert)} • Responder: ${responses.length}',
                      style: const TextStyle(
                        color: darkNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: textGray),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
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

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}