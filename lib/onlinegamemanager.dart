import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'play_with_online/firebase_service.dart';

class OnlineGameManager {
  static final OnlineGameManager _instance = OnlineGameManager._internal();
  factory OnlineGameManager() => _instance;
  OnlineGameManager._internal();

  final FirebaseService _firebase = FirebaseService();
  StreamSubscription? _gameStateSubscription;

  String? currentMatchId;
  String? currentPlayerId;
  String? opponentPlayerId;
  String? myColor;
  String? opponentColor;

  bool isMyTurn = false;
  int currentDiceNumber = 0;
  Map<String, dynamic> currentGameState = {};

  void init(String matchId, String myId, String opponentId) {
    currentMatchId = matchId;
    currentPlayerId = myId;
    opponentPlayerId = opponentId;
  }

  Future<Map<String, dynamic>?> getMatchData() async {
    if (currentMatchId == null) return null;
    final snapshot = await _firebase.matchesRef.child(currentMatchId!).once();
    if (snapshot.snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
  }

  Future<bool> setInitialTurnIfEmpty(String player1UserId) async {
    if (currentMatchId == null) return false;

    final ref = _firebase.matchesRef.child(currentMatchId!);

    final result = await ref.runTransaction((Object? currentData) {
      if (currentData == null) return Transaction.abort();

      final data = Map<String, dynamic>.from(currentData as Map);
      final currentValue = data['currentTurn']?.toString() ?? '';

      if (currentValue.isEmpty) {
        data['currentTurn'] = player1UserId;
      }

      data['hasRolledDice'] = false;
      data['diceValue'] = 0;
      data['currentDiceNumber'] = 0;
      data['gameStatus'] = 'active';
      data['status'] = 'active';
      data['lastActionBy'] = '';

      return Transaction.success(data);
    });

    return result.committed;
  }

  Stream<DatabaseEvent> listenToMatch() {
    return _firebase.matchesRef.child(currentMatchId!).onValue;
  }

  Future<bool> rollDiceForTurn({
    required String rollingUserId,
    required int diceNumber,
  }) async {
    if (currentMatchId == null) return false;

    final ref = _firebase.matchesRef.child(currentMatchId!);

    final result = await ref.runTransaction((Object? currentData) {
      Map<String, dynamic> data;

      if (currentData == null) {
        print('⚠️ TX currentData null, creating match node inside transaction');

        data = {
          'player1Id': rollingUserId,
          'player2Id': opponentPlayerId ?? '',
          'player1Color': 'red',
          'player2Color': 'yellow',
          'currentTurn': rollingUserId,
          'hasRolledDice': false,
          'diceValue': 0,
          'currentDiceNumber': 0,
          'gameStatus': 'active',
          'status': 'active',
          'lastActionBy': '',
          'createdAt': ServerValue.timestamp,
          'lastMoveTime': ServerValue.timestamp,
        };
      } else {
        data = Map<String, dynamic>.from(currentData as Map);
      }

      final currentTurn = data['currentTurn']?.toString() ?? '';
      final hasRolled = data['hasRolledDice'] == true;
      final status =
          data['gameStatus']?.toString() ??
          data['status']?.toString() ??
          'active';

      print(
        '🎲 TX CHECK => matchId=$currentMatchId currentTurn=$currentTurn rollingUserId=$rollingUserId hasRolled=$hasRolled status=$status',
      );

      if (status == 'finished' || status == 'completed') {
        return Transaction.abort();
      }

      if (currentTurn.isNotEmpty && currentTurn != rollingUserId) {
        return Transaction.abort();
      }

      if (hasRolled) {
        return Transaction.abort();
      }

      data['currentTurn'] = rollingUserId;
      data['currentDiceNumber'] = diceNumber;
      data['diceValue'] = diceNumber;
      data['hasRolledDice'] = true;
      data['lastActionBy'] = rollingUserId;
      data['lastMoveTime'] = ServerValue.timestamp;

      return Transaction.success(data);
    });

    print('🎲 TX RESULT committed=${result.committed}');
    return result.committed;
  }

  Future<void> ensureMatchReady({
    required String player1Id,
    required String player2Id,
  }) async {
    if (currentMatchId == null) return;

    final ref = _firebase.matchesRef.child(currentMatchId!);
    final snapshot = await ref.once();

    if (snapshot.snapshot.value == null) {
      await ref.set({
        'player1Id': player1Id,
        'player2Id': player2Id,
        'player1Color': 'red',
        'player2Color': 'yellow',
        'currentTurn': player1Id,
        'hasRolledDice': false,
        'diceValue': 0,
        'currentDiceNumber': 0,
        'gameStatus': 'active',
        'status': 'active',
        'lastActionBy': '',
        'createdAt': ServerValue.timestamp,
        'lastMoveTime': ServerValue.timestamp,
      });
      return;
    }

    final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
    final updates = <String, dynamic>{};

    if ((data['player1Id']?.toString() ?? '').isEmpty) {
      updates['player1Id'] = player1Id;
    }
    if ((data['player2Id']?.toString() ?? '').isEmpty) {
      updates['player2Id'] = player2Id;
    }
    if ((data['currentTurn']?.toString() ?? '').isEmpty) {
      updates['currentTurn'] = player1Id;
    }
    if (!data.containsKey('hasRolledDice')) {
      updates['hasRolledDice'] = false;
    }
    if (!data.containsKey('currentDiceNumber')) {
      updates['currentDiceNumber'] = 0;
    }
    if (!data.containsKey('diceValue')) {
      updates['diceValue'] = 0;
    }
    if ((data['gameStatus']?.toString() ?? '').isEmpty) {
      updates['gameStatus'] = 'active';
    }
    if ((data['status']?.toString() ?? '').isEmpty) {
      updates['status'] = 'active';
    }

    if (updates.isNotEmpty) {
      await ref.update(updates);
    }
  }

  Future<bool> switchTurnAtomic({
    required String expectedCurrentTurnUserId,
    required String nextTurnUserId,
  }) async {
    if (currentMatchId == null) return false;

    final ref = _firebase.matchesRef.child(currentMatchId!);

    final result = await ref.runTransaction((Object? currentData) {
      if (currentData == null) {
        print('❌ SWITCH TX abort: currentData null');
        return Transaction.abort();
      }

      final data = Map<String, dynamic>.from(currentData as Map);
      final currentTurn = data['currentTurn']?.toString() ?? '';

      print(
        '🔁 SWITCH TX CHECK => currentTurn=$currentTurn expected=$expectedCurrentTurnUserId next=$nextTurnUserId',
      );

      if (currentTurn != expectedCurrentTurnUserId) {
        print('❌ SWITCH TX abort: wrong expected turn');
        return Transaction.abort();
      }

      data['currentTurn'] = nextTurnUserId;
      data['hasRolledDice'] = false;
      data['lastActionBy'] = expectedCurrentTurnUserId;
      data['lastMoveTime'] = ServerValue.timestamp;

      return Transaction.success(data);
    });

    print('🔁 SWITCH TX RESULT committed=${result.committed}');
    return result.committed;
  }

  Future<void> loadColors() async {
    if (currentMatchId == null) return;

    final snapshot = await _firebase.matchesRef.child(currentMatchId!).once();

    if (snapshot.snapshot.value == null) return;

    final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);

    String player1Id = data['player1Id'] ?? '';
    String player2Id = data['player2Id'] ?? '';

    String player1Color = data['player1Color'] ?? '';
    String player2Color = data['player2Color'] ?? '';

    if (currentPlayerId == player1Id) {
      myColor = player1Color;
      opponentColor = player2Color;
    } else {
      myColor = player2Color;
      opponentColor = player1Color;
    }

    print('🎨 My Color: $myColor');
    print('🎨 Opponent Color: $opponentColor');
  }

