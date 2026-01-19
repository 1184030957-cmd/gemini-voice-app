import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ConfigPage(),
    );
  }
}

class ConfigPage extends StatefulWidget {
  final String? initialApiUrl;
  final String? initialApiKey;
  final String? initialModel;

  ConfigPage({this.initialApiUrl, this.initialApiKey, this.initialModel});

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

    if (widget.initialApiUrl != null) {
      _apiUrlController.text = widget.initialApiUrl!;
      _apiKeyController.text = widget.initialApiKey!;
      _modelController.text = widget.initialModel!;
      setState(() => _isLoading = false);
      return;
    }

    final apiUrl = prefs.getString('api_url');
    final apiKey = prefs.getString('api_key');
    final model = prefs.getString('model');

    if (apiUrl != null && apiKey != null && model != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(apiUrl: apiUrl, apiKey: apiKey, model: model),
        ),
      );
    } else {
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
        builder: (context) => ChatPage(
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
      return Scaffold(body: Center(child: CircularProgressIndicator()));
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
              decoration: InputDecoration(labelText: 'API 地址', border: OutlineInputBorder()),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(labelText: '模型名称', border: OutlineInputBorder()),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveAndContinue,
              child: Text('保存并开始使用'),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String apiUrl;
  final String apiKey;
  final String model;

  ChatPage({required this.apiUrl, required this.apiKey, required this.model});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _messages = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("zh-CN");
    _tts.setSpeechRate(0.5);
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isProcessing = true;
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(widget.apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.apiKey}",
        },
        body: jsonEncode({
          "model": widget.model,
          "messages": _messages.map((m) => {"role": m["role"], "content": m["text"]}).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add({"role": "assistant", "text": reply});
          _isProcessing = false;
        });

        _scrollToBottom();
        await _tts.speak(reply);
      } else {
        throw Exception("API 错误: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "text": "错误: $e"});
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _editConfig() async {
    final prefs = await SharedPreferences.getInstance();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConfigPage(
          initialApiUrl: prefs.getString('api_url') ?? '',
          initialApiKey: prefs.getString('api_key') ?? '',
          initialModel: prefs.getString('model') ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gemini 对话'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _editConfig,
            tooltip: '修改配置',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
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
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _sendMessage(text);
                        _textController.clear();
                      }
                    },
                    enabled: !_isProcessing,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: _isProcessing ? CircularProgressIndicator() : Icon(Icons.send),
                  onPressed: _isProcessing
                      ? null
                      : () {
                          if (_textController.text.isNotEmpty) {
                            _sendMessage(_textController.text);
                            _textController.clear();
                          }
                        },
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
