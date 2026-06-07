import 'api_service.dart';

class SafetyAiService {
  static Future<Map<String, dynamic>> getDailyBriefing() async {
    return await ApiService.get('/safety-ai/briefing');
  }

  static Future<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
  }) async {
    return await ApiService.post('/safety-ai/chat', {
      'message': message,
      'sessionId': sessionId,
    });
  }

  static Future<Map<String, dynamic>> getChatHistory() async {
    return await ApiService.get('/safety-ai/chat/history');
  }

  static Future<Map<String, dynamic>> createVoiceAlertDraft({
    required String transcript,
  }) async {
    return await ApiService.post('/safety-ai/voice-alert-draft', {
      'transcript': transcript,
    });
  }
}
