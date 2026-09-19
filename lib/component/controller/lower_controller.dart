import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../component/ui_components/dice_pointer.dart';
import '../../ludo.dart';
import '../../state/game_state.dart';
// user files
import 'controller_block.dart';

class LowerController extends RectangleComponent with HasGameReference<Ludo> {
  final RectangleComponent leftArrow;
  final RectangleComponent rightArrow;

  LowerController({
    required double width,
    required double height,
    Vector2? position,
  }) : leftArrow = RectangleComponent(
         size: Vector2(width * 0.45 * 0.3, height * 0.8),
         position: Vector2(width * 0.45 * 0.8, width * 0.45 * 0.05),
         paint: Paint()..color = Colors.transparent,
       ),
       rightArrow = RectangleComponent(
         size: Vector2(width * 0.45 * 0.3, height * 0.8),
         position: Vector2(width * 0.45 * 0.975, width * 0.45 * 0.05),
         paint: Paint()..color = Colors.transparent,
       ),
       super(
         size: Vector2(width, height),
         paint: Paint()..color = Colors.transparent,
       ) {
    final double innerWidth = width * 0.45;
    final double innerHeight = height;

    final leftToken = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
      position: Vector2(2.2, innerWidth * 0.05),
      paint: Paint()..color = GameState().blue,
      children: [
        ControllerBlock(
          transparentRight: true,
          transparentLeft: false,
          size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
          position: Vector2(0, 0),
          paint: Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = const Color(0xFF03346E),
          children: [],
        ),
      ],
    );

    final leftDice = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight),
      position: Vector2(innerWidth * 0.4, 0),
      paint: Paint()..color = GameState().blue,
      children: [
        RectangleComponent(
          size: Vector2(innerWidth * 0.4, innerHeight),
          paint: Paint()
            ..color = Colors.transparent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..color = const Color(0xFF03346E),
          children: [
            RectangleComponent(
              position: Vector2(innerWidth * 0.20, innerHeight * 0.5),
            ),
          ],
        ),
      ],
    );

    final rightDice = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight),
      position: Vector2(width - innerWidth * 0.8, 0),
      paint: Paint()..color = GameState().yellow,
      children: [
        RectangleComponent(
          size: Vector2(innerWidth * 0.4, innerHeight),
          paint: Paint()
            ..color = Colors.transparent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..color = const Color(0xFF03346E),
          children: [
            RectangleComponent(
              position: Vector2(innerWidth * 0.20, innerHeight * 0.5),
            ),
          ],
        ),
      ],
    );

    final rightToken = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
      position: Vector2(width - innerWidth * 0.4 - 2.5, innerWidth * 0.05),
      paint: Paint()..color = GameState().yellow,
      children: [
        ControllerBlock(
          transparentLeft: true,
          size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
          position: Vector2(0, 0),
          paint: Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = const Color(0xFF03346E),
          children: [],
        ),
      ],
    );

    addAll([leftDice, leftToken, rightDice, rightToken, leftArrow, rightArrow]);

    this.position = position ?? Vector2.zero();
  }

  // Displays a `DicePointer` with a movement effect on the `leftArrow` component
  void showPointer(String playerId) {
    final pointerX = size.x * 0.05;
    final pointerY = (size.x * 0.20) * 0.2;

    // Show pointer on the correct side based on player ID
    if (playerId == 'BP') {
      // Blue player - show on left side with Blue arrow
      final pointer = DicePointer(
        direction: PointerDirection.left,
        size: size.x * 0.07,
        paint: Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill,
        position: Vector2(pointerX, pointerY),
      );
      pointer.add(
        MoveByEffect(
          Vector2((size.x * 0.20) * 0.1, 0),
          EffectController(duration: 0.2, reverseDuration: 0.2, infinite: true),
        ),
      );
      leftArrow.add(pointer);
      debugPrint('🎯 Showing BLUE arrow on left side');
    } else if (playerId == 'YP') {
      // Yellow player - show on right side with Yellow arrow
      final pointer = DicePointer(
        direction: PointerDirection.right,
        size: size.x * 0.07,
        paint: Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.fill,
        position: Vector2(pointerX, pointerY),
      );
      pointer.add(
        MoveByEffect(
          Vector2((size.x * 0.20) * 0.1, 0),
          EffectController(duration: 0.2, reverseDuration: 0.2, infinite: true),
        ),
      );
      rightArrow.add(pointer);
      debugPrint('🎯 Showing YELLOW arrow on right side');
    }
  }

  void hidePointer(String playerId) {
    if (playerId == 'BP') {
      final pointer = leftArrow.children.whereType<DicePointer>().firstOrNull;
      if (pointer != null) {
        leftArrow.remove(pointer);
      }
    } else if (playerId == 'YP') {
      final pointer = rightArrow.children.whereType<DicePointer>().firstOrNull;
      if (pointer != null) {
        rightArrow.remove(pointer);
      }
    }
  }
}
