import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/state/token_manager.dart';

import '../../state/game_state.dart';

class SpotManager {
  static final SpotManager _instance = SpotManager._internal();
  final Map<String, Spot> _spotMap = {};
  List<Spot>? _cachedSpots;

  SpotManager._internal();

  factory SpotManager() {
    return _instance;
  }

  void addSpot(Spot spot) {
    _spotMap[spot.uniqueId] = spot;
    _cachedSpots = null;
  }

  void removeSpot(String spotId) {
    if (_spotMap.remove(spotId) != null) {
      _cachedSpots = null;
    }
  }

  Spot? getSpotById(String spotId) {
    return _spotMap[spotId];
  }

  List<Spot> getSpots() {
    _cachedSpots ??= List.unmodifiable(_spotMap.values.toList());
    return _cachedSpots!;
  }

  static final Spot _defaultSpot = Spot(
    uniqueId: 'default',
    position: Vector2.zero(),
    size: Vector2(10, 10),
    paint: Paint()..color = Colors.grey,
  );

  Spot findSpotById(String spotId) {
    Spot? spot = getSpotById(spotId);
    return spot ?? _defaultSpot;
  }
}

class Spot extends RectangleComponent {
  final String uniqueId;
  late final Vector2 tokenPosition;

  Spot({
    required this.uniqueId,
    required Vector2 position,
    required Vector2 size,
    required Paint paint,
    List<Component>? children,
  }) : super(
         position: position,
         size: size,
         paint: paint,
         children: children ?? [],
       ) {
    SpotManager().addSpot(this);
  }

  @override
  void onLoad() {
    super.onLoad();

    // FIXED: Check if tokens exist before accessing
    double tokenSizeAdjustmentX = 0;
    double tokenSizeAdjustmentY = 0;

    if (TokenManager().allTokens.isNotEmpty) {
      tokenSizeAdjustmentX = TokenManager().allTokens.first.size.x * 0.10;
      tokenSizeAdjustmentY = TokenManager().allTokens.first.size.x * 0.15;
    }

    final spotGlobalPosition = absolutePositionOf(Vector2.zero());
    final ludoBoardGlobalPosition = GameState().ludoBoardAbsolutePosition;

    tokenPosition = Vector2(
      spotGlobalPosition.x + tokenSizeAdjustmentX - ludoBoardGlobalPosition.x,
      spotGlobalPosition.y - tokenSizeAdjustmentY - ludoBoardGlobalPosition.y,
    );
  }
}