  Stream<DatabaseEvent> listenToGameState() {
    return _firebase.matchesRef
        .child(currentMatchId!)
        .child('gameState')
        .onValue;
  }

  Stream<DatabaseEvent> listenToTokenPositions() {
    return _firebase.matchesRef
        .child(currentMatchId!)
        .child('tokenPositions')
        .onValue;
  }

  Stream<DatabaseEvent> listenToTurn() {
    return _firebase.matchesRef
        .child(currentMatchId!)
        .child('currentTurn')
        .onValue;
  }

  Stream<DatabaseEvent> listenToDiceNumber() {
    return _firebase.matchesRef
        .child(currentMatchId!)
        .child('currentDiceNumber')
        .onValue;
  }

  Future<void> updateGameState(Map<String, dynamic> gameData) async {
    if (currentMatchId == null) return;
    await _firebase.matchesRef
        .child(currentMatchId!)
        .child('gameState')
        .set(gameData);
  }

  Future<void> updateTurn(String nextPlayerId) async {
    if (currentMatchId == null) return;
    await _firebase.matchesRef.child(currentMatchId!).update({
      'currentTurn': nextPlayerId,
      'lastMoveTime': ServerValue.timestamp,
    });
  }

  Future<void> updateDiceNumber(int diceNumber) async {
    if (currentMatchId == null) return;
    await _firebase.matchesRef.child(currentMatchId!).update({
      'currentDiceNumber': diceNumber,
    });
  }

