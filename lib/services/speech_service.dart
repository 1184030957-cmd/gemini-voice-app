import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

enum SpeechState {
  notAvailable,
  permissionDenied,
  initializing,
  available,
  listening,
  recognizing,
  stopped,
  error
}

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  SpeechState _state = SpeechState.notAvailable;
  String _lastWords = '';
  String _errorMessage = '';
  Timer? _silenceTimer;
  bool _isInitialized = false;

  SpeechState get state => _state;
  String get lastWords => _lastWords;
  String get errorMessage => _errorMessage;

  Function(SpeechState)? onStateChanged;
  Function(String)? onResult;
  Function(String)? onStatus;
  Function(String)? onError;

  Future<bool> initialize() async {
    _updateState(SpeechState.initializing);
    _errorMessage = '';
    _isInitialized = false;

    try {
      final micStatus = await Permission.microphone.status;

      if (!micStatus.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          _errorMessage = '麦克风权限被拒绝。请前往手机设置 → 应用设置 → Gemini Voice → 权限 → 开启麦克风权限';
          _updateState(SpeechState.permissionDenied);
          return false;
        }
      }

      if (micStatus.isPermanentlyDenied) {
        _errorMessage = '麦克风权限已被永久拒绝。请前往手机设置 → 应用设置 → Gemini Voice → 权限 → 开启麦克风权限';
        _updateState(SpeechState.permissionDenied);
        return false;
      }

      bool hasSpeech = await _speech.initialize(
        onError: (error) {
          if (error.errorMsg.contains('not available')) {
            _errorMessage = '当前设备不支持语音识别功能。请使用文字输入或尝试更新系统。';
          } else if (error.errorMsg.contains('permission')) {
            _errorMessage = '麦克风权限被拒绝。请前往手机设置开启权限。';
          } else {
            _errorMessage = '语音服务错误: ${error.errorMsg}';
          }
          _updateState(SpeechState.error);
          onError?.call(_errorMessage);
        },
        onStatus: (status) {
          onStatus?.call(status);
          if (status == 'done' || status == 'notListening') {
            if (_state == SpeechState.listening) {
              _updateState(SpeechState.recognizing);
            }
          }
        },
      );

      if (hasSpeech) {
        _isInitialized = true;
        _updateState(SpeechState.available);
        
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              _lastWords = result.recognizedWords;
              _stopListening();
              onResult?.call(_lastWords);
            }
          },
          localeId: "zh_CN",
          partialResults: false,
        );
        
        await _speech.stop();
        return true;
      } else {
        _errorMessage = '语音服务初始化失败。您的设备可能不支持语音识别功能。';
        _updateState(SpeechState.notAvailable);
        return false;
      }
    } catch (e) {
      _errorMessage = '语音服务初始化异常: $e。请尝试重启应用或更新系统。';
      _updateState(SpeechState.error);
      return false;
    }
  }

  void _updateState(SpeechState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call(newState);
    }
  }

  Future<bool> checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    return micStatus.isGranted;
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  bool startListening({Function(String)? onPartialResult}) {
    if (_state == SpeechState.permissionDenied) {
      _errorMessage = '请先开启麦克风权限';
      onError?.call(_errorMessage);
      return false;
    }

    if (_state == SpeechState.notAvailable || _state == SpeechState.error) {
      onError?.call(_errorMessage);
      return false;
    }

    if (_state == SpeechState.initializing) {
      onError?.call('语音服务正在初始化，请稍候...');
      return false;
    }

    if (_state == SpeechState.listening) {
      return true;
    }

    _lastWords = '';
    _updateState(SpeechState.listening);

    try {
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _lastWords = result.recognizedWords;
            _stopListening();
            onResult?.call(_lastWords);
          } else if (onPartialResult != null && result.recognizedWords.isNotEmpty) {
            onPartialResult(result.recognizedWords);
          }
        },
        listenFor: Duration(seconds: 60),
        pauseFor: Duration(seconds: 4),
        localeId: "zh_CN",
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );
      return true;
    } catch (e) {
      _errorMessage = '启动监听失败: $e';
      _updateState(SpeechState.error);
      return false;
    }
  }

  void _stopListening() {
    try {
      _speech.stop();
    } catch (e) {
      // 忽略停止错误
    }
    _silenceTimer?.cancel();
    _updateState(SpeechState.stopped);
  }

  void stopListening() {
    _stopListening();
  }

  void onSilenceDetected() {
    _silenceTimer?.cancel();
    if (_state == SpeechState.listening) {
      _silenceTimer = Timer(const Duration(seconds: 2), () {
        if (_state == SpeechState.listening && _lastWords.isNotEmpty) {
          _stopListening();
          onResult?.call(_lastWords);
        } else if (_state == SpeechState.listening) {
          _stopListening();
        }
      });
    }
  }

  void cancelListening() {
    try {
      _speech.cancel();
    } catch (e) {
      // 忽略取消错误
    }
    _silenceTimer?.cancel();
    _updateState(SpeechState.stopped);
  }

  void resetState() {
    if (_state == SpeechState.listening || _state == SpeechState.recognizing) {
      _stopListening();
    }
    _updateState(SpeechState.available);
  }

  void dispose() {
    _silenceTimer?.cancel();
    try {
      _speech.cancel();
    } catch (e) {
      // 忽略错误
    }
  }

  String getStateMessage() {
    switch (_state) {
      case SpeechState.notAvailable:
        return '语音功能不可用';
      case SpeechState.permissionDenied:
        return '麦克风权限被拒绝';
      case SpeechState.initializing:
        return '正在初始化...';
      case SpeechState.available:
        return '准备就绪';
      case SpeechState.listening:
        return '正在聆听...';
      case SpeechState.recognizing:
        return '识别中...';
      case SpeechState.stopped:
        return '已停止';
      case SpeechState.error:
        return _errorMessage;
    }
  }
}
