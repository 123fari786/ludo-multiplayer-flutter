import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/component/home/home_spot.dart';
import 'package:ludo_game/onlinegamemanager.dart';
import 'package:ludo_game/play_with_online.dart';
import 'package:ludo_game/play_with_online/firebase_service.dart';
import 'package:ludo_game/state/player.dart';
import 'package:ordered_set/read_only_ordered_set.dart';

import 'component/controller/lower_controller.dart';
import 'component/controller/upper_controller.dart';
import 'component/home/home.dart';
import 'component/ui_components/ludo_dice.dart';
import 'component/ui_components/rank_modal_component.dart';
import 'component/ui_components/spot.dart';
import 'component/ui_components/token.dart';
import 'ludo_board.dart';
import 'state/audio_manager.dart';
import 'state/event_bus.dart';
import 'state/game_state.dart';
import 'state/token_manager.dart';

// Global reference for online mode (used in helper functions)
bool _globalIsOnline = false;
OnlineGameManager? _globalOnlineManager;
String? _globalCurrentPlayerId;
String? _globalOpponentPlayerId;
String? _globalCurrentTurnPlayerId; // Add this line

class Ludo extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapDetector {
  List<String> teams;
  final BuildContext context;
  final bool isOnline;
  final String? matchId;
  final String? currentPlayerId;
  final String? opponentPlayerId;

  // Online game manager
  late OnlineGameManager _onlineManager;
  bool _isSyncing = false;
  String? _currentTurnPlayerId;
  bool _onlineResultHandled = false;

  // Firebase service
  final FirebaseService _firebase = FirebaseService();

  // Getter for online manager
  OnlineGameManager get onlineManager => _onlineManager;

  Ludo(
    this.teams,
    this.context, {
    this.isOnline = false,
    this.matchId,
    this.currentPlayerId,
    this.opponentPlayerId,
  }) {
    // Set global variables for helper functions
    _globalIsOnline = isOnline;
    _globalCurrentPlayerId = currentPlayerId;
    _globalOpponentPlayerId = opponentPlayerId;
  }

  bool get canPlay {
    if (!isOnline) return true;
    if (_currentTurnPlayerId == null) return false;

    // Map the Firebase user ID to check if it's my turn
    bool isMyTurn = _currentTurnPlayerId == currentPlayerId;
    debugPrint(
      'canPlay check: _currentTurnPlayerId=$_currentTurnPlayerId, currentPlayerId=$currentPlayerId, isMyTurn=$isMyTurn',
    );
    return isMyTurn;
  }

  String? _myColorCache;
  String? _opponentColorCache;

  String get myColor {
    if (_myColorCache != null) return _myColorCache!;

    // fallback only
    return 'RP';
  }

  String get opponentColor {
    if (_opponentColorCache != null) return _opponentColorCache!;

    return myColor == 'RP' ? 'YP' : 'RP';
  }

  final rand = Random();
  double get width => size.x;
  double get height => size.y;

  ColorEffect? _greenBlinkEffect;
  ColorEffect? _greenStaticEffect;

  ColorEffect? _blueBlinkEffect;
  ColorEffect? _blueStaticEffect;

  ColorEffect? _yellowBlinkEffect;
  ColorEffect? _yellowStaticEffect;

  ColorEffect? _redBlinkEffect;
  ColorEffect? _redStaticEffect;

  @override
  void onLoad() async {
    super.onLoad();

    camera = CameraComponent.withFixedResolution(width: size.x, height: size.y);
    camera.viewfinder.anchor = Anchor.topLeft;

    world.add(
      UpperController(
        position: Vector2(0, size.x * 0.05),
        width: size.x,
        height: size.x * 0.20,
      ),
    );
    world.add(
      LudoBoard(
        width: size.x,
        height: size.x,
        position: Vector2(0, size.y * 0.175),
      ),
    );
    world.add(
      LowerController(
        position: Vector2(0, size.x + (size.x * 0.35)),
        width: size.x,
        height: size.x * 0.20,
      ),
    );

    GameState().ludoBoard = world.children.whereType<LudoBoard>().first;
    GameState().ludoBoardAbsolutePosition =
        (GameState().ludoBoard as PositionComponent).absolutePosition;

    EventBus().on<OpenPlayerModalEvent>((event) => showPlayerModal());
    EventBus().on<SwitchPointerEvent>((event) => switchOffPointer());

    // === FIXED BLINK LISTENERS ===
    EventBus().on<BlinkGreenBaseEvent>((event) {
      if (!isOnline || (_currentTurnPlayerId == currentPlayerId))
        blinkGreenBase(true);
    });
    EventBus().on<BlinkBlueBaseEvent>((event) {
      if (!isOnline || (_currentTurnPlayerId == currentPlayerId))
        blinkBlueBase(true);
    });
    EventBus().on<BlinkRedBaseEvent>((event) {
      if (!isOnline || (_currentTurnPlayerId == currentPlayerId))
        blinkRedBase(true);
    });
    EventBus().on<BlinkYellowBaseEvent>((event) {
      if (!isOnline || (_currentTurnPlayerId == currentPlayerId))
        blinkYellowBase(true);
    });

    if (isOnline && matchId != null) {
      await _initializeOnlineGame();
    } else {
      await startGame();
    }
  }

  Future<void> _initializeOnlineGame() async {
    _onlineManager = OnlineGameManager();
    _onlineManager.init(matchId!, currentPlayerId!, opponentPlayerId!);
    await _onlineManager.ensureMatchReady(
      player1Id: currentPlayerId!,
      player2Id: opponentPlayerId!,
    );
    await _onlineManager.loadColors();

    _myColorCache = _getColorCode(_onlineManager.myColor ?? '');
    _opponentColorCache = _getColorCode(_onlineManager.opponentColor ?? '');
    _globalOnlineManager = _onlineManager;

    // _onlineManager.listenToTurn().listen((event) async {
    //   final value = event.snapshot.value?.toString() ?? '';
    //   if (value.isEmpty) return;

    //   _currentTurnPlayerId = value;
    //   _globalCurrentTurnPlayerId = value;
    //   await _syncPlayerTurnState(value);
    // }
    // );

    // _onlineManager.listenToDiceNumber().listen((event) async {
    //   if (event.snapshot.value == null) return;
    //   final diceNum = (event.snapshot.value as num).toInt();
    //   GameState().diceNumber = diceNum;
    //   await updateDiceFaceOnBothDevices(diceNum);
    // });

    // _onlineManager.listenToTokenPositions().listen((event) async {
    //   if (event.snapshot.value == null || _isSyncing) return;
    //   _isSyncing = true;
    //   final tokenPositions = Map<String, dynamic>.from(
    //     event.snapshot.value as Map,
    //   );
    //   await _syncGameState({'tokenPositions': tokenPositions});
    //   _isSyncing = false;
    // });
    _onlineManager.listenToMatch().listen((event) async {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      final status = data['status']?.toString().toLowerCase() ?? '';
      final gameStatus = data['gameStatus']?.toString().toLowerCase() ?? '';

      if (status == 'completed' || gameStatus == 'completed') {
        await _handleOnlineGameCompleted(data);
        return;
      }

      final turnId = data['currentTurn']?.toString() ?? '';
      if (turnId.isNotEmpty) {
        debugPrint('🔥 MATCH LISTENER TURN => $turnId | myId=$currentPlayerId');

        _currentTurnPlayerId = turnId;
        _globalCurrentTurnPlayerId = turnId;

        await _syncPlayerTurnState(turnId);
      }
      final diceNum =
          int.tryParse(
            data['currentDiceNumber']?.toString() ??
                data['diceValue']?.toString() ??
                '0',
          ) ??
          0;

      if (diceNum > 0) {
        GameState().diceNumber = diceNum;
        await updateDiceFaceOnBothDevices(diceNum);
      }

      if (data['tokenPositions'] != null && !_isSyncing) {
        _isSyncing = true;
        await _syncGameState({
          'tokenPositions': Map<String, dynamic>.from(data['tokenPositions']),
        });
        _isSyncing = false;
      }
    });
    await startGame();
    await Future.delayed(const Duration(milliseconds: 500));

    final matchData = await _onlineManager.getMatchData();
    final player1Id = matchData?['player1Id']?.toString() ?? currentPlayerId!;
    final firebaseTurn = matchData?['currentTurn']?.toString() ?? '';

    if (firebaseTurn.isEmpty) {
      await _onlineManager.setInitialTurnIfEmpty(player1Id);
      _currentTurnPlayerId = player1Id;
    } else {
      _currentTurnPlayerId = firebaseTurn;
    }

    _globalCurrentTurnPlayerId = _currentTurnPlayerId;
    await _syncPlayerTurnState(_currentTurnPlayerId!);
  }

