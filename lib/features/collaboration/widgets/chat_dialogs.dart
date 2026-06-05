import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/constants/api_constants.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/toast_helper.dart';

class NewDmDialog extends StatefulWidget {
  final Function(ChatRoom) onRoomCreated;

  const NewDmDialog({super.key, required this.onRoomCreated});

  @override
  State<NewDmDialog> createState() => _NewDmDialogState();
}

class _NewDmDialogState extends State<NewDmDialog> {
  late ChatService _chatService;
  List<ChatMember> _coworkers = [];
  List<ChatMember> _filteredCoworkers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _fetchCoworkers();
  }

  Future<void> _fetchCoworkers() async {
    final list = await _chatService.getCoworkers();
    if (mounted) {
      setState(() {
        _coworkers = list;
        _filteredCoworkers = list;
        _isLoading = false;
      });
    }
  }

  void _filterCoworkers(String query) {
    setState(() {
      _filteredCoworkers = _coworkers.where((c) {
        return c.userName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _startChat(ChatMember other) async {
    setState(() => _isLoading = true);
    final room = await _chatService.createRoom(
      type: 'direct',
      memberIds: [other.userId],
    );
    if (mounted) {
      if (room != null) {
        Navigator.pop(context);
        widget.onRoomCreated(room);
      } else {
        setState(() => _isLoading = false);
        context.showToast("Failed to start chat session.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final sheetWidth = screenWidth > 600 ? 500.0 : double.infinity;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: GlassContainer(
          width: sheetWidth,
          height: 500,
          blur: 20,
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: 24,
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Direct Message",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF24292F),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCoworkers,
                style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Search coworkers...",
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Coworkers List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCoworkers.isEmpty
                      ? Center(
                          child: Text(
                            "No coworkers found",
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredCoworkers.length,
                          separatorBuilder: (context, index) => Divider(
                            color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final c = _filteredCoworkers[index];
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: _buildMemberAvatar(c.userName, c.profileImage),
                                title: Text(
                                  c.userName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  c.userType ?? 'Employee',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                ),
                                onTap: () => _startChat(c),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class NewGroupDialog extends StatefulWidget {
  final Function(ChatRoom) onRoomCreated;

  const NewGroupDialog({super.key, required this.onRoomCreated});

  @override
  State<NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<NewGroupDialog> {
  late ChatService _chatService;
  List<ChatMember> _coworkers = [];
  List<ChatMember> _filteredCoworkers = [];
  final List<int> _selectedIds = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _fetchCoworkers();
  }

  Future<void> _fetchCoworkers() async {
    final list = await _chatService.getCoworkers();
    if (mounted) {
      setState(() {
        _coworkers = list;
        _filteredCoworkers = list;
        _isLoading = false;
      });
    }
  }

  void _filterCoworkers(String query) {
    setState(() {
      _filteredCoworkers = _coworkers.where((c) {
        return c.userName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showToast("Group name is required.", isWarning: true);
      return;
    }
    if (_selectedIds.isEmpty) {
      context.showToast("Please select at least one member.", isWarning: true);
      return;
    }

    setState(() => _isLoading = true);
    final currentUserId = int.tryParse(context.read<AuthService>().user?.id ?? '') ?? 0;
    final List<int> memberIds = List<int>.from(_selectedIds);
    if (currentUserId != 0 && !memberIds.contains(currentUserId)) {
      memberIds.add(currentUserId);
    }

    final room = await _chatService.createRoom(
      type: 'group',
      roomName: name,
      memberIds: memberIds,
    );
    if (mounted) {
      if (room != null) {
        Navigator.pop(context);
        widget.onRoomCreated(room);
      } else {
        setState(() => _isLoading = false);
        context.showToast("Failed to create group channel.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final sheetWidth = screenWidth > 600 ? 500.0 : double.infinity;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: GlassContainer(
          width: sheetWidth,
          height: 560,
          blur: 20,
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: 24,
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "New Group Channel",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF24292F),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Group Name Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.poppins(fontSize: 13.5, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Enter group name...",
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCoworkers,
                style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Search coworkers to add...",
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Coworkers List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCoworkers.isEmpty
                      ? Center(
                          child: Text(
                            "No coworkers found",
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredCoworkers.length,
                          separatorBuilder: (context, index) => Divider(
                            color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final c = _filteredCoworkers[index];
                            final isSelected = _selectedIds.contains(c.userId);
                            return Material(
                              color: Colors.transparent,
                              child: CheckboxListTile(
                                value: isSelected,
                                title: Text(
                                  c.userName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  c.userType ?? 'Employee',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                ),
                                secondary: _buildMemberAvatar(c.userName, c.profileImage),
                                activeColor: const Color(0xFF5B60F6),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(c.userId);
                                    } else {
                                      _selectedIds.remove(c.userId);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B60F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Create Group Channel",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class GroupDetailsDialog extends StatefulWidget {
  final ChatRoom room;
  final Function(ChatRoom) onRoomUpdated;

  const GroupDetailsDialog({
    super.key,
    required this.room,
    required this.onRoomUpdated,
  });

  @override
  State<GroupDetailsDialog> createState() => _GroupDetailsDialogState();
}

class _GroupDetailsDialogState extends State<GroupDetailsDialog> {
  late ChatService _chatService;
  List<ChatMember> _coworkers = [];
  List<ChatMember> _filteredCoworkers = [];
  bool _isLoading = true;
  String _tab = 'members'; // 'members' | 'add'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _fetchCoworkers();
  }

  Future<void> _fetchCoworkers() async {
    final list = await _chatService.getCoworkers();
    if (mounted) {
      setState(() {
        _coworkers = list;
        _isLoading = false;
      });
      _filterAddableList();
    }
  }

  void _filterAddableList() {
    final memberIds = widget.room.members.map((m) => m.userId).toSet();
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCoworkers = _coworkers.where((c) {
        final matchesQuery = c.userName.toLowerCase().contains(query);
        final notInGroup = !memberIds.contains(c.userId);
        return matchesQuery && notInGroup;
      }).toList();
    });
  }

  Future<void> _removeMember(ChatMember member) async {
    setState(() => _isLoading = true);
    final memberIds = widget.room.members.map((m) => m.userId).where((id) => id != member.userId).toList();
    final updatedRoom = await _chatService.updateMembers(widget.room.roomId, memberIds);
    if (mounted) {
      if (updatedRoom != null) {
        context.showToast("${member.userName} removed.", isSuccess: true);
        widget.onRoomUpdated(updatedRoom);
      } else {
        context.showToast("Failed to remove member.", isError: true);
      }
      setState(() => _isLoading = false);
      _filterAddableList();
    }
  }

  Future<void> _addMember(ChatMember member) async {
    setState(() => _isLoading = true);
    final memberIds = [...widget.room.members.map((m) => m.userId), member.userId];
    final updatedRoom = await _chatService.updateMembers(widget.room.roomId, memberIds);
    if (mounted) {
      if (updatedRoom != null) {
        context.showToast("${member.userName} added.", isSuccess: true);
        widget.onRoomUpdated(updatedRoom);
      } else {
        context.showToast("Failed to add member.", isError: true);
      }
      setState(() => _isLoading = false);
      _filterAddableList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = int.tryParse(context.read<AuthService>().user?.id ?? '') ?? 0;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final sheetWidth = screenWidth > 600 ? 500.0 : double.infinity;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: GlassContainer(
          width: sheetWidth,
          height: 520,
          blur: 20,
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: 24,
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.room.roomName ?? 'Group Info',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF24292F),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.grey : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tab = 'members'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _tab == 'members' ? const Color(0xFF5B60F6) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Members (${widget.room.members.length})",
                          style: GoogleFonts.poppins(
                            fontWeight: _tab == 'members' ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                            color: _tab == 'members' ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _tab = 'add';
                        _filterAddableList();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _tab == 'add' ? const Color(0xFF5B60F6) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Add Members",
                          style: GoogleFonts.poppins(
                            fontWeight: _tab == 'add' ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                            color: _tab == 'add' ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Members List or Add List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tab == 'members'
                      ? ListView.separated(
                          itemCount: widget.room.members.length,
                          separatorBuilder: (context, index) => Divider(
                            color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final m = widget.room.members[index];
                            final isMe = m.userId == currentUserId;
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: _buildMemberAvatar(m.userName, m.profileImage),
                                title: Text(
                                  m.userName + (isMe ? ' (You)' : ''),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  m.userType ?? 'Employee',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: isMe
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => _removeMember(m),
                                      ),
                              ),
                            );
                          },
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => _filterAddableList(),
                                style: GoogleFonts.poppins(fontSize: 12.5, color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: "Search colleagues to add...",
                                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _filteredCoworkers.isEmpty
                                  ? Center(
                                      child: Text(
                                        "No other coworkers to add",
                                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _filteredCoworkers.length,
                                      separatorBuilder: (context, index) => Divider(
                                        color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
                                        height: 1,
                                      ),
                                       itemBuilder: (context, index) {
                                        final c = _filteredCoworkers[index];
                                        return Material(
                                          color: Colors.transparent,
                                          child: ListTile(
                                            leading: _buildMemberAvatar(c.userName, c.profileImage),
                                            title: Text(
                                              c.userName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            subtitle: Text(
                                              c.userType ?? 'Employee',
                                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF5B60F6), size: 20),
                                              onPressed: () => _addMember(c),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    ),
    );
  }
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

Widget _buildMemberAvatar(String displayName, String? avatarPath, {double radius = 18}) {
  final initials = displayName.initials;
  String? imageUrl = avatarPath;
  if (imageUrl != null && imageUrl.isNotEmpty) {
    if (!imageUrl.startsWith('http')) {
      imageUrl = '${ApiConstants.baseUrl}/$imageUrl';
    }
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.transparent,
    child: ClipOval(
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: radius * 2,
              height: radius * 2,
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
              errorWidget: (context, url, error) => _buildInitialsAvatar(displayName, initials, radius),
            )
          : _buildInitialsAvatar(displayName, initials, radius),
    ),
  );
}

Widget _buildInitialsAvatar(String displayName, String initials, double radius) {
  return Container(
    width: radius * 2,
    height: radius * 2,
    decoration: BoxDecoration(
      gradient: _getAvatarGradient(displayName),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: GoogleFonts.poppins(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}
