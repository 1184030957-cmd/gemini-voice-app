import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ApiService {
  final String apiUrl;
  final String apiKey;
  final String model;

  ApiService({required this.apiUrl, required this.apiKey, required this.model});

  Future<String> sendMessage(List<Message> messages) async {
    final formattedMessages = messages.map((m) {
      return {"role": m.role, "content": m.content};
    }).toList();

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": model,
        "messages": formattedMessages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception("API 错误: ${response.statusCode} - ${response.body}");
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": model,
          "messages": [{"role": "user", "content": "test"}],
          "max_tokens": 1,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