  Future<void> updateDiceFaceOnBothDevices(int diceNumber) async {
    debugPrint('🎲 Updating dice face to $diceNumber');

    GameState().diceNumber = diceNumber;

    final lower = world.children.whereType<LowerController>().firstOrNull;
    final upper = world.children.whereType<UpperController>().firstOrNull;

    final containers = [
      _getDiceContainer(upper ?? Component(), 0), // Red
      _getDiceContainer(lower ?? Component(), 2), // Yellow
    ];

    for (final container in containers) {
      final dice = container?.children.whereType<LudoDice>().firstOrNull;
      if (dice != null) {
        dice.diceFace.updateDiceValue(diceNumber);
      }
    }
  }

  Future<void> _syncPlayerTurnState(String turnPlayerId) async {
    _currentTurnPlayerId = turnPlayerId;
    _globalCurrentTurnPlayerId = turnPlayerId;

    final String turnColorCode = _getTurnColorFromUserId(turnPlayerId);
    final bool thisDeviceCanPlay = turnPlayerId == currentPlayerId;

    final turnIndex = GameState().players.indexWhere(
      (p) => _getColorCode(p.playerId) == turnColorCode,
    );
    if (turnIndex != -1) {
      GameState().currentPlayerIndex = turnIndex;
    }

    for (final player in GameState().players) {
      final playerCode = _getColorCode(player.playerId);
      final isTurnPlayer = playerCode == turnColorCode;

      player.isCurrentTurn = isTurnPlayer;
      player.enableDice = isTurnPlayer && thisDeviceCanPlay;

      for (final token in player.tokens) {
        token.enableToken = false;
        token.disableCircleAnimation();
      }
    }

    updateDiceVisibility();
    if (thisDeviceCanPlay) {
      _showTurnPointerByColor(turnColorCode);
    } else {
      switchOffPointer();
    }
  }

  String _getTurnColorFromUserId(String userId) {
    if (userId == currentPlayerId) return _getColorCode(myColor);
    if (userId == opponentPlayerId) return _getColorCode(opponentColor);

    debugPrint('⚠️ Unknown turn userId: $userId, fallback opponentColor');
    return _getColorCode(opponentColor);
  }

  void _showTurnPointerByColor(String colorCode) {
    switchOffPointer();

    if (_currentTurnPlayerId != currentPlayerId) {
      return;
    }

    final lower = world.children.whereType<LowerController>().firstOrNull;

    final upper = world.children.whereType<UpperController>().firstOrNull;

    if (colorCode == myColor) {
      if (colorCode == 'YP' || colorCode == 'BP') {
        lower?.showPointer(colorCode);
      } else {
        upper?.showPointer(colorCode);
      }
    }
  }

  Future<void> forceOnlineTurnSync(String turnPlayerId) async {
    if (!isOnline) return;
    if (turnPlayerId.isEmpty) return;

    _currentTurnPlayerId = turnPlayerId;
    _globalCurrentTurnPlayerId = turnPlayerId;

    await _syncPlayerTurnState(turnPlayerId);
    updateDiceVisibility();
  }

  // Add this helper method in Ludo class
  String _getColorCode(String colorName) {
    final lower = colorName.toLowerCase();

    if (lower == 'red' || colorName == 'RP') return 'RP';
    if (lower == 'green' || colorName == 'GP') return 'GP';
    if (lower == 'blue' || colorName == 'BP') return 'BP';
    if (lower == 'yellow' || colorName == 'YP') return 'YP';

    // Already a code
    if (['BP', 'GP', 'RP', 'YP'].contains(colorName)) {
      return colorName;
    }

    debugPrint('⚠️ _getColorCode fallback for: $colorName');
    return colorName;
  }

  Future<void> syncAllTokenPositions() async {
    if (!isOnline || _onlineManager == null) return;

    debugPrint('🔄 Syncing all token positions to Firebase...');

    for (var token in TokenManager().allTokens) {
      await _onlineManager.updateTokenPosition(
        token.playerId,
        token.tokenId,
        token.positionId,
      );
    }
  }

  void _updateLocalTurn() {
    final playerId = _currentTurnPlayerId;
    if (playerId == null) return;

    String playingColor;
    if (playerId == currentPlayerId) {
      playingColor = myColor;
    } else {
      playingColor = opponentColor;
    }

    for (var player in GameState().players) {
      if (player.playerId == playingColor) {
        player.isCurrentTurn = true;
        player.enableDice = (playerId == currentPlayerId);
      } else {
        player.isCurrentTurn = false;
        player.enableDice = false;
      }
    }

    if (playerId == currentPlayerId) {
      _showInitialPointer();
    }
  }

  Future<void> _syncGameState(Map<String, dynamic> gameState) async {
    if (gameState['tokenPositions'] == null) return;

    final tokenPositions = Map<String, dynamic>.from(
      gameState['tokenPositions'],
    );

    for (final playerEntry in tokenPositions.entries) {
      final playerColor = playerEntry.key;
      final tokens = Map<String, dynamic>.from(playerEntry.value);

      for (final tokenEntry in tokens.entries) {
        final tokenId = tokenEntry.key;
        final newPositionId = tokenEntry.value.toString();

        final token = TokenManager().allTokens.firstWhere(
          (t) => t.playerId == playerColor && t.tokenId == tokenId,
        );

        if (token.positionId != newPositionId) {
          await _moveTokenToPosition(token, newPositionId);
        }
      }
    }
  }

  Future<void> _moveTokenToPosition(Token token, String newPositionId) async {
    final tokenPath = GameState().getTokenPath(token.playerId);

    if (token.state == TokenState.inBase && tokenPath.first == newPositionId) {
      token.state = TokenState.onBoard;
    }

    final spot = SpotManager().findSpotById(newPositionId);
    token.positionId = newPositionId;

    await applyEffectHelper(
      token,
      MoveToEffect(
        token.state == TokenState.inBase ? spot.position : spot.tokenPosition,
        EffectController(duration: 0.12, curve: Curves.easeInOut),
      ),
    );

    resizeTokensOnSpot(world);
  }

  Future<void> moveForwardOnline({
    required World world,
    required Token token,
    required List<String> tokenPath,
    required int diceNumber,
  }) async {
    if (!canPlay || token.playerId != myColor) return;

    final currentIndex = tokenPath.indexOf(token.positionId);
    final finalIndex = currentIndex + diceNumber;

    for (
      int i = currentIndex + 1;
      i <= finalIndex && i < tokenPath.length;
      i++
    ) {
      token.positionId = tokenPath[i];

      await applyEffectHelper(
        token,
        MoveToEffect(
          SpotManager()
              .getSpots()
              .firstWhere((spot) => spot.uniqueId == token.positionId)
              .tokenPosition,
          EffectController(duration: 0.12, curve: Curves.easeInOut),
        ),
      );

      await _onlineManager.updateTokenPosition(
        token.playerId,
        token.tokenId,
        token.positionId,
      );
      await Future.delayed(const Duration(milliseconds: 120));
    }

    final isTokenInHome = await checkTokenInHomeAndHandle(token, world);
    bool wasAttack = false;

    if (!isTokenInHome) {
      wasAttack = await tokenCollisionOnline(world, token);
    }

    clearTokenTrail();
    resizeTokensOnSpot(world);

    await finishOnlineMoveAndSwitchTurn(
      movedColorCode: token.playerId,
      keepSameTurn: GameState().diceNumber == 6 || wasAttack || isTokenInHome,
    );
  }

