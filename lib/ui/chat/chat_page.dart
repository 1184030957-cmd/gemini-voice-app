import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';
import '../../services/update_service.dart';
import '../../utils/validators.dart';
import '../components/message_widget.dart';
import '../components/input_widget.dart';
import '../components/state_indicator.dart';
import 'config_page.dart';

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
                _updateService.downloadUpdate(downloadUrl);
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final releaseInfo = await _updateService.getLatestReleaseInfo();
    Navigator.pop(context);

    if (releaseInfo != null) {
      _showUpdateDialog(releaseInfo);
    } else {
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
