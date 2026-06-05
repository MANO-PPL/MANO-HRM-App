import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../../../../shared/services/socket_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/widgets/interactive_image_viewer.dart';
import '../../../../shared/constants/api_constants.dart';
import '../../../../shared/navigation/navigation_controller.dart';
import 'chat_dialogs.dart';

class ChatWorkspaceWidget extends StatefulWidget {
  final ChatRoom initialRoom;
  final Function(ChatMessage)? onMessageSentOrReceived;

  const ChatWorkspaceWidget({
    super.key,
    required this.initialRoom,
    this.onMessageSentOrReceived,
  });

  @override
  State<ChatWorkspaceWidget> createState() => _ChatWorkspaceWidgetState();
}

class _ChatWorkspaceWidgetState extends State<ChatWorkspaceWidget> {
  late ChatRoom _room;
  late ChatService _chatService;
  SocketService? _socketService;
  late int _currentUserId;

  final List<ChatMessage> _messages = [];
  bool _isLoadingMessages = true;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // Typing state
  final Map<int, String> _typingUsers = {};
  Timer? _typingTimeoutTimer;
  bool _isTyping = false;

  // Mention Autocomplete
  bool _showMentionSuggestions = false;
  List<ChatMember> _coworkers = [];
  List<ChatMember> _filteredCoworkers = [];