  Future<void> updateTokenPosition(
    String playerId,
    String tokenId,
    String newPositionId,
  ) async {
    if (currentMatchId == null) return;
    await _firebase.matchesRef.child(currentMatchId!).update({
      'tokenPositions/$playerId/$tokenId': newPositionId,
      'lastActionBy': currentPlayerId,
      'lastMoveTime': ServerValue.timestamp,
    });
  }

  Future<void> updatePlayerState(
    String playerId,
    String playerColor, {
    bool? enableDice,
    bool? isCurrentTurn,
  }) async {
    if (currentMatchId == null) return;
    Map<String, dynamic> updates = {};
    if (enableDice != null) {
      updates['players/$playerColor/enableDice'] = enableDice;
    }
    if (isCurrentTurn != null) {
      updates['players/$playerColor/isCurrentTurn'] = isCurrentTurn;
    }
    if (updates.isNotEmpty) {
      await _firebase.matchesRef.child(currentMatchId!).update(updates);
    }
  }

  // Add to OnlineGameManager class
  Stream<DatabaseEvent> listenToPointerState() {
    return _firebase.matchesRef
        .child(currentMatchId!)
        .child('pointerState')
        .onValue;
  }

  Stream<DatabaseEvent> listenToDiceVisibility() {
    return _firebase.matchesRef
        .child(currentMatchId!)
        .child('diceVisibility')
        .onValue;
  }

  Future<void> updatePointerState(String playerId, String color) async {
    if (currentMatchId == null) return;
    await _firebase.matchesRef.child(currentMatchId!).update({
      'pointerState': {
        'playerId': playerId,
        'color': color,
        'timestamp': ServerValue.timestamp,
      },
    });
  }

  Future<void> updateDiceVisibility(String color) async {
    if (currentMatchId == null) return;
    await _firebase.matchesRef.child(currentMatchId!).update({
      'diceVisibility': {'color': color, 'timestamp': ServerValue.timestamp},
    });
  }

  String _colorCode(String color) {
    final lower = color.toLowerCase();

    if (lower == 'red' || color == 'RP') return 'RP';
    if (lower == 'green' || color == 'GP') return 'GP';
    if (lower == 'blue' || color == 'BP') return 'BP';
    if (lower == 'yellow' || color == 'YP') return 'YP';

    return color;
  }

  int _parseIntValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String? getUserIdFromColorCode(String colorCode) {
    final myCode = _colorCode(myColor ?? '');
    final opponentCode = _colorCode(opponentColor ?? '');

    if (myCode == colorCode) return currentPlayerId;
    if (opponentCode == colorCode) return opponentPlayerId;

    return null;
  }

  Future<void> endGame({
    required String winnerId,
    required String winnerColor,
  }) async {
    if (currentMatchId == null) return;

    final ref = _firebase.matchesRef.child(currentMatchId!);

    await ref.runTransaction((Object? currentData) {
      if (currentData == null) return Transaction.abort();

      final data = Map<String, dynamic>.from(currentData as Map);

      final status = data['status']?.toString().toLowerCase() ?? '';
      final gameStatus = data['gameStatus']?.toString().toLowerCase() ?? '';

      if (status == 'completed' || gameStatus == 'completed') {
        return Transaction.success(data);
      }

      final int entryFee = _parseIntValue(data['entryFee']);
      final int winPrize = _parseIntValue(
        data['winPrize'],
        fallback: entryFee + (entryFee ~/ 2),
      );

      final player1Id = data['player1Id']?.toString() ?? '';
      final player2Id = data['player2Id']?.toString() ?? '';
      final loserId = winnerId == player1Id ? player2Id : player1Id;

      data['status'] = 'completed';
      data['gameStatus'] = 'completed';
      data['winner'] = winnerId;
      data['winnerId'] = winnerId;
      data['winnerColor'] = winnerColor;
      data['loserId'] = loserId;
      data['entryFee'] = entryFee;
      data['winPrize'] = winPrize;
      data['endTime'] = ServerValue.timestamp;
      data['currentTurn'] = '';
      data['hasRolledDice'] = false;
      data['lastActionBy'] = winnerId;

      return Transaction.success(data);
    });
  }

  void dispose() {
    _gameStateSubscription?.cancel();
  }
}
