import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/nexus_guard_theme.dart';
import '../../services/alert_service.dart';
import '../alerts/alert_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final String? initialAlertId;
  final double? initialLatitude;
  final double? initialLongitude;

  const MapScreen({
    super.key,
    this.initialAlertId,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  late final NetworkTileProvider _tileProvider;
  List<_MapIncident> _incidents = [];
  String? _selectedId;
  String? _loadError;
  int _invalidCount = 0;
  int _reportCount = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _hasLoaded = false;
  bool _requestInFlight = false;
  bool _mapReady = false;
  Size _mapSize = Size.zero;

  static const _defaultCenter =
      LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

  LatLng? get _initialPoint =>
      _validPoint(widget.initialLatitude, widget.initialLongitude);

  _MapIncident? get _selected {
    for (final incident in _incidents) {
      if (incident.id == _selectedId) return incident;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tileProvider = NetworkTileProvider();
    _loadAlerts();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAlertId != widget.initialAlertId ||
        oldWidget.initialLatitude != widget.initialLatitude ||
        oldWidget.initialLongitude != widget.initialLongitude) {
      _selectedId = widget.initialAlertId;
      _scheduleFocus();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    // TileLayer owns and disposes its NetworkTileProvider.
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    if (_requestInFlight || !mounted) return;
    _requestInFlight = true;
    final firstLoad = !_hasLoaded;
    setState(() {
      _loading = firstLoad;
      _refreshing = !firstLoad;
    });
    try {
      final response = await AlertService.getActiveAlerts()
          .timeout(const Duration(seconds: 20));
      if (response['success'] != true || response['data'] is! List) {
        throw const FormatException('Daftar laporan belum tersedia.');
      }
      final data = response['data'] as List;
      final incidents = <_MapIncident>[];
      final ids = <String>{};
      var invalid = 0;
      for (final item in data) {
        if (item is! Map) {
          throw const FormatException('Format laporan tidak sesuai.');
        }
        final alert = Map<String, dynamic>.from(item);
        final id = alert['id']?.toString().trim() ?? '';
        final point = _validPoint(alert['latitude'], alert['longitude']);
        if (id.isEmpty || point == null || !ids.add(id)) {
          invalid++;
          continue;
        }
        incidents.add(_MapIncident(id: id, point: point, data: alert));
      }
      if (!mounted) return;
      final preferredId = _selectedId ?? widget.initialAlertId;
      final hasPreferred = incidents.any((item) => item.id == preferredId);
      setState(() {
        _incidents = incidents;
        _invalidCount = invalid;
        _reportCount = data.length;
        _selectedId = hasPreferred
            ? preferredId
            : widget.initialAlertId == null && incidents.isNotEmpty
                ? incidents.first.id
                : null;
        _hasLoaded = true;
        _loadError = null;
        _loading = false;
        _refreshing = false;
      });
      if (firstLoad) _scheduleFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = _hasLoaded
            ? 'Pembaruan gagal. Lokasi di peta berasal dari pemuatan terakhir.'
            : 'Lokasi laporan belum dapat dimuat. Periksa koneksi dan coba lagi.';
        _loading = false;
        _refreshing = false;
      });
    } finally {
      _requestInFlight = false;
    }
  }

  static double? _coordinate(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value.trim())
            : null;
    return number != null && number.isFinite ? number : null;
  }

  static LatLng? _validPoint(dynamic latitude, dynamic longitude) {
    final lat = _coordinate(latitude);
    final lng = _coordinate(longitude);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  void _scheduleFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapReady) _focusLocations(useInitialFocus: true);
    });
  }

  void _onMapReady() {
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _focusLocations(useInitialFocus: true);
    });
  }

  void _focusLocations({bool useInitialFocus = false}) {
    if (!_mapReady || !mounted) return;
    if (useInitialFocus && _initialPoint != null) {
      _mapController.move(_initialPoint!, 16);
      return;
    }
    if (useInitialFocus && widget.initialAlertId != null && _selected != null) {
      _mapController.move(_selected!.point, 16);
      return;
    }
    if (_incidents.isEmpty) {
      _mapController.move(
          _initialPoint ?? _defaultCenter, AppConstants.defaultZoom);
    } else if (_incidents.length == 1) {
      _mapController.move(_incidents.single.point, 16);
    } else {
      _mapController.fitCamera(CameraFit.coordinates(
        coordinates: _incidents.map((incident) => incident.point).toList(),
        padding: EdgeInsets.fromLTRB(
            48, 86, 68, math.min(210.0, _mapSize.height * 0.35)),
        maxZoom: 16,
        minZoom: 3,
      ));
    }
  }

  void _zoom(double change) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(
        camera.center, (camera.zoom + change).clamp(3.0, 19.0).toDouble());
  }

  void _selectIncident(_MapIncident incident) {
    setState(() => _selectedId = incident.id);
    if (_mapReady) {
      _mapController.move(
        incident.point,
        math.max(16.0, _mapController.camera.zoom),
        offset: Offset(0, -math.min(70.0, _mapSize.height * 0.1)),
      );
    }
  }

  Future<void> _openDetail(_MapIncident incident) async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => AlertDetailScreen(alertId: incident.id)));
    if (mounted) await _loadAlerts();
  }

  TextStyle _text(double size,
          {Color color = NexusGuard.slate,
          FontWeight weight = FontWeight.w500}) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: size, color: color, fontWeight: weight, height: 1.4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('map-screen'),
      backgroundColor: NexusGuard.slate,
      appBar: AppBar(
        title: const Text('Peta Kejadian'),
        centerTitle: true,
        backgroundColor: NexusGuard.slate,
        foregroundColor: Colors.white,
        titleTextStyle: _text(18, color: Colors.white, weight: FontWeight.w700),
        actions: [
          IconButton(
            key: const ValueKey('map-refresh'),
            tooltip: 'Perbarui lokasi laporan',
            onPressed: _loading || _refreshing ? null : _loadAlerts,
            disabledColor: Colors.white60,
            icon: _refreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: LayoutBuilder(builder: (context, constraints) {
            _mapSize = constraints.biggest;
            return Stack(children: [
              Positioned.fill(
                  child: FlutterMap(
                key: const ValueKey('map-canvas'),
                mapController: _mapController,
                options: MapOptions(
                  backgroundColor: const Color(0xFFE4ECE4),
                  initialCenter: _initialPoint ?? _defaultCenter,
                  initialZoom: AppConstants.defaultZoom,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: _onMapReady,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.komplekguard.ai',
                    tileProvider: _tileProvider,
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(markers: _incidents.map(_marker).toList()),
                ],
              )),
              Positioned(top: 12, left: 12, right: 12, child: _summary()),
              Positioned(
                  right: 12,
                  top: math.max(105, constraints.maxHeight * 0.32),
                  child: _mapControls()),
              Positioned(
                left: 12,
                right: 12,
                bottom: 47,
                child: Center(
                    child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight: math.max(100, constraints.maxHeight * 0.43)),
                  child: RefreshIndicator(
                    onRefresh: _loadAlerts,
                    child: SingleChildScrollView(
                      key: const ValueKey('map-information-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: _informationCard(),
                    ),
                  ),
                )),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _attribution()),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _summary() {
    final text = _loading
        ? 'Memuat lokasi laporan…'
        : !_hasLoaded
            ? 'Data lokasi belum tersedia'
            : '${_incidents.length} lokasi laporan aktif';
    return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: Colors.white.withValues(alpha: 0.97),
            elevation: 3,
            shadowColor: NexusGuard.slate.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 20, color: NexusGuard.emerald),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Text(text,
                              style: _text(13, weight: FontWeight.w700))),
                    ]),
                    if (_invalidCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                          '$_invalidCount laporan belum dapat dipetakan karena lokasi belum valid.',
                          key: const ValueKey('map-invalid-locations'),
                          style: _text(11, color: NexusGuard.muted)),
                    ],
                    if (_loadError != null && _hasLoaded) ...[
                      const SizedBox(height: 5),
                      Text(_loadError!,
                          key: const ValueKey('map-refresh-error'),
                          style: _text(11, color: NexusGuard.red)),
                    ],
                  ]),
            ),
          ),
        ));
  }

  Marker _marker(_MapIncident incident) {
    final selected = incident.id == _selectedId;
    return Marker(
      point: incident.point,
      width: 62,
      height: 68,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${incident.title}. ${incident.statusLabel}. Risiko ${incident.riskLabel}.',
        child: GestureDetector(
          key: ValueKey('map-marker-${incident.id}'),
          onTap: () => _selectIncident(incident),
          child: Tooltip(
              message: incident.title,
              child: Stack(alignment: Alignment.center, children: [
                if (selected)
                  Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: incident.color.withValues(alpha: 0.18))),
                const Icon(Icons.location_on_rounded,
                    size: 57, color: Colors.white),
                Icon(Icons.location_on_rounded,
                    size: 50, color: incident.color),
                Positioned(
                    top: 19,
                    child: Icon(
                        incident.data['status'] == 'DIPROSES'
                            ? Icons.more_horiz_rounded
                            : Icons.priority_high_rounded,
                        color: Colors.white,
                        size: 20)),
              ])),
        ),
      ),
    );
  }

  Widget _mapControls() => Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: NexusGuard.slate.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              key: const ValueKey('map-zoom-in'),
              tooltip: 'Perbesar peta',
              onPressed: _mapReady ? () => _zoom(1) : null,
              icon: const Icon(Icons.add_rounded, color: NexusGuard.slate)),
          const SizedBox(width: 26, child: Divider(height: 1)),
          IconButton(
              key: const ValueKey('map-zoom-out'),
              tooltip: 'Perkecil peta',
              onPressed: _mapReady ? () => _zoom(-1) : null,
              icon: const Icon(Icons.remove_rounded, color: NexusGuard.slate)),
          const SizedBox(width: 26, child: Divider(height: 1)),
          IconButton(
              key: const ValueKey('map-recenter'),
              tooltip: 'Tampilkan semua lokasi laporan',
              onPressed: _mapReady ? () => _focusLocations() : null,
              icon: const Icon(Icons.center_focus_strong_rounded,
                  color: NexusGuard.emerald)),
        ]),
      );

  Widget _informationCard() {
    if (_loading) {
      return _stateCard(
          stateKey: 'map-loading',
          icon: const SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
          title: 'Memuat lokasi laporan',
          message: 'Mengambil laporan aktif dari lingkungan Anda.');
    }
    if (_loadError != null && !_hasLoaded) {
      return _stateCard(
          stateKey: 'map-error',
          icon: const Icon(Icons.cloud_off_outlined,
              color: NexusGuard.red, size: 28),
          title: 'Peta laporan belum tersedia',
          message: _loadError!,
          retry: true);
    }
    if (_reportCount == 0) {
      return _stateCard(
          stateKey: 'map-empty',
          icon: const Icon(Icons.location_on_outlined,
              color: NexusGuard.emerald, size: 28),
          title: 'Belum ada laporan aktif',
          message:
              'Laporan aktif akan muncul di peta jika lokasi tersedia. Tarik kartu ini untuk memperbarui.');
    }
    if (_incidents.isEmpty) {
      return _stateCard(
          stateKey: 'map-no-valid-locations',
          icon: const Icon(Icons.wrong_location_outlined,
              color: NexusGuard.amber, size: 28),
          title: 'Lokasi laporan belum tersedia',
          message:
              '$_reportCount laporan tidak dipetakan karena koordinat atau informasi lokasi belum valid.');
    }
    final incident = _selected;
    if (incident == null) {
      return _stateCard(
          stateKey: 'map-choose-location',
          icon: const Icon(Icons.touch_app_outlined,
              color: NexusGuard.emerald, size: 28),
          title: 'Pilih penanda laporan',
          message: widget.initialAlertId == null
              ? 'Ketuk penanda untuk melihat informasi kejadian.'
              : 'Peta difokuskan ke lokasi pilihan. Penanda menunjukkan laporan yang masih aktif.');
    }
    return Material(
      key: const ValueKey('map-selected-card'),
      color: Colors.white,
      elevation: 5,
      shadowColor: NexusGuard.slate.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        key: const ValueKey('map-selected-detail'),
        onTap: () => _openDetail(incident),
        borderRadius: BorderRadius.circular(21),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _thumbnail(incident),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(incident.title,
                            key: const ValueKey('map-selected-title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _text(15, weight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(incident.verificationStatus,
                            style: _text(11, color: NexusGuard.amber,
                                weight: FontWeight.w700)),
                        if (incident.approximate)
                          Text('Titik peta adalah perkiraan, bukan lokasi tepat.',
                            style: _text(10, color: NexusGuard.muted)),
                        const SizedBox(height: 4),
                        Text(incident.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _text(11, color: NexusGuard.muted)),
                      ])),
                  const SizedBox(width: 5),
                  const Icon(Icons.chevron_right_rounded,
                      size: 22, color: NexusGuard.slate),
                ]),
                const SizedBox(height: 13),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  _badge(incident.riskLabel, incident.color,
                      Icons.shield_outlined),
                  _badge(
                      incident.statusLabel,
                      incident.data['status'] == 'DIPROSES'
                          ? NexusGuard.amber
                          : NexusGuard.emerald,
                      Icons.circle,
                      iconSize: 8),
                ]),
                const SizedBox(height: 8),
                Text('Lihat detail laporan',
                    style: _text(11,
                        color: NexusGuard.emerald, weight: FontWeight.w700)),
              ],
            )),
      ),
    );
  }

  Widget _stateCard(
          {required String stateKey,
          required Widget icon,
          required String title,
          required String message,
          bool retry = false}) =>
      Material(
        key: ValueKey(stateKey),
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  icon,
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(title,
                          style: _text(15, weight: FontWeight.w700)))
                ]),
                const SizedBox(height: 9),
                Text(message, style: _text(12, color: NexusGuard.muted)),
                if (retry) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                      key: const ValueKey('map-retry'),
                      onPressed: _loadAlerts,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba lagi')),
                ],
              ],
            )),
      );

  Widget _thumbnail(_MapIncident incident) {
    final photo = incident.data['photoUrl']?.toString();
    final uri = photo == null ? null : Uri.tryParse(photo);
    final fallback = ColoredBox(
        color: NexusGuard.bg2,
        child:
            Icon(Icons.location_on_outlined, color: incident.color, size: 27));
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 57,
        height: 62,
        child: uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
            ? Image.network(photo!,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
            : fallback,
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon,
          {double iconSize = 13}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(label, style: _text(11, color: color, weight: FontWeight.w700)),
        ]),
      );

  Widget _attribution() => ColoredBox(
        color: Colors.white.withValues(alpha: 0.96),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.layers_outlined,
                size: 14, color: NexusGuard.muted),
            const SizedBox(width: 5),
            Flexible(
                child: Tooltip(
                    message: 'https://www.openstreetmap.org/copyright',
                    child: Text('© OpenStreetMap contributors',
                        key: const ValueKey('map-attribution'),
                        textAlign: TextAlign.center,
                        style: _text(10, color: NexusGuard.muted)))),
          ]),
        ),
      );
}

