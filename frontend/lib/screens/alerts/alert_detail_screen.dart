import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/nexus_guard_theme.dart';
import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
import '../map/map_screen.dart';

class AlertDetailScreen extends StatefulWidget {
  final String alertId;

  const AlertDetailScreen({super.key, required this.alertId});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

enum _DetailAction { response, status, delete }

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  static const _timeout = Duration(seconds: 20);
  static const _statuses = ['AKTIF', 'DIPROSES', 'SELESAI', 'DIBATALKAN'];
  static const _responseStatuses = [
    'SAYA_BISA_BANTU',
    'MENUJU_LOKASI',
    'SUDAH_DI_LOKASI'
  ];

  final _responseNote = TextEditingController();
  Map<String, dynamic>? _alert;
  Map<String, dynamic>? _currentUser;
  bool _loading = true;
  bool _loadInFlight = false;
  bool _refreshing = false;
  bool _actionLoading = false;
  bool _confirming = false;
  bool _selectingStatus = false;
  String? _loadError;
  String? _actionError;
  _DetailAction? _retryAction;
  String? _retryStatus;
  Timer? _pollingTimer;

  bool get _busy =>
      _loadInFlight || _actionLoading || _confirming || _selectingStatus;
  bool get _canInteract =>
      _alert != null && _loadError == null && _id(_currentUser?['id']) != null;