  Future<bool> tokenCollisionOnline(World world, Token attackerToken) async {
    final tokensOnSpot = TokenManager().allTokens
        .where((token) => token.positionId == attackerToken.positionId)
        .toList();

    bool wasTokenAttacked = false;

    if (tokensOnSpot.length > 1 &&
        ![
          'B04',
          'B23',
          'R22',
          'R10',
          'G02',
          'G21',
          'Y30',
          'Y42',
        ].contains(attackerToken.positionId)) {
      final tokensToMove = tokensOnSpot
          .where((token) => token.playerId != attackerToken.playerId)
          .toList();

      wasTokenAttacked = tokensToMove.isNotEmpty;

      await Future.wait(
        tokensToMove.map(
          (token) => moveBackward(
            world: world,
            token: token,
            tokenPath: GameState().getTokenPath(token.playerId),
            ludoBoard: GameState().ludoBoard as PositionComponent,
          ),
        ),
      );

      for (final token in tokensToMove) {
        await _onlineManager.updateTokenPosition(
          token.playerId,
          token.tokenId,
          token.positionId,
        );
      }
    }

    for (final token in TokenManager().allTokens) {
      token.enableToken = false;
      token.disableCircleAnimation();
    }

    return wasTokenAttacked;
  }

  void updateDiceVisibility() {
    final lowerController = world.children
        .whereType<LowerController>()
        .firstOrNull;
    final upperController = world.children
        .whereType<UpperController>()
        .firstOrNull;
    if (lowerController == null || upperController == null) return;

    final lowerLeft = _getDiceContainer(lowerController, 0);
    final lowerRight = _getDiceContainer(lowerController, 2);
    final upperLeft = _getDiceContainer(upperController, 0);
    final upperRight = _getDiceContainer(upperController, 2);

    const faceSize = 45.0;

    // Dice ko remove mat karo. Sirf missing ho to add karo.
    safeAddDice(upperLeft, 'RP', faceSize);
    safeAddDice(lowerRight, 'YP', faceSize);

    final myColorCode = _getColorCode(myColor);
    final opponentColorCode = _getColorCode(opponentColor);

    final currentTurnColorCode = _currentTurnPlayerId == currentPlayerId
        ? myColorCode
        : _currentTurnPlayerId == opponentPlayerId
        ? opponentColorCode
        : '';

    for (final player in GameState().players) {
      final playerCode = _getColorCode(player.playerId);

      player.isCurrentTurn = playerCode == currentTurnColorCode;
      player.enableDice =
          playerCode == currentTurnColorCode &&
          _currentTurnPlayerId == currentPlayerId;

      for (final token in player.tokens) {
        token.enableToken = false;
        token.disableCircleAnimation();
      }
    }
  }

  Future<void> finishOnlineMoveAndSwitchTurn({
    required String movedColorCode,
    required bool keepSameTurn,
  }) async {
    if (!isOnline || _currentTurnPlayerId != currentPlayerId) return;

    final nextPlayerId = keepSameTurn ? currentPlayerId! : opponentPlayerId!;

    final switched = await _onlineManager.switchTurnAtomic(
      expectedCurrentTurnUserId: currentPlayerId!,
      nextTurnUserId: nextPlayerId,
    );

    if (!switched) {
      debugPrint('❌ Turn switch failed. Do not force local turn.');
      return;
    }

    // Firebase listener will update both devices.
    _currentTurnPlayerId = nextPlayerId;
    _globalCurrentTurnPlayerId = nextPlayerId;
    await _syncPlayerTurnState(nextPlayerId);
  }

  RectangleComponent? _getDiceContainer(Component parent, int index) {
    if (parent.children.length <= index) return null;
    final comp = parent.children.elementAt(index);
    if (comp is! RectangleComponent) return null;

    final inner = comp.children.whereType<RectangleComponent>().firstOrNull;
    if (inner == null) return null;

    return inner.children.whereType<RectangleComponent>().firstOrNull;
  }

  void safeRemoveDice(RectangleComponent? container) {
    if (container == null) return;
    final diceList = container.children.whereType<LudoDice>().toList();
    for (var dice in diceList) {
      dice.removeFromParent();
    }
  }

  void safeAddDice(
    RectangleComponent? container,
    String playerId,
    double faceSize,
  ) {
    if (container == null) return;

    if (container.children.whereType<LudoDice>().isNotEmpty) return;

    final player = GameState().players
        .where((p) => p.playerId == playerId)
        .firstOrNull;

    if (player == null) {
      debugPrint('⚠️ Player not found for dice: $playerId');
      return;
    }

    final dice = LudoDice(player: player, faceSize: faceSize)..game = this;
    container.add(dice);
    debugPrint('✅ Added dice for $playerId');
  }

  void switchOffPointer() {
    final lower = world.children.whereType<LowerController>().firstOrNull;
    final upper = world.children.whereType<UpperController>().firstOrNull;

    lower?.hidePointer('BP');
    lower?.hidePointer('YP');
    lower?.hidePointer('RP');
    lower?.hidePointer('GP');
    upper?.hidePointer('BP');
    upper?.hidePointer('YP');
    upper?.hidePointer('RP');
    upper?.hidePointer('GP');
  }

