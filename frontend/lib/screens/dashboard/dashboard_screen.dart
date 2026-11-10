import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../ai/ai_chat_screen.dart';
import '../alerts/alert_detail_screen.dart';
import '../alerts/alert_list_screen.dart';
import '../alerts/create_alert_screen.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _activeAlerts = [];
  bool _loading = true;
  bool _hasLoaded = false;
  bool _refreshing = false;
  bool _requestInFlight = false;
  String? _loadError;
  DateTime? _lastUpdated;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_requestInFlight || !mounted) return;
    _requestInFlight = true;
    if (!silent) {
      setState(() {
        _loading = !_hasLoaded;
        _refreshing = _hasLoaded;
      });
    }
    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      setState(() => _user = user);
      final response = await AlertService.getActiveAlerts()
          .timeout(const Duration(seconds: 20));
      if (response['success'] != true || response['data'] is! List) {
        throw const FormatException('Daftar laporan belum tersedia.');
      }
      final data = response['data'] as List;
      if (data.any((item) => item is! Map)) {
        throw const FormatException('Format daftar laporan tidak sesuai.');
      }
      final alerts =
          data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      if (!mounted) return;
      setState(() {
        _activeAlerts = alerts;
        _hasLoaded = true;
        _loading = false;
        _refreshing = false;
        _loadError = null;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _loadError = _hasLoaded
            ? 'Pembaruan gagal. Laporan di bawah berasal dari sinkronisasi terakhir.'
            : 'Laporan belum dapat dimuat. Kondisi lingkungan belum dapat dipastikan dari aplikasi.';
      });
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push<void>(
        context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _loadData(silent: true);
  }

  void _openCreateAlert() => _openScreen(const CreateAlertScreen());
  void _openMap() => _openScreen(const MapScreen());
  void _openAiChat() => _openScreen(const AiChatScreen());
  void _openProfile() => _openScreen(const ProfileScreen());
  void _openAlertList() => _openScreen(const AlertListScreen());

  void _openDetail(Map<String, dynamic> alert) {
    final id = alert['id']?.toString();
    if (id == null || id.isEmpty) return;
    _openScreen(AlertDetailScreen(alertId: id));
  }

  void _openContacts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NexusGuard.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const FractionallySizedBox(
          heightFactor: 0.65, child: _EmergencyContactsSheet()),
    );
  }

  String get _firstName {
    final name = _user?['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Warga' : name.split(RegExp(r'\s+')).first;
  }

  int get _waitingCount =>
      _activeAlerts.where((alert) => alert['status'] == 'AKTIF').length;
  int get _responseCount => _activeAlerts.fold<int>(
        0,
        (total, alert) =>
            total +
            (alert['responses'] is List
                ? (alert['responses'] as List).length
                : 0),
      );

  String _categoryName(Map<String, dynamic> alert) {
    final custom = alert['customCategory']?.toString().trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final category = alert['category'];
    if (category is Map) {
      final name = category['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Laporan warga';
  }

  String? _riskLevel(Map<String, dynamic> alert) {
    final summaries = alert['aiSummaries'];
    if (summaries is List && summaries.isNotEmpty && summaries.first is Map) {
      final risk = summaries.first['riskLevel']?.toString();
      if (risk != null && risk.isNotEmpty) return risk;
    }
    return alert['riskLevel']?.toString();
  }

  String _riskLabel(String? risk) {
    switch (risk) {
      case 'RENDAH':
        return 'Rendah';
      case 'SEDANG':
        return 'Sedang';
      case 'TINGGI':
        return 'Tinggi';
      case 'KRITIS':
        return 'Kritis';
      default:
        return 'Menunggu AI';
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'TINGGI':
      case 'KRITIS':
        return NexusGuard.red;
      case 'SEDANG':
        return NexusGuard.amber;
      case 'RENDAH':
        return NexusGuard.emerald;
      default:
        return NexusGuard.muted;
    }
  }

  String _timeLabel(Map<String, dynamic> alert) {
    final date = DateTime.tryParse(alert['createdAt']?.toString() ?? '');
    if (date == null) return 'Waktu belum tersedia';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inMinutes < 60) return '${difference.inMinutes} menit lalu';
    if (difference.inHours < 24) return '${difference.inHours} jam lalu';
    if (difference.inDays < 7) return '${difference.inDays} hari lalu';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  TextStyle _text(
          {double size = 14,
          FontWeight weight = FontWeight.w500,
          Color? color,
          double height = 1.4}) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color ?? NexusGuard.slate,
        height: height,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      return Scaffold(
        key: const ValueKey('dashboard-screen'),
        backgroundColor: NexusGuard.slate,
        appBar: _header(desktop),
        bottomNavigationBar: _bottomNavigation(),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: NexusGuard.ivory,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: RefreshIndicator(
            onRefresh: () => _loadData(),
            color: NexusGuard.emerald,
            child: SingleChildScrollView(
              key: const ValueKey('dashboard-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  desktop ? 32 : 16, desktop ? 28 : 12, desktop ? 32 : 16, 26),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _welcomeCard(desktop),
                      const SizedBox(height: 14),
                      _quickActions(desktop),
                      const SizedBox(height: 18),
                      _statistics(),
                      const SizedBox(height: 18),
                      if (_loadError != null) ...[
                        _errorNotice(),
                        const SizedBox(height: 16)
                      ],
                      if (_refreshing) ...[
                        const LinearProgressIndicator(
                            key: ValueKey('dashboard-refreshing'),
                            minHeight: 2,
                            color: NexusGuard.emerald),
                        const SizedBox(height: 12),
                      ],
                      _reportsHeader(),
                      const SizedBox(height: 10),
                      _reportContent(),
                      const SizedBox(height: 14),
                      _syncFooter(),
                    ]),
              )),
            ),
          ),
        ),
      );
    });
  }

  PreferredSizeWidget _header(bool desktop) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: NexusGuard.slate,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: desktop ? 86 : 76,
      titleSpacing: desktop ? 32 : 18,
      title: Row(children: [
        Container(
          width: 38,
          height: 42,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.shield_outlined,
              color: NexusGuard.emerald, size: 29),
        ),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('KomplekGuard AI',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(
                  size: desktop ? 21 : 17,
                  weight: FontWeight.w800,
                  color: Colors.white)),
          Text('Keamanan Lingkungan Bersama',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(
                  size: desktop ? 12 : 10, color: const Color(0xFFD5E7E0))),
        ])),
      ]),
      actions: [
        IconButton(
            key: const ValueKey('dashboard-header-reports'),
            tooltip: 'Buka daftar laporan',
            onPressed: _openAlertList,
            icon: const Icon(Icons.notifications_none_rounded)),
        PopupMenuButton<String>(
          key: const ValueKey('dashboard-account-menu'),
          tooltip: 'Menu akun',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'profile') _openProfile();
            if (value == 'logout') _logout();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_outline_rounded),
                    title: Text('Profil saya'))),
            const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout_rounded),
                    title: Text('Keluar'))),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _welcomeCard(bool desktop) {
    return Container(
      key: const ValueKey('dashboard-welcome'),
      constraints: BoxConstraints(minHeight: desktop ? 225 : 178),
      decoration: BoxDecoration(
          color: const Color(0xFFE0F0E9),
          borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
          builder: (context, constraints) => Stack(children: [
                const Positioned.fill(
                    child: ExcludeSemantics(
                        child: CustomPaint(painter: _NeighborhoodPainter()))),
                Padding(
                  padding: EdgeInsets.all(desktop ? 30 : 20),
                  child: SizedBox(
                    width: constraints.maxWidth * (desktop ? 0.55 : 0.64),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Selamat datang,\n$_firstName',
                              key: const ValueKey('dashboard-greeting'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: _text(
                                  size: desktop ? 33 : 22,
                                  weight: FontWeight.w800,
                                  height: 1.2)),
                          const SizedBox(height: 11),
                          Text(
                              'Pantau kondisi lingkungan, kirim laporan, dan bantu warga di sekitar Anda.',
                              style:
                                  _text(size: desktop ? 15 : 12, height: 1.65)),
                        ]),
                  ),
                ),
              ])),
    );
  }

  Widget _quickActions(bool desktop) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: _quickAction(
              actionKey: 'dashboard-create-alert',
              label: 'Buat\nLaporan',
              icon: Icons.notification_important_outlined,
              onTap: _openCreateAlert,
              primary: true,
              desktop: desktop)),
      const SizedBox(width: 9),
      Expanded(
          child: _quickAction(
              actionKey: 'dashboard-open-map',
              label: 'Peta\nKejadian',
              icon: Icons.location_on_rounded,
              onTap: _openMap,
              desktop: desktop)),
      const SizedBox(width: 9),
      Expanded(
          child: _quickAction(
              actionKey: 'dashboard-open-assistant',
              label: 'Asisten\nAI',
              icon: Icons.smart_toy_outlined,
              onTap: _openAiChat,
              desktop: desktop)),
      const SizedBox(width: 9),
      Expanded(
          child: _quickAction(
              actionKey: 'dashboard-open-contacts',
              label: 'Kontak\nDarurat',
              icon: Icons.phone_rounded,
              onTap: _openContacts,
              desktop: desktop)),
    ]);
  }

  Widget _quickAction(
      {required String actionKey,
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      required bool desktop,
      bool primary = false}) {
    final foreground = primary ? Colors.white : NexusGuard.slate;
    return Semantics(
        button: true,
        label: label.replaceAll('\n', ' '),
        child: Material(
          color: primary ? NexusGuard.red : NexusGuard.panel,
          elevation: primary ? 2 : 0,
          shadowColor: NexusGuard.red.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(
                  color: primary ? NexusGuard.red : NexusGuard.border)),
          child: InkWell(
            key: ValueKey(actionKey),
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 4, vertical: desktop ? 20 : 14),
                child: Column(children: [
                  Icon(icon,
                      size: desktop ? 31 : 27,
                      color: primary ? Colors.white : NexusGuard.emerald),
                  const SizedBox(height: 9),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: _text(
                          size: desktop ? 14 : 11,
                          weight: FontWeight.w700,
                          color: foreground,
                          height: 1.35)),
                ])),
          ),
        ));
  }

  Widget _statistics() {
    return Container(
      decoration: BoxDecoration(
          color: NexusGuard.panel,
          border: Border.all(color: NexusGuard.border),
          borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: IntrinsicHeight(
          child: Row(children: [
        _stat('dashboard-active-count', _activeAlerts.length, 'Laporan aktif',
            NexusGuard.emerald),
        const VerticalDivider(width: 1),
        _stat('dashboard-waiting-count', _waitingCount, 'Menunggu respons',
            NexusGuard.amber),
        const VerticalDivider(width: 1),
        _stat('dashboard-response-count', _responseCount, 'Respons warga',
            NexusGuard.emerald),
      ])),
    );
  }

  Widget _stat(String key, int value, String label, Color color) {
    return Expanded(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(children: [
        Text(_hasLoaded ? value.toString() : '—',
            key: ValueKey(key),
            style: _text(
                size: 23, weight: FontWeight.w800, color: color, height: 1.2)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: _text(size: 10, color: NexusGuard.muted)),
      ]),
    ));
  }

  Widget _errorNotice() {
    return Container(
      key: const ValueKey('dashboard-error'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: NexusGuard.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NexusGuard.amber.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.cloud_off_outlined,
              size: 20, color: NexusGuard.slate),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_loadError!, style: _text(size: 13, height: 1.55))),
        ]),
        const SizedBox(height: 8),
        TextButton.icon(
            key: const ValueKey('dashboard-retry'),
            onPressed: _loading || _refreshing ? null : () => _loadData(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi')),
      ]),
    );
  }

  Widget _reportsHeader() {
    return Row(children: [
      Expanded(
          child: Text('Laporan Terbaru',
              style: _text(size: 19, weight: FontWeight.w800))),
      TextButton(
          key: const ValueKey('dashboard-all-alerts'),
          onPressed: _openAlertList,
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Lihat Semua',
                style: _text(
                    size: 11,
                    weight: FontWeight.w700,
                    color: NexusGuard.emerald)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ])),
    ]);
  }

  Widget _reportContent() {
    if (_loading) {
      return _stateCard(
          stateKey: 'dashboard-loading',
          icon: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: NexusGuard.emerald)),
          title: 'Memuat laporan lingkungan',
          message: 'Mengambil informasi terbaru untuk Anda.');
    }
    if (!_hasLoaded) {
      return _stateCard(
          stateKey: 'dashboard-unavailable',
          icon: const Icon(Icons.wifi_off_rounded,
              size: 29, color: NexusGuard.muted),
          title: 'Data laporan belum tersedia',
          message: 'Gunakan tombol Coba lagi untuk memperbarui data.');
    }
    if (_activeAlerts.isEmpty) {
      return _stateCard(
          stateKey: 'dashboard-empty',
          icon: const Icon(Icons.fact_check_outlined,
              size: 30, color: NexusGuard.emerald),
          title: _loadError == null
              ? 'Belum ada laporan aktif'
              : 'Data terakhir: tidak ada laporan aktif',
          message: _loadError == null
              ? 'Laporan warga akan muncul di sini ketika tersedia.'
              : 'Pembaruan belum berhasil. Status terkini belum dapat dipastikan.');
    }
    return Column(key: const ValueKey('dashboard-alert-list'), children: [
      for (final alert in _activeAlerts) ...[
        _incidentCard(alert),
        const SizedBox(height: 10)
      ],
    ]);
  }

  Widget _stateCard(
      {required String stateKey,
      required Widget icon,
      required String title,
      required String message}) {
    return Container(
      key: ValueKey(stateKey),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
      decoration: BoxDecoration(
          color: NexusGuard.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NexusGuard.border)),
      child: Column(children: [
        icon,
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: _text(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(message,
            textAlign: TextAlign.center,
            style: _text(size: 12, color: NexusGuard.muted)),
      ]),
    );
  }

  Widget _incidentCard(Map<String, dynamic> alert) {
    final risk = _riskLevel(alert);
    final color = _riskColor(risk);
    final title = alert['title']?.toString().trim() ?? '';
    final status = alert['status'] == 'DIPROSES' ? 'Diproses' : 'Aktif';
    final reporter = alert['user'];
    final reporterName =
        reporter is Map ? reporter['name']?.toString().trim() ?? '' : '';
    final responses = alert['responses'];
    final responseCount = responses is List ? responses.length : 0;
    return Material(
      color: NexusGuard.panel,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: NexusGuard.border)),
      child: InkWell(
        key: ValueKey('dashboard-alert-${alert['id']}'),
        onTap: () => _openDetail(alert),
        borderRadius: BorderRadius.circular(17),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _thumbnail(alert),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title.isEmpty ? 'Laporan tanpa judul' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _text(
                            size: 14, weight: FontWeight.w700, height: 1.35)),
                    const SizedBox(height: 5),
                    Text(_categoryName(alert),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(size: 11, color: NexusGuard.muted)),
                    const SizedBox(height: 2),
                    Text(
                        'Pelapor: ${reporterName.isEmpty ? 'Belum tersedia' : reporterName} · $responseCount respons',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _text(size: 10, color: NexusGuard.muted)),
                    const SizedBox(height: 2),
                    Text('${_timeLabel(alert)} · $status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(size: 10, color: NexusGuard.muted)),
                  ])),
              const SizedBox(width: 8),
              Tooltip(
                message: risk == null
                    ? 'Analisis risiko belum tersedia'
                    : 'Tingkat risiko: ${_riskLabel(risk)}',
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 79),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(_riskLabel(risk),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: _text(
                              size: 10,
                              weight: FontWeight.w700,
                              color: color,
                              height: 1.3)),
                    )),
              ),
            ])),
      ),
    );
  }

  Widget _thumbnail(Map<String, dynamic> alert) {
    final photo =
        (alert['photoUrl'] ?? alert['image'])?.toString().trim() ?? '';
    final placeholder = Container(
        color: const Color(0xFFE8F1EC),
        alignment: Alignment.center,
        child: const Icon(Icons.description_outlined,
            size: 27, color: NexusGuard.emerald));
    Widget image = placeholder;
    try {
      if (photo.startsWith('data:image/')) {
        final bytes = Uri.parse(photo).data?.contentAsBytes();
        if (bytes != null) {
          image = Image.memory(bytes,
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (_, __, ___) => placeholder);
        }
      } else if (photo.startsWith('https://') || photo.startsWith('http://')) {
        image = Image.network(photo,
            fit: BoxFit.cover,
            cacheWidth: 160,
            errorBuilder: (_, __, ___) => placeholder);
      }
    } catch (_) {
      image = placeholder;
    }
    return Semantics(
        image: true,
        label: photo.isEmpty ? 'Laporan tanpa foto' : 'Foto laporan',
        child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(width: 58, height: 65, child: image)));
  }

  Widget _syncFooter() {
    final lastUpdated = _lastUpdated;
    final message = _loading
        ? 'Sedang menyinkronkan laporan'
        : _loadError != null
            ? 'Sinkronisasi belum berhasil'
            : lastUpdated == null
                ? 'Belum tersinkron'
                : 'Diperbarui ${TimeOfDay.fromDateTime(lastUpdated).format(context)} · Otomatis setiap 10 detik';
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_loadError == null ? Icons.sync_rounded : Icons.sync_problem_rounded,
          size: 14, color: NexusGuard.muted),
      const SizedBox(width: 6),
      Flexible(
          child: Text(message,
              textAlign: TextAlign.center,
              style: _text(size: 10, color: NexusGuard.muted))),
      IconButton(
          key: const ValueKey('dashboard-refresh'),
          tooltip: 'Perbarui laporan',
          visualDensity: VisualDensity.compact,
          onPressed: _loading || _refreshing ? null : () => _loadData(),
          icon: const Icon(Icons.refresh_rounded, size: 17)),
    ]);
  }

  Widget _bottomNavigation() {
    final scaledLabelSize = MediaQuery.textScalerOf(context).scale(10);
    final extraHeight =
        scaledLabelSize > 10 ? (scaledLabelSize - 10) * 1.4 : 0.0;
    return Material(
      color: NexusGuard.panel,
      elevation: 8,
      shadowColor: NexusGuard.slate.withValues(alpha: 0.12),
      child: SafeArea(
          top: false,
          child: SizedBox(
              height: 74.0 + extraHeight,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Row(children: [
                  _navItem('dashboard-nav-home', 'Beranda', Icons.home_rounded,
                      () {},
                      selected: true),
                  _navItem('dashboard-nav-map', 'Peta', Icons.map_outlined,
                      _openMap),
                  Expanded(
                      child: Center(
                          child: Tooltip(
                              message: 'Buat laporan',
                              child: Material(
                                color: NexusGuard.emerald,
                                elevation: 2,
                                shadowColor:
                                    NexusGuard.emerald.withValues(alpha: 0.25),
                                shape: const CircleBorder(),
                                child: InkWell(
                                    key: const ValueKey('dashboard-nav-create'),
                                    onTap: _openCreateAlert,
                                    customBorder: const CircleBorder(),
                                    child: const SizedBox(
                                        width: 51,
                                        height: 51,
                                        child: Icon(Icons.add_rounded,
                                            size: 31, color: Colors.white))),
                              )))),
                  _navItem('dashboard-nav-alerts', 'Laporan',
                      Icons.assignment_outlined, _openAlertList),
                  _navItem('dashboard-nav-profile', 'Profil',
                      Icons.person_outline_rounded, _openProfile),
                ]),
              )))),
    );
  }

  Widget _navItem(String key, String label, IconData icon, VoidCallback onTap,
      {bool selected = false}) {
    final color = selected ? NexusGuard.emerald : NexusGuard.slate;
    return Expanded(
        child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _text(
                      size: 10,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color)),
            ])),
      ),
    ));
  }
}

