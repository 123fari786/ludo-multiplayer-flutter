import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  // Cache variables
  List<Map<String, dynamic>> _cachedUsers = [];
  Map<String, bool> _cachedOnlineStatus = {};
  final Map<String, List<Map<String, dynamic>>> _cachedMessages = {};
  bool _isCacheLoaded = false;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ==================== CACHE METHODS ====================

  Future<void> initCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUsers = prefs.getString('cached_users');
      if (cachedUsers != null) {
        _cachedUsers = List<Map<String, dynamic>>.from(
          json.decode(cachedUsers),
        );
      }
      final cachedStatus = prefs.getString('cached_online_status');
      if (cachedStatus != null) {
        final Map<String, dynamic> decoded = json.decode(cachedStatus);
        _cachedOnlineStatus = decoded.map(
          (key, value) => MapEntry(key, value as bool),
        );
      }
      _isCacheLoaded = true;
    } catch (e) {
      print('Error loading cache: $e');
    }
  }

  List<Map<String, dynamic>> getCachedUsersInstant() => _cachedUsers;
  Map<String, bool> getCachedOnlineStatusInstant() => _cachedOnlineStatus;

  List<Map<String, dynamic>> getCachedMessagesInstant(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];
    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);
    return _cachedMessages[chatRoomId] ?? [];
  }

  Future<void> _saveUsersToCache(List<Map<String, dynamic>> users) async {
    _cachedUsers = users;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_users', json.encode(users));
    } catch (e) {
      print('Error saving users to cache: $e');
    }
  }

  Future<void> _saveOnlineStatusToCache(Map<String, bool> status) async {
    _cachedOnlineStatus = status;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_online_status', json.encode(status));
    } catch (e) {
      print('Error saving online status to cache: $e');
    }
  }

  Future<void> _saveMessagesToCache(
    String chatRoomId,
    List<Map<String, dynamic>> messages,
  ) async {
    _cachedMessages[chatRoomId] = messages;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_messages_$chatRoomId',
        json.encode(messages),
      );
    } catch (e) {
      print('Error saving messages to cache: $e');
    }
  }

  // ==================== USER STATUS ====================

  Future<void> updateUserStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _rtdb.child('users/${user.uid}').set({
        'isOnline': isOnline,
        'lastSeen': ServerValue.timestamp,
        'name': user.displayName ?? 'User',
        'email': user.email,
      });
      print('✅ User status updated: ${isOnline ? "Online" : "Offline"}');
    } catch (e) {
      print('⚠️ Online status update failed: $e');
    }
  }

  // ==================== USERS ====================

  Stream<List<Map<String, dynamic>>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final currentUserId = _auth.currentUser?.uid;
      final users = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        if (doc.id != currentUserId) {
          final data = doc.data();
          users.add({
            'id': doc.id,
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'email': data['email'] ?? '',
            'profileImageBase64': data['profileImageBase64'] ?? '',
            'createdAt': data['createdAt'],
          });
        }
      }
      _saveUsersToCache(users);
      return users;
    });
  }

  // ==================== ONLINE STATUS ====================

  Stream<Map<String, bool>> getOnlineStatus() {
    return _rtdb
        .child('users')
        .onValue
        .handleError((error) {
          print('⚠️ Realtime Database error: $error');
          return Stream<DatabaseEvent>.empty();
        })
        .map((event) {
          final status = <String, bool>{};
          try {
            final data = event.snapshot.value as Map?;
            if (data != null) {
              data.forEach((key, value) {
                if (value is Map) {
                  final isOnline = value['isOnline'] == true;
                  status[key] = isOnline;
                  print('📱 User $key is ${isOnline ? "ONLINE" : "OFFLINE"}');
                }
              });
            }
          } catch (e) {
            print('Error parsing online status: $e');
          }
          _saveOnlineStatusToCache(status);
          return status;
        });
  }

  // ==================== MESSAGES ====================

  Future<void> sendMessage({
    required String receiverId,
    required String message,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messageData = {
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    final chatRoomId = _getChatRoomId(currentUser.uid, receiverId);

    try {
      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chats').doc(chatRoomId).set({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUser.uid, receiverId],
        'lastSenderId': currentUser.uid,
      }, SetOptions(merge: true));

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
    }
  }

  Stream<QuerySnapshot> getMessages(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);

    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final messagesList = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'senderId': data['senderId'] ?? '',
              'receiverId': data['receiverId'] ?? '',
              'message': data['message'] ?? '',
              'timestamp': data['timestamp']?.millisecondsSinceEpoch,
              'isRead': data['isRead'] ?? false,
            };
          }).toList();
          _saveMessagesToCache(chatRoomId, messagesList);
          return snapshot;
        });
  }

  Future<void> markMessageAsRead(String messageId, String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);
    try {
      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      // Silent fail
    }
  }

  Stream<int> getUnreadCount(String otherUserId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    final chatRoomId = _getChatRoomId(currentUser.uid, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  String _getChatRoomId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_users');
      await prefs.remove('cached_online_status');
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('cached_messages_')) {
          await prefs.remove(key);
        }
      }
      _cachedUsers.clear();
      _cachedOnlineStatus.clear();
      _cachedMessages.clear();
      print('✅ Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
