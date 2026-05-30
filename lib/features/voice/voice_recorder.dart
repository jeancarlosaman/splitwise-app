import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps `speech_to_text` for our use case: long, manually-stopped voice
/// instructions ("split 120 between me, Alice, and Bob, it was for dinner").
///
/// Key behaviors vs the package defaults:
///   - No silence cutoff (`pauseFor` set very high) so the user can think mid-sentence.
///   - Long max duration (5 min) — manual stop is the expected path.
///   - Reports errors via callback so the UI can surface them instead of dying silently.
class VoiceRecorder {
  final _stt = SpeechToText();
  bool _isAvailable = false;
  String _lastError = '';

  /// Latest transcript accumulated across partial results, kept here so the
  /// caller doesn't lose what was recognized if a final result never fires
  /// (which happens on iOS when the user taps stop quickly).
  String _lastTranscript = '';

  bool get isAvailable => _isAvailable;
  bool get isListening => _stt.isListening;
  String get lastError => _lastError;
  String get lastTranscript => _lastTranscript;

  Future<bool> initialize({
    void Function(String message)? onError,
  }) async {
    try {
      _isAvailable = await _stt.initialize(
        onError: (e) {
          _lastError = e.errorMsg;
          debugPrint('[VoiceRecorder] STT error: ${e.errorMsg} (permanent=${e.permanent})');
          onError?.call(e.errorMsg);
        },
        onStatus: (status) {
          debugPrint('[VoiceRecorder] STT status: $status');
        },
        debugLogging: kDebugMode,
      );
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[VoiceRecorder] initialize() threw: $e');
      _isAvailable = false;
    }
    return _isAvailable;
  }

  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'en_US',
  }) async {
    if (!_isAvailable) {
      _lastError = 'Speech recognizer not available';
      return;
    }
    _lastTranscript = '';
    _lastError = '';
    await _stt.listen(
      onResult: (result) {
        _lastTranscript = result.recognizedWords;
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      // Long limits — the UI controls when to stop. iOS caps single-segment
      // recognition around 60s on-device, so we use ListenMode.dictation
      // to get continuous segmentation.
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(minutes: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<String> stopListening() async {
    await _stt.stop();
    return _lastTranscript;
  }

  Future<void> cancel() async {
    await _stt.cancel();
  }

  void dispose() {
    _stt.cancel();
  }
}
