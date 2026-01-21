import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';
import '../models/message.dart';

class StorageService {
  static const String _keyApiUrl = 'api_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyModel = 'model';
  static const String _keyMessages = 'chat_messages';

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveConfig(ApiConfig config) async {
    await _secureStorage.write(key: _keyApiUrl, value: config.apiUrl);
    await _secureStorage.write(key: _keyApiKey, value: config.apiKey);
    await _secureStorage.write(key: _keyModel, value: config.model);
  }

  Future<ApiConfig?> getConfig() async {
    final apiUrl = await _secureStorage.read(key: _keyApiUrl);
    final apiKey = await _secureStorage.read(key: _keyApiKey);
    final model = await _secureStorage.read(key: _keyModel);

    if (apiUrl == null || apiKey == null || model == null) {
      return null;
    }

    return ApiConfig(
      apiUrl: apiUrl,
      apiKey: apiKey,
      model: model,
    );
  }

  Future<void> clearConfig() async {
    await _secureStorage.deleteAll();
  }

  Future<void> saveMessages(List<Message> messages) async {
    final prefs = await _prefsInstance;
    final messagesData = messages.map((m) => m.toMap()).toList();
    await prefs.setString(_keyMessages, jsonEncode(messagesData));
  }

  Future<List<Message>> getMessages() async {
    final prefs = await _prefsInstance;
    final messagesString = prefs.getString(_keyMessages);
    if (messagesString == null) return [];

    try {
      final messagesData = jsonDecode(messagesString) as List;
      return messagesData.map((m) => Message.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> clearMessages() async {
    final prefs = await _prefsInstance;
    await prefs.remove(_keyMessages);
  }
}
