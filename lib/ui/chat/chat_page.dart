import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';
import '../../services/update_service.dart';
import '../../utils/validators.dart';
import '../components/message_widget.dart';
import '../components/input_widget.dart';
import '../components/state_indicator.dart';
import '../config/config_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConfig();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showUpdateDialog(Map<String, dynamic> releaseInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 ${releaseInfo['version']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(releaseInfo['releaseNotes'] ?? '暂无更新说明'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final downloadUrl = releaseInfo['downloadUrl'] as String?;
              if (downloadUrl != null) {
                _startDownload(downloadUrl);
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  void _startDownload(String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DownloadProgressDialog(),
    );

    _updateService.downloadUpdate(
      downloadUrl: downloadUrl,
      onProgress: (received, total) {
        if (mounted) {
          final progress = (received / total * 100).round();
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => DownloadProgressDialog(
              initialProgress: progress,
              received: received,
              total: total,
            ),
          );
        }
      },
      onComplete: (filePath) {
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InstallReadyDialog(filePath: filePath),
            ),
          );
        }
      },
        }
      },
      onError: (error) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载失败: $error')),
          );
        }
      },
    );
  }

  Future<void> _checkUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final releaseInfo = await _updateService.getLatestReleaseInfo();

      Navigator.pop(context);

      if (releaseInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查更新失败')),
        );
        return;
      }

      final latestVersion = releaseInfo['version'] as String;
      final comparison = _updateService.compareVersions(latestVersion, currentVersion);

      if (comparison > 0) {
        _showUpdateDialog(releaseInfo);
      } else if (comparison == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前已是最新版本 v$currentVersion')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查更新失败')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败')),
      );
    }
  }

  void _editConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfigPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini 对话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: _checkUpdate,
            tooltip: '检查更新',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _editConfig,
            tooltip: '设置',
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatProvider.chatState != ChatState.idle)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ChatStateIndicator(state: chatProvider.chatState),
            ),
          Expanded(
            child: chatProvider.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '开始与 AI 对话吧',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '按住麦克风按钮开始说话',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      final isUser = message.role == 'user';
                      return MessageWidget(message: message, isUser: isUser);
                    },
                  ),
          ),
          if (chatProvider.errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatProvider.errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => chatProvider.clearError(),
                    child: const Text('关闭', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          InputWidget(
            controller: _textController,
            chatState: chatProvider.chatState,
            onSend: (text) => chatProvider.sendTextMessage(text),
            onStartListening: () => chatProvider.startListening(),
            onStopListening: () => chatProvider.stopListening(),
          ),
        ],
      ),
    );
  }
}

class DownloadProgressDialog extends StatefulWidget {
  final int initialProgress;
  final int received;
  final int total;
  final String filePath;

  const DownloadProgressDialog({
    super.key,
    this.initialProgress = 0,
    this.received = 0,
    this.total = 0,
    this.filePath = '',
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  int _progress = 0;
  int _received = 0;
  int _total = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _received = widget.received;
    _total = widget.total;
  }

  void updateProgress(int received, int total) {
    if (mounted) {
      setState(() {
        _received = received;
        _total = total;
        _progress = total > 0 ? (received * 100 / total).round() : 0;
      });
    }
  }

  void completeDownload() {
    if (mounted) {
      setState(() {
        _progress = 100;
        _isComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String receivedText = _formatBytes(_received);
    String totalText = _formatBytes(_total);

    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: Text(_isComplete ? '下载完成' : '正在下载更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 16),
            Text('$_progress%'),
            const SizedBox(height: 8),
            Text('$receivedText / $totalText'),
            const SizedBox(height: 8),
            Text(
              _isComplete ? '点击安装按钮开始安装' : '请稍候...',
              style: TextStyle(
                color: _isComplete ? Colors.green : Colors.grey,
                fontWeight: _isComplete ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_isComplete)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InstallReadyDialog(filePath: widget.filePath),
                  ),
                );
              },
              child: const Text('安装'),
            )
          else
            const Text('下载中...'),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class InstallReadyDialog extends StatelessWidget {
  final String filePath;

  const InstallReadyDialog({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下载完成'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text('APK 已下载完成'),
          const SizedBox(height: 8),
          Text(
            '安装包位置:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            filePath,
            style: TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '点击"立即安装"开始更新',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            context.read<UpdateService>().installApk(filePath).catchError((e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('安装失败: $e')),
              );
            });
          },
          child: const Text('立即安装'),
        ),
      ],
    );
  }
}
