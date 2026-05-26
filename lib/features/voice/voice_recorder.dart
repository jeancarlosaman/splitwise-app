import 'package:speech_to_text/speech_to_text.dart';

class VoiceRecorder {
  final _stt = SpeechToText();
  bool _isAvailable = false;

  Future<bool> initialize() async {
    _isAvailable = await _stt.initialize(
      onError: (error) => print('STT error: $error'),
    );
    return _isAvailable;
  }

  bool get isAvailable => _isAvailable;
  bool get isListening => _stt.isListening;

  Future<void> startListening({
    required void Function(String text) onResult,
    String localeId = 'en_US',
  }) async {
    if (!_isAvailable) return;
    await _stt.listen(
      onResult: (result) => onResult(result.recognizedWords),
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  void dispose() => _stt.cancel();
}
