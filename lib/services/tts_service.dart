import 'package:flutter_tts/flutter_tts.dart';

enum TtsState {
  playing,
  stopped,
  paused,
  continued
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  TtsState _state = TtsState.stopped;

  TtsState get state => _state;

  Function()? onStart;
  Function()? onComplete;
  Function(String)? onError;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage("zh-CN");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      onStart?.call();
    });

    _tts.setCompletionHandler(() {
      _state = TtsState.stopped;
      onComplete?.call();
    });

    _tts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      onError?.call(msg);
    });
  }

  Future<void> speak(String text) async {
    if (_state == TtsState.playing) {
      await stop();
    }

    try {
      await _tts.speak(text);
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> stop() async {
    _state = TtsState.stopped;
    await _tts.stop();
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  void dispose() {
    _tts.stop();
  }
}
