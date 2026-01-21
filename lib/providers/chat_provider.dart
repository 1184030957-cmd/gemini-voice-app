import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/config.dart';
import '../services/api_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/storage_service.dart';

class ChatProvider with ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();
  final StorageService _storageService = StorageService();

  List<Message> _messages = [];
  ChatState _chatState = ChatState.idle;
  String _currentInput = '';
  String _errorMessage = '';
  ApiConfig? _config;

  List<Message> get messages => _messages;
  ChatState get chatState => _chatState;
  String get currentInput => _currentInput;
  String get errorMessage => _errorMessage;

  ChatProvider() {
    _initServices();
  }

  void _initServices() {
    _speechService.initialize();
    _ttsService.setSpeechRate(0.5);

    _speechService.onResult = (text) {
      if (text.isNotEmpty) {
        _sendMessage(text);
      } else {
        _updateState(ChatState.idle);
      }
    };

    _speechService.onStatus = (status) {
      if (status == 'done' && _chatState == ChatState.listening) {
        _updateState(ChatState.recognizing);
      }
    };

    _speechService.onError = (error) {
      _setError('语音识别错误: $error');
      _updateState(ChatState.error);
    };

    _ttsService.onComplete = () {
      _updateState(ChatState.idle);
      _speechService.startListening();
    };

    _ttsService.onError = (error) {
      _setError('语音合成错误: $error');
      _updateState(ChatState.error);
    };
  }

  Future<void> loadConfig() async {
    _config = await _storageService.getConfig();
    if (_config != null) {
      _messages = await _storageService.getMessages();
      notifyListeners();
    }
  }

  ApiConfig? getConfig() => _config;

  Future<void> saveConfig(ApiConfig config) async {
    await _storageService.saveConfig(config);
    _config = config;
    notifyListeners();
  }

  void _updateState(ChatState newState) {
    _chatState = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
  }

  void setInput(String text) {
    _currentInput = text;
    notifyListeners();
  }

  void startListening() {
    if (_chatState == ChatState.thinking || _chatState == ChatState.speaking) {
      _ttsService.stop();
    }
    _clearError();
    _speechService.startListening();
    _updateState(ChatState.listening);
  }

  void stopListening() {
    _speechService.stopListening();
    if (_chatState == ChatState.listening || _chatState == ChatState.recognizing) {
      _updateState(ChatState.idle);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    final userMessage = Message(role: 'user', content: text);
    _messages.add(userMessage);
    _currentInput = '';
    _updateState(ChatState.thinking);
    notifyListeners();

    try {
      if (_config == null || !_config!.isValid) {
        throw Exception('请先配置 API 信息');
      }

      final apiService = ApiService(
        apiUrl: _config!.apiUrl,
        apiKey: _config!.apiKey,
        model: _config!.model,
      );

      final reply = await apiService.sendMessage(_messages);

      final assistantMessage = Message(role: 'assistant', content: reply);
      _messages.add(assistantMessage);
      await _storageService.saveMessages(_messages);

      notifyListeners();

      _updateState(ChatState.speaking);
      await _ttsService.speak(reply);
    } catch (e) {
      _setError(e.toString());
      _messages.add(Message(
        role: 'assistant',
        content: '错误: ${e.toString()}',
      ));
      _updateState(ChatState.error);
    }
  }

  void sendTextMessage(String text) {
    if (text.isNotEmpty && _chatState != ChatState.thinking) {
      _sendMessage(text);
    }
  }

  void clearMessages() {
    _messages.clear();
    _storageService.clearMessages();
    notifyListeners();
  }

  void clearError() {
    _clearError();
    if (_chatState == ChatState.error) {
      _updateState(ChatState.idle);
    }
  }

  void setSpeechRate(double rate) {
    _ttsService.setSpeechRate(rate);
  }

  void dispose() {
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
