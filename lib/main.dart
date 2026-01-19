import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final apiUrl = prefs.getString('api_url');
    final apiKey = prefs.getString('api_key');
    final model = prefs.getString('model');

    // 如果有传入的初始值，使用初始值
    if (widget.initialApiUrl != null) {
      _apiUrlController.text = widget.initialApiUrl!;
      _apiKeyController.text = widget.initialApiKey!;
      _modelController.text = widget.initialModel!;
      setState(() => _isLoading = false);
      return;
    }

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
  final TextEditingController _textController = TextEditingController();

  List<Map<String, String>> _messages = [];
  String _statusText = "点击麦克风开始说话";
  bool _isListening = false;
  bool _isProcessing = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onError: (error) {
          print("语音识别错误: ${error.errorMsg}");
          setState(() {
            _statusText = "语音错误: ${error.errorMsg}";
          });
        },
        onStatus: (status) {
          print("语音识别状态: $status");
          if (status == "notListening") {
            setState(() {
              _isListening = false;
            });
          }
        },
      );

      print("语音识别初始化结果: $available");

      setState(() {
        _speechAvailable = available;
        if (!available) {
          _statusText = "语音识别不可用\n可能需要安装 Google 语音输入\n或使用文字输入";
        }
      });
    } catch (e) {
      print("语音识别初始化异常: $e");
      setState(() {
        _speechAvailable = false;
        _statusText = "语音识别初始化失败: $e";
      });
    }
  }

  void _initTts() async {
    await _tts.setLanguage("zh-CN");
    await _tts.setSpeechRate(0.5);
  }

  void _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语音识别不可用，请检查麦克风权限')),
      );
      return;
    }

    if (!_isListening && !_isProcessing) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _statusText = "正在听...";
        });
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              _stopListening();
              _sendMessage(result.recognizedWords);
            }
          },
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 3),
          localeId: "zh_CN",
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法启动语音识别')),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
        _statusText = "点击麦克风开始说话";
      });
    }
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

  Future<void> _editConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('api_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';
    final model = prefs.getString('model') ?? '';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConfigPage(
          initialApiUrl: apiUrl,
          initialApiKey: apiKey,
          initialModel: model,
        ),
      ),
    );
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

      // 检查 GitHub Releases
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/1184030957-cmd/gemini-voice-app/releases/latest'),
      );

      Navigator.pop(context); // 关闭加载对话框

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final downloadUrl = data['assets'][0]['browser_download_url'] as String;
        final releaseNotes = data['body'] as String;

        if (_compareVersions(latestVersion, currentVersion) > 0) {
          // 有新版本
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
                  onPressed: () async {
                    Navigator.pop(context);
                    // 使用镜像加速下载
                    final mirrorUrl = 'https://ghproxy.com/$downloadUrl';
                    final uri = Uri.parse(mirrorUrl);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('正在打开浏览器下载...')),
                    );

                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        throw Exception('无法打开下载链接');
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('打开下载失败: $e')),
                      );
                    }
                  },
                  child: Text('立即更新'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已是最新版本 $currentVersion')),
          );
        }
      } else {
        throw Exception('无法获取版本信息');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gemini 语音对话'),
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
                Text(_statusText, style: TextStyle(fontSize: 14), textAlign: TextAlign.center),
                SizedBox(height: 12),
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
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {
                        if (_textController.text.isNotEmpty) {
                          _sendMessage(_textController.text);
                          _textController.clear();
                        }
                      },
                      color: Colors.blue,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : (_speechAvailable ? Colors.blue : Colors.grey),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 35,
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
