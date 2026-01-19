import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';

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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _messages = [];
  bool _isProcessing = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
    _tts.setLanguage("zh-CN");
    _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当 App 从后台回到前台时，确保状态正常
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<void> _initSpeech() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() => _speechAvailable = false);
        return;
      }

      bool available = await _speech.initialize(
        onError: (error) => print("语音错误: ${error.errorMsg}"),
        onStatus: (status) {
          if (status == "notListening" && _isListening) {
            setState(() => _isListening = false);
          }
        },
      );

      setState(() => _speechAvailable = available);
    } catch (e) {
      setState(() => _speechAvailable = false);
    }
  }

  void _startListening() async {
    if (!_speechAvailable || _isListening || _isProcessing) return;

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _sendMessage(result.recognizedWords);
            setState(() => _isListening = false);
          }
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        localeId: "zh_CN",
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
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

  Future<void> _checkUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/1184030957-cmd/gemini-voice-app/releases/latest'),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final downloadUrl = data['assets'][0]['browser_download_url'] as String;

        if (_compareVersions(latestVersion, currentVersion) > 0) {
          _showUpdateDialog(latestVersion, currentVersion, downloadUrl, data['body'] as String);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已是最新版本 $currentVersion')),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败，请访问 GitHub Releases 手动下载')),
      );
    }
  }

  void _showUpdateDialog(String latestVersion, String currentVersion, String downloadUrl, String releaseNotes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 $latestVersion'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前版本: $currentVersion'),
              SizedBox(height: 8),
              Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(releaseNotes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadUpdate(downloadUrl);
            },
            child: Text('立即更新'),
          ),
        ],
      ),
    );
  }

  void _downloadUpdate(String downloadUrl) async {
    final mirrorUrl = 'https://ghproxy.com/$downloadUrl';
    final uri = Uri.parse(mirrorUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开下载失败，请访问 GitHub Releases 手动下载')),
      );
    }
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
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
            icon: Icon(Icons.system_update),
            onPressed: _checkUpdate,
            tooltip: '检查更新',
          ),
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
            child: Column(
              children: [
                Row(
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
                      icon: _isProcessing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.send),
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
                if (_speechAvailable) ...[
                  SizedBox(height: 12),
                  GestureDetector(
                    onTapDown: (_) => _startListening(),
                    onTapUp: (_) => _stopListening(),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mic, color: Colors.white, size: 30),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _isListening ? '正在听...' : '按住说话',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
