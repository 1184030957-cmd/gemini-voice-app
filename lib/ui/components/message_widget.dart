import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageWidget extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageWidget({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? (isDarkMode ? Colors.blue[700] : Colors.blue[100])
              : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(
            color: isUser
                ? (isDarkMode ? Colors.white : Colors.black87)
                : (isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}
