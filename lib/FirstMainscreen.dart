library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/ludo.dart';
import 'package:ludo_game/play_with_online.dart';
import 'package:ludo_game/play_with_online/firebase_service.dart';

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key, this.selectedPlayerCount});
  final int? selectedPlayerCount;

  @override
  FirstScreenState createState() => FirstScreenState();
}

class FirstScreenState extends State<FirstScreen> {
  int? selectedPlayerCount;

  @override
  void initState() {
    super.initState();
    selectedPlayerCount = widget.selectedPlayerCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // No back arrow on first screen
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff002fa7), Color(0xff002fa7)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Select Number of Players',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SecondScreen(selectedPlayerCount: 2),
                        ),
                      );
                    },
                    child: const Text('2 Player Game'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecondScreen extends StatefulWidget {
  final int? selectedPlayerCount;

  const SecondScreen({super.key, this.selectedPlayerCount});

  @override
  SecondScreenState createState() => SecondScreenState();
}

class SecondScreenState extends State<SecondScreen> {
  List<String> selectedTeams = [];
  int? selectedOption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FirstScreen()),
            );
          },
        ),
        title: const Text(
          'Select Team Colors',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff002fa7), Color(0xff002fa7)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const GameApp(selectedTeams: ['BP', 'GP']),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        TokenDisplay(color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Player 1',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 30),
                        TokenDisplay(color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Player 2',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const GameApp(selectedTeams: ['RP', 'YP']),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        TokenDisplay(color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'Player 1',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 30),
                        TokenDisplay(color: Colors.yellow),
                        SizedBox(width: 4),
                        Text(
                          'Player 2',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameApp extends StatefulWidget {
  final List<String> selectedTeams;
  final bool isOnline;
  final String? matchId;
  final String? currentPlayerId;
  final String? opponentPlayerId;

  const GameApp({
    super.key,
    required this.selectedTeams,
    this.isOnline = false,
    this.matchId,
    this.currentPlayerId,
    this.opponentPlayerId,
  });

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with TickerProviderStateMixin {
  final FirebaseService _firebase = FirebaseService();

  StreamSubscription<DatabaseEvent>? _matchDeletedSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _coinsSubscription;
  String _currentUserCoins = '0';

  bool _isLeavingGame = false;
  bool _isExitDialogOpen = false;
  Ludo? game;
  late AnimationController _controller;

  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);
  final Color cardPurple = const Color(0xff220033);

  @override
  void initState() {
    super.initState();
    game = Ludo(
      widget.selectedTeams,
      context,
      isOnline: widget.isOnline,
      matchId: widget.matchId,
      currentPlayerId: widget.currentPlayerId,
      opponentPlayerId: widget.opponentPlayerId,
    );
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();
    _listenUserCoins();
    _listenIfMatchDeletedByOpponent();
  }

  void _listenUserCoins() {
    final String? userId = widget.currentPlayerId ?? _firebase.currentUserId;

    if (userId == null || userId.isEmpty) {
      debugPrint('❌ GameApp coins: user id not found');
      return;
    }

    _coinsSubscription?.cancel();

    _coinsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            final data = snapshot.data();
            final coinsValue = data?['coins'];

            setState(() {
              _currentUserCoins = _formatCoins(coinsValue);
            });

            debugPrint('💰 GameApp live coins: $_currentUserCoins');
          },
          onError: (error) {
            debugPrint('❌ GameApp coins listen error: $error');
          },
        );
  }

  String _formatCoins(dynamic value) {
    if (value == null) return '0';

    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();

    return int.tryParse(value.toString())?.toString() ?? '0';
  }

  void _listenIfMatchDeletedByOpponent() {
    if (!widget.isOnline || widget.matchId == null) return;

    _matchDeletedSubscription = _firebase.matchesRef
        .child(widget.matchId!)
        .onValue
        .listen((event) {
          if (!mounted || _isLeavingGame) return;

          if (event.snapshot.value == null) {
            _isLeavingGame = true;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PlayWithOnline()),
            );
          }
        });
  }

  Future<void> _exitAndCleanupGame() async {
    if (_isLeavingGame) return;

    _isLeavingGame = true;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    try {
      if (widget.isOnline &&
          widget.matchId != null &&
          widget.currentPlayerId != null &&
          widget.opponentPlayerId != null) {
        await _firebase.completeMatchAsOpponentWinOnExit(
          matchId: widget.matchId!,
          currentUserId: widget.currentPlayerId!,
          opponentUserId: widget.opponentPlayerId!,
        );

        // Thora delay taake opponent ko completed event/dialog mil sake
        await Future.delayed(const Duration(milliseconds: 1200));

        // Ab old completed match aur lock delete
        await _firebase.cleanupCompletedMatchAfterResult(
          matchId: widget.matchId!,
          currentUserId: widget.currentPlayerId!,
          opponentUserId: widget.opponentPlayerId!,
        );
      }

      try {
        if (widget.isOnline) {
          game?.onlineManager.dispose();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ Exit match cleanup failed: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PlayWithOnline()),
    );
  }

  @override
  void dispose() {
    _matchDeletedSubscription?.cancel();
    _coinsSubscription?.cancel();
    _controller.dispose();

    try {
      if (widget.isOnline) {
        game?.onlineManager.dispose();
      }
    } catch (_) {}

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic) {
        _showExitConfirmationDialog();
      },
      child: Scaffold(
        backgroundColor: darkPurple,
        body: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // ===================================================
                    // TOP BAR
                    // ===================================================
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showExitConfirmationDialog();
                          },
                          child: _topButton(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xff2d0b44),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: gold, width: 1.2),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_esports,
                                  color: Color(0xfff7a900),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "LUDO KING",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _coinBox(),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ===================================================
                    // GAME WIDGET
                    // ===================================================
                    Expanded(
                      child: FadeTransition(
                        opacity: _controller,
                        child: SizedBox(
                          width: screenWidth,
                          height: screenWidth + screenWidth * 0.70,
                          child: GameWidget(game: game!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topButton(IconData icon) {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }

  Widget _coinBox() {
    return Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 68),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/coin.png', height: 18),
          const SizedBox(width: 5),
          Text(
            _currentUserCoins,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExitConfirmationDialog() async {
    if (_isExitDialogOpen || _isLeavingGame) return;

    _isExitDialogOpen = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            builder: (context, double scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff2d0b44), Color(0xff1a0625)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: gold.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Header Icon
                  const SizedBox(height: 15),

                  // Warning Message with Icon
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: gold.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xfff7a900),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Warning!',
                                style: TextStyle(
                                  color: Color(0xfff7a900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your current game progress will be lost',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats Summary (Optional)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff1a0625),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.timer, "Time", "00:00"),
                        _buildStatItem(Icons.emoji_events, "Score", "0"),
                        _buildStatItem(Icons.people, "Turn", "1"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xff1a0625),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: gold, width: 1.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _exitAndCleanupGame,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff3bdc62),
                                    Color(0xff19a83e),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xff3bdc62,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Exit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _isExitDialogOpen = false;
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: gold.withOpacity(0.7), size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 10)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class TokenDisplay extends StatelessWidget {
  final Color color;

  const TokenDisplay({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 30),
      painter: TokenPainter(
        fillPaint: Paint()..color = color,
        borderPaint: Paint()
          ..color = Colors.black
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      ),
    );
  }
}

class TokenPainter extends CustomPainter {
  final Paint fillPaint;
  final Paint borderPaint;

  TokenPainter({required this.fillPaint, required this.borderPaint});

  @override
  void paint(Canvas canvas, Size size) {
    final outerRadius = size.width / 2;
    final smallerCircleRadius = outerRadius / 1.7;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(center, outerRadius, Paint()..color = Colors.white);
    canvas.drawCircle(center, outerRadius, borderPaint);
    canvas.drawCircle(center, smallerCircleRadius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlayArea extends RectangleComponent with HasGameReference<Ludo> {
  PlayArea() : super(children: [RectangleHitbox()]);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.width, game.height);
  }
}
