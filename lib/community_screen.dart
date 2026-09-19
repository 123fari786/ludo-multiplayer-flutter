// lib/Chatscreen/community_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ludo_game/Chatscreen/chat_service.dart';
import 'package:ludo_game/Chatscreen/real_chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);
  final ChatService _chatService = ChatService();

  // Initialize with cached data immediately
  List<Map<String, dynamic>> _users = [];
  Map<String, bool> _onlineStatus = {};
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _chatService.updateUserStatus(true);

    // Load cached data instantly (synchronous)
    _users = _chatService.getCachedUsersInstant();
    _onlineStatus = _chatService.getCachedOnlineStatusInstant();
    _hasData = _users.isNotEmpty;

    // Refresh data in background
    _refreshData();
  }

  void _refreshData() {
    // Users will be updated via StreamBuilder in background
    setState(() {});
  }

  @override
  void dispose() {
    _chatService.updateUserStatus(false);
    super.dispose();
  }

  void _openChatScreen(Map<String, dynamic> user) {
    final fullName = "${user['firstName']} ${user['lastName']}".trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealChatScreen(
          userId: user['id'],
          userName: fullName,
          userImageBase64: user['profileImageBase64'] ?? '',
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? base64Image, double size) {
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: size,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: MemoryImage(base64Decode(base64Image)),
          onBackgroundImageError: (error, stackTrace) {
            // Fallback to avatar
          },
        );
      } catch (e) {
        return CircleAvatar(
          radius: size,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: const AssetImage('assets/avatar.png'),
        );
      }
    } else {
      return CircleAvatar(
        radius: size,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: const AssetImage('assets/avatar.png'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkPurple,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/back_dash.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: darkPurple),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xff2d0b44),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gold),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                color: gold,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Community",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(color: darkPurple),
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _chatService.getAllUsers(),
                      builder: (context, userSnapshot) {
                        // Update users if new data arrives
                        final updatedUsers =
                            userSnapshot.hasData &&
                                userSnapshot.data!.isNotEmpty
                            ? userSnapshot.data!
                            : _users;

                        if (userSnapshot.hasData &&
                            userSnapshot.data!.isNotEmpty) {
                          _users = updatedUsers;
                        }

                        if (updatedUsers.isEmpty) {
                          return Center(
                            child: Text(
                              'Please Waiting......',
                              style: TextStyle(
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }

                        return StreamBuilder<Map<String, bool>>(
                          stream: _chatService.getOnlineStatus(),
                          builder: (context, onlineSnapshot) {
                            // Update online status if new data arrives
                            if (onlineSnapshot.hasData &&
                                onlineSnapshot.data != null) {
                              _onlineStatus = onlineSnapshot.data!;
                            }

                            final onlineCount = _onlineStatus.values
                                .where((v) => v == true)
                                .length;

                            return Column(
                              children: [
                                const SizedBox(height: 12),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "All Users",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.greenAccent
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          "$onlineCount Online",
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    itemCount: updatedUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = updatedUsers[index];
                                      final fullName =
                                          "${user['firstName']} ${user['lastName']}"
                                              .trim();
                                      final isOnline =
                                          _onlineStatus[user['id']] ?? false;

                                      return GestureDetector(
                                        onTap: () => _openChatScreen(user),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xff2a0540),
                                                Color(0xff1b022b),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: gold.withOpacity(.22),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Stack(
                                                children: [
                                                  _buildProfileImage(
                                                    user['profileImageBase64'],
                                                    28,
                                                  ),
                                                  if (isOnline)
                                                    Positioned(
                                                      bottom: 1,
                                                      right: 1,
                                                      child: Container(
                                                        width: 14,
                                                        height: 14,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .greenAccent,
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color:
                                                                    darkPurple,
                                                                width: 2,
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 14),

                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      fullName,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      user['email'] ?? '',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isOnline
                                                      ? Colors.greenAccent
                                                            .withOpacity(0.15)
                                                      : Colors.white
                                                            .withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: isOnline
                                                        ? Colors.greenAccent
                                                              .withOpacity(0.3)
                                                        : Colors.white
                                                              .withOpacity(0.1),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.circle,
                                                      color: isOnline
                                                          ? Colors.greenAccent
                                                          : Colors.grey,
                                                      size: 8,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isOnline
                                                          ? "Online"
                                                          : "Offline",
                                                      style: TextStyle(
                                                        color: isOnline
                                                            ? Colors.greenAccent
                                                            : Colors.white54,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              StreamBuilder<int>(
                                                stream: _chatService
                                                    .getUnreadCount(user['id']),
                                                builder: (context, unreadSnapshot) {
                                                  final unreadCount =
                                                      unreadSnapshot.data ?? 0;
                                                  return Stack(
                                                    children: [
                                                      Container(
                                                        height: 42,
                                                        width: 42,
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                          gradient:
                                                              const LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0xff6b28b8,
                                                                  ),
                                                                  Color(
                                                                    0xff4b0f89,
                                                                  ),
                                                                ],
                                                              ),
                                                          border: Border.all(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                  .12,
                                                                ),
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: gold
                                                                  .withOpacity(
                                                                    0.2,
                                                                  ),
                                                              blurRadius: 8,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    2,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Center(
                                                          child: SizedBox(
                                                            height: 24,
                                                            width: 24,
                                                            child: Image.asset(
                                                              'assets/comments.png',
                                                              fit: BoxFit
                                                                  .contain,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) {
                                                                    return const Icon(
                                                                      Icons
                                                                          .chat_bubble_outline,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 20,
                                                                    );
                                                                  },
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      if (unreadCount > 0)
                                                        Positioned(
                                                          right: 0,
                                                          top: 0,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  4,
                                                                ),
                                                            decoration:
                                                                const BoxDecoration(
                                                                  color: Colors
                                                                      .red,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                            constraints:
                                                                const BoxConstraints(
                                                                  minWidth: 18,
                                                                  minHeight: 18,
                                                                ),
                                                            child: Text(
                                                              unreadCount
                                                                  .toString(),
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
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