class _EmergencyContactsSheet extends StatefulWidget {
  const _EmergencyContactsSheet();
  @override
  State<_EmergencyContactsSheet> createState() =>
      _EmergencyContactsSheetState();
}

class _EmergencyContactsSheetState extends State<_EmergencyContactsSheet> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await ApiService.get('/emergency-contacts')
          .timeout(const Duration(seconds: 20));
      if (response['success'] != true || response['data'] is! List) {
        throw const FormatException('Kontak darurat belum tersedia.');
      }
      final contacts = (response['data'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text('Kontak Darurat',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Tutup kontak',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 6),
            Text(
                'Nomor layanan yang terdaftar. Salin nomor untuk menghubungi melalui telepon.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: NexusGuard.muted)),
            const SizedBox(height: 16),
            Expanded(child: _content()),
          ]),
        ));
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, color: NexusGuard.muted, size: 30),
        const SizedBox(height: 12),
        const Text('Kontak darurat belum dapat dimuat.',
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi')),
      ]));
    }
    if (_contacts.isEmpty) {
      return const Center(
          child: Text('Belum ada kontak darurat yang terdaftar.',
              textAlign: TextAlign.center));
    }
    return ListView.separated(
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final phone = contact['phone']?.toString().trim() ?? '';
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.phone_outlined, color: NexusGuard.emerald)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(contact['name']?.toString() ?? 'Layanan darurat',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 5),
                SelectableText(phone.isEmpty ? 'Nomor belum tersedia' : phone),
                if (contact['description']?.toString().trim().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 4),
                  Text(contact['description'].toString(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ])),
          if (phone.isNotEmpty)
            IconButton(
                tooltip: 'Salin nomor',
                icon: const Icon(Icons.copy_outlined, size: 19),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: phone));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor telepon disalin')));
                }),
        ]);
      },
    );
  }
}