  @override
  void initState() {
    super.initState();
    _load();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_busy && ModalRoute.of(context)?.isCurrent != false) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _responseNote.dispose();
    super.dispose();
  }

  String? _id(dynamic value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  bool _belongsToCurrentUser(Map<String, dynamic> item) {
    final currentId = _id(_currentUser?['id']);
    final user = item['user'];
    final nestedId = user is Map ? _id(user['id']) : null;
    final directId = _id(item['userId']);
    if (currentId == null || (directId == null && nestedId == null)) {
      return false;
    }
    return (directId == null || directId == currentId) &&
        (nestedId == null || nestedId == currentId);
  }

  bool get _isOwner => _alert != null && _belongsToCurrentUser(_alert!);

  List<Map<String, dynamic>> get _responses {
    final responses = _alert?['responses'];
    if (responses is! List) return [];
    return responses
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? get _latestOwnResponse {
    Map<String, dynamic>? latest;
    for (final response in _responses.where(_belongsToCurrentUser)) {
      final candidateTime =
          DateTime.tryParse(response['createdAt']?.toString() ?? '');
      final latestTime =
          DateTime.tryParse(latest?['createdAt']?.toString() ?? '');
      if (latest == null ||
          (candidateTime != null &&
              (latestTime == null || candidateTime.isAfter(latestTime)))) {
        latest = response;
      }
    }
    return latest;
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadInFlight || !mounted) return;
    _loadInFlight = true;

    setState(() {
      if (!silent) {
        _loading = _alert == null;
        _refreshing = _alert != null;
      }
    });

    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      setState(() => _currentUser = user);

      final response =
          await AlertService.getAlertDetail(widget.alertId).timeout(_timeout);

      if (response['success'] != true) {
        throw _DetailFailure(
            _message(response, 'Detail laporan belum dapat dimuat.'));
      }

      if (response['data'] is! Map) {
        throw const _DetailFailure('Data detail laporan belum tersedia.');
      }

      final alert = Map<String, dynamic>.from(response['data'] as Map);
      if (!mounted) return;

      setState(() {
        _alert = alert;
        _loadError = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _loadError = _failureMessage(error,
            'Detail laporan belum dapat dimuat. Periksa koneksi lalu coba lagi.');
      });
    } finally {
      _loadInFlight = false;
      if (mounted) setState(() {});
    }
  }

  String _message(Map<String, dynamic> response, String fallback) {
    final message = response['message']?.toString().trim() ?? '';
    return message.isEmpty ? fallback : message;
  }

  String _failureMessage(Object error, String fallback) {
    if (error is _DetailFailure) return error.message;
    if (error is TimeoutException) {
      return 'Waktu koneksi habis. Periksa koneksi lalu coba lagi.';
    }
    return fallback;
  }

  void _failedAction(_DetailAction action, String? status, String message) {
    if (!mounted) return;
    setState(() {
      _actionError = message;
      _retryAction = action;
      _retryStatus = status;
    });
  }

  Future<void> _respond(String status) async {
    if (_busy || !_canInteract || !_responseStatuses.contains(status)) return;
    setState(() {
      _actionLoading = true;
      _actionError = null;
    });
    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      setState(() => _currentUser = user);
      if (_id(user?['id']) == null) {
        throw const _DetailFailure(
            'Akun Anda belum tersedia. Muat ulang detail sebelum merespons.');
      }
      final note = _responseNote.text.trim();
      final response = await AlertService.respondToAlert(
        widget.alertId,
        status,
        note: note.isEmpty ? null : note,
      ).timeout(_timeout);
      if (!mounted) return;
      if (response['success'] != true) {
        throw _DetailFailure(
            _message(response, 'Respons belum berhasil dikirim.'));
      }
      _responseNote.clear();
      setState(() {
        _retryAction = null;
        _retryStatus = null;
      });
      _showSnack('Respons terkirim. Pelapor dapat melihat bantuan Anda.');
      await _load(silent: true);
    } catch (error) {
      _failedAction(
          _DetailAction.response,
          status,
          _failureMessage(
              error, 'Respons belum berhasil dikirim. Silakan coba lagi.'));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _selectStatus() async {
    if (_busy || !_canInteract || !_isOwner) return;
    setState(() => _selectingStatus = true);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: SingleChildScrollView(
              child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Ubah status laporan',
                      style: Theme.of(context).textTheme.titleLarge)),
              for (final status in _statuses)
                ListTile(
                  key: ValueKey('detail-status-option-$status'),
                  title: Text(_statusLabel(status)),
                  leading:
                      Icon(_statusIcon(status), color: _statusColor(status)),
                  trailing: _alert?['status'] == status
                      ? const Icon(Icons.check_rounded,
                          color: NexusGuard.emerald)
                      : null,
                  onTap: () => Navigator.pop(context, status),
                ),
            ]),
      ))),
    );
    if (!mounted) return;
    setState(() => _selectingStatus = false);
    if (selected != null) await _updateStatus(selected);
  }

  Future<void> _updateStatus(String status) => _ownerMutation(status: status);
  Future<void> _deleteAlert() => _ownerMutation(delete: true);

  Future<void> _ownerMutation({String? status, bool delete = false}) async {
    if (_busy || !_canInteract) return;
    if (!_isOwner) {
      _showSnack(
          'Hanya pelapor yang dapat mengubah atau menghapus laporan ini.');
      return;
    }
    if (!delete && !_statuses.contains(status)) return;
    setState(() => _confirming = true);
    try {
      final confirmed = await _confirmDialog(delete: delete, status: status);
      if (!mounted || confirmed != true) return;
      final user = await AuthService.getUser();
      if (!mounted || _actionLoading || _loadInFlight) return;
      setState(() => _currentUser = user);
      if (!_isOwner) {
        _failedAction(delete ? _DetailAction.delete : _DetailAction.status,
            status, 'Akses ditolak. Akun saat ini bukan pelapor laporan ini.');
        return;
      }
      setState(() {
        _confirming = false;
        _actionLoading = true;
        _actionError = null;
      });
      final response = delete
          ? await AlertService.deleteAlert(widget.alertId).timeout(_timeout)
          : await AlertService.updateStatus(widget.alertId, status!,
                  note: 'Status diubah oleh pelapor')
              .timeout(_timeout);
      if (!mounted) return;
      if (response['success'] != true) {
        throw _DetailFailure(_message(
            response,
            delete
                ? 'Laporan belum berhasil dihapus.'
                : 'Status belum berhasil diperbarui.'));
      }
      setState(() {
        _retryAction = null;
        _retryStatus = null;
      });
      if (delete) {
        _showSnack('Laporan berhasil dihapus.');
        Navigator.pop(context);
      } else {
        _showSnack(
            'Status laporan berhasil diubah menjadi ${_statusLabel(status)}.');
        await _load(silent: true);
      }
    } catch (error) {
      _failedAction(
          delete ? _DetailAction.delete : _DetailAction.status,
          status,
          _failureMessage(
              error,
              delete
                  ? 'Laporan belum berhasil dihapus. Silakan coba lagi.'
                  : 'Status belum berhasil diperbarui. Silakan coba lagi.'));
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _actionLoading = false;
        });
      }
    }
  }

  Future<bool?> _confirmDialog({required bool delete, String? status}) {
    return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              key: const ValueKey('detail-confirm-dialog'),
              title: Text(delete ? 'Hapus laporan?' : 'Ubah status laporan?'),
              content: Text(delete
                  ? 'Laporan, respons warga, dan analisis AI terkait akan dihapus. Tindakan ini tidak dapat dibatalkan.'
                  : 'Ubah status laporan menjadi ${_statusLabel(status)}?'),
              actions: [
                TextButton(
                    key: const ValueKey('detail-confirm-cancel'),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal')),
                FilledButton(
                  key: ValueKey(delete
                      ? 'detail-confirm-delete'
                      : 'detail-confirm-status'),
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          delete ? NexusGuard.red : NexusGuard.emerald),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(delete ? 'Hapus laporan' : 'Ubah status'),
                ),
              ],
            ));
  }

  void _retryFailedAction() {
    final action = _retryAction;
    if (_busy || action == null) return;

    switch (action) {
      case _DetailAction.response:
        if (_retryStatus != null) unawaited(_respond(_retryStatus!));
        return;
      case _DetailAction.status:
        if (_retryStatus != null) unawaited(_updateStatus(_retryStatus!));
        return;
      case _DetailAction.delete:
        unawaited(_deleteAlert());
        return;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic>? get _latestAi {
    final summaries = _alert?['aiSummaries'];
    if (summaries is List && summaries.isNotEmpty && summaries.first is Map) {
      return Map<String, dynamic>.from(summaries.first as Map);
    }
    return null;
  }

  String? get _risk =>
      _latestAi?['riskLevel']?.toString() ?? _alert?['riskLevel']?.toString();

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
        return 'Belum dinilai';
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'RENDAH':
        return NexusGuard.emerald;
      case 'SEDANG':
        return NexusGuard.amber;
      case 'TINGGI':
      case 'KRITIS':
        return NexusGuard.red;
      default:
        return NexusGuard.muted;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'AKTIF':
        return 'Aktif';
      case 'DIPROSES':
        return 'Diproses';
      case 'SELESAI':
        return 'Selesai';
      case 'DIBATALKAN':
        return 'Dibatalkan';
      default:
        return 'Status belum tersedia';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'AKTIF':
        return NexusGuard.red;
      case 'DIPROSES':
        return NexusGuard.amber;
      case 'SELESAI':
        return NexusGuard.emerald;
      default:
        return NexusGuard.muted;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'AKTIF':
        return Icons.notifications_active_outlined;
      case 'DIPROSES':
        return Icons.pending_actions_rounded;
      case 'SELESAI':
        return Icons.check_circle_outline_rounded;
      case 'DIBATALKAN':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _responseLabel(dynamic status) {
    switch (status?.toString()) {
      case 'SAYA_BISA_BANTU':
        return 'Bisa bantu';
      case 'MENUJU_LOKASI':
        return 'Menuju lokasi';
      case 'SUDAH_DI_LOKASI':
        return 'Sudah di lokasi';
      default:
        return status?.toString().replaceAll('_', ' ') ??
            'Respons belum tersedia';
    }
  }

  String _categoryName(Map<String, dynamic> alert) {
    final custom = alert['customCategory']?.toString().trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final category = alert['category'];
    return category is Map
        ? _value(category['name'], fallback: 'Laporan lingkungan')
        : 'Laporan lingkungan';
  }

  String _value(dynamic value, {String fallback = 'Belum tersedia'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double? _coordinate(dynamic value, {required bool latitude}) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    final limit = latitude ? 90 : 180;
    return parsed != null &&
            parsed.isFinite &&
            parsed >= -limit &&
            parsed <= limit
        ? parsed
        : null;
  }

  void _openMap() {
    final alert = _alert;
    if (alert == null) return;
    final latitude = _coordinate(alert['latitude'], latitude: true);
    final longitude = _coordinate(alert['longitude'], latitude: false);
    if (latitude == null || longitude == null) return;
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => MapScreen(
                  initialAlertId: widget.alertId,
                  initialLatitude: latitude,
                  initialLongitude: longitude,
                )));
  }

  TextStyle _text(
          {double size = 14,
          FontWeight weight = FontWeight.w400,
          Color? color,
          double height = 1.5}) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color ?? NexusGuard.slate,
        height: height,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('detail-screen'),
      backgroundColor: NexusGuard.slate,
      appBar: AppBar(
        title: Text('Detail Laporan',
            style:
                _text(size: 18, weight: FontWeight.w700, color: Colors.white)),
        backgroundColor: NexusGuard.slate,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
              key: const ValueKey('detail-refresh'),
              tooltip: 'Perbarui detail',
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      bottomNavigationBar: _alert != null && _isOwner ? _ownerActions() : null,
      body: Container(
        decoration: const BoxDecoration(
            color: NexusGuard.ivory,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        clipBehavior: Clip.antiAlias,
        child: RefreshIndicator(
          onRefresh: () => _busy ? Future<void>.value() : _load(),
          color: NexusGuard.emerald,
          child: SingleChildScrollView(
            key: const ValueKey('detail-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: _content())),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return _stateCard('detail-loading', 'Memuat detail laporan',
          'Mengambil informasi kejadian terbaru.',
          loading: true);
    }
    if (_alert == null) {
      return _stateCard('detail-error', 'Detail belum tersedia',
          _loadError ?? 'Laporan belum dapat dimuat.',
          retry: true);
    }
    final alert = _alert!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_loadError != null) ...[
        _notice(
            key: 'detail-error',
            message:
                'Pembaruan belum berhasil: $_loadError Data terakhir masih ditampilkan.',
            retryKey: 'detail-retry',
            onRetry: _busy ? null : () => _load()),
        const SizedBox(height: 14),
      ],
      if (_refreshing)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
                minHeight: 2, color: NexusGuard.emerald)),
      _hero(alert),
      const SizedBox(height: 16),
      _aiSummary(),
      const SizedBox(height: 12),
      _aiAdvice(),
      const SizedBox(height: 12),
      _locationCard(alert),
      const SizedBox(height: 16),
      _reporterCard(alert),
      const SizedBox(height: 16),
      if (_actionError != null) ...[
        _notice(
            key: 'detail-action-error',
            message: _actionError!,
            retryKey: 'detail-action-retry',
            onRetry: _busy ? null : _retryFailedAction),
        const SizedBox(height: 16),
      ],
      _responsePanel(),
      const SizedBox(height: 16),
      _responders(),
      const SizedBox(height: 18),
      Text('Detail diperbarui otomatis setiap 8 detik.',
          textAlign: TextAlign.center,
          style: _text(size: 11, color: NexusGuard.muted)),
    ]);
  }

  Widget _stateCard(String key, String title, String message,
      {bool loading = false, bool retry = false}) {
    return _card(
        key: key,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(children: [
            if (loading)
              const CircularProgressIndicator()
            else
              const Icon(Icons.cloud_off_outlined,
                  size: 32, color: NexusGuard.muted),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: _text(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: _text(color: NexusGuard.muted)),
            if (retry)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                      key: const ValueKey('detail-retry'),
                      onPressed: _busy ? null : () => _load(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba lagi'))),
          ]),
        ));
  }

  Widget _card({String? key, required Widget child, Color? color}) => Container(
        key: key == null ? null : ValueKey(key),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color ?? NexusGuard.panel,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: NexusGuard.border)),
        child: child,
      );

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
        Icon(icon, size: 22, color: NexusGuard.emerald),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(title, style: _text(size: 17, weight: FontWeight.w700))),
      ]);

  Widget _chip(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30)),
        child: Text.rich(
            TextSpan(children: [
              if (icon != null)
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(icon, size: 14, color: color))),
              TextSpan(text: label),
            ]),
            style: _text(size: 12, weight: FontWeight.w600, color: color)),
      );

  Widget _hero(Map<String, dynamic> alert) {
    final status = alert['status']?.toString();
    final photo = [alert['photoUrl'], alert['image']]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _chip(_statusLabel(status), _statusColor(status),
            icon: _statusIcon(status)),
        const SizedBox(width: 10),
        Expanded(
            child: Tooltip(
                message: 'ID: ${widget.alertId}',
                child: Text('ID: ${widget.alertId}',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(size: 10, color: NexusGuard.muted)))),
      ]),
      if (photo.isNotEmpty) ...[
        const SizedBox(height: 15),
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                key: const ValueKey('detail-photo'),
                width: double.infinity,
                height: MediaQuery.sizeOf(context).width >= 800 ? 320 : 185,
                child: _photo(photo))),
      ],
      const SizedBox(height: 16),
      Text(_value(alert['title'], fallback: 'Laporan lingkungan'),
          key: const ValueKey('detail-title'),
          style: _text(size: 23, weight: FontWeight.w800, height: 1.3)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(_categoryName(alert), NexusGuard.emerald,
            icon: Icons.category_outlined),
        _chip('Risiko: ${_riskLabel(_risk)}', _riskColor(_risk),
            icon: Icons.shield_outlined),
      ]),
      const SizedBox(height: 14),
      Text(_value(alert['description'], fallback: 'Deskripsi belum tersedia.'),
          style: _text(color: NexusGuard.muted)),
    ]);
  }

  Widget _photo(String source) {
    Widget unavailable() => ColoredBox(
        color: const Color(0xFFE8EFE9),
        child: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                size: 30, color: NexusGuard.muted),
            const SizedBox(height: 8),
            Text('Foto tidak dapat ditampilkan',
                style: _text(size: 12, color: NexusGuard.muted)),
          ],
        )));
    try {
      if (source.startsWith('data:image/')) {
        final bytes = Uri.parse(source).data?.contentAsBytes();
        if (bytes != null) {
          return Image.memory(bytes,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => unavailable());
        }
      } else if (source.startsWith('http://') ||
          source.startsWith('https://')) {
        return Image.network(source,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => unavailable());
      }
    } catch (_) {
      return unavailable();
    }
    return unavailable();
  }

  Widget _aiSummary() {
    final summary = _latestAi?['summary'] ?? _alert?['aiSummary'];
    return _card(
        key: 'detail-ai-summary',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Analisis AI', Icons.smart_toy_outlined),
          const SizedBox(height: 10),
          Text(
              _value(summary,
                  fallback: 'Analisis AI belum tersedia untuk laporan ini.'),
              style: _text()),
        ]));
  }

  Widget _aiAdvice() => _card(
        key: 'detail-ai-advice',
        color: const Color(0xFFE9F3E8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Saran Tindakan', Icons.verified_user_outlined),
          const SizedBox(height: 10),
          Text(
              _value(_latestAi?['recommendedAction'],
                  fallback: 'Saran tindakan AI belum tersedia.'),
              style: _text()),
        ]),
      );

  Widget _locationCard(Map<String, dynamic> alert) {
    final validCoordinates =
        _coordinate(alert['latitude'], latitude: true) != null &&
            _coordinate(alert['longitude'], latitude: false) != null;
    return Material(
      color: NexusGuard.panel,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: NexusGuard.border)),
      child: InkWell(
        key: const ValueKey('detail-location'),
        onTap: validCoordinates ? _openMap : null,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_outlined, color: NexusGuard.emerald),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Lokasi Kejadian',
                      style: _text(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(
                      _value(alert['address'],
                          fallback: 'Alamat belum tersedia'),
                      style: _text(size: 12)),
                  const SizedBox(height: 5),
                  Text(
                      validCoordinates
                          ? '${alert['latitude']}, ${alert['longitude']}'
                          : 'Koordinat belum tersedia',
                      style: _text(size: 11, color: NexusGuard.muted)),
                ])),
            if (validCoordinates)
              const Icon(Icons.chevron_right_rounded,
                  color: NexusGuard.emerald),
          ]),
        ),
      ),
    );
  }

  Widget _reporterCard(Map<String, dynamic> alert) {
    final reporter =
        alert['user'] is Map ? alert['user'] as Map : <String, dynamic>{};
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Pelapor', Icons.person_outline_rounded),
      const SizedBox(height: 14),
      _info('Nama', reporter['name']),
      _info('Peran', reporter['role']),
      _info('Telepon', reporter['phone']),
      _info('Alamat', reporter['address']),
    ]));
  }

  Widget _responsePanel() {
    final latest = _latestOwnResponse;
    final currentId = _id(_currentUser?['id']);
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Respons Anda', Icons.volunteer_activism_outlined),
      const SizedBox(height: 10),
      Text(
          'Beri tahu pelapor bila Anda dapat membantu. Perubahan status Anda ditambahkan ke riwayat respons.',
          style: _text(size: 12, color: NexusGuard.muted)),
      if (latest != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                'Respons terbaru Anda: ${_responseLabel(latest['responseStatus'])}',
                key: const ValueKey('detail-my-response'),
                style: _text(
                    size: 13,
                    weight: FontWeight.w700,
                    color: NexusGuard.emerald))),
      const SizedBox(height: 14),
      if (currentId == null)
        Text('Akun Anda belum tersedia. Muat ulang detail untuk merespons.',
            style: _text(color: NexusGuard.muted))
      else ...[
        TextField(
            key: const ValueKey('detail-response-note'),
            controller: _responseNote,
            enabled: !_busy && _canInteract,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Informasi bantuan yang dapat Anda berikan')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final status in _responseStatuses)
            OutlinedButton(
              key: ValueKey('detail-response-$status'),
              onPressed: _busy || !_canInteract ? null : () => _respond(status),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  backgroundColor: latest?['responseStatus'] == status
                      ? NexusGuard.emerald.withValues(alpha: 0.08)
                      : null),
              child: Text(_responseLabel(status),
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center),
            ),
        ]),
      ],
      if (_actionLoading)
        const Padding(
            padding: EdgeInsets.only(top: 14),
            child: LinearProgressIndicator(
                key: ValueKey('detail-action-loading'),
                minHeight: 3,
                color: NexusGuard.emerald)),
    ]));
  }

  Widget _responders() {
    final responses = _responses;
    return _card(
        key: 'detail-responders',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Riwayat Respons (${responses.length})',
              Icons.people_outline_rounded),
          const SizedBox(height: 12),
          if (responses.isEmpty)
            Text('Belum ada warga yang merespons laporan ini.',
                style: _text(color: NexusGuard.muted))
          else
            for (final response in responses)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _responseRow(response)),
        ]));
  }

  Widget _responseRow(Map<String, dynamic> response) {
    final user =
        response['user'] is Map ? response['user'] as Map : <String, dynamic>{};
    final own = _belongsToCurrentUser(response);
    final note = response['note']?.toString().trim() ?? '';
    return Container(
      key: ValueKey('detail-response-row-${response['id']}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: NexusGuard.ivory, borderRadius: BorderRadius.circular(13)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${_value(user['name'], fallback: 'Warga')}${own ? ' (Anda)' : ''}',
            style: _text(weight: FontWeight.w700)),
        const SizedBox(height: 6),
        _chip(_responseLabel(response['responseStatus']), NexusGuard.emerald),
        const SizedBox(height: 9),
        _info('Peran', user['role']),
        _info('Telepon', user['phone']),
        if (_value(user['address'], fallback: '').isNotEmpty)
          _info('Alamat', user['address']),
        if (note.isNotEmpty) _info('Catatan', note),
      ]),
    );
  }

  Widget _info(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 75,
              child:
                  Text(label, style: _text(size: 12, color: NexusGuard.muted))),
          const SizedBox(width: 8),
          Expanded(child: Text(_value(value), style: _text(size: 12))),
        ]),
      );

  Widget _notice(
          {required String key,
          required String message,
          required String retryKey,
          required VoidCallback? onRetry}) =>
      _card(
          key: key,
          color: const Color(0xFFFFF4E3),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message, style: _text(size: 13)),
            const SizedBox(height: 8),
            TextButton.icon(
                key: ValueKey(retryKey),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba lagi')),
          ]));

  Widget _ownerActions() => Material(
        color: NexusGuard.panel,
        elevation: 4,
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Row(
                        key: const ValueKey('detail-owner-actions'),
                        children: [
                          Expanded(
                              child: OutlinedButton(
                                  key: const ValueKey('detail-update-status'),
                                  onPressed: _busy || !_canInteract
                                      ? null
                                      : _selectStatus,
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: NexusGuard.emerald),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 13)),
                                  child: const Text('Ubah status',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: FilledButton(
                                  key: const ValueKey('detail-delete-alert'),
                                  onPressed: _busy || !_canInteract
                                      ? null
                                      : _deleteAlert,
                                  style: FilledButton.styleFrom(
                                      backgroundColor: NexusGuard.red,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 13)),
                                  child: const Text('Hapus',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13)))),
                        ]),
                  )),
            )),
      );
}

class _DetailFailure implements Exception {
  final String message;
  const _DetailFailure(this.message);
}