  void blinkRedBase(bool shouldBlink) {
    if (GameState().ludoBoard == null) return;

    final childrenOfLudoBoard = GameState().ludoBoard?.children.toList();
    if (childrenOfLudoBoard == null || childrenOfLudoBoard.isEmpty) {
      debugPrint('⚠️ blinkRedBase: Ludo board children not ready yet');
      return;
    }

    final child = childrenOfLudoBoard[0];
    if (child == null) return;

    final home = child.children.toList();
    if (home.isEmpty) return;

    final homePlate = home[0] as Home?;
    if (homePlate == null) return;

    _redBlinkEffect ??= ColorEffect(
      const Color(0xffa3333d),
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    _redStaticEffect ??= ColorEffect(
      GameState().red,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    final upperController = world.children
        .whereType<UpperController>()
        .firstOrNull;
    if (upperController == null) return;

    final upperControllerComponents = upperController.children.toList();
    if (upperControllerComponents.isEmpty) return;

    final leftDice = upperControllerComponents[0].children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (leftDice == null) return;

    final rightDiceContainer = leftDice.children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (rightDiceContainer == null) return;

    homePlate.add(shouldBlink ? _redBlinkEffect! : _redStaticEffect!);

    if (shouldBlink) {
      if (GameState().players.isNotEmpty) {
        // Find the Red player
        final player = GameState().players.firstWhere(
          (p) => p.playerId == 'RP',
          orElse: () => GameState().players[GameState().currentPlayerIndex],
        );

        // Remove existing dice before adding new one
        final existingDice = rightDiceContainer.children
            .whereType<LudoDice>()
            .firstOrNull;
        if (existingDice != null) {
          rightDiceContainer.remove(existingDice);
          debugPrint('🎲 Removed existing red dice');
        }

        rightDiceContainer.add(
          LudoDice(player: player, faceSize: leftDice.size.x * 0.70),
        );
        debugPrint(
          '🎲 Red dice added to right container for player: ${player.playerId}',
        );

        // Only show pointer if it's THIS device's turn
        if (_currentTurnPlayerId == currentPlayerId) {
          upperController.showPointer(player.playerId);
        }
      }
    } else {
      final ludoDice = rightDiceContainer.children
          .whereType<LudoDice>()
          .firstOrNull;
      if (ludoDice != null) {
        rightDiceContainer.remove(ludoDice);
        debugPrint('🎲 Removed red dice');
      }
    }
  }

  void blinkYellowBase(bool shouldBlink) {
    if (GameState().ludoBoard == null) return;

    final childrenOfLudoBoard = GameState().ludoBoard?.children.toList();
    if (childrenOfLudoBoard == null || childrenOfLudoBoard.length <= 8) {
      debugPrint('⚠️ blinkYellowBase: Ludo board children not ready yet');
      return;
    }

    final child = childrenOfLudoBoard[8];
    if (child == null) return;

    final home = child.children.toList();
    if (home.isEmpty) return;

    final homePlate = home[0] as Home?;
    if (homePlate == null) return;

    _yellowBlinkEffect ??= ColorEffect(
      Colors.yellowAccent,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    _yellowStaticEffect ??= ColorEffect(
      GameState().yellow,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    final lowerController = world.children
        .whereType<LowerController>()
        .firstOrNull;
    if (lowerController == null) return;

    final lowerControllerComponents = lowerController.children.toList();
    if (lowerControllerComponents.length <= 2) return;

    final rightDiceContainer = _getRightDiceContainer(
      lowerControllerComponents,
    );
    if (rightDiceContainer == null) return;

    homePlate.add(shouldBlink ? _yellowBlinkEffect! : _yellowStaticEffect!);

    if (shouldBlink) {
      if (GameState().players.isNotEmpty) {
        // Find the Yellow player
        final player = GameState().players.firstWhere(
          (p) => p.playerId == 'YP',
          orElse: () => GameState().players[GameState().currentPlayerIndex],
        );

        // Remove existing dice before adding new one
        final existingDice = rightDiceContainer.children
            .whereType<LudoDice>()
            .firstOrNull;
        if (existingDice != null) {
          rightDiceContainer.remove(existingDice);
          debugPrint('🎲 Removed existing yellow dice');
        }

        rightDiceContainer.add(
          LudoDice(player: player, faceSize: rightDiceContainer.size.x * 0.70),
        );
        debugPrint(
          '🎲 Yellow dice added to right container for player: ${player.playerId}',
        );

        // Only show pointer if it's THIS device's turn
        if (_currentTurnPlayerId == currentPlayerId) {
          lowerController.showPointer(player.playerId);
        }
      }
    } else {
      final ludoDice = rightDiceContainer.children
          .whereType<LudoDice>()
          .firstOrNull;
      if (ludoDice != null) {
        rightDiceContainer.remove(ludoDice);
        debugPrint('🎲 Removed yellow dice');
      }
    }
  }

  RectangleComponent? _getRightDiceContainer(
    List<Component> lowerControllerComponents,
  ) {
    if (lowerControllerComponents.length <= 2) return null;

    final rightDice = lowerControllerComponents[2].children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (rightDice == null) return null;

    return rightDice.children.whereType<RectangleComponent>().firstOrNull;
  }

  void blinkBlueBase(bool shouldBlink) {
    if (GameState().ludoBoard == null) return;

    final childrenOfLudoBoard = GameState().ludoBoard?.children.toList();
    if (childrenOfLudoBoard == null || childrenOfLudoBoard.length <= 6) {
      debugPrint('⚠️ blinkBlueBase: Ludo board children not ready yet');
      return;
    }

    final child = childrenOfLudoBoard[6];
    if (child == null) return;

    final home = child.children.toList();
    if (home.isEmpty) return;

    final homePlate = home[0] as Home?;
    if (homePlate == null) return;

    _blueBlinkEffect ??= ColorEffect(
      Colors.lightBlueAccent,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    _blueStaticEffect ??= ColorEffect(
      GameState().blue,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    final lowerController = world.children
        .whereType<LowerController>()
        .firstOrNull;
    if (lowerController == null) return;

    final lowerControllerComponents = lowerController.children.toList();
    if (lowerControllerComponents.isEmpty) return;

    final leftDice = lowerControllerComponents[0].children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (leftDice == null) return;

    final leftDiceContainer = leftDice.children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (leftDiceContainer == null) return;

    homePlate.add(shouldBlink ? _blueBlinkEffect! : _blueStaticEffect!);

    if (shouldBlink) {
      if (GameState().players.isNotEmpty) {
        // Find the Blue player
        final player = GameState().players.firstWhere(
          (p) => p.playerId == 'BP',
          orElse: () => GameState().players[GameState().currentPlayerIndex],
        );

        // Remove existing dice before adding new one
        final existingDice = leftDiceContainer.children
            .whereType<LudoDice>()
            .firstOrNull;
        if (existingDice != null) {
          leftDiceContainer.remove(existingDice);
          debugPrint('🎲 Removed existing blue dice');
        }

        leftDiceContainer.add(
          LudoDice(player: player, faceSize: leftDice.size.x * 0.70),
        );
        debugPrint(
          '🎲 Blue dice added to left container for player: ${player.playerId}',
        );

        // Only show pointer if it's THIS device's turn
        if (_currentTurnPlayerId == currentPlayerId) {
          lowerController.showPointer(player.playerId);
        }
      }
    } else {
      final ludoDice = leftDiceContainer.children
          .whereType<LudoDice>()
          .firstOrNull;
      if (ludoDice != null) {
        leftDiceContainer.remove(ludoDice);
        debugPrint('🎲 Removed blue dice');
      }
    }
  }

  void blinkGreenBase(bool shouldBlink) {
    if (GameState().ludoBoard == null) return;

    final childrenOfLudoBoard = GameState().ludoBoard?.children.toList();
    if (childrenOfLudoBoard == null || childrenOfLudoBoard.length <= 2) {
      debugPrint('⚠️ blinkGreenBase: Ludo board children not ready yet');
      return;
    }

    final child = childrenOfLudoBoard[2];
    if (child == null) return;

    final home = child.children.toList();
    if (home.isEmpty) return;

    final homePlate = home[0] as Home?;
    if (homePlate == null) return;

    _greenBlinkEffect ??= ColorEffect(
      Colors.lightGreenAccent,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    _greenStaticEffect ??= ColorEffect(
      GameState().green,
      EffectController(
        duration: 0.2,
        reverseDuration: 0.2,
        infinite: true,
        alternate: true,
      ),
    );

    final upperController = world.children
        .whereType<UpperController>()
        .firstOrNull;
    if (upperController == null) return;

    final upperControllerComponents = upperController.children.toList();
    if (upperControllerComponents.length <= 2) return;

    final rightDice = upperControllerComponents[2].children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (rightDice == null) return;

    final rightDiceContainer = rightDice.children
        .whereType<RectangleComponent>()
        .firstOrNull;
    if (rightDiceContainer == null) return;

    homePlate.add(shouldBlink ? _greenBlinkEffect! : _greenStaticEffect!);

    if (shouldBlink) {
      if (GameState().players.isNotEmpty) {
        // Find the Green player
        final player = GameState().players.firstWhere(
          (p) => p.playerId == 'GP',
          orElse: () => GameState().players[GameState().currentPlayerIndex],
        );

        // Remove existing dice before adding new one
        final existingDice = rightDiceContainer.children
            .whereType<LudoDice>()
            .firstOrNull;
        if (existingDice != null) {
          rightDiceContainer.remove(existingDice);
          debugPrint('🎲 Removed existing green dice');
        }

        rightDiceContainer.add(
          LudoDice(player: player, faceSize: rightDice.size.x * 0.70),
        );
        debugPrint(
          '🎲 Green dice added to right container for player: ${player.playerId}',
        );

        // Only show pointer if it's THIS device's turn
        if (_currentTurnPlayerId == currentPlayerId) {
          upperController.showPointer(player.playerId);
        }
      }
    } else {
      final ludoDice = rightDiceContainer.children
          .whereType<LudoDice>()
          .firstOrNull;
      if (ludoDice != null) {
        rightDiceContainer.remove(ludoDice);
        debugPrint('🎲 Removed green dice');
      }
    }
  }

  @override
  void onRemove() {
    _onlineManager.dispose();
    super.onRemove();
  }

  Future<void> startGame() async {
    debugPrint('🎮 ========== STARTING GAME ==========');
    debugPrint('  isOnline: $isOnline');
    debugPrint('  teams: $teams');
    debugPrint('  currentPlayerId: $currentPlayerId');
    debugPrint('  opponentPlayerId: $opponentPlayerId');
    debugPrint('  myColor: $myColor');
    debugPrint('  opponentColor: $opponentColor');

    await TokenManager().clearTokens();
    await GameState().clearPlayers();
    await AudioManager.dispose();

    await AudioManager.initialize();
    await Future.delayed(const Duration(milliseconds: 100));

    // First, initialize all tokens and players
    for (var team in teams) {
      if (team == 'BP' || team.toLowerCase() == 'blue') {
        if (TokenManager().getBlueTokens().isEmpty) {
          TokenManager().initializeTokens(TokenManager().blueTokensBase);

          const homeSpotSizeFactorX = 0.10;
          const homeSpotSizeFactorY = 0.05;
          const tokenSizeFactorX = 0.80;
          const tokenSizeFactorY = 1.05;

          for (var token in TokenManager().getBlueTokens()) {
            final homeSpot = getHomeSpotHelper(world, 6)
                .whereType<HomeSpot>()
                .firstWhere((spot) => spot.uniqueId == token.positionId);
            final spot = SpotManager().findSpotById(token.positionId);
            spot.position = Vector2(
              homeSpot.absolutePosition.x +
                  (homeSpot.size.x * homeSpotSizeFactorX) -
                  GameState().ludoBoardAbsolutePosition.x,
              homeSpot.absolutePosition.y -
                  (homeSpot.size.x * homeSpotSizeFactorY) -
                  GameState().ludoBoardAbsolutePosition.y,
            );
            token.sideColor = const Color(0xFF0D92F4);
            token.topColor = const Color(0xFF77CDFF);

            token.position = spot.position;
            token.size = Vector2(
              homeSpot.size.x * tokenSizeFactorX,
              homeSpot.size.x * tokenSizeFactorY,
            );
            GameState().ludoBoard?.add(token);
          }

          const playerId = 'BP';
          Player bluePlayer = Player(
            playerId: playerId,
            tokens: TokenManager().getBlueTokens(),
            isCurrentTurn: false,
            enableDice: false,
          );
          GameState().players.add(bluePlayer);
          for (var token in TokenManager().getBlueTokens()) {
            token.playerId = bluePlayer.playerId;
            token.enableToken = false;
          }
        }
      } else if (team == 'GP' || team.toLowerCase() == 'green') {
        if (TokenManager().getGreenTokens().isEmpty) {
          TokenManager().initializeTokens(TokenManager().greenTokensBase);

          final ludoBoardPosition = GameState().ludoBoardAbsolutePosition;
          const homeSpotSizeFactorX = 0.10;
          const homeSpotSizeFactorY = 0.05;
          const tokenSizeFactorX = 0.80;
          const tokenSizeFactorY = 1.05;

          for (var token in TokenManager().getGreenTokens()) {
            final homeSpot = getHomeSpotHelper(world, 2)
                .whereType<HomeSpot>()
                .firstWhere((spot) => spot.uniqueId == token.positionId);
            final spot = SpotManager().findSpotById(token.positionId);
            spot.position = Vector2(
              homeSpot.absolutePosition.x +
                  (homeSpot.size.x * homeSpotSizeFactorX) -
                  ludoBoardPosition.x,
              homeSpot.absolutePosition.y -
                  (homeSpot.size.x * homeSpotSizeFactorY) -
                  ludoBoardPosition.y,
            );
            token.sideColor = const Color(0xFF54C392);
            token.topColor = const Color(0xFF73EC8B);
            token.position = spot.position;
            token.size = Vector2(
              homeSpot.size.x * tokenSizeFactorX,
              homeSpot.size.x * tokenSizeFactorY,
            );
            GameState().ludoBoard?.add(token);
          }

          const playerId = 'GP';
          Player greenPlayer = Player(
            playerId: playerId,
            tokens: TokenManager().getGreenTokens(),
            isCurrentTurn: false,
            enableDice: false,
          );
          GameState().players.add(greenPlayer);
          for (var token in TokenManager().getGreenTokens()) {
            token.playerId = greenPlayer.playerId;
            token.enableToken = false;
          }
        }
      }
      // FIXED: Red & Yellow blocks with proper color codes
      else if (team.toLowerCase() == 'rp' || team.toLowerCase() == 'red') {
        if (TokenManager().getRedTokens().isEmpty) {
          TokenManager().initializeTokens(TokenManager().redTokensBase);

          final ludoBoardPosition = GameState().ludoBoardAbsolutePosition;
          const homeSpotSizeFactorX = 0.10;
          const homeSpotSizeFactorY = 0.05;
          const tokenSizeFactorX = 0.80;
          const tokenSizeFactorY = 1.05;

          for (var token in TokenManager().getRedTokens()) {
            final homeSpot = getHomeSpotHelper(world, 0)
                .whereType<HomeSpot>()
                .firstWhere((spot) => spot.uniqueId == token.positionId);
            final spot = SpotManager().findSpotById(token.positionId);
            spot.position = Vector2(
              homeSpot.absolutePosition.x +
                  (homeSpot.size.x * homeSpotSizeFactorX) -
                  ludoBoardPosition.x,
              homeSpot.absolutePosition.y -
                  (homeSpot.size.x * homeSpotSizeFactorY) -
                  ludoBoardPosition.y,
            );
            token.sideColor = const Color(0xff780000);
            token.topColor = const Color(0xffFF5B5B);
            token.position = spot.position;
            token.size = Vector2(
              homeSpot.size.x * tokenSizeFactorX,
              homeSpot.size.x * tokenSizeFactorY,
            );
            GameState().ludoBoard?.add(token);
          }

          const playerId = 'RP';
          Player redPlayer = Player(
            playerId: playerId,
            tokens: TokenManager().getRedTokens(),
            isCurrentTurn: false,
            enableDice: false,
          );
          GameState().players.add(redPlayer);
          for (var token in TokenManager().getRedTokens()) {
            token.playerId = playerId;
            token.enableToken = false;
          }
        }
      } else if (team.toLowerCase() == 'yp' || team.toLowerCase() == 'yellow') {
        if (TokenManager().getYellowTokens().isEmpty) {
          TokenManager().initializeTokens(TokenManager().yellowTokensBase);

          final ludoBoardPosition = GameState().ludoBoardAbsolutePosition;
          const homeSpotSizeFactorX = 0.10;
          const homeSpotSizeFactorY = 0.05;
          const tokenSizeFactorX = 0.80;
          const tokenSizeFactorY = 1.05;

          for (var token in TokenManager().getYellowTokens()) {
            final homeSpot = getHomeSpotHelper(world, 8)
                .whereType<HomeSpot>()
                .firstWhere((spot) => spot.uniqueId == token.positionId);
            final spot = SpotManager().findSpotById(token.positionId);
            spot.position = Vector2(
              homeSpot.absolutePosition.x +
                  (homeSpot.size.x * homeSpotSizeFactorX) -
                  ludoBoardPosition.x,
              homeSpot.absolutePosition.y -
                  (homeSpot.size.x * homeSpotSizeFactorY) -
                  ludoBoardPosition.y,
            );
            token.sideColor = const Color(0xffc9a227);
            token.topColor = const Color(0xffFFDF5B);
            token.position = spot.position;
            token.size = Vector2(
              homeSpot.size.x * tokenSizeFactorX,
              homeSpot.size.x * tokenSizeFactorY,
            );
            GameState().ludoBoard?.add(token);
          }

          const playerId = 'YP';
          Player yellowPlayer = Player(
            playerId: playerId,
            tokens: TokenManager().getYellowTokens(),
            isCurrentTurn: false,
            enableDice: false,
          );
          GameState().players.add(yellowPlayer);
          for (var token in TokenManager().getYellowTokens()) {
            token.playerId = playerId;
            token.enableToken = false;
          }
        }
      }
    }

    // NOW add dice to board AFTER all players are created
    _addDiceToBoard();

    debugPrint(
      '🎮 All players added. Total players: ${GameState().players.length}',
    );

    // ==================== ONLINE INITIAL TURN SETUP ====================
    if (isOnline && GameState().players.isNotEmpty) {
      String myColorId = myColor;
      String opponentColorId = opponentColor;

      debugPrint(
        '🎮 ONLINE INITIAL SETUP - MyColor: $myColorId | Opponent: $opponentColorId',
      );

      // Player 1 is always Red (RP), Player 2 is Yellow (YP)
      bool amIPlayer1 = (myColorId == 'RP');
      final matchData = await _onlineManager.getMatchData();
      final firebaseTurn = matchData?['currentTurn']?.toString() ?? '';

      if (firebaseTurn.isNotEmpty) {
        _currentTurnPlayerId = firebaseTurn;
        await _syncPlayerTurnState(firebaseTurn);
      }

      _globalCurrentTurnPlayerId = _currentTurnPlayerId;

      debugPrint(
        '👑 ${amIPlayer1 ? "I am Player 1 (Red)" : "I am Player 2 (Yellow)"}',
      );

      for (var player in GameState().players) {
        if (player.playerId == 'RP') {
          // Red is always Player 1
          player.isCurrentTurn = true;
          player.enableDice = amIPlayer1;
          debugPrint(
            '✅ Red (RP) set as current turn | enableDice = $amIPlayer1',
          );
        } else {
          player.isCurrentTurn = false;
          player.enableDice = false;
          debugPrint('❌ ${player.playerId} waiting');
        }

        for (var token in player.tokens) {
          token.enableToken = player.enableDice;
        }
      }

      // Update Firebase turn
      if (_onlineManager != null) {
        debugPrint('✅ Firebase turn updated to: $_currentTurnPlayerId');
      }

      await _syncPlayerTurnState(_currentTurnPlayerId!);
      updateDiceVisibility();
      _showInitialPointer();
    }
    // Offline mode
    else if (!isOnline && GameState().players.isNotEmpty) {
      GameState().players[0].isCurrentTurn = true;
      GameState().players[0].enableDice = true;
      for (var token in GameState().players[0].tokens) {
        token.enableToken = true;
      }
      _showInitialPointer();
    }

    // Final dice visibility update
    updateDiceVisibility();

    debugPrint('🎮 Game started successfully');
    return Future.value();
  }

  // Add this method inside the Ludo class
  void _addDiceToBoard() {
    debugPrint('🎲 Adding dice to board for all players...');
    updateDiceVisibility();
    final lowerController = world.children
        .whereType<LowerController>()
        .firstOrNull;
    final upperController = world.children
        .whereType<UpperController>()
        .firstOrNull;

    // Check if players exist before adding dice
    if (GameState().players.isEmpty) {
      debugPrint('⚠️ No players found, cannot add dice yet');
      return;
    }

    // Add dice for LowerController (Blue and Yellow)
    if (lowerController != null) {
      final lowerComponents = lowerController.children.toList();

      // Left dice container for Blue player
      if (lowerComponents.length > 0) {
        final leftDice = lowerComponents[0].children
            .whereType<RectangleComponent>()
            .firstOrNull;
        if (leftDice != null) {
          final leftDiceContainer = leftDice.children
              .whereType<RectangleComponent>()
              .firstOrNull;
          if (leftDiceContainer != null) {
            // Check if Blue player exists, if not skip
            Player? bluePlayer;
            try {
              bluePlayer = GameState().players.firstWhere(
                (p) => p.playerId == 'BP',
              );
            } catch (_) {
              bluePlayer = null;
            }
            if (bluePlayer != null) {
              final existingDice = leftDiceContainer.children
                  .whereType<LudoDice>()
                  .firstOrNull;
              if (existingDice != null) {
                leftDiceContainer.remove(existingDice);
              }
              leftDiceContainer.add(
                LudoDice(player: bluePlayer, faceSize: leftDice.size.x * 0.70)
                  ..game = this,
              );
              debugPrint('🎲 Blue dice added to left container');
            }
          }
        }
      }

      // Right dice container for Yellow player
      if (lowerComponents.length > 2) {
        final rightDice = lowerComponents[2].children
            .whereType<RectangleComponent>()
            .firstOrNull;
        if (rightDice != null) {
          final rightDiceContainer = rightDice.children
              .whereType<RectangleComponent>()
              .firstOrNull;
          if (rightDiceContainer != null) {
            Player? yellowPlayer;
            try {
              yellowPlayer = GameState().players.firstWhere(
                (p) => p.playerId == 'YP',
              );
            } catch (_) {
              yellowPlayer = null;
            }
            if (yellowPlayer != null) {
              final existingDice = rightDiceContainer.children
                  .whereType<LudoDice>()
                  .firstOrNull;
              if (existingDice != null) {
                rightDiceContainer.remove(existingDice);
              }
              rightDiceContainer.add(
                LudoDice(
                  player: yellowPlayer,
                  faceSize: rightDice.size.x * 0.70,
                )..game = this,
              );
              debugPrint('🎲 Yellow dice added to right container');
            }
          }
        }
      }
    }

    // Add dice for UpperController (Red and Green)
    if (upperController != null) {
      final upperComponents = upperController.children.toList();

      // Left dice container for Red player
      if (upperComponents.length > 0) {
        final leftDice = upperComponents[0].children
            .whereType<RectangleComponent>()
            .firstOrNull;
        if (leftDice != null) {
          final leftDiceContainer = leftDice.children
              .whereType<RectangleComponent>()
              .firstOrNull;
          if (leftDiceContainer != null) {
            final redPlayer = GameState().players
                .where((p) => p.playerId == 'RP')
                .firstOrNull;
            if (redPlayer != null) {
              final existingDice = leftDiceContainer.children
                  .whereType<LudoDice>()
                  .firstOrNull;
              if (existingDice != null) {
                leftDiceContainer.remove(existingDice);
              }
              leftDiceContainer.add(
                LudoDice(player: redPlayer, faceSize: leftDice.size.x * 0.70)
                  ..game = this,
              );
              debugPrint('🎲 Red dice added to left container');
            }
          }
        }
      }

      // Right dice container for Green player
      if (upperComponents.length > 2) {
        final rightDice = upperComponents[2].children
            .whereType<RectangleComponent>()
            .firstOrNull;
        if (rightDice != null) {
          final rightDiceContainer = rightDice.children
              .whereType<RectangleComponent>()
              .firstOrNull;
          if (rightDiceContainer != null) {
            final greenPlayer = GameState().players
                .where((p) => p.playerId == 'GP')
                .firstOrNull;
            if (greenPlayer != null) {
              final existingDice = rightDiceContainer.children
                  .whereType<LudoDice>()
                  .firstOrNull;
              if (existingDice != null) {
                rightDiceContainer.remove(existingDice);
              }
              rightDiceContainer.add(
                LudoDice(player: greenPlayer, faceSize: rightDice.size.x * 0.70)
                  ..game = this,
              );
              debugPrint('🎲 Green dice added to right container');
            }
          }
        }
      }
    }

    // After adding all dice, hide the ones that shouldn't be visible based on turn
    updateDiceVisibility();

    debugPrint('✅ Dice added to board successfully');
  }

  // Add this method to sync pointer visibility across devices
  // In Ludo.dart - Update syncPointerVisibility method

  Future<void> syncPointerVisibility(String playerId) async {
    if (!isOnline) return;

    final String colorCode = _getTurnColorFromUserId(playerId);
    _showTurnPointerByColor(colorCode);

    // IMPORTANT: Pointer is now local UI only.
    // Do not write pointerState to Firebase, otherwise both devices can fight each other.
    debugPrint(
      '🎯 Local pointer synced for player: $playerId, color: $colorCode',
    );
  }

  // Add this method to sync dice visibility
  Future<void> syncDiceVisibility() async {
    if (!isOnline) return;

    // Dice visibility/enable state is derived from currentTurn only.
    // Do not write diceVisibility to Firebase.
    updateDiceVisibility();
  }

  // Add this method to sync dice face
  Future<void> syncDiceFace(int diceNumber) async {
    if (!isOnline || _onlineManager == null) return;

    await _onlineManager.updateDiceNumber(diceNumber);
    await updateDiceFaceOnBothDevices(diceNumber);
  }

  void _showInitialPointer() {
    if (_currentTurnPlayerId == null) return;
    _showTurnPointerByColor(_getTurnColorFromUserId(_currentTurnPlayerId!));
  }

  @override
  Color backgroundColor() => const Color.fromARGB(0, 0, 0, 0);

  RankModalComponent? _playerModal;

  int _parseIntValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _handleOnlineGameCompleted(Map<String, dynamic> data) async {
    if (_onlineResultHandled) return;
    _onlineResultHandled = true;

    switchOffPointer();

    for (final player in GameState().players) {
      player.enableDice = false;
      player.isCurrentTurn = false;
    }

    for (final token in TokenManager().allTokens) {
      token.enableToken = false;
      token.disableCircleAnimation();
    }

    final String winnerId =
        data['winnerId']?.toString() ?? data['winner']?.toString() ?? '';

    if (winnerId.isEmpty || currentPlayerId == null || matchId == null) {
      return;
    }

    final int finalEntryFee = _parseIntValue(data['entryFee']);
    final int finalWinPrize = _parseIntValue(
      data['winPrize'],
      fallback: finalEntryFee + (finalEntryFee ~/ 2),
    );

    final bool iAmWinner = winnerId == currentPlayerId;

    await _firebase.settleOnlineMatchResultForCurrentUser(
      matchId: matchId!,
      userId: currentPlayerId!,
      winnerId: winnerId,
      entryFee: finalEntryFee,
      winPrize: finalWinPrize,
    );

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff2a0540), Color(0xff180128)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: iAmWinner ? const Color(0xfff7a900) : Colors.red,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iAmWinner
                      ? Icons.emoji_events_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  color: iAmWinner ? const Color(0xfff7a900) : Colors.red,
                  size: 70,
                ),
                const SizedBox(height: 18),
                Text(
                  iAmWinner ? 'Congratulations!' : 'Oops!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: iAmWinner ? const Color(0xfff7a900) : Colors.red,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  iAmWinner ? 'You win $finalWinPrize coins' : 'You are lost',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (!iAmWinner)
                  Text(
                    'Entry fee: $finalEntryFee coins',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();

                      if (matchId != null &&
                          currentPlayerId != null &&
                          opponentPlayerId != null) {
                        await _firebase.cleanupCompletedMatchAfterResult(
                          matchId: matchId!,
                          currentUserId: currentPlayerId!,
                          opponentUserId: opponentPlayerId!,
                        );
                      }

                      if (!context.mounted) return;

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const PlayWithOnline(),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff7a900),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showPlayerModal() {
    _playerModal = RankModalComponent(
      players: GameState().players,
      position: Vector2(size.x * 0.05, size.y * 0.10),
      size: Vector2(size.x * 0.90, size.y * 0.90),
      context: context,
    );
    world.add(_playerModal!);
  }

  void hidePlayerModal() {
    _playerModal?.removeFromParent();
    _playerModal = null;
  }
}

extension on ReadOnlyOrderedSet<Component> {
  Object? operator [](int other) {}
}

// Helper functions
List<Component> getHomeSpotHelper(World world, int index) {
  final ludoBoard = GameState().ludoBoard;
  if (ludoBoard == null) return [];

  final childrenOfLudoBoard = ludoBoard.children.toList();
  if (childrenOfLudoBoard.length <= index) return [];

  final child = childrenOfLudoBoard[index];
  if (child == null) return [];

  final home = child.children.toList();
  if (home.isEmpty) return [];

  final homePlate = home[0].children.toList();
  if (homePlate.length <= 1) return [];

  final homeSpotContainer = homePlate[1].children.toList();
  if (homeSpotContainer.length <= 1) return [];

  final homeSpotList = homeSpotContainer[1].children.toList();
  return homeSpotList;
}

Future<void> applyEffectHelper(PositionComponent component, Effect effect) {
  final completer = Completer<void>();
  effect.onComplete = completer.complete;
  component.add(effect);
  return completer.future;
}

void moveOutOfBase({
  required World world,
  required Token token,
  required List<String> tokenPath,
}) async {
  token.positionId = tokenPath.first;
  token.state = TokenState.onBoard;

  await applyEffectHelper(
    token,
    MoveToEffect(
      SpotManager().findSpotById(tokenPath.first).tokenPosition,
      EffectController(duration: 0.1, curve: Curves.easeInOut),
    ),
  );

  tokenCollision(world, token);
}

Future<void> moveOutOfBaseOnline({
  required World world,
  required Token token,
  required List<String> tokenPath,
}) async {
  token.positionId = tokenPath.first;
  token.state = TokenState.onBoard;

  await applyEffectHelper(
    token,
    MoveToEffect(
      SpotManager().findSpotById(tokenPath.first).tokenPosition,
      EffectController(duration: 0.12, curve: Curves.easeInOut),
    ),
  );

  if (_globalIsOnline && _globalOnlineManager != null) {
    await _globalOnlineManager!.updateTokenPosition(
      token.playerId,
      token.tokenId,
      token.positionId,
    );
  }

  clearTokenTrail();
  resizeTokensOnSpot(world);

  if (_globalIsOnline &&
      _globalOnlineManager != null &&
      _globalCurrentPlayerId != null &&
      _globalOpponentPlayerId != null) {
    final nextPlayerId = GameState().diceNumber == 6
        ? _globalCurrentPlayerId!
        : _globalOpponentPlayerId!;

    await _globalOnlineManager!.switchTurnAtomic(
      expectedCurrentTurnUserId: _globalCurrentPlayerId!,
      nextTurnUserId: nextPlayerId,
    );

    _globalCurrentTurnPlayerId = nextPlayerId;
  }
}

Future<void> tokenCollisionOnlineHelper(
  World world,
  Token attackerToken,
) async {
  final tokensOnSpot = TokenManager().allTokens
      .where((token) => token.positionId == attackerToken.positionId)
      .toList();

  bool wasTokenAttacked = false;

  if (tokensOnSpot.length > 1 &&
      ![
        'B04',
        'B23',
        'R22',
        'R10',
        'G02',
        'G21',
        'Y30',
        'Y42',
      ].contains(attackerToken.positionId)) {
    final tokensToMove = tokensOnSpot
        .where((token) => token.playerId != attackerToken.playerId)
        .toList();

    if (tokensToMove.isNotEmpty) {
      wasTokenAttacked = true;
    }

    await Future.wait(
      tokensToMove.map(
        (token) => moveBackward(
          world: world,
          token: token,
          tokenPath: GameState().getTokenPath(token.playerId),
          ludoBoard: GameState().ludoBoard as PositionComponent,
        ),
      ),
    );
  }

  final player = GameState().players.firstWhere(
    (player) => player.playerId == attackerToken.playerId,
  );

  String nextPlayerId;

  if (wasTokenAttacked || GameState().diceNumber == 6) {
    if (wasTokenAttacked) {
      if (player.hasRolledThreeConsecutiveSixes()) {
        player.resetExtraTurns();
      }
      player.grantAnotherTurn();
    }

    nextPlayerId = _globalCurrentPlayerId!;
  } else {
    nextPlayerId = _globalOpponentPlayerId!;
  }

  player.enableDice = true;

  if (_globalIsOnline && _globalOnlineManager != null) {
    await _globalOnlineManager!.updateTurn(nextPlayerId);
    await _globalOnlineManager!.updatePlayerState(
      _globalCurrentPlayerId!,
      player.playerId,
      enableDice: true,
    );

    _globalCurrentTurnPlayerId = nextPlayerId;
  }

  // ALWAYS show pointer for the player whose turn it is.
  // If same player got turn again, show attacker color.
  // If turn changed, show opponent color according to your online pair.
  String currentTurnColor;
  if (_globalCurrentTurnPlayerId == _globalCurrentPlayerId) {
    currentTurnColor = attackerToken.playerId;
  } else {
    if (attackerToken.playerId == 'RP') {
      currentTurnColor = 'YP';
    } else if (attackerToken.playerId == 'YP') {
      currentTurnColor = 'RP';
    } else if (attackerToken.playerId == 'BP') {
      currentTurnColor = 'GP';
    } else {
      currentTurnColor = 'BP';
    }
  }

  final lowerController = world.children
      .whereType<LowerController>()
      .firstOrNull;
  final upperController = world.children
      .whereType<UpperController>()
      .firstOrNull;

  // Hide all pointers first
  lowerController?.hidePointer('BP');
  lowerController?.hidePointer('YP');
  lowerController?.hidePointer('RP');
  lowerController?.hidePointer('GP');
  upperController?.hidePointer('BP');
  upperController?.hidePointer('YP');
  upperController?.hidePointer('RP');
  upperController?.hidePointer('GP');

  // Show pointer for the current turn player
  lowerController?.showPointer(currentTurnColor);
  upperController?.showPointer(currentTurnColor);
}

void tokenCollision(World world, Token attackerToken) async {
  final tokensOnSpot = TokenManager().allTokens
      .where((token) => token.positionId == attackerToken.positionId)
      .toList();

  bool wasTokenAttacked = false;

  if (tokensOnSpot.length > 1 &&
      ![
        'B04',
        'B23',
        'R22',
        'R10',
        'G02',
        'G21',
        'Y30',
        'Y42',
      ].contains(attackerToken.positionId)) {
    final tokensToMove = tokensOnSpot
        .where((token) => token.playerId != attackerToken.playerId)
        .toList();

    if (tokensToMove.isNotEmpty) {
      wasTokenAttacked = true;
    }

    await Future.wait(
      tokensToMove.map(
        (token) => moveBackward(
          world: world,
          token: token,
          tokenPath: GameState().getTokenPath(token.playerId),
          ludoBoard: GameState().ludoBoard as PositionComponent,
        ),
      ),
    );
  }

  final player = GameState().players.firstWhere(
    (player) => player.playerId == attackerToken.playerId,
  );

  if (wasTokenAttacked) {
    if (player.hasRolledThreeConsecutiveSixes()) {
      player.resetExtraTurns();
    }
    player.grantAnotherTurn();
  } else {
    if (GameState().diceNumber != 6) {
      GameState().switchToNextPlayer();
    }
  }

  player.enableDice = true;

  if (GameState().diceNumber == 6 || wasTokenAttacked == true) {
    final lowerController = world.children.whereType<LowerController>().first;
    final upperController = world.children.whereType<UpperController>().first;
    lowerController.showPointer(player.playerId);
    upperController.showPointer(player.playerId);
  }

  for (var token in player.tokens) {
    token.enableToken = false;
  }

  resizeTokensOnSpot(world);
}

void resizeTokensOnSpot(World world) {
  final positionIncrements = {1: 0, 2: 10, 3: 5};

  final Map<String, List<Token>> tokensByPositionId = {};
  for (var token in TokenManager().allTokens) {
    if (!tokensByPositionId.containsKey(token.positionId)) {
      tokensByPositionId[token.positionId] = [];
    }
    tokensByPositionId[token.positionId]!.add(token);
  }

  tokensByPositionId.forEach((positionId, tokenList) {
    final spot = SpotManager().findSpotById(positionId);
    final positionIncrement = positionIncrements[tokenList.length] ?? 5;

    for (var i = 0; i < tokenList.length; i++) {
      final token = tokenList[i];
      if (token.state == TokenState.inBase) {
        token.position = spot.position;
      } else if (token.state == TokenState.onBoard ||
          token.state == TokenState.inHome) {
        token.position = Vector2(
          spot.tokenPosition.x + i * positionIncrement,
          spot.tokenPosition.y,
        );
      }
    }
  });
}

void addTokenTrail(List<Token> tokensInBase, List<Token> tokensOnBoard) {
  var trailingTokens = [];

  for (var token in tokensOnBoard) {
    if (!token.spaceToMove()) {
      continue;
    }
    trailingTokens.add(token);
  }

  if (GameState().diceNumber == 6) {
    for (var token in tokensInBase) {
      trailingTokens.add(token);
    }
  }

  for (var token in trailingTokens) {
    token.enableCircleAnimation();
  }
}

Future<void> moveBackward({
  required World world,
  required Token token,
  required List<String> tokenPath,
  required PositionComponent ludoBoard,
}) async {
  final currentIndex = tokenPath.indexOf(token.positionId);
  const finalIndex = 0;

  bool audioPlayed = false;

  for (int i = currentIndex; i >= finalIndex; i--) {
    token.positionId = tokenPath[i];

    if (!audioPlayed) {
      FlameAudio.play('move.mp3');
      audioPlayed = true;
    }

    await applyEffectHelper(
      token,
      MoveToEffect(
        SpotManager()
            .getSpots()
            .firstWhere((spot) => spot.uniqueId == token.positionId)
            .tokenPosition,
        EffectController(duration: 0.1, curve: Curves.easeInOut),
      ),
    );
  }

  if (token.playerId == 'BP') {
    await moveTokenToBase(
      world: world,
      token: token,
      tokenBase: TokenManager().blueTokensBase,
      homeSpotIndex: 6,
      ludoBoard: ludoBoard,
    );
  } else if (token.playerId == 'GP') {
    await moveTokenToBase(
      world: world,
      token: token,
      tokenBase: TokenManager().greenTokensBase,
      homeSpotIndex: 2,
      ludoBoard: ludoBoard,
    );
  } else if (token.playerId == 'RP') {
    await moveTokenToBase(
      world: world,
      token: token,
      tokenBase: TokenManager().redTokensBase,
      homeSpotIndex: 0,
      ludoBoard: ludoBoard,
    );
  } else if (token.playerId == 'YP') {
    await moveTokenToBase(
      world: world,
      token: token,
      tokenBase: TokenManager().yellowTokensBase,
      homeSpotIndex: 8,
      ludoBoard: ludoBoard,
    );
  }
}

Future<void> moveForward({
  required World world,
  required Token token,
  required List<String> tokenPath,
  required int diceNumber,
}) async {
  final currentIndex = tokenPath.indexOf(token.positionId);
  final finalIndex = currentIndex + diceNumber;

  for (int i = currentIndex + 1; i <= finalIndex && i < tokenPath.length; i++) {
    token.positionId = tokenPath[i];
    await applyEffectHelper(
      token,
      MoveToEffect(
        SpotManager()
            .getSpots()
            .firstWhere((spot) => spot.uniqueId == token.positionId)
            .tokenPosition,
        EffectController(duration: 0.12, curve: Curves.easeInOut),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 120));
  }

  bool isTokenInHome = await checkTokenInHomeAndHandle(token, world);

  if (isTokenInHome) {
    resizeTokensOnSpot(world);
  } else {
    tokenCollision(world, token);
  }
  clearTokenTrail();
}

void clearTokenTrail() {
  final tokens = TokenManager().allTokens;
  for (var token in tokens) {
    token.disableCircleAnimation();
  }
}

Future<void> moveTokenToBase({
  required World world,
  required Token token,
  required Map<String, String> tokenBase,
  required int homeSpotIndex,
  required PositionComponent ludoBoard,
}) async {
  for (var entry in tokenBase.entries) {
    var tokenId = entry.key;
    var homePosition = entry.value;
    if (token.tokenId == tokenId) {
      token.positionId = homePosition;
      token.state = TokenState.inBase;
    }
  }

  await applyEffectHelper(
    token,
    MoveToEffect(
      SpotManager().findSpotById(token.positionId).position,
      EffectController(duration: 0.03, curve: Curves.easeInOut),
    ),
  );
  await Future.delayed(const Duration(milliseconds: 30));
}

Future<bool> checkTokenInHomeAndHandle(Token token, World world) async {
  const homePositions = ['BF', 'GF', 'YF', 'RF'];

  if (!homePositions.contains(token.positionId)) return false;

  token.state = TokenState.inHome;

  // Sync token position to Firebase when it reaches home
  if (_globalIsOnline && _globalOnlineManager != null) {
    await _globalOnlineManager!.updateTokenPosition(
      token.playerId,
      token.tokenId,
      token.positionId,
    );
  }

  final player = GameState().players.firstWhere(
    (p) => p.playerId == token.playerId,
  );
  player.totalTokensInHome++;

  if (player.totalTokensInHome == 4) {
    player.hasWon = true;

    final playersWhoWon = GameState().players.where((p) => p.hasWon).toList();
    final playersWhoNotWon = GameState().players
        .where((p) => !p.hasWon)
        .toList();

    if (playersWhoWon.length == GameState().players.length - 1) {
      playersWhoNotWon.first.rank = GameState().players.length;
      player.rank = playersWhoWon.length;

      for (var p in GameState().players) {
        p.enableDice = false;
        p.isCurrentTurn = false;
      }

      for (var t in TokenManager().allTokens) {
        t.enableToken = false;
        t.disableCircleAnimation();
      }

      if (_globalIsOnline && _globalOnlineManager != null) {
        final winnerUserId = _globalOnlineManager!.getUserIdFromColorCode(
          player.playerId,
        );

        if (winnerUserId != null && winnerUserId.isNotEmpty) {
          await _globalOnlineManager!.endGame(
            winnerId: winnerUserId,
            winnerColor: player.playerId,
          );
        }
      } else {
        EventBus().emit(OpenPlayerModalEvent());
      }
    } else {
      player.rank = playersWhoWon.length;
    }
    return true;
  }

  player.enableDice = true;

  // Only show pointer if it's THIS device's turn
  if (_globalCurrentTurnPlayerId == _globalCurrentPlayerId) {
    final lowerController = world.children
        .whereType<LowerController>()
        .firstOrNull;
    final upperController = world.children
        .whereType<UpperController>()
        .firstOrNull;

    if (player.playerId == 'BP' || player.playerId == 'YP') {
      lowerController?.showPointer(player.playerId);
    } else {
      upperController?.showPointer(player.playerId);
    }
  }

  for (var t in player.tokens) {
    t.enableToken = false;
  }

  if (player.hasRolledThreeConsecutiveSixes()) {
    await player.resetExtraTurns();
  }

  player.grantAnotherTurn();

  // Sync the extra turn to Firebase
  if (_globalIsOnline && _globalOnlineManager != null) {
    await _globalOnlineManager!.updateTurn(_globalCurrentTurnPlayerId!);
  }

  return true;
}
