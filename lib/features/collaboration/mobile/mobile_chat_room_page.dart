import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_models.dart';
import '../widgets/chat_workspace_widget.dart';

class MobileChatRoomPage extends StatelessWidget {
  final ChatRoom room;

  const MobileChatRoomPage({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Conversation",
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: ChatWorkspaceWidget(initialRoom: room),
      ),
    );
  }
}
