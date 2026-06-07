import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/alert_service.dart';
import '../../core/constants/app_constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final res = await AlertService.getActiveAlerts();
    if (res['success'] == true) setState(() => _alerts = res['data'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peta Alert'), backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
          initialZoom: AppConstants.defaultZoom,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.komplekguard.ai',
          ),
          MarkerLayer(
            markers: _alerts.map((alert) {
              final lat = (alert['latitude'] as num?)?.toDouble() ?? AppConstants.defaultLat;
              final lng = (alert['longitude'] as num?)?.toDouble() ?? AppConstants.defaultLng;
              return Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(alert['title'] ?? ''),
                      content: Text(alert['description'] ?? ''),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
                    ),
                  ),
                  child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}