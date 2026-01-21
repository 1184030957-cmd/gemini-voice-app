import 'package:flutter/material.dart';
import '../../models/message.dart';

class InputWidget extends StatefulWidget {
  final TextEditingController controller;
  final ChatState chatState;
  final Function(String) onSend;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;

  const InputWidget({
    super.key,
    required this.controller,
    required this.chatState,
    required this.onSend,
    required this.onStartListening,
    required this.onStopListening,
  });

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isListening = widget.chatState == ChatState.listening;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  ),
                  maxLines: 4,
                  minLines: 1,
                  enabled: widget.chatState != ChatState.thinking &&
                      widget.chatState != ChatState.speaking,
                  onChanged: (text) {
                    if (widget.chatState == ChatState.listening) {
                      widget.onStopListening();
                    }
                  },
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      widget.onSend(text.trim());
                      widget.controller.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: widget.chatState == ChatState.thinking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: widget.chatState == ChatState.thinking ||
                        widget.chatState == ChatState.speaking
                    ? null
                    : () {
                        final text = widget.controller.text.trim();
                        if (text.isNotEmpty) {
                          widget.onSend(text);
                          widget.controller.clear();
                        }
                      },
                color: Colors.blue,
                iconSize: 28,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTapDown: (_) {
              if (widget.chatState != ChatState.thinking &&
                  widget.chatState != ChatState.speaking) {
                widget.onStartListening();
              }
            },
            onTapUp: (_) {
              if (widget.chatState == ChatState.listening) {
                widget.onStopListening();
              }
            },
            onTapCancel: () {
              if (widget.chatState == ChatState.listening) {
                widget.onStopListening();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isListening ? Colors.red : Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isListening ? Colors.red : Colors.blue)
                        .withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isListening ? '松开发送' : '按住说话',
            style: TextStyle(
              fontSize: 12,
              color: isListening ? Colors.red : Colors.grey[600],
              fontWeight: isListening ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
