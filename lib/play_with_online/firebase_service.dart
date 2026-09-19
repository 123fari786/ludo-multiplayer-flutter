import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return null;
    }
  }

  // Update user coins
  Future<void> updateUserCoins(String userId, int newCoins) async {
    await _firestore.collection('users').doc(userId).update({
      'coins': newCoins,
    });
  }

  // Get user coins
  Future<int> getUserCoins(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return 0;

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final coinsValue = data['coins'];

      if (coinsValue is int) return coinsValue;
      if (coinsValue is num) return coinsValue.toInt();

      return int.tryParse(coinsValue?.toString() ?? '0') ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting user coins: $e');
      return 0;
    }
  }

  // Real-time Database references for matchmaking
  DatabaseReference get waitingRoomRef => _rtdb.child('waiting_room');
  DatabaseReference get matchesRef => _rtdb.child('matches');

  // Create a waiting entry for a player with timestamp
  Future<String?> addToWaitingRoom({
    required String userId,
    required String userName,
    required String profileImage,
    required int coins,
    required int entryFee,
  }) async {
    try {
      String waitingId = _rtdb.child('waiting_room').push().key!;

      // Use ServerValue.timestamp for consistent server time
      Map<String, dynamic> waitingData = {
        'userId': userId,
        'userName': userName,
        'profileImage': profileImage,
        'coins': coins,
        'entryFee': entryFee,
        'timestamp': ServerValue.timestamp,
        'status': 'waiting',
      };

      await waitingRoomRef.child(waitingId).set(waitingData);
      debugPrint('✅ Added to waiting room: $waitingId with timestamp');
      return waitingId;
    } catch (e) {
      debugPrint('❌ Error adding to waiting room: $e');
      return null;
    }
  }

  // Get existing match between two players
  Future<String?> getExistingMatch(String player1Id, String player2Id) async {
    try {
      final snapshot = await matchesRef.once();
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> matchesMap = snapshot.snapshot.value as Map;
        for (var entry in matchesMap.entries) {
          Map<String, dynamic> matchData = Map<String, dynamic>.from(
            entry.value,
          );
          String gameStatus = matchData['gameStatus'] ?? '';

          // Check if both players are in this match and status is not completed
          if ((matchData['player1Id'] == player1Id &&
                  matchData['player2Id'] == player2Id) ||
              (matchData['player1Id'] == player2Id &&
                  matchData['player2Id'] == player1Id)) {
            if (gameStatus == 'waiting_to_start' ||
                gameStatus == 'ready_to_start' ||
                gameStatus == 'playing' ||
                gameStatus == 'active' ||
                gameStatus == 'waiting_colors') {
              debugPrint(
                '📌 Found existing match: ${entry.key} with status: $gameStatus',
              );
              return entry.key;
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking existing match: $e');
      return null;
    }
  }

  // Clean user's waiting room entry
  Future<void> cleanUserWaitingEntry(String userId) async {
    try {
      final snapshot = await waitingRoomRef.once();
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> waitingMap = snapshot.snapshot.value as Map;
        List<String> keysToRemove = [];

        for (var entry in waitingMap.entries) {
          Map<String, dynamic> playerData = Map<String, dynamic>.from(
            entry.value,
          );
          if (playerData['userId'] == userId) {
            keysToRemove.add(entry.key);
          }
        }

        for (String key in keysToRemove) {
          await waitingRoomRef.child(key).remove();
          debugPrint('🧹 Cleaned waiting room entry: $key');
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning waiting entry: $e');
    }
  }

  // Remove from waiting room
  Future<void> removeFromWaitingRoom(String waitingId) async {
    try {
      await waitingRoomRef.child(waitingId).remove();
      debugPrint('✅ Removed from waiting room: $waitingId');
    } catch (e) {
      debugPrint('❌ Error removing from waiting room: $e');
    }
  }

  // Listen for waiting players
  Stream<DatabaseEvent> listenToWaitingRoom() {
    return waitingRoomRef.orderByChild('timestamp').limitToLast(50).onValue;
  }

  // Create a match between two players with auto color assignment
  Future<String?> createMatch({
    required String player1Id,
    required String player1Name,
    required String player1Image,
    required int player1Coins,
    required String player2Id,
    required String player2Name,
    required String player2Image,
    required int player2Coins,
    required int entryFee,
  }) async {
    try {
      String matchId = _rtdb.child('matches').push().key!;

      Map<String, dynamic> matchData = {
        'roomId': matchId,
        'player1Id': player1Id,
        'player1Name': player1Name,
        'player1Image': player1Image,
        'player1Coins': player1Coins,
        'player2Id': player2Id,
        'player2Name': player2Name,
        'player2Image': player2Image,
        'player2Coins': player2Coins,
        'entryFee': entryFee,
        'winPrize': entryFee + (entryFee ~/ 2),
        'player1Color': '',
        'player2Color': '',
        'currentTurn': '', // Will be set after color assignment
        'gameStatus': 'waiting_colors',
        'createdAt': ServerValue.timestamp,
        'winner': null,
      };

      await matchesRef.child(matchId).set(matchData);
      debugPrint(
        '✅ Match created: $matchId with Player1: $player1Name, Player2: $player2Name',
      );

      // Remove both players from waiting room
      await _removePlayersFromWaitingRoom(player1Id, player2Id);

      return matchId;
    } catch (e) {
      debugPrint('❌ Error creating match: $e');
      return null;
    }
  }

  Future<void> _removePlayersFromWaitingRoom(
    String player1Id,
    String player2Id,
  ) async {
    try {
      final waitingSnapshot = await waitingRoomRef.once();
      if (waitingSnapshot.snapshot.value != null) {
        Map<dynamic, dynamic> waitingMap =
            waitingSnapshot.snapshot.value as Map;
        for (var entry in waitingMap.entries) {
          Map<String, dynamic> playerData = Map<String, dynamic>.from(
            entry.value,
          );
          if (playerData['userId'] == player1Id ||
              playerData['userId'] == player2Id) {
            await waitingRoomRef.child(entry.key).remove();
            debugPrint(
              '✅ Removed player from waiting room: ${playerData['userId']}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error removing players from waiting room: $e');
    }
  }

  // Listen to match updates
  Stream<DatabaseEvent> listenToMatch(String matchId) {
    return matchesRef.child(matchId).onValue;
  }

  DatabaseReference get matchLocksRef => _rtdb.child('match_locks');
  String _getPairKey(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  bool _isCompletedMatch(Map<String, dynamic> data) {
    final gameStatus = data['gameStatus']?.toString().toLowerCase() ?? '';
    final status = data['status']?.toString().toLowerCase() ?? '';
    final winner = data['winner']?.toString() ?? '';
    final winnerId = data['winnerId']?.toString() ?? '';

    return gameStatus == 'completed' ||
        gameStatus == 'finished' ||
        status == 'completed' ||
        status == 'finished' ||
        winner.isNotEmpty ||
        winnerId.isNotEmpty;
  }

  String _readPlayerId(
    Map<String, dynamic> data,
    String flatKey,
    String nestedKey,
  ) {
    final flatValue = data[flatKey]?.toString() ?? '';
    if (flatValue.isNotEmpty) return flatValue;

    final nestedValue = data[nestedKey];
    if (nestedValue is Map && nestedValue['userId'] != null) {
      return nestedValue['userId'].toString();
    }

    return '';
  }

  Future<void> cleanupCompletedMatchesForPair({
    required String player1Id,
    required String player2Id,
  }) async {
    try {
      final pairKey = _getPairKey(player1Id, player2Id);
      final updates = <String, Object?>{'match_locks/$pairKey': null};

      final matchesSnapshot = await matchesRef.once();

      if (matchesSnapshot.snapshot.value != null) {
        final matchesMap = Map<dynamic, dynamic>.from(
          matchesSnapshot.snapshot.value as Map,
        );

        for (final entry in matchesMap.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);

          final p1 = _readPlayerId(data, 'player1Id', 'player1');
          final p2 = _readPlayerId(data, 'player2Id', 'player2');

          final samePair =
              (p1 == player1Id && p2 == player2Id) ||
              (p1 == player2Id && p2 == player1Id);

          if (samePair && _isCompletedMatch(data)) {
            updates['matches/${entry.key}'] = null;
          }
        }
      }

      await _rtdb.update(updates);

      debugPrint('🧹 Completed old matches cleaned for pair: $pairKey');
    } catch (e) {
      debugPrint('❌ cleanupCompletedMatchesForPair error: $e');
    }
  }

  Future<void> cleanupCompletedMatchAfterResult({
    required String matchId,
    required String currentUserId,
    required String opponentUserId,
  }) async {
    try {
      final pairKey = _getPairKey(currentUserId, opponentUserId);
      final matchSnap = await matchesRef.child(matchId).once();

      final updates = <String, Object?>{'match_locks/$pairKey': null};

      if (matchSnap.snapshot.value != null) {
        final data = Map<String, dynamic>.from(matchSnap.snapshot.value as Map);

        // Sirf completed match delete karo.
        // Active match galti se delete nahi hoga.
        if (_isCompletedMatch(data)) {
          updates['matches/$matchId'] = null;
        }
      }

      await _rtdb.update(updates);

      debugPrint('🧹 Completed match cleaned after result: $matchId');
    } catch (e) {
      debugPrint('❌ cleanupCompletedMatchAfterResult error: $e');
    }
  }

  Future<Map<String, dynamic>?> createOrGetMatchOnce({
    required String player1Id,
    required String player1Name,
    required String player1Image,
    required int player1Coins,
    required String player2Id,
    required String player2Name,
    required String player2Image,
    required int player2Coins,
    required int entryFee,
  }) async {
    try {
      final pairKey = _getPairKey(player1Id, player2Id);
      final lockRef = matchLocksRef.child(pairKey);

      // Pehle old completed match/lock clean karo
      await cleanupCompletedMatchesForPair(
        player1Id: player1Id,
        player2Id: player2Id,
      );

      final newMatchId = matchesRef.push().key!;

      final result = await lockRef.runTransaction((Object? currentData) {
        if (currentData != null) {
          final data = Map<String, dynamic>.from(currentData as Map);
          final existingMatchId = data['matchId']?.toString() ?? '';

          // Agar lock me active match hai to new create na karo
          if (existingMatchId.isNotEmpty) {
            return Transaction.abort();
          }
        }

        return Transaction.success({
          'matchId': newMatchId,
          'player1Id': player1Id,
          'player2Id': player2Id,
          'createdAt': ServerValue.timestamp,
        });
      });

      if (result.committed) {
        final matchData = {
          'roomId': newMatchId,

          'player1Id': player1Id,
          'player1Name': player1Name,
          'player1Image': player1Image,
          'player1Coins': player1Coins,

          'player2Id': player2Id,
          'player2Name': player2Name,
          'player2Image': player2Image,
          'player2Coins': player2Coins,

          'entryFee': entryFee,
          'winPrize': entryFee + (entryFee ~/ 2),

          'player1Color': 'Red',
          'player2Color': 'Yellow',

          'currentTurn': player1Id,
          'diceValue': 0,
          'currentDiceNumber': 0,
          'hasRolledDice': false,

          'gameStatus': 'ready_to_start',
          'status': 'ready_to_start',

          'lastActionBy': '',
          'createdAt': ServerValue.timestamp,
          'lastMoveTime': ServerValue.timestamp,

          'winner': null,
          'winnerId': '',
          'winnerColor': '',
          'loserId': '',
        };

        await matchesRef.child(newMatchId).set(matchData);
        await _removePlayersFromWaitingRoom(player1Id, player2Id);

        debugPrint('✅ New clean match created: $newMatchId');

        return {
          'matchId': newMatchId,
          'isNew': true,
          'player1Id': player1Id,
          'player2Id': player2Id,
        };
      }

      // Agar transaction abort hui, active lock ka match read karo
      final lockSnapshot = await lockRef.once();

      if (lockSnapshot.snapshot.value != null) {
        final lockData = Map<String, dynamic>.from(
          lockSnapshot.snapshot.value as Map,
        );

        final existingMatchId = lockData['matchId']?.toString() ?? '';

        if (existingMatchId.isNotEmpty) {
          final matchSnapshot = await matchesRef.child(existingMatchId).once();

          // Agar lock old/deleted match ki taraf point kar raha hai to lock remove
          if (matchSnapshot.snapshot.value == null) {
            await lockRef.remove();
            return null;
          }

          final matchData = Map<String, dynamic>.from(
            matchSnapshot.snapshot.value as Map,
          );

          // Agar existing match completed hai to delete karo aur null return karo
          // Next waiting event me new match ban jayega.
          if (_isCompletedMatch(matchData)) {
            await _rtdb.update({
              'matches/$existingMatchId': null,
              'match_locks/$pairKey': null,
            });

            debugPrint(
              '🧹 Old completed locked match removed: $existingMatchId',
            );
            return null;
          }

          return {
            'matchId': existingMatchId,
            'isNew': false,
            'player1Id': player1Id,
            'player2Id': player2Id,
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ createOrGetMatchOnce error: $e');
      return null;
    }
  }

  // Check if user is already in waiting room
  Future<bool> isUserInWaitingRoom(String userId) async {
    try {
      final snapshot = await waitingRoomRef.once();
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> waitingMap = snapshot.snapshot.value as Map;
        for (var entry in waitingMap.values) {
          Map<String, dynamic> playerData = Map<String, dynamic>.from(entry);
          if (playerData['userId'] == userId &&
              playerData['status'] == 'waiting') {
            debugPrint('✅ User already in waiting room: $userId');
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking waiting room: $e');
      return false;
    }
  }

  // Get user's active match
  Future<String?> getUserActiveMatch(String userId) async {
    try {
      final snapshot = await matchesRef.once();
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> matchesMap = snapshot.snapshot.value as Map;
        for (var entry in matchesMap.entries) {
          Map<String, dynamic> matchData = Map<String, dynamic>.from(
            entry.value,
          );
          if ((matchData['player1Id'] == userId ||
                  matchData['player2Id'] == userId) &&
              (matchData['gameStatus'] == 'waiting_colors' ||
                  matchData['gameStatus'] == 'waiting_to_start' ||
                  matchData['gameStatus'] == 'playing')) {
            return entry.key;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting active match: $e');
      return null;
    }
  }

  // Delete match after game ends
  Future<void> deleteMatch(String matchId) async {
    try {
      await matchesRef.child(matchId).remove();
      debugPrint('✅ Match deleted: $matchId');
    } catch (e) {
      debugPrint('❌ Error deleting match: $e');
    }
  }

  Future<void> cleanupAbandonedMatch({
    required String matchId,
    required String currentUserId,
    required String opponentUserId,
  }) async {
    try {
      final updates = <String, Object?>{};
      final pairKey = _getPairKey(currentUserId, opponentUserId);

      bool isIncompleteMatch(Map<String, dynamic> data) {
        final gameStatus = data['gameStatus']?.toString().toLowerCase() ?? '';
        final status = data['status']?.toString().toLowerCase() ?? '';
        final winner = data['winner']?.toString() ?? '';

        final completed =
            gameStatus == 'completed' ||
            gameStatus == 'finished' ||
            status == 'completed' ||
            status == 'finished' ||
            winner.isNotEmpty;

        return !completed;
      }

      String readPlayerId(
        Map<String, dynamic> data,
        String flatKey,
        String nestedKey,
      ) {
        final flatValue = data[flatKey]?.toString() ?? '';
        if (flatValue.isNotEmpty) return flatValue;

        final nestedValue = data[nestedKey];
        if (nestedValue is Map && nestedValue['userId'] != null) {
          return nestedValue['userId'].toString();
        }

        return '';
      }

      // 1) Same dono users ke incomplete matches remove karo
      final matchesSnapshot = await matchesRef.once();

      if (matchesSnapshot.snapshot.value != null) {
        final matchesMap = Map<dynamic, dynamic>.from(
          matchesSnapshot.snapshot.value as Map,
        );

        for (final entry in matchesMap.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);

          final player1Id = readPlayerId(data, 'player1Id', 'player1');
          final player2Id = readPlayerId(data, 'player2Id', 'player2');

          final samePair =
              (player1Id == currentUserId && player2Id == opponentUserId) ||
              (player1Id == opponentUserId && player2Id == currentUserId);

          if (samePair && isIncompleteMatch(data)) {
            updates['matches/${entry.key}'] = null;
          }
        }
      }

      // Safety: current match id bhi remove karo, agar above loop miss kar de
      updates['matches/$matchId'] = null;

      // 2) Match lock remove karo warna same users old match lock me phas jayenge
      updates['match_locks/$pairKey'] = null;

      // 3) Dono users ke waiting room entries remove karo
      final waitingSnapshot = await waitingRoomRef.once();

      if (waitingSnapshot.snapshot.value != null) {
        final waitingMap = Map<dynamic, dynamic>.from(
          waitingSnapshot.snapshot.value as Map,
        );

        for (final entry in waitingMap.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);
          final userId = data['userId']?.toString() ?? '';

          if (userId == currentUserId || userId == opponentUserId) {
            updates['waiting_room/${entry.key}'] = null;
          }
        }
      }

      if (updates.isNotEmpty) {
        await _rtdb.update(updates);
      }

      debugPrint('✅ Abandoned match cleaned completely: $matchId');
    } catch (e) {
      debugPrint('❌ Error cleaning abandoned match: $e');
    }
  }

  Future<void> completeMatchAsOpponentWinOnExit({
    required String matchId,
    required String currentUserId,
    required String opponentUserId,
  }) async {
    try {
      final matchRef = matchesRef.child(matchId);

      await matchRef.runTransaction((Object? currentData) {
        if (currentData == null) return Transaction.abort();

        final data = Map<String, dynamic>.from(currentData as Map);

        final status = data['status']?.toString().toLowerCase() ?? '';
        final gameStatus = data['gameStatus']?.toString().toLowerCase() ?? '';

        // Agar match already complete hai to dobara winner change nahi hoga
        if (status == 'completed' || gameStatus == 'completed') {
          return Transaction.success(data);
        }

        final int entryFee = _parseIntValue(data['entryFee']);
        final int winPrize = _parseIntValue(
          data['winPrize'],
          fallback: entryFee + (entryFee ~/ 2),
        );

        final String player1Id = data['player1Id']?.toString() ?? '';
        final String player2Id = data['player2Id']?.toString() ?? '';

        String winnerColor = '';

        if (opponentUserId == player1Id) {
          winnerColor = data['player1Color']?.toString() ?? '';
        } else if (opponentUserId == player2Id) {
          winnerColor = data['player2Color']?.toString() ?? '';
        }

        data['status'] = 'completed';
        data['gameStatus'] = 'completed';

        // Jo user exit karega wo loser hoga
        data['winner'] = opponentUserId;
        data['winnerId'] = opponentUserId;
        data['winnerColor'] = winnerColor;
        data['loserId'] = currentUserId;

        data['entryFee'] = entryFee;
        data['winPrize'] = winPrize;

        data['endReason'] = 'user_exit';
        data['exitBy'] = currentUserId;
        data['endTime'] = ServerValue.timestamp;

        data['currentTurn'] = '';
        data['hasRolledDice'] = false;
        data['lastActionBy'] = currentUserId;

        return Transaction.success(data);
      });

      // Match complete rahega taake opponent screen ko winner event mil sake.
      // Sirf lock/waiting clean karo, match delete nahi karna.
      final pairKey = _getPairKey(currentUserId, opponentUserId);
      final updates = <String, Object?>{'match_locks/$pairKey': null};

      final waitingSnapshot = await waitingRoomRef.once();

      if (waitingSnapshot.snapshot.value != null) {
        final waitingMap = Map<dynamic, dynamic>.from(
          waitingSnapshot.snapshot.value as Map,
        );

        for (final entry in waitingMap.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);
          final userId = data['userId']?.toString() ?? '';

          if (userId == currentUserId || userId == opponentUserId) {
            updates['waiting_room/${entry.key}'] = null;
          }
        }
      }

      await _rtdb.update(updates);

      debugPrint(
        '✅ Exit completed match: loser=$currentUserId winner=$opponentUserId',
      );
    } catch (e) {
      debugPrint('❌ completeMatchAsOpponentWinOnExit error: $e');
    }
  }

  Future<bool> deductEntryFeeOnceForMatch({
    required String matchId,
    required String userId,
    required int entryFee,
  }) async {
    if (entryFee <= 0) return true;

    try {
      final String? authUserId = _auth.currentUser?.uid;

      if (authUserId == null || authUserId != userId) {
        debugPrint('❌ Invalid auth user for entry fee deduction');
        return false;
      }

      final userRef = _firestore.collection('users').doc(userId);

      // IMPORTANT:
      // Firestore rules me top-level match_entry_fee_deductions allowed nahi hai.
      // Is liye user ke andar allowed sub-collection use kar rahe hain:
      // users/{userId}/matches/{matchId}
      final deductionRef = userRef.collection('matches').doc(matchId);

      bool success = false;

      await _firestore.runTransaction((transaction) async {
        final deductionSnap = await transaction.get(deductionRef);

        // Same match ke liye same user se dobara coins deduct nahi honge
        if (deductionSnap.exists) {
          final alreadyDeducted =
              deductionSnap.data()?['entryFeeDeducted'] == true;

          if (alreadyDeducted) {
            debugPrint('✅ Entry fee already deducted for this match');
            success = true;
            return;
          }
        }

        final userSnap = await transaction.get(userRef);

        if (!userSnap.exists) {
          throw Exception('USER_NOT_FOUND');
        }

        final data = userSnap.data() as Map<String, dynamic>? ?? {};
        final coinsValue = data['coins'];

        int currentCoins = 0;

        if (coinsValue is int) {
          currentCoins = coinsValue;
        } else if (coinsValue is num) {
          currentCoins = coinsValue.toInt();
        } else {
          currentCoins = int.tryParse(coinsValue?.toString() ?? '0') ?? 0;
        }

        if (currentCoins < entryFee) {
          throw Exception('INSUFFICIENT_COINS');
        }

        final int newCoins = currentCoins - entryFee;

        transaction.update(userRef, {'coins': newCoins});

        transaction.set(deductionRef, {
          'matchId': matchId,
          'userId': userId,
          'entryFee': entryFee,
          'coinsBefore': currentCoins,
          'coinsAfter': newCoins,
          'entryFeeDeducted': true,
          'deductedAt': FieldValue.serverTimestamp(),
          'reason': 'online_match_entry_fee',
        }, SetOptions(merge: true));

        success = true;
      });

      if (success) {
        await matchesRef
            .child(matchId)
            .child('entryFeeDeducted')
            .child(userId)
            .set({
              'deducted': true,
              'entryFee': entryFee,
              'deductedAt': ServerValue.timestamp,
            });
      }

      debugPrint('✅ Entry fee deducted successfully for match: $matchId');
      return success;
    } catch (e) {
      debugPrint('❌ Entry fee deduction failed: $e');
      return false;
    }
  }

  int _parseIntValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<Map<String, dynamic>> settleOnlineMatchResultForCurrentUser({
    required String matchId,
    required String userId,
    required String winnerId,
    required int entryFee,
    required int winPrize,
  }) async {
    try {
      final String? authUserId = _auth.currentUser?.uid;

      if (authUserId == null || authUserId != userId) {
        return {'success': false, 'message': 'Invalid user'};
      }

      final bool isWinner = userId == winnerId;

      final userRef = _firestore.collection('users').doc(userId);
      final matchResultRef = userRef.collection('matches').doc(matchId);

      Map<String, dynamic> result = {
        'success': false,
        'isWinner': isWinner,
        'coinsChanged': 0,
        'alreadySettled': false,
      };

      await _firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final matchSnap = await transaction.get(matchResultRef);

        if (!userSnap.exists) {
          throw Exception('USER_NOT_FOUND');
        }

        final matchData = matchSnap.data() as Map<String, dynamic>? ?? {};

        // Same match ka result dobara apply nahi hoga
        if (matchData['resultSettled'] == true) {
          result = {
            'success': true,
            'isWinner': isWinner,
            'coinsChanged': _parseIntValue(matchData['coinsChanged']),
            'alreadySettled': true,
          };
          return;
        }

        final userData = userSnap.data() as Map<String, dynamic>? ?? {};
        final int currentCoins = _parseIntValue(userData['coins']);

        int coinsChanged = 0;

        if (isWinner) {
          // Winner ko reward add hoga.
          coinsChanged = winPrize;
        } else {
          // Entry fee start game par already deduct hoti hai.
          final bool entryFeeAlreadyDeducted =
              matchData['entryFeeDeducted'] == true;

          coinsChanged = entryFeeAlreadyDeducted ? 0 : -entryFee;

          if (!entryFeeAlreadyDeducted && currentCoins < entryFee) {
            throw Exception('INSUFFICIENT_COINS');
          }
        }

        final int newCoins = currentCoins + coinsChanged;

        // IMPORTANT:
        // Direct coins = newCoins ki jagah increment use karo,
        // taake kisi aur live update ko overwrite na kare.
        if (coinsChanged != 0) {
          transaction.update(userRef, {
            'coins': FieldValue.increment(coinsChanged),
          });
        }

        transaction.set(matchResultRef, {
          'matchId': matchId,
          'winnerId': winnerId,
          'entryFee': entryFee,
          'winPrize': winPrize,
          'result': isWinner ? 'win' : 'loss',
          'coinsBeforeResult': currentCoins,
          'coinsAfterResult': newCoins,
          'coinsChanged': coinsChanged,
          'resultSettled': true,
          'resultSettledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        result = {
          'success': true,
          'isWinner': isWinner,
          'coinsChanged': coinsChanged,
          'alreadySettled': false,
        };
      });

      debugPrint(
        '✅ Match result settled: match=$matchId user=$userId winner=$winnerId coins=${result['coinsChanged']}',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Match result settlement error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get match data with colors
  Future<Map<String, dynamic>?> getMatchData(String matchId) async {
    try {
      final snapshot = await matchesRef.child(matchId).once();
      if (snapshot.snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting match data: $e');
      return null;
    }
  }
}
