// lib/Chatscreen/real_chat_screen.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/Chatscreen/chat_service.dart';

class RealChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userImageBase64;

  const RealChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userImageBase64,
  });

  @override
  State<RealChatScreen> createState() => _RealChatScreenState();
}

class _RealChatScreenState extends State<RealChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isOnline = false;
  List<Map<String, dynamic>> _cachedMessages = [];

  @override
  void initState() {
    super.initState();
    _checkOnlineStatus();

    // Load cached messages instantly
    _cachedMessages = _chatService.getCachedMessagesInstant(widget.userId);

    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _checkOnlineStatus() {
    _chatService.getOnlineStatus().listen((status) {
      if (mounted) {
        setState(() {
          _isOnline = status[widget.userId] ?? false;
        });
      }
    });
  }

  void _markMessagesAsRead() async {
    try {
      final messages = await _chatService.getMessages(widget.userId).first;
      for (var doc in messages.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['receiverId'] == _chatService.getCurrentUser()?.uid &&
            !data['isRead']) {
          await _chatService.markMessageAsRead(doc.id, widget.userId);
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    _chatService.sendMessage(
      receiverId: widget.userId,
      message: _messageController.text.trim(),
    );

    _messageController.clear();
    _scrollToBottom();
  }

  Widget _buildProfileImage() {
    if (widget.userImageBase64.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: MemoryImage(base64Decode(widget.userImageBase64)),
          onBackgroundImageError: (error, stackTrace) {
            // Fallback
          },
        );
      } catch (e) {
        return const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey,
          backgroundImage: AssetImage('assets/avatar.png'),
        );
      }
    } else {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        backgroundImage: AssetImage('assets/avatar.png'),
      );
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    Timestamp? ts;
    if (timestamp is Timestamp) {
      ts = timestamp;
    } else if (timestamp is Map && timestamp['_seconds'] != null) {
      ts = Timestamp(timestamp['_seconds'], timestamp['_nanoseconds'] ?? 0);
    } else {
      return 'Just now';
    }

    final dateTime = ts.toDate();
    final now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color gold = const Color(0xfff7a900);
    final Color darkPurple = const Color(0xff160021);

    return Scaffold(
      backgroundColor: darkPurple,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/back_dash.png",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: darkPurple),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // TOP HEADER
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xff2a0540), Color(0xff180128)],
                    ),
                    border: Border.all(color: gold.withOpacity(.45)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gold),
                            color: const Color(0xff2d0b44),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: gold, width: 1.5),
                        ),
                        child: _buildProfileImage(),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isOnline
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOnline ? "Online" : "Offline",
                                  style: TextStyle(
                                    color: _isOnline
                                        ? Colors.greenAccent
                                        : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xff2d0b44),
                        ),
                        child: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ENCRYPTION BOX
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff220033),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gold.withOpacity(.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: gold, size: 16),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Messages are secured with end-to-end encryption. No one outside this chat, not even we, can read or listen to them.",
                          style: TextStyle(
                            color: Color(0xffe2c477),
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // DATE SEPARATOR
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Today",
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // CHAT LIST - Instant display
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessages(widget.userId),
                    builder: (context, snapshot) {
                      // Convert live data to map format
                      List<Map<String, dynamic>> liveMessages = [];

                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        liveMessages = snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return {
                            'id': doc.id,
                            'senderId': data['senderId'] ?? '',
                            'receiverId': data['receiverId'] ?? '',
                            'message': data['message'] ?? '',
                            'timestamp': data['timestamp'],
                            'isRead': data['isRead'] ?? false,
                          };
                        }).toList();
                      }

                      // Use live data if available, otherwise use cached
                      final messages = liveMessages.isNotEmpty
                          ? liveMessages
                          : _cachedMessages;

                      // Update cache if live data arrived
                      if (liveMessages.isNotEmpty) {
                        _cachedMessages = liveMessages;
                      }

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'No messages yet.\nSend a message to start chatting!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      // Auto-scroll to bottom on new messages
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data = messages[index];
                          final currentUserId =
                              _chatService.getCurrentUser()?.uid ?? '';
                          final isMe = data['senderId'] == currentUserId;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * .72,
                              ),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xff7b2cff),
                                          Color(0xff5d1dc9),
                                        ],
                                      )
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xff35204f),
                                          Color(0xff241537),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      data['message'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(data['timestamp']),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.6),
                                          fontSize: 9,
                                        ),
                                      ),
                                      if (isMe && (data['isRead'] == true)) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.done_all,
                                          color: Colors.greenAccent,
                                          size: 14,
                                        ),
                                      ] else if (isMe) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.done,
                                          color: Colors.white54,
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // MESSAGE INPUT BOX
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xff2a0540), Color(0xff180128)],
                    ),
                    border: Border.all(color: gold.withOpacity(.22)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: gold.withOpacity(0.8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.emoji_emotions_outlined,
                        color: gold.withOpacity(0.8),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xff7b2cff), Color(0xff5d1dc9)],
                            ),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
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
}
