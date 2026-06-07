import 'api_service.dart';

class AlertService {
  static Future<Map<String, dynamic>> getActiveAlerts() async {
    return await ApiService.get('/alerts/active');
  }

  static Future<Map<String, dynamic>> getAlertHistory() async {
    return await ApiService.get('/alerts/history');
  }

  static Future<Map<String, dynamic>> createAlert(Map<String, dynamic> data) async {
    return await ApiService.post('/alerts', data);
  }

  static Future<Map<String, dynamic>> getAlertDetail(String id) async {
    return await ApiService.get('/alerts/$id');
  }

  static Future<Map<String, dynamic>> respondToAlert(String id, String responseStatus, {String? note}) async {
    return await ApiService.post('/alerts/$id/respond', {'responseStatus': responseStatus, 'note': note});
  }

  static Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    return await ApiService.put('/alerts/$id/status', {'status': status});
  }
}