class _MapIncident {
  final String id;
  final LatLng point;
  final Map<String, dynamic> data;

  const _MapIncident(
      {required this.id, required this.point, required this.data});

  String get title => data['title']?.toString().trim().isNotEmpty == true
      ? data['title'].toString()
      : 'Laporan warga';

  bool get approximate => data['locationApproximate'] == true;
  String get verificationStatus => switch (data['verificationStatus']) {
    'TERVERIFIKASI' => 'Terverifikasi petugas',
    'PERLU_PEMERIKSAAN' => 'Perlu pemeriksaan',
    'DITOLAK' => 'Verifikasi ditolak',
    _ => 'Belum terverifikasi',
  };

  String get address => data['address']?.toString().trim().isNotEmpty == true
      ? data['address'].toString()
      : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  String get statusLabel {
    switch (data['status']) {
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

  String? get risk {
    final summaries = data['aiSummaries'];
    if (summaries is List && summaries.isNotEmpty && summaries.first is Map) {
      final value = summaries.first['riskLevel']?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return data['riskLevel']?.toString();
  }

  String get riskLabel {
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

  Color get color {
    switch (risk) {
      case 'TINGGI':
      case 'KRITIS':
        return NexusGuard.red;
      case 'SEDANG':
        return NexusGuard.amber;
      case 'RENDAH':
        return NexusGuard.emerald;
      default:
        return NexusGuard.slate;
    }
  }
}
