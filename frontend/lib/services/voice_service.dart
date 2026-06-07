import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  VoiceService._();

  static final VoiceService instance = VoiceService._();

  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    if (_initialized) return true;

    _initialized = await _speech.initialize(
      onError: (error) {},
      onStatus: (status) {},
    );

    return _initialized;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    void Function()? onDone,
  }) async {
    final available = await init();

    if (!available) {
      throw Exception('Microphone / speech recognition tidak tersedia');
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);

        if (result.finalResult) {
          onDone?.call();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'id_ID',
        listenMode: ListenMode.confirmation,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
