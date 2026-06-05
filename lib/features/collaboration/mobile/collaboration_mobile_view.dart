import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/constants/api_constants.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'mobile_chat_room_page.dart';
import '../widgets/chat_dialogs.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/widgets/loading_screen.dart';
import '../../../../shared/services/socket_service.dart';

class CollaborationMobileView extends StatefulWidget {
  const CollaborationMobileView({super.key});

  @override
  State<CollaborationMobileView> createState() => _CollaborationMobileViewState();
}

class _CollaborationMobileViewState extends State<CollaborationMobileView> {
  late ChatService _chatService;
  late int _currentUserId;

  List<ChatRoom> _rooms = [];
  bool _isLoading = true;
  SocketService? _socketService;

  String _tab = 'all'; // 'all' | 'direct' | 'group'
  String _searchQuery = '';
  List<int> _pinnedRoomIds = [];

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _currentUserId = int.tryParse(context.read<AuthService>().user?.id ?? '') ?? 0;
    _socketService = context.read<SocketService>();
    _setupSocketListeners();
    _fetchRooms();
    _loadPinnedRooms();
  }

  void _setupSocketListeners() {
    final s = _socketService?.socket;
    if (s == null) return;
    s.on('room_created', _onSocketRoomCreated);
    s.on('room_deleted', _onSocketRoomDeleted);
    s.on('message_received', _onSocketMessageReceived);
  }

  void _onSocketRoomCreated(dynamic data) {
    if (!mounted) return;
    _fetchRooms(showLoading: false);
  }

  void _onSocketRoomDeleted(dynamic data) {
    if (!mounted) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final deletedRoomId = map['room_id'] is String ? int.parse(map['room_id']) : map['room_id'];
      setState(() {
        _rooms.removeWhere((r) => r.roomId == deletedRoomId);
      });
    } catch (_) {
      _fetchRooms(showLoading: false);
    }
  }

  void _onSocketMessageReceived(dynamic data) {
    if (!mounted) return;
    _fetchRooms(showLoading: false);
  }

  @override
  void dispose() {
    final s = _socketService?.socket;
    if (s != null) {
      s.off('room_created', _onSocketRoomCreated);
      s.off('room_deleted', _onSocketRoomDeleted);
      s.off('message_received', _onSocketMessageReceived);
    }
    super.dispose();
  }

  Future<void> _fetchRooms({bool showLoading = true}) async {
    if (showLoading && _rooms.isEmpty) setState(() => _isLoading = true);
    final list = await _chatService.getRooms();
    if (mounted) {
      setState(() {
        _rooms = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPinnedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "pinnedRoomIds_$_currentUserId";
    final stored = prefs.getString(key);
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        if (mounted) {
          setState(() {
            _pinnedRoomIds = decoded.cast<int>();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _togglePinRoom(ChatRoom room) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "pinnedRoomIds_$_currentUserId";
    setState(() {
      if (_pinnedRoomIds.contains(room.roomId)) {
        _pinnedRoomIds.remove(room.roomId);
        context.showToast("Conversation unpinned", isSuccess: true);
      } else {
        _pinnedRoomIds.add(room.roomId);
        context.showToast("Conversation pinned", isSuccess: true);
      }
    });
    await prefs.setString(key, jsonEncode(_pinnedRoomIds));
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Create Conversation",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF5B60F6)),
                  ),
                  title: Text(
                    "Direct Message",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Start a direct conversation with a colleague",
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openNewDmDialog();
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EA043).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline, color: Color(0xFF2EA043)),
                  ),
                  title: Text(
                    "New Group Channel",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Collaborate with multiple coworkers in a room",
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openNewGroupDialog();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openNewDmDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NewDmDialog(
        onRoomCreated: (room) {
          _fetchRooms(showLoading: false);
          _navigateToRoom(room);
        },
      ),
    );
  }

  void _openNewGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NewGroupDialog(
        onRoomCreated: (room) {
          _fetchRooms(showLoading: false);
          _navigateToRoom(room);
        },
      ),
    );
  }

  void _navigateToRoom(ChatRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileChatRoomPage(room: room),
      ),
    ).then((_) => _fetchRooms(showLoading: false));
  }

  List<ChatRoom> _getProcessedRooms() {
    return _rooms.where((room) {
      final matchesTab = _tab == 'all' ||
          (_tab == 'direct' && room.roomType == 'direct') ||
          (_tab == 'group' && room.roomType == 'group');

      final displayName = room.getRoomDisplayName(_currentUserId).toLowerCase();
      final preview = (room.lastMessage?.displayPreview ?? '').toLowerCase();
      final matchesSearch = displayName.contains(_searchQuery.toLowerCase()) ||
          preview.contains(_searchQuery.toLowerCase());

      return matchesTab && matchesSearch;
    }).toList()
      ..sort((a, b) {
        final aPinned = _pinnedRoomIds.contains(a.roomId);
        final bPinned = _pinnedRoomIds.contains(b.roomId);

        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;

        final timeA = a.lastMessage != null
            ? DateTime.parse(a.lastMessage!.createdAt)
            : DateTime.parse(a.createdAt);
        final timeB = b.lastMessage != null
            ? DateTime.parse(b.lastMessage!.createdAt)
            : DateTime.parse(b.createdAt);
        return timeB.compareTo(timeA);
      });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final processedRooms = _getProcessedRooms();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LoadingScreen(
        isLoading: _isLoading,
        message: "Loading chats...",
        child: Column(
          children: [
            // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22).withValues(alpha: 0.8) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D).withValues(alpha: 0.5) : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _buildTabButton('all', 'All', isDark),
                  _buildTabButton('direct', 'Direct', isDark),
                  _buildTabButton('group', 'Groups', isDark),
                ],
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search conversations...",
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF5B60F6)),
                filled: true,
                fillColor: isDark ? const Color(0xFF161B22).withValues(alpha: 0.6) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF30363D).withValues(alpha: 0.5) : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF5B60F6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // List region
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchRooms(showLoading: false),
              color: const Color(0xFF5B60F6),
              child: processedRooms.isEmpty
                  ? (_isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [SizedBox.shrink()],
                        )
                      : ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Text(
                                "No chats found",
                                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          ],
                        ))
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: processedRooms.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final room = processedRooms[index];
                        return _buildChatListItem(context, room, isDark);
                      },
                    ),
            ),
          ),
        ],
      ),
     ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF5B60F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B60F6).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showCreateOptions,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showPinActions(ChatRoom room) {
    final isPinned = _pinnedRoomIds.contains(room.roomId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    color: const Color(0xFF5B60F6),
                  ),
                  title: Text(
                    isPinned ? "Unpin Conversation" : "Pin Conversation",
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _togglePinRoom(room);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String value, String label, bool isDark) {
    final isSelected = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF5B60F6) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF5B60F6))
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getAvatarGradient(String name) {
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final index = hash % 5;
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[index];
  }

  Widget _buildAvatarWidget(String displayName, String initials, String? avatarPath, double size, bool isDark, bool isSelected, {bool isGroup = false}) {
    String? imageUrl = avatarPath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (!imageUrl.startsWith('http')) {
        imageUrl = '${ApiConstants.baseUrl}/$imageUrl';
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? const Color(0xFF5B60F6).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF30363D).withValues(alpha: 0.5) : Colors.grey[300]!),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: _getAvatarGradient(displayName),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => isGroup
                    ? _buildGroupFallbackAvatar(size)
                    : _buildInitialsAvatar(displayName, initials, size),
              )
            : (isGroup
                ? _buildGroupFallbackAvatar(size)
                : _buildInitialsAvatar(displayName, initials, size)),
      ),
    );
  }

  Widget _buildGroupFallbackAvatar(double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
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

  Widget _buildInitialsAvatar(String displayName, String initials, double size) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getAvatarGradient(displayName),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: size * 0.3,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatListItem(BuildContext context, ChatRoom room, bool isDark) {
    final displayName = room.getRoomDisplayName(_currentUserId);
    final initials = displayName.initials;
    final isPinned = _pinnedRoomIds.contains(room.roomId);
    final hasUnread = room.unreadCount > 0;

    Widget previewWidget;
    if (room.lastMessage != null) {
      final msg = room.lastMessage!;
      String senderPrefix = "";
      if (msg.senderId == _currentUserId) {
        senderPrefix = "You: ";
      } else if (room.roomType == 'group') {
        senderPrefix = "${msg.userName ?? 'Member'}: ";
      }

      if (msg.attachment != null) {
        final attachmentName = msg.attachment!['name'] ?? 'File';
        previewWidget = Text(
          "$senderPrefix📎 $attachmentName",
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: hasUnread ? (isDark ? Colors.white : Colors.black) : Colors.grey[600],
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        previewWidget = Text(
          "$senderPrefix${msg.displayPreview.replaceAll('\n', ' ')}",
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: hasUnread ? (isDark ? Colors.white : Colors.black) : Colors.grey[600],
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    } else {
      previewWidget = Text(
        'No messages yet',
        style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[500]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22).withValues(alpha: 0.25) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D).withValues(alpha: 0.3) : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToRoom(room),
          onLongPress: () => _showPinActions(room),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    _buildAvatarWidget(
                      displayName,
                      initials,
                      room.getRoomDisplayAvatar(_currentUserId),
                      46,
                      isDark,
                      false,
                      isGroup: room.roomType == 'group',
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2EA043),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0D1117) : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2EA043).withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isPinned)
                            const Icon(Icons.push_pin, size: 11, color: Color(0xFF5B60F6)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      previewWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (room.lastMessage != null)
                      Text(
                        DateFormat('h:mm a').format(
                          DateTime.parse(room.lastMessage!.createdAt).toLocal(),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          color: hasUnread ? const Color(0xFF5B60F6) : Colors.grey,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "${room.unreadCount}",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
