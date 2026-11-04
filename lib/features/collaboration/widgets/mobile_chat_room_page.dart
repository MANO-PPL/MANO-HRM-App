import 'package:flutter/material.dart';
import 'package:flutter_application/features/collaboration/core/chat_models.dart';
import 'package:flutter_application/features/collaboration/widgets/chat_workspace_widget.dart';

class MobileChatRoomPage extends StatelessWidget {
  final ChatRoom room;

  const MobileChatRoomPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ChatWorkspaceWidget(
          initialRoom: room,
          showBackButton: true,
        ),
      ),
    );
  }
}

// [mod:2026-02-23T17:30:00+05:30]
