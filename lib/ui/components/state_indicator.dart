import 'package:flutter/material.dart';
import '../../models/message.dart';

class ChatStateIndicator extends StatelessWidget {
  final ChatState state;

  const ChatStateIndicator({super.key, required this.state});

  String _getStateText() {
    switch (state) {
      case ChatState.idle:
        return '准备就绪';
      case ChatState.listening:
        return '正在聆听...';
      case ChatState.recognizing:
        return '识别中...';
      case ChatState.thinking:
        return 'AI 思考中...';
      case ChatState.speaking:
        return 'AI 说话中...';
      case ChatState.error:
        return '出错了';
    }
  }

  Color _getStateColor() {
    switch (state) {
      case ChatState.idle:
        return Colors.grey;
      case ChatState.listening:
        return Colors.red;
      case ChatState.recognizing:
        return Colors.orange;
      case ChatState.thinking:
        return Colors.blue;
      case ChatState.speaking:
        return Colors.green;
      case ChatState.error:
        return Colors.red;
    }
  }

  IconData _getStateIcon() {
    switch (state) {
      case ChatState.idle:
        return Icons.mic;
      case ChatState.listening:
        return Icons.mic;
      case ChatState.recognizing:
        return Icons.search;
      case ChatState.thinking:
        return Icons.auto_awesome;
      case ChatState.speaking:
        return Icons.volume_up;
      case ChatState.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStateColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStateColor().withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state != ChatState.idle && state != ChatState.error)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _getStateColor(),
              ),
            )
          else
            Icon(_getStateIcon(), size: 16, color: _getStateColor()),
          const SizedBox(width: 8),
          Text(
            _getStateText(),
            style: TextStyle(
              color: _getStateColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
