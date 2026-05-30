import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps `speech_to_text` for our use case: long, manually-stopped voice
/// instructions ("split 120 between me, Alice, and Bob, it was for dinner").
///
/// Key behaviors vs the package defaults:
///   - No silence cutoff (`pauseFor` set very high) so the user can think mid-sentence.
///   - Long max duration (5 min) — manual stop is the expected path.
///   - Auto-detects the device's preferred locale (hardcoding en_US breaks
///     recognition for users whose system locale doesn't have an en_US model).
///   - Reports errors via callback so the UI can surface them.
class VoiceRecorder {
  final _stt = SpeechToText();
  bool _isAvailable = false;
  bool _initialized = false;
  String _lastError = '';
  String _lastStatus = '';
  String? _resolvedLocaleId;

  /// Latest transcript accumulated across partial results, kept here so the
  /// caller doesn't lose what was recognized if a final result never fires
  /// (which happens on iOS when the user taps stop quickly).
  String _lastTranscript = '';

  /// Highest sound level seen during the most recent listening session.
  /// Useful for telling the user "we heard nothing" vs "we heard audio
  /// but couldn't transcribe it".
  double _peakSoundLevel = 0;

  bool get isAvailable => _isAvailable;
  bool get isListening => _stt.isListening;
  String get lastError => _lastError;
  String get lastStatus => _lastStatus;
  String get lastTranscript => _lastTranscript;
  double get peakSoundLevel => _peakSoundLevel;
  String? get localeId => _resolvedLocaleId;

  Future<bool> initialize({
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async {
    // Only run the full setup once — subsequent calls just re-check state.
    if (_initialized) return _isAvailable;
    try {
      _isAvailable = await _stt.initialize(
        onError: (e) {
          _lastError = e.errorMsg;
          debugPrint(
              '[VoiceRecorder] STT error: ${e.errorMsg} (permanent=${e.permanent})');
          onError?.call(e.errorMsg);
        },
        onStatus: (status) {
          _lastStatus = status;
          debugPrint('[VoiceRecorder] STT status: $status');
          onStatus?.call(status);
        },
        debugLogging: kDebugMode,
      );

      if (_isAvailable) {
        // Pick a locale the device actually has a model for. Prefer the system
        // locale; fall back to the first available; final fallback en_US.
        try {
          final system = await _stt.systemLocale();
          if (system != null) _resolvedLocaleId = system.localeId;
          if (_resolvedLocaleId == null) {
            final locales = await _stt.locales();
            if (locales.isNotEmpty) _resolvedLocaleId = locales.first.localeId;
          }
          _resolvedLocaleId ??= 'en_US';
          debugPrint('[VoiceRecorder] using locale: $_resolvedLocaleId');
        } catch (e) {
          debugPrint('[VoiceRecorder] locale lookup failed: $e');
          _resolvedLocaleId = 'en_US';
        }
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[VoiceRecorder] initialize() threw: $e');
      _isAvailable = false;
    }
    _initialized = true;
    return _isAvailable;
  }

  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    String? localeOverride,
  }) async {
    if (!_isAvailable) {
      _lastError = 'Speech recognizer not available';
      return;
    }
    _lastTranscript = '';
    _lastError = '';
    _peakSoundLevel = 0;
    await _stt.listen(
      onResult: (result) {
        // Some iOS configurations only emit the final result, others stream
        // partials. Capture whatever comes in.
        if (result.recognizedWords.isNotEmpty) {
          _lastTranscript = result.recognizedWords;
        }
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeOverride ?? _resolvedLocaleId,
      onSoundLevelChange: (level) {
        if (level > _peakSoundLevel) _peakSoundLevel = level;
        onSoundLevel?.call(level);
      },
      // Long limits — the UI controls when to stop. iOS caps single-segment
      // recognition around 60s on-device, so we use ListenMode.dictation
      // to get continuous segmentation.
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(minutes: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        // Don't force on-device — iOS Speech Framework's cloud path is more
        // accurate and supports more locales.
        onDevice: false,
      ),
    );
  }

  Future<String> stopListening() async {
    await _stt.stop();
    // Give iOS a brief moment to deliver any pending final result.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _lastTranscript;
  }

  Future<void> cancel() async {
    await _stt.cancel();
  }

  void dispose() {
    _stt.cancel();
  }
}