  // Attachment upload
  PlatformFile? _pickedFile;
  bool _isUploading = false;
  Map<String, dynamic>? _uploadedAttachment;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _chatService = context.read<ChatService>();
    _currentUserId = int.tryParse(context.read<AuthService>().user?.id ?? '') ?? 0;
    _fetchHistory();
    _fetchCoworkers();
    _setupSocketListeners();
  }

  @override
  void didUpdateWidget(covariant ChatWorkspaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRoom.roomId != widget.initialRoom.roomId) {
      _leaveCurrentRoomSocket(oldWidget.initialRoom.roomId);
      setState(() {
        _room = widget.initialRoom;
        _messages.clear();
        _isLoadingMessages = true;
        _pickedFile = null;
        _uploadedAttachment = null;
        _showMentionSuggestions = false;
        _typingUsers.clear();
      });
      _fetchHistory();
      _joinCurrentRoomSocket();
    }
  }

  @override
  void dispose() {
    _leaveCurrentRoomSocket(_room.roomId);
    _typingTimeoutTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final list = await _chatService.getMessages(_room.roomId);
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(list);
        _isLoadingMessages = false;
      });
      _scrollToBottom();
      _chatService.markAsRead(_room.roomId);
    }
  }

  Future<void> _fetchCoworkers() async {
    final list = await _chatService.getCoworkers();
    if (mounted) {
      setState(() {
        _coworkers = list;
      });
    }
  }

  void _setupSocketListeners() {
    _socketService = context.read<SocketService>();
    _joinCurrentRoomSocket();

    final s = _socketService?.socket;
    if (s == null) return;

    s.on('message_received', _onSocketMessageReceived);
    s.on('user_typing', _onSocketUserTyping);
    s.on('user_stop_typing', _onSocketUserStopTyping);
    s.on('group_updated', _onSocketGroupUpdated);
  }

  void _joinCurrentRoomSocket() {
    final s = _socketService?.socket;
    if (s != null && s.connected) {
      debugPrint("🔌 Socket: Joining room ${_room.roomId}");
      s.emit('join_room', _room.roomId);
    }
  }

  void _leaveCurrentRoomSocket(int roomId) {
    final s = _socketService?.socket;
    if (s != null && s.connected) {
      debugPrint("🔌 Socket: Leaving room $roomId");
      s.emit('leave_room', roomId);
    }
  }

  void _onSocketMessageReceived(dynamic data) {
    if (!mounted) return;
    try {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      if (msg.roomId == _room.roomId) {
        setState(() {
          // Reconcile optimistic messages
          final index = _messages.indexWhere((m) =>
              m.messageId == msg.messageId ||
              (m.status == 'sending' &&
                  m.senderId == msg.senderId &&
                  m.messageText == msg.messageText));

          if (index != -1) {
            _messages[index] = msg;
          } else {
            _messages.add(msg);
          }
        });
        _scrollToBottom();
        _chatService.markAsRead(_room.roomId);
        widget.onMessageSentOrReceived?.call(msg);
      }
    } catch (e) {
      debugPrint("Error parsing socket message: $e");
    }
  }

  void _onSocketUserTyping(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final roomId = map['roomId'] is String ? int.parse(map['roomId']) : map['roomId'];
      final userId = map['userId'] is String ? int.parse(map['userId']) : map['userId'];
      final username = map['username'] ?? 'Someone';

      if (roomId == _room.roomId && userId != _currentUserId) {
        setState(() {
          _typingUsers[userId] = username;
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _onSocketUserStopTyping(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final roomId = map['roomId'] is String ? int.parse(map['roomId']) : map['roomId'];
      final userId = map['userId'] is String ? int.parse(map['userId']) : map['userId'];

      if (roomId == _room.roomId) {
        setState(() {
          _typingUsers.remove(userId);
        });
      }
    } catch (_) {}
  }

  void _onSocketGroupUpdated(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final roomId = map['room_id'] is String ? int.parse(map['room_id']) : map['room_id'];
      if (roomId == _room.roomId) {
        final updatedRoom = ChatRoom.fromJson(map);
        setState(() {
          _room = updatedRoom;
        });
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onInputChanged(String text) {
    _sendTypingIndicator();

    final lastAtIndex = text.lastIndexOf('@');
    if (lastAtIndex != -1 && (lastAtIndex == 0 || text[lastAtIndex - 1] == ' ')) {
      final query = text.substring(lastAtIndex + 1);
      if (query.length < 20 && !query.contains(' ')) {
        setState(() {
          _showMentionSuggestions = true;
          _filteredCoworkers = _coworkers.where((c) {
            return c.userName.toLowerCase().contains(query.toLowerCase());
          }).toList();
        });
        return;
      }
    }

    if (_showMentionSuggestions) {
      setState(() {
        _showMentionSuggestions = false;
      });
    }
  }

  void _selectMention(ChatMember member) {
    final text = _messageController.text;
    final lastAtIndex = text.lastIndexOf('@');
    final prefix = text.substring(0, lastAtIndex);
    _messageController.text = "$prefix@${member.userName} ";
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    setState(() {
      _showMentionSuggestions = false;
    });
    _inputFocusNode.requestFocus();
  }

  void _sendTypingIndicator() {
    final s = _socketService?.socket;
    if (s == null || !s.connected) return;

    if (!_isTyping) {
      _isTyping = true;
      final auth = context.read<AuthService>();
      s.emit('typing', {
        'roomId': _room.roomId,
        'username': auth.user?.name ?? 'Coworker',
      });
    }

    _typingTimeoutTimer?.cancel();
    _typingTimeoutTimer = Timer(const Duration(seconds: 3), () {
      _stopTypingIndicator();
    });
  }

  void _stopTypingIndicator() {
    if (!_isTyping) return;
    _isTyping = false;
    final s = _socketService?.socket;
    if (s != null && s.connected) {
      s.emit('stop_typing', {'roomId': _room.roomId});
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    const limit50MB = 50 * 1024 * 1024;
    if (file.size > limit50MB) {
      if (mounted) {
        context.showToast("File size exceeds 50MB limit.", isError: true);
      }
      return;
    }

    setState(() {
      _pickedFile = file;
      _isUploading = true;
    });

    if (file.path != null) {
      final res = await _chatService.uploadAttachment(_room.roomId, file.path!, file.name);
      if (mounted) {
        setState(() {
          _isUploading = false;
          if (res != null) {
            _uploadedAttachment = res;
          } else {
            _pickedFile = null;
          }
        });
        if (res != null) {
          context.showToast("Attachment uploaded successfully!", isSuccess: true);
        } else {
          context.showToast("Failed to upload attachment.", isError: true);
        }
      }
    } else {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadFile(String url, String filename) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savePath = "${appDir.path}/$filename";

      if (!mounted) return;
      context.showToast("Downloading file...");

      await authService.dio.download(
        url,
        savePath,
      );

      if (!mounted) return;
      context.showToast("Download complete!", isSuccess: true);
      await OpenFilex.open(savePath);
    } catch (e) {
      if (!mounted) return;
      context.showToast("Failed to open file: $e", isError: true);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _uploadedAttachment == null) return;

    _messageController.clear();
    _stopTypingIndicator();

    final optimisticId = "optimistic-${DateTime.now().millisecondsSinceEpoch}";
    final auth = context.read<AuthService>();
    final newMsg = ChatMessage(
      messageId: optimisticId,
      roomId: _room.roomId,
      senderId: _currentUserId,
      messageText: text,
      attachment: _uploadedAttachment,
      createdAt: DateTime.now().toIso8601String(),
      userName: auth.user?.name ?? 'You',
      profileImageUrl: auth.user?.profileImage,
      status: 'sending',
    );

    setState(() {
      _messages.add(newMsg);
      _pickedFile = null;
      _uploadedAttachment = null;
    });
    _scrollToBottom();

    final responseMsg = await _chatService.sendMessage(_room.roomId, text, newMsg.attachment);
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.messageId == optimisticId);
        if (index != -1) {
          if (responseMsg != null) {
            _messages[index] = responseMsg;
            widget.onMessageSentOrReceived?.call(responseMsg);
          } else {
            _messages[index].status = 'failed';
          }
        }
      });
    }
  }

  List<InlineSpan> _parseMessageText(String text, bool isSelf) {
    final List<InlineSpan> spans = [];
    final urlRegex = RegExp(r"(https?:\/\/[^\s]+|www\.[^\s]+)", caseSensitive: false);
    final mentionRegex = RegExp(r"(@[a-zA-Z0-9._-]+)");

    final words = text.split(' ');
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final space = i == words.length - 1 ? "" : " ";

      if (urlRegex.hasMatch(word)) {
        spans.add(TextSpan(
          text: word + space,
          style: GoogleFonts.poppins(
            color: isSelf ? Colors.lightBlueAccent : Colors.blue,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (mentionRegex.hasMatch(word)) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isSelf ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF5B60F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              word,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelf ? Colors.white : const Color(0xFF5B60F6),
              ),
            ),
          ),
        ));
        spans.add(TextSpan(text: space, style: GoogleFonts.poppins()));
      } else {
        spans.add(TextSpan(text: word + space, style: GoogleFonts.poppins()));
      }
    }
    return spans;
  }

  void _showGroupDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GroupDetailsDialog(
        room: _room,
        onRoomUpdated: (updatedRoom) {
          setState(() {
            _room = updatedRoom;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header Row
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildHeaderAvatar(isDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _room.getRoomDisplayName(_currentUserId),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_room.roomType == 'group')
                      Text(
                        "${_room.members.length} members",
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (_room.roomType == 'group')
                IconButton(
                  icon: Icon(Icons.info_outline, color: isDark ? Colors.grey : Colors.black54),
                  onPressed: _showGroupDetails,
                ),
            ],
          ),
        ),

        // Message Thread Area
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // List of Messages
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _messages.length + (_typingUsers.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            // Render typing indicator
                            final users = _typingUsers.values.join(', ');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    "$users is typing...",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final msg = _messages[index];
                          final isSelf = msg.senderId == _currentUserId;

                          // Group dates logic
                          bool showDateHeader = false;
                          if (index == 0) {
                            showDateHeader = true;
                          } else {
                            final prevMsg = _messages[index - 1];
                            final curDate = DateTime.parse(msg.createdAt).toLocal();
                            final prevDate = DateTime.parse(prevMsg.createdAt).toLocal();
                            if (curDate.year != prevDate.year ||
                                curDate.month != prevDate.month ||
                                curDate.day != prevDate.day) {
                              showDateHeader = true;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateHeader) _buildDateHeader(msg.createdAt),
                              _buildMessageBubble(msg, isSelf),
                            ],
                          );
                        },
                      ),

                      // Mention autocomplete suggestions list positioned above input
                      if (_showMentionSuggestions && _filteredCoworkers.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 12,
                          right: 12,
                          child: GlassContainer(
                            height: 180,
                            blur: 20,
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                            borderRadius: 12,
                            border: Border.all(
                              color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
                            ),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: _filteredCoworkers.length,
                              separatorBuilder: (context, idx) => Divider(
                                color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
                                height: 1,
                              ),
                              itemBuilder: (context, idx) {
                                final coworker = _filteredCoworkers[idx];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    coworker.userName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  onTap: () => _selectMention(coworker),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        // Text & Attachment Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
              ),
            ),
          ),
          child: Column(
            children: [
              if (_pickedFile != null) _buildAttachmentPreviewBar(),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file, color: isDark ? Colors.grey : Colors.black54),
                    onPressed: _pickedFile != null ? null : _pickAttachment,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _inputFocusNode,
                      onChanged: _onInputChanged,
                      maxLines: 4,
                      minLines: 1,
                      style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: "Write a message...",
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF5B60F6)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(String createdAt) {
    final date = DateTime.parse(createdAt).toLocal();
    final today = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    String formatText;
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      formatText = "Today";
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      formatText = "Yesterday";
    } else {
      formatText = DateFormat('MMMM d, yyyy').format(date);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatText,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isSelf) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = (msg.userName ?? '').initials;
    final parsedTime = DateFormat('h:mm a').format(DateTime.parse(msg.createdAt).toLocal());

    final isSystemCard = msg.messageText.startsWith("[SYSTEM_CARD:");
    String cardType = "";
    String cardStatus = "";
    Map<String, dynamic>? cardPayload;
    String cardTextTitle = "";
    String cardTextDesc = "";

    if (isSystemCard) {
      final endHeaderIndex = msg.messageText.indexOf("]");
      if (endHeaderIndex != -1) {
        final header = msg.messageText.substring(13, endHeaderIndex); // omit "[SYSTEM_CARD:"
        final parts = header.split(":");
        cardType = parts.isNotEmpty ? parts[0] : "";
        cardStatus = parts.length > 2 ? parts[2] : "";

        final body = msg.messageText.substring(endHeaderIndex + 1).trim();
        try {
          cardPayload = jsonDecode(body) as Map<String, dynamic>;
        } catch (_) {
          final bodyLines = body.split("\n");
          cardTextTitle = bodyLines.isNotEmpty ? bodyLines[0] : "";
          if (bodyLines.length > 1) {
            cardTextDesc = bodyLines.sublist(1).join("\n").replaceAll(RegExp(r'^"|"$'), "").trim();
          }
        }
      }
    }

    if (msg.senderId == 0 || cardType == 'group_update') {
      String cleanText = msg.messageText;
      if (cleanText.startsWith("[SYSTEM_CARD:group_update:info]")) {
        cleanText = cleanText.substring(31).trim();
      } else if (cleanText.startsWith("[SYSTEM_CARD:group_update:alert]")) {
        cleanText = cleanText.substring(32).trim();
      } else if (cleanText.startsWith("[SYSTEM_CARD:")) {
        final closeBracketIdx = cleanText.indexOf("]");
        if (closeBracketIdx != -1) {
          cleanText = cleanText.substring(closeBracketIdx + 1).trim();
        }
      }
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF0F3F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            cleanText,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSelf) ...[
            _buildMessageAvatar(msg, initials, isDark),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isSelf && _room.roomType == 'group')
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.userName ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.black54,
                      ),
                    ),
                  ),
                (() {
                  final isMentionPreview = msg.messageText.contains("Mentioned you in my Daily Activity");
                  return Container(
                    padding: (isSystemCard || isMentionPreview) ? EdgeInsets.zero : const EdgeInsets.all(12),
                    decoration: (isSystemCard || isMentionPreview)
                        ? (isMentionPreview
                            ? BoxDecoration(
                                gradient: isSelf
                                    ? LinearGradient(
                                        colors: isDark
                                            ? [const Color(0xFF388BFD).withValues(alpha: 0.2), const Color(0xFF1F6FEB).withValues(alpha: 0.2)]
                                            : [const Color(0xFFBAE6FD), const Color(0xFF7DD3FC)],
                                      )
                                    : null,
                                color: isSelf
                                    ? null
                                    : (isDark ? const Color(0xFF161B22) : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isSelf ? const Radius.circular(12) : const Radius.circular(0),
                                  bottomRight: isSelf ? const Radius.circular(0) : const Radius.circular(12),
                                ),
                                border: Border.all(
                                  color: isSelf
                                      ? (isDark ? const Color(0xFF388BFD).withValues(alpha: 0.3) : const Color(0xFF7DD3FC).withValues(alpha: 0.3))
                                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
                                ),
                              )
                            : null)
                        : BoxDecoration(
                            color: isSelf
                                ? const Color(0xFF5B60F6)
                                : (isDark ? const Color(0xFF161B22) : Colors.white),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: isSelf ? const Radius.circular(12) : const Radius.circular(0),
                              bottomRight: isSelf ? const Radius.circular(0) : const Radius.circular(12),
                            ),
                            border: isSelf
                                ? null
                                : Border.all(
                                    color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
                                  ),
                          ),
                    child: isSystemCard
                        ? _buildSystemCard(
                            cardType,
                            cardStatus,
                            cardPayload,
                            cardTextTitle,
                            cardTextDesc,
                            isDark,
                          )
                        : (isMentionPreview
                            ? _buildMentionPreviewCard(msg, isSelf, isDark)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Render message content with links / mentions
                                  if (msg.messageText.isNotEmpty)
                                    RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: isSelf ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                        ),
                                        children: _parseMessageText(msg.messageText, isSelf),
                                      ),
                                    ),
                                  if (msg.attachment != null) ...[
                                    if (msg.messageText.isNotEmpty) const SizedBox(height: 8),
                                    _buildMessageAttachment(msg.attachment!, isSelf),
                                  ],
                                ],
                              )),
                  );
                })(),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        parsedTime,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 4),
                        if (msg.status == 'sending')
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                          )
                        else if (msg.status == 'failed')
                          const Icon(Icons.error_outline, size: 12, color: Colors.redAccent)
                        else
                          const Icon(Icons.check, size: 12, color: Colors.grey),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard(
    String cardType,
    String cardStatus,
    Map<String, dynamic>? cardPayload,
    String cardTextTitle,
    String cardTextDesc,
    bool isDark,
  ) {
    // Determine colors
    final List<Color> gradientColors;
    final Color textColor;
    final Color borderColor;
    final IconData icon;
    final String badgeText;

    if (cardType == 'leave_request') {
      gradientColors = isDark
          ? [const Color(0xFF1E1B4B).withValues(alpha: 0.3), const Color(0xFF312E81).withValues(alpha: 0.3)]
          : [const Color(0xFFE0F2FE), const Color(0xFFC7D2FE)];
      textColor = isDark ? const Color(0xFF8C959F) : const Color(0xFF0550AE);
      borderColor = isDark ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFA5B4FC).withValues(alpha: 0.4);
      icon = Icons.calendar_today;
      badgeText = "LEAVE: $cardStatus";
    } else if (cardType == 'correction_request') {
      gradientColors = isDark
          ? [const Color(0xFF451A03).withValues(alpha: 0.3), const Color(0xFF78350F).withValues(alpha: 0.3)]
          : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)];
      textColor = isDark ? const Color(0xFFFFEDD5) : const Color(0xFFB45309);
      borderColor = isDark ? const Color(0xFF92400E).withValues(alpha: 0.4) : const Color(0xFFFCD34D).withValues(alpha: 0.4);
      icon = Icons.schedule;
      badgeText = "CORRECTION: $cardStatus";
    } else if (cardType == 'shift_assign') {
      gradientColors = isDark
          ? [const Color(0xFF064E3B).withValues(alpha: 0.3), const Color(0xFF065F46).withValues(alpha: 0.3)]
          : [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)];
      textColor = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF047857);
      borderColor = isDark ? const Color(0xFF047857).withValues(alpha: 0.4) : const Color(0xFF6EE7B7).withValues(alpha: 0.4);
      icon = Icons.watch_later;
      badgeText = "SHIFT ASSIGNED";
    } else {
      // geofence_assign and others
      gradientColors = isDark
          ? [const Color(0xFF4A044E).withValues(alpha: 0.3), const Color(0xFF581C87).withValues(alpha: 0.3)]
          : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)];
      textColor = isDark ? const Color(0xFFF3E8FF) : const Color(0xFF6B21A8);
      borderColor = isDark ? const Color(0xFF7E22CE).withValues(alpha: 0.4) : const Color(0xFFD8B4FE).withValues(alpha: 0.4);
      icon = Icons.map;
      badgeText = cardType == 'geofence_assign' ? "WORK LOCATION" : cardType.toUpperCase();
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Badge Row
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 12, color: textColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (cardPayload != null && cardPayload['local_time'] != null)
                  Text(
                    _formatTimePretty(cardPayload['local_time']),
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content Block
          if (cardPayload != null) ...[
            if (cardType == 'leave_request') ...[
              Text(
                "${cardPayload['employee_name'] ?? cardPayload['reviewer_name'] ?? 'Employee'} : ${cardPayload['leave_type'] ?? 'Leave'}",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              _buildCardDetailRow("Period", "${_formatDatePretty(cardPayload['start_date'])} to ${_formatDatePretty(cardPayload['end_date'])}", textColor),
              _buildCardDetailRow("Reason", "\"${cardPayload['reason'] ?? ''}\"", textColor),
              if (cardPayload['admin_comment'] != null && cardPayload['admin_comment'] != 'None') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.15))),
                  ),
                  child: _buildCardDetailRow("Comment", "\"${cardPayload['admin_comment']}\"", textColor),
                ),
              ],
            ] else if (cardType == 'correction_request') ...[
              Text(
                "${cardPayload['employee_name'] ?? cardPayload['reviewer_name'] ?? 'Employee'} : ${cardPayload['correction_type'] ?? 'Correction'}",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              _buildCardDetailRow("Target Date", _formatDatePretty(cardPayload['request_date']), textColor),
              _buildCardDetailRow("Reason", "\"${cardPayload['reason'] ?? ''}\"", textColor),
              if (cardPayload['review_comments'] != null && cardPayload['review_comments'] != 'None') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.15))),
                  ),
                  child: _buildCardDetailRow("Comment", "\"${cardPayload['review_comments']}\"", textColor),
                ),
              ],
              if (cardPayload['proposed_data'] != null && (cardPayload['proposed_data'] as List).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "Proposed Sessions:",
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 2),
                ...(cardPayload['proposed_data'] as List).asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sess = entry.value as Map<String, dynamic>;
                  final timeIn = sess['time_in'] != null ? _formatTimePretty(sess['time_in']) : '-';
                  final timeOut = sess['time_out'] != null ? _formatTimePretty(sess['time_out']) : '-';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Session ${idx + 1}: $timeIn to $timeOut",
                      style: GoogleFonts.poppins(fontSize: 8.5, color: textColor),
                    ),
                  );
                }),
              ],
            ] else if (cardType == 'shift_assign') ...[
              Text(
                "Shift Assigned",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              _buildCardDetailRow("Assigner", cardPayload['admin_name'] ?? '', textColor),
              _buildCardDetailRow("Shift name", cardPayload['shift_name'] ?? '', textColor),
              _buildCardDetailRow("Timings", "${cardPayload['start_time'] ?? ''} to ${cardPayload['end_time'] ?? ''}", textColor),
              _buildCardDetailRow("Grace Allowed", "${cardPayload['grace_period_mins'] ?? '0'} mins", textColor),
            ] else if (cardType == 'geofence_assign') ...[
              Text(
                "Work Location Assigned",
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              _buildCardDetailRow("Assigner", cardPayload['admin_name'] ?? '', textColor),
              _buildCardDetailRow("Site", cardPayload['location_name'] ?? '', textColor),
              _buildCardDetailRow("Address", cardPayload['address'] ?? '', textColor),
              _buildCardDetailRow("Boundary Radius", "${cardPayload['radius'] ?? '0'} meters", textColor),
            ],
            // Documents/Attachments list inside payload
            if (cardPayload['attachments'] != null && (cardPayload['attachments'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.15))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Documents:",
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 4),
                    ...(cardPayload['attachments'] as List).map((att) {
                      final name = att['name'] ?? 'File';
                      final url = att['url'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (url.isNotEmpty) {
                              _downloadFile(url, name);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.attachment, size: 10, color: textColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(fontSize: 9, color: textColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Icon(Icons.download, size: 10, color: textColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ] else ...[
            // FALLBACK FOR LEGACY PLAIN TEXT
            Text(
              cardTextTitle,
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
            ),
            if (cardTextDesc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                cardTextDesc,
                style: GoogleFonts.poppins(fontSize: 10, color: textColor),
              ),
            ],
          ],
          // Deep Link Redirection Button matching the web app
          if (cardType == 'leave_request' ||
              cardType == 'correction_request' ||
              cardType == 'shift_assign' ||
              cardType == 'geofence_assign') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                if (cardType == 'leave_request') {
                  navigateTo(PageType.leavesAndHolidays);
                } else if (cardType == 'correction_request') {
                  navigateTo(PageType.myAttendance);
                } else if (cardType == 'shift_assign') {
                  navigateTo(PageType.policyEngine);
                } else if (cardType == 'geofence_assign') {
                  navigateTo(PageType.geoFencing);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cardType == 'leave_request'
                      ? const Color(0xFF0284C7)
                      : (cardType == 'correction_request'
                          ? const Color(0xFFD97706)
                          : (cardType == 'shift_assign'
                              ? const Color(0xFF059669)
                              : const Color(0xFF7C3AED))),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    cardType == 'leave_request'
                        ? 'View Leave Panel'
                        : (cardType == 'correction_request'
                            ? 'View Corrections'
                            : (cardType == 'shift_assign'
                                ? 'View Shift Details'
                                : 'View Location Map')),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMentionPreviewCard(ChatMessage msg, bool isSelf, bool isDark) {
    final text = msg.messageText;
    final isTask = text.contains("Task");
    final previewType = isTask ? "Daily Activity Task" : "Daily Activity Meeting";
    final lines = text.split('\n');
    String previewTitle = "Untitled Entry";
    String previewDesc = "";

    if (lines.length > 1) {
      previewTitle = lines[1].replaceAll('*', '').trim();
    }
    if (lines.length > 2) {
      previewDesc = lines.sublist(2).join('\n').replaceAll('"', '').trim();
    }

    final Color primaryColor = isDark ? const Color(0xFF58A6FF) : const Color(0xFF0550AE);

    final Color titleColor = isSelf
        ? (isDark ? Colors.white : const Color(0xFF0550AE))
        : (isDark ? const Color(0xFFC9D1D9) : const Color(0xFF24292F));

    final Color descColor = isSelf
        ? (isDark ? const Color(0xFF8B949E) : const Color(0xFF044E95))
        : (isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A));

    final Color borderSideColor = isSelf
        ? (isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF044E95).withValues(alpha: 0.3))
        : (isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE));

    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Type Badge
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              previewType.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: primaryColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            previewTitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),

          // Description
          if (previewDesc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: borderSideColor,
                    width: 2,
                  ),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: descColor,
                  ),
                  children: _parseMessageText(previewDesc, isSelf),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 9.5, color: textColor),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _formatTimePretty(String timeStr) {
    try {
      final parsed = DateTime.parse(timeStr).toLocal();
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {
      try {
        final parsed = DateFormat('HH:mm:ss').parse(timeStr);
        return DateFormat('h:mm a').format(parsed);
      } catch (_) {
        return timeStr;
      }
    }
  }

  String _formatDatePretty(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildHeaderAvatar(bool isDark) {
    final displayName = _room.getRoomDisplayName(_currentUserId);
    final initials = displayName.initials;
    String? imageUrl = _room.getRoomDisplayAvatar(_currentUserId);
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http')) {
        imageUrl = '${ApiConstants.baseUrl}/$imageUrl';
      }
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                  child: const Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF5B60F6)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _room.roomType == 'group'
                    ? _buildGroupHeaderFallbackAvatar(36)
                    : _buildInitialsHeaderAvatar(initials),
              )
            : (_room.roomType == 'group'
                ? _buildGroupHeaderFallbackAvatar(36)
                : _buildInitialsHeaderAvatar(initials)),
      ),
    );
  }

  Widget _buildGroupHeaderFallbackAvatar(double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.groups,
          size: size * 0.55,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInitialsHeaderAvatar(String initials) {
    return Container(
      color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5B60F6),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageAvatar(ChatMessage msg, String initials, bool isDark) {
    String? imageUrl = msg.profileImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      // 1. Try finding in room members
      final member = _room.members.firstWhere(
        (m) => m.userId == msg.senderId,
        orElse: () => ChatMember(userId: 0, userName: ''),
      );
      if (member.userId != 0 && member.profileImage != null && member.profileImage!.isNotEmpty) {
        imageUrl = member.profileImage;
      } else {
        // 2. Try finding in coworkers
        final coworker = _coworkers.firstWhere(
          (c) => c.userId == msg.senderId,
          orElse: () => ChatMember(userId: 0, userName: ''),
        );
        if (coworker.userId != 0 && coworker.profileImage != null && coworker.profileImage!.isNotEmpty) {
          imageUrl = coworker.profileImage;
        }
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http')) {
        imageUrl = '${ApiConstants.baseUrl}/$imageUrl';
      }
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                  child: const Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF5B60F6)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildInitialsMessageAvatar(initials),
              )
            : _buildInitialsMessageAvatar(initials),
      ),
    );
  }

  Widget _buildInitialsMessageAvatar(String initials) {
    return Container(
      color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5B60F6),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageAttachment(Map<String, dynamic> attachment, bool isSelf) {
    final name = attachment['name'] ?? 'File';
    final url = attachment['url'] ?? '';
    final type = (attachment['type'] ?? '').toString().toLowerCase();

    // Check if attachment is an image
    final isImage = type.contains('image') ||
        ['png', 'jpg', 'jpeg', 'gif', 'webp'].any((ext) => name.toLowerCase().endsWith(ext));

    if (isImage && url.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          // Open interactive fullscreen image viewer
          InteractiveImageViewerDialog.show(context, url, title: name);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 240),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelf ? Colors.white.withValues(alpha: 0.1) : (isDark ? const Color(0xFF21262D) : Colors.grey[100]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            color: isSelf ? Colors.white : const Color(0xFF5B60F6),
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelf ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  attachment['size'] != null ? "${(attachment['size'] / 1024).toStringAsFixed(1)} KB" : '',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.download_for_offline,
              color: isSelf ? Colors.white : const Color(0xFF5B60F6),
              size: 20,
            ),
            onPressed: () => _downloadFile(url, name),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreviewBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: isDark ? Colors.grey : Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pickedFile!.name,
              style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isUploading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B60F6)),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
              onPressed: () => setState(() {
                _pickedFile = null;
                _uploadedAttachment = null;
              }),
            ),
        ],
      ),
    );
  }
}
