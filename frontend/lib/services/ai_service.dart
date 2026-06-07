import 'api_service.dart';

class AiService {
  static Future<Map<String, dynamic>> fullAnalysis({
    required String alertId,
    required String category,
    String? customCategory,
    required String description,
  }) async {
    return await ApiService.post('/ai/full-analysis', {
      'alertId': alertId,
      'category': category,
      'customCategory': customCategory,
      'description': description,
    });
  }
}