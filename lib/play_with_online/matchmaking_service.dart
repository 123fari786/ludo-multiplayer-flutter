import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'firebase_service.dart';

class MatchmakingService {
  static final MatchmakingService _instance = MatchmakingService._internal();
  factory MatchmakingService() => _instance;
  MatchmakingService._internal();

  final FirebaseService _firebase = FirebaseService();
  StreamSubscription? _waitingSubscription;
  String? _currentMatchId;
  String? _currentWaitingId;
  bool _isCreatingMatch = false;

  // Color pairs for automatic assignment
  static const List<List<String>> _colorPairs = [
    ['Red', 'Green'],
    ['Yellow', 'Blue'],
  ];

  // Start searching for opponent
  Future<String?> startSearching({
    required String userId,
    required String userName,
    required String profileImage,
    required int coins,
    required int entryFee,
    Function(Map<String, dynamic>)? onMatchFound,
  }) async {
    debugPrint('🎯 Starting search for user: $userId');

    // Check if already in waiting room
    bool isWaiting = await _firebase.isUserInWaitingRoom(userId);
    if (isWaiting) {
      debugPrint('⚠️ User already in waiting room');
      return null;
    }

    // Add to waiting room
    String? waitingId = await _firebase.addToWaitingRoom(
      userId: userId,
      userName: userName,
      profileImage: profileImage,
      coins: coins,
      entryFee: entryFee,
    );

    _currentWaitingId = waitingId;
    debugPrint('✅ Added to waiting room with ID: $waitingId');

    // Listen for matches
    _waitingSubscription = _firebase.listenToWaitingRoom().listen((
      event,
    ) async {
      if (event.snapshot.value != null &&
          _currentMatchId == null &&
          !_isCreatingMatch) {
        Map<dynamic, dynamic> waitingMap = event.snapshot.value as Map;

        debugPrint('📡 Waiting room has ${waitingMap.length} players');

        // Find ANOTHER player (not self) who is waiting
        String? opponentWaitingId;
        Map<String, dynamic>? opponentData;
        String? myWaitingId;

        // First find my own waiting entry and opponent
        for (var entry in waitingMap.entries) {
          Map<String, dynamic> playerData = Map<String, dynamic>.from(
            entry.value,
          );
          if (playerData['userId'] == userId) {
            myWaitingId = entry.key;
            debugPrint('📍 Found my waiting entry: $myWaitingId');
          } else if (playerData['userId'] != userId &&
              playerData['status'] == 'waiting' &&
              playerData['entryFee'] == entryFee) {
            opponentWaitingId = entry.key;
            opponentData = playerData;
            debugPrint('🎯 Found opponent: ${opponentData!['userName']}');
          }
        }

        // IMPORTANT: Determine who is player1 (first in waiting room)
        // Player1 is the one with EARLIER timestamp
        if (opponentWaitingId != null &&
            opponentData != null &&
            myWaitingId != null &&
            _currentMatchId == null) {
          _isCreatingMatch = true;
          debugPrint('🤝 Creating match...');

          // Get both waiting entries to compare timestamps
          final mySnapshot = await _firebase.waitingRoomRef
              .child(myWaitingId)
              .once();
          final opponentSnapshot = await _firebase.waitingRoomRef
              .child(opponentWaitingId)
              .once();

          Map<String, dynamic> myData = Map<String, dynamic>.from(
            mySnapshot.snapshot.value as Map,
          );
          Map<String, dynamic> oppData = Map<String, dynamic>.from(
            opponentSnapshot.snapshot.value as Map,
          );

          int myTimestamp = myData['timestamp'] ?? 0;
          int oppTimestamp = oppData['timestamp'] ?? 0;

          // Determine who joined first (earlier timestamp = Player 1)
          String player1Id, player1Name, player1Image;
          int player1Coins;
          String player2Id, player2Name, player2Image;
          int player2Coins;
          bool isPlayer1;

          if (myTimestamp < oppTimestamp) {
            // I joined first - I am Player 1
            player1Id = userId;
            player1Name = userName;
            player1Image = profileImage;
            player1Coins = coins;
            player2Id = opponentData['userId'];
            player2Name = opponentData['userName'];
            player2Image = opponentData['profileImage'];
            player2Coins = opponentData['coins'];
            isPlayer1 = true;
            debugPrint('👑 I am Player 1 (joined first)');
          } else {
            // Opponent joined first - Opponent is Player 1, I am Player 2
            player1Id = opponentData['userId'];
            player1Name = opponentData['userName'];
            player1Image = opponentData['profileImage'];
            player1Coins = opponentData['coins'];
            player2Id = userId;
            player2Name = userName;
            player2Image = profileImage;
            player2Coins = coins;
            isPlayer1 = false;
            debugPrint('👑 I am Player 2 (joined second)');
          }
          await _firebase.cleanupCompletedMatchesForPair(
            player1Id: player1Id,
            player2Id: player2Id,
          );
          // Check if a match already exists for these players
          String? existingMatch = await _firebase.getExistingMatch(
            player1Id,
            player2Id,
          );

          if (existingMatch != null) {
            debugPrint('⚠️ Match already exists: $existingMatch');
            _currentMatchId = existingMatch;

            await _waitingSubscription?.cancel();
            _waitingSubscription = null;

            if (_currentWaitingId != null) {
              await _firebase.removeFromWaitingRoom(_currentWaitingId!);
            }

            _isCreatingMatch = false;
            onMatchFound?.call({
              'matchId': existingMatch,
              'opponent': opponentData,
              'isPlayer1': isPlayer1,
              'player1Id': player1Id,
              'player2Id': player2Id,
            });
            return;
          }

          // Create new match with correct player order and auto colors
          final matchResult = await _firebase.createOrGetMatchOnce(
            player1Id: player1Id,
            player1Name: player1Name,
            player1Image: player1Image,
            player1Coins: player1Coins,
            player2Id: player2Id,
            player2Name: player2Name,
            player2Image: player2Image,
            player2Coins: player2Coins,
            entryFee: entryFee,
          );

          if (matchResult != null && matchResult['matchId'] != null) {
            final matchId = matchResult['matchId'].toString();

            _currentMatchId = matchId;

            debugPrint('✅ FINAL MATCH ID FOR BOTH DEVICES: $matchId');

            await _waitingSubscription?.cancel();
            _waitingSubscription = null;

            if (_currentWaitingId != null) {
              await _firebase.removeFromWaitingRoom(_currentWaitingId!);
            }

            _isCreatingMatch = false;

            onMatchFound?.call({
              'matchId': matchId,
              'opponent': opponentData,
              'isPlayer1': isPlayer1,
              'player1Id': player1Id,
              'player2Id': player2Id,
            });
          } else {
            _isCreatingMatch = false;
          }
        }
      }
    });

    return waitingId;
  }