class _NeighborhoodPainter extends CustomPainter {
  const _NeighborhoodPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * 0.5, 0);
    final width = size.width * 0.5;
    final height = size.height;
    final distantHill = Path()
      ..moveTo(-width * 0.18, height)
      ..quadraticBezierTo(
          width * 0.26, height * 0.36, width * 0.78, height * 0.43)
      ..quadraticBezierTo(width * 1.1, height * 0.28, width * 1.2, height * 0.5)
      ..lineTo(width * 1.2, height)
      ..close();
    canvas.drawPath(distantHill, Paint()..color = const Color(0xFFBDD9BC));

    void tree(double x, double y, double radius, Color color) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 2.5, y, 5, radius * 1.8),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFF74937A));
      final foliage = Paint()..color = color;
      canvas.drawCircle(Offset(x, y - radius * 0.44), radius, foliage);
      canvas.drawCircle(
          Offset(x - radius * 0.57, y + radius * 0.12), radius * 0.75, foliage);
      canvas.drawCircle(
          Offset(x + radius * 0.59, y + radius * 0.12), radius * 0.8, foliage);
    }

    tree(width * 0.8, height * 0.37, height * 0.12, const Color(0xFF9ABE8D));
    tree(width * 0.51, height * 0.5, height * 0.14, const Color(0xFF80AC77));
    tree(width * 1.01, height * 0.52, height * 0.17, const Color(0xFF719B73));

    void house(
        double x, double y, double houseWidth, double houseHeight, Color roof) {
      final wall = Rect.fromLTWH(x, y, houseWidth, houseHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(wall, const Radius.circular(2)),
          Paint()..color = const Color(0xFFFAF7E9));
      canvas.drawRect(
          Rect.fromLTWH(x + houseWidth * 0.7, y, houseWidth * 0.3, houseHeight),
          Paint()..color = const Color(0xFFE1E4D5));
      final roofPath = Path()
        ..moveTo(x - houseWidth * 0.08, y + 2)
        ..lineTo(x + houseWidth * 0.5, y - houseHeight * 0.48)
        ..lineTo(x + houseWidth * 1.08, y + 2)
        ..close();
      canvas.drawPath(roofPath, Paint()..color = roof);
      canvas.drawRect(
          Rect.fromLTWH(x + houseWidth * 0.41, y + houseHeight * 0.54,
              houseWidth * 0.2, houseHeight * 0.46),
          Paint()..color = const Color(0xFF9A9F83));
      final windowPaint = Paint()..color = const Color(0xFF82ACA5);
      canvas.drawRect(
          Rect.fromLTWH(x + houseWidth * 0.15, y + houseHeight * 0.2,
              houseWidth * 0.18, houseHeight * 0.23),
          windowPaint);
      canvas.drawRect(
          Rect.fromLTWH(x + houseWidth * 0.67, y + houseHeight * 0.2,
              houseWidth * 0.15, houseHeight * 0.23),
          windowPaint);
    }

    house(width * 0.71, height * 0.48, width * 0.23, height * 0.24,
        const Color(0xFF78928B));
    house(width * 0.48, height * 0.6, width * 0.3, height * 0.29,
        const Color(0xFF4E706A));
    house(width * 0.24, height * 0.7, width * 0.22, height * 0.21,
        const Color(0xFF8E9A83));

    final foreground = Path()
      ..moveTo(-width * 0.15, height)
      ..quadraticBezierTo(width * 0.36, height * 0.82, width, height * 0.88)
      ..lineTo(width * 1.1, height)
      ..close();
    canvas.drawPath(foreground, Paint()..color = const Color(0xFFA7C68D));
    final road = Path()
      ..moveTo(width * 0.47, height)
      ..quadraticBezierTo(
          width * 0.73, height * 0.87, width * 0.66, height * 0.83)
      ..lineTo(width * 0.73, height * 0.84)
      ..quadraticBezierTo(width * 0.86, height * 0.9, width * 0.77, height)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFFE2E7CA));
    tree(width * 0.91, height * 0.83, height * 0.055, const Color(0xFF65946E));
    tree(width * 0.14, height * 0.88, height * 0.05, const Color(0xFF78A77D));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
