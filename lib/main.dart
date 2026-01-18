import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Voice Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ConfigPage(),
    );
  }
}

// 配置页面 - 首次打开或修改设置
class ConfigPage extends StatefulWidget {
  @override
  _ConfigPageState createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('https://doubao.zwchat.cn/v1/chat/completions');
    final apiKey = prefs.getString('api_key');
    final model = prefs.getString('gemini-3-flash-preview');

    if (apiUrl != null && apiKey != null && model != null) {
      // 已有配置，直接进入聊天页面
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceChatPage(
            apiUrl: apiUrl,
            apiKey: apiKey,
            model: model,
          ),
        ),
      );
    } else {
      // 设置默认值
      _apiUrlController.text = 'https://doubao.zwchat.cn/v1/chat/completions';
      _modelController.text = 'gemini-3-flash-preview';
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_apiUrlController.text.isEmpty || _apiKeyController.text.isEmpty || _modelController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请填写所有配置项')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', _apiUrlController.text);
    await prefs.setString('api_key', _apiKeyController.text);
    await prefs.setString('model', _modelController.text);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceChatPage(
          apiUrl: _apiUrlController.text,
          apiKey: _apiKeyController.text,
          model: _modelController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('配置 API')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _apiUrlController,
              decoration: InputDecoration(
                labelText: 'API 地址',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: '模型名称',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveAndContinue,
              child: Text('保存并开始使用'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 语音聊天页面
class VoiceChatPage extends StatefulWidget {
  final String apiUrl;
  final String apiKey;
  final String model;

  VoiceChatPage({required this.apiUrl, required this.apiKey, required this.model});

  @override
  _VoiceChatPageState createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  List<Map<String, String>> _messages = [];
  String _statusText = "点击麦克风开始说话";
  bool _isListening = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _initTts() async {
    await _tts.setLanguage("zh-CN");
    await _tts.setSpeechRate(0.5);
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _statusText = "正在听...";
        });
        _speech.listen(onResult: (result) {
          if (result.finalResult) {
            _sendMessage(result.recognizedWords);
          }
        });
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _statusText = "点击麦克风开始说话";
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isProcessing = true;
      _statusText = "思考中...";
    });

    try {
      final response = await http.post(
        Uri.parse(widget.apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.apiKey}",
        },
        body: jsonEncode({
          "model": widget.model,
          "messages": _messages.map((m) => {
            "role": m["role"],
            "content": m["text"]
          }).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add({"role": "assistant", "text": reply});
          _statusText = "正在播放回复...";
        });

        await _tts.speak(reply);

        setState(() {
          _statusText = "点击麦克风开始说话";
          _isProcessing = false;
        });
      } else {
        throw Exception("API 错误: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _statusText = "错误: $e";
        _isProcessing = false;
      });
    }
  }

  Future<void> _clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ConfigPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gemini 语音对话'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _clearConfig,
            tooltip: '重新配置',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg["text"]!),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_statusText, style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
