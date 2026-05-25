import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around the [SpeechToText] plugin.
///
/// Usage:
///   final recorder = VoiceRecorder();
///   final available = await recorder.initialize();
///   await recorder.startListening();
///   // ... user speaks ...
///   final transcript = await recorder.stopListening();
///   recorder.dispose();
class VoiceRecorder {
  VoiceRecorder() : _speech = SpeechToText();

  final SpeechToText _speech;

  bool _initialized = false;
  String _lastTranscript = '';

  /// Initializes the speech engine and requests microphone permission.
  /// Returns true if available on this device.
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) {
        // Errors are surfaced to callers via stopListening return value
      },
      onStatus: (status) {
        // Status changes handled by caller polling isListening
      },
    );
    return _initialized;
  }

  /// Returns true if currently recording.
  bool get isListening => _speech.isListening;

  /// Returns the list of available locales (for locale picker, if desired).
  Future<List<LocaleName>> availableLocales() async {
    if (!_initialized) await initialize();
    return _speech.locales();
  }

  /// Starts listening.  Transcriptions are accumulated internally.
  Future<void> startListening({String? localeId}) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _lastTranscript = '';

    await _speech.listen(
      onResult: (result) {
        _lastTranscript = result.recognizedWords;
      },
      listenFor:            const Duration(seconds: 30),
      pauseFor:             const Duration(seconds: 3),
      partialResults:       true,
      cancelOnError:        false,
      localeId:             localeId,
      listenMode:           ListenMode.dictation,
    );
  }

  /// Stops listening and returns the final transcript.
  Future<String> stopListening() async {
    await _speech.stop();
    // Give the engine a brief moment to finalise
    await Future.delayed(const Duration(milliseconds: 200));
    return _lastTranscript.trim();
  }

  /// Cancels listening without returning a transcript.
  Future<void> cancel() async {
    await _speech.cancel();
    _lastTranscript = '';
  }

  /// Call when the owning widget is disposed.
  void dispose() {
    _speech.cancel();
  }
}
