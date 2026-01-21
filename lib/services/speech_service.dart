import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

enum SpeechState {
  notAvailable,
  available,
  listening,
  recognizing,
  stopped
}

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  SpeechState _state = SpeechState.notAvailable;
  String _lastWords = '';
  Timer? _silenceTimer;

  SpeechState get state => _state;
  String get lastWords => _lastWords;

  Function(String)? onResult;
  Function(String)? onStatus;
  Function(String)? onError;

  Future<void> initialize() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _state = SpeechState.notAvailable;
        return;
      }

      bool available = await _speech.initialize(
        onError: (error) {
          _state = SpeechState.stopped;
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          onStatus?.call(status);
          if (status == 'done' || status == 'notListening') {
            if (_state == SpeechState.listening) {
              _state = SpeechState.recognizing;
            }
          }
        },
      );

      _state = available ? SpeechState.available : SpeechState.notAvailable;
    } catch (e) {
      _state = SpeechState.notAvailable;
    }
  }

  void startListening({Function(String)? onPartialResult}) {
    if (_state != SpeechState.available && _state != SpeechState.recognizing) {
      return;
    }

    _lastWords = '';
    _state = SpeechState.listening;

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _lastWords = result.recognizedWords;
          _stopListening();
          onResult?.call(_lastWords);
        } else if (onPartialResult != null) {
          onPartialResult.call(result.recognizedWords);
        }
      },
      listenFor: Duration(seconds: 60),
      pauseFor: Duration(seconds: 3),
      localeId: "zh_CN",
      partialResults: true,
    );
  }

  void _stopListening() {
    _speech.stop();
    _state = SpeechState.stopped;
    _silenceTimer?.cancel();
  }

  void stopListening() {
    _stopListening();
  }

  void onVoiceInputDetected() {
    _silenceTimer?.cancel();
    if (_state == SpeechState.recognizing || _state == SpeechState.available) {
      startListening();
    }
  }

  void onSilenceDetected() {
    _silenceTimer?.cancel();
    if (_state == SpeechState.listening) {
      _silenceTimer = Timer(Duration(seconds: 2), () {
        if (_state == SpeechState.listening && _lastWords.isNotEmpty) {
          _stopListening();
          onResult?.call(_lastWords);
        }
      });
    }
  }

  void dispose() {
    _speech.cancel();
    _silenceTimer?.cancel();
  }
}