  // Automatic color assignment
  static const Map<String, String> _playerColors = {
    'player1': 'Red',
    'player2': 'Yellow',
  };

  // Automatic color assignment - FIXED: Always Player1=Red, Player2=Yellow
  Future<void> _assignColorsToMatch(
    String matchId,
    String player1Id,
    String player2Id,
  ) async {
    try {
      // Player 1 always gets Red, Player 2 always gets Yellow
      String player1Color = 'Red';
      String player2Color = 'Yellow';

      debugPrint('🎨 Assigned Colors (FIXED):');
      debugPrint('  Player 1: $player1Color');
      debugPrint('  Player 2: $player2Color');

      // Determine first turn (Player 1 gets first turn by default)
      String firstTurn = player1Id;

      // Update match with colors and initial turn
      await _firebase.matchesRef.child(matchId).update({
        'player1Color': player1Color,
        'player2Color': player2Color,
        'currentTurn': firstTurn,
        'gameStatus': 'ready_to_start',
      });

      debugPrint('✅ Colors assigned and turn set to Player 1');
    } catch (e) {
      debugPrint('❌ Error assigning colors: $e');
    }
  }

  // Cancel search
  Future<void> cancelSearch(String waitingId) async {
    debugPrint('🛑 Cancelling search for waiting ID: $waitingId');
    await _waitingSubscription?.cancel();
    _waitingSubscription = null;
    await _firebase.removeFromWaitingRoom(waitingId);
    _currentWaitingId = null;
    _currentMatchId = null;
    _isCreatingMatch = false;
  }

  // Get current match ID
  String? get currentMatchId => _currentMatchId;

  // Listen to match
  Stream<DatabaseEvent> listenToMatch(String matchId) {
    return _firebase.listenToMatch(matchId);
  }

  // DEPRECATED: This method is no longer used (automatic color assignment)
  // Kept for backward compatibility to avoid errors
  Future<void> selectColor(String matchId, String userId, String color) async {
    debugPrint(
      '⚠️ selectColor() is deprecated. Colors are assigned automatically.',
    );
    // Do nothing - colors are assigned automatically in _assignColorsToMatch
  }

  // Wait for game to be ready
  Stream<bool> waitForGameReady(String matchId) {
    return _firebase.matchesRef.child(matchId).onValue.map((event) {
      if (event.snapshot.value != null) {
        Map<String, dynamic> matchData = Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );
        String status = matchData['gameStatus'] ?? '';
        return status == 'ready_to_start' || status == 'playing';
      }
      return false;
    }).distinct();
  }

  // Get match data with colors
  Future<Map<String, dynamic>?> getMatchData(String matchId) async {
    try {
      final snapshot = await _firebase.matchesRef.child(matchId).once();
      if (snapshot.snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting match data: $e');
      return null;
    }
  }

  // Clean up
  void dispose() {
    _waitingSubscription?.cancel();
    _waitingSubscription = null;
    _currentMatchId = null;
    _currentWaitingId = null;
    _isCreatingMatch = false;
  }
}
