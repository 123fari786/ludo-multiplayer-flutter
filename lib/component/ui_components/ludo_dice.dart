import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/material.dart';

import '../../ludo.dart';
import '../../ludo_board.dart';
import '../../state/audio_manager.dart';
import '../../state/game_state.dart';
import '../../state/player.dart';
// user files
import 'dice_face_component.dart';
import 'token.dart';

class LudoDice extends PositionComponent
    with TapCallbacks, HasGameReference<Ludo> {
  static const double borderRadiusFactor = 0.2;
  static const double innerSizeFactor = 0.9;

  final double faceSize;
  late final double borderRadius;
  late final double innerRectangleWidth;
  late final double innerRectangleHeight;

  late final RectangleComponent innerRectangle;
  late final DiceFaceComponent diceFace;

  final Player player;

  void playSound() async {
    await AudioManager.playDiceSound();
  }

  @override
  void onTapDown(TapDownEvent event) async {
    debugPrint('🎲 Dice tapped for player: ${player.playerId}');

    if (parent == null) return;

    if (game.isOnline) {
      if (!game.canPlay) return;
      if (player.playerId != game.myColor) return;
      if (!player.enableDice || !player.isCurrentTurn) return;
    } else {
      if (!player.enableDice || !player.isCurrentTurn) return;
      if (player != GameState().currentPlayer) return;
    }

    final world = parent?.parent?.parent?.parent?.parent;
    if (world is! World) return;

    GameState().hidePointer();
    player.enableDice = false;
    for (final token in player.tokens) {
      token.enableToken = false;
      token.disableCircleAnimation();
    }

    final rolledNumber = Random().nextInt(6) + 1;

    if (game.isOnline) {
      final accepted = await game.onlineManager.rollDiceForTurn(
        rollingUserId: game.currentPlayerId!,
        diceNumber: rolledNumber,
      );
      if (!accepted) {
        debugPrint('❌ Dice roll rejected by Firebase transaction');

        player.enableDice = true;
        player.isCurrentTurn = true;

        return;
      }
    }

    GameState().diceNumber = rolledNumber;
    diceFace.updateDiceValue(rolledNumber);
    playSound();
    _applyDiceRollEffect();

    await Future.delayed(const Duration(milliseconds: 300));

    if (game.isOnline) {
      await game.updateDiceFaceOnBothDevices(rolledNumber);

      if (rolledNumber == 6) {
        _handleSixRollOnline(
          world,
          GameState().ludoBoard as LudoBoard,
          rolledNumber,
        );
      } else {
        _handleNonSixRollOnline(
          world,
          GameState().ludoBoard as LudoBoard,
          rolledNumber,
        );
      }
    } else {
      final handleRoll = rolledNumber == 6 ? _handleSixRoll : _handleNonSixRoll;
      handleRoll(world, GameState().ludoBoard as LudoBoard, rolledNumber);
    }
  }

  FutureOr<void> _applyDiceRollEffect() {
    add(
      RotateEffect.by(
        tau,
        EffectController(duration: 0.3, curve: Curves.linear),
      ),
    );
    return Future.value();
  }

  void _handleSixRollOnline(World world, LudoBoard ludoBoard, int diceNumber) {
    player.grantAnotherTurn();

    if (player.hasRolledThreeConsecutiveSixes()) {
      game.finishOnlineMoveAndSwitchTurn(
        movedColorCode: player.playerId,
        keepSameTurn: false,
      );
      return;
    }

    _handleSixRoll(world, ludoBoard, diceNumber);
  }

  void _handleNonSixRollOnline(
    World world,
    LudoBoard ludoBoard,
    int diceNumber,
  ) {
    final tokensOnBoard = player.tokens
        .where((token) => token.state == TokenState.onBoard)
        .toList();

    if (tokensOnBoard.isEmpty) {
      game.finishOnlineMoveAndSwitchTurn(
        movedColorCode: player.playerId,
        keepSameTurn: false,
      );
      return;
    }

    _handleNonSixRoll(world, ludoBoard, diceNumber);
  }

  void _handleSixRoll(World world, LudoBoard ludoBoard, int diceNumber) {
    player.grantAnotherTurn();

    if (player.hasRolledThreeConsecutiveSixes()) {
      GameState().switchToNextPlayer();
      return;
    }

    final tokensInBase = player.tokens
        .where((token) => token.state == TokenState.inBase)
        .toList();

    final tokensOnBoard = player.tokens
        .where((token) => token.state == TokenState.onBoard)
        .toList();

    final movableTokens = tokensOnBoard
        .where((token) => token.spaceToMove())
        .toList();

    final allMovableTokens = [...movableTokens, ...tokensInBase];

    if (allMovableTokens.length == 1) {
      if (allMovableTokens.first.state == TokenState.inBase) {
        if (game.isOnline) {
          moveOutOfBaseOnline(
            world: world,
            token: allMovableTokens.first,
            tokenPath: GameState().getTokenPath(player.playerId),
          );
        } else {
          moveOutOfBase(
            world: world,
            token: allMovableTokens.first,
            tokenPath: GameState().getTokenPath(player.playerId),
          );
        }
      } else if (allMovableTokens.first.state == TokenState.onBoard) {
        _moveForwardSingleToken(
          world,
          ludoBoard,
          diceNumber,
          allMovableTokens.first,
        );
      }
      return;
    } else if (allMovableTokens.length > 1) {
      _enableManualTokenSelection(world, tokensInBase, tokensOnBoard);
    } else if (allMovableTokens.isEmpty) {
      GameState().switchToNextPlayer();
      return;
    }
  }

  void _handleNonSixRoll(World world, LudoBoard ludoBoard, int diceNumber) {
    final tokensOnBoard = player.tokens
        .where((token) => token.state == TokenState.onBoard)
        .toList();

    if (tokensOnBoard.isEmpty) {
      GameState().switchToNextPlayer();
      return;
    }

    final movableTokens = tokensOnBoard
        .where((token) => token.spaceToMove())
        .toList();
    final tokensInBase = player.tokens
        .where((token) => token.state == TokenState.inBase)
        .toList();

    if (movableTokens.length == 1) {
      _moveForwardSingleToken(
        world,
        ludoBoard,
        diceNumber,
        movableTokens.first,
      );
      return;
    } else if (movableTokens.length > 1) {
      _enableManualTokenSelection(world, tokensInBase, tokensOnBoard);
    } else if (movableTokens.isEmpty) {
      GameState().switchToNextPlayer();
      return;
    }
  }

  void _enableManualTokenSelection(
    World world,
    List<Token> tokensInBase,
    List<Token> tokensOnBoard,
  ) {
    GameState().hidePointer();
    player.enableDice = false;

    for (var token in player.tokens) {
      token.enableToken = true;
    }
    if (tokensInBase.isNotEmpty && tokensOnBoard.isNotEmpty) {
      GameState().enableMoveFromBoth();
      addTokenTrail(tokensInBase, tokensOnBoard);
    } else if (tokensInBase.isNotEmpty) {
      GameState().enableMoveFromBase();
      addTokenTrail(tokensInBase, tokensOnBoard);
    } else if (tokensOnBoard.isNotEmpty) {
      addTokenTrail(tokensInBase, tokensOnBoard);
      GameState().enableMoveOnBoard();
    }
  }

  void _moveForwardSingleToken(
    World world,
    LudoBoard ludoBoard,
    int diceNumber,
    Token token,
  ) {
    if (game.isOnline) {
      game.moveForwardOnline(
        world: world,
        token: token,
        tokenPath: GameState().getTokenPath(player.playerId),
        diceNumber: diceNumber,
      );
    } else {
      moveForward(
        world: world,
        token: token,
        tokenPath: GameState().getTokenPath(player.playerId),
        diceNumber: diceNumber,
      );
    }
  }

  LudoDice({required this.faceSize, required this.player}) {
    final double borderRadiusValue = faceSize * borderRadiusFactor;
    final double innerWidth = faceSize * innerSizeFactor;
    final double innerHeight = faceSize * innerSizeFactor;
    final Vector2 innerSize = Vector2(innerWidth, innerHeight);
    final Vector2 innerPosition = Vector2(
      (faceSize - innerWidth) / 2,
      (faceSize - innerHeight) / 2,
    );

    borderRadius = borderRadiusValue;
    innerRectangleWidth = innerWidth;
    innerRectangleHeight = innerHeight;

    size = Vector2.all(faceSize);
    anchor = Anchor.center;

    diceFace = DiceFaceComponent(faceSize: innerWidth, diceValue: 6);

    final innerRectangle = RoundedRectangle(
      size: innerSize,
      position: innerPosition,
      paint: Paint()..color = Colors.white,
      borderRadius: 15.0,
      children: [diceFace],
    );

    add(innerRectangle);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..color = const Color(0xFFD6D6D6)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = Radius.circular(borderRadius);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(rrect, paint);
  }
}

class RoundedRectangle extends PositionComponent {
  final Paint paint;
  final double borderRadius;

  RoundedRectangle({
    required Vector2 size,
    required this.paint,
    this.borderRadius = 10.0,
    super.position,
    super.children,
  }) : super(size: size);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    canvas.drawRRect(rrect, paint);
    super.render(canvas);
  }
}
