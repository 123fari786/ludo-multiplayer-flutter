import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ludo_game/FirstMainscreen.dart';
import 'package:ludo_game/play_with_online/firebase_service.dart';
import 'package:ludo_game/play_with_online/matchmaking_service.dart';

class PlayWithOnline extends StatefulWidget {
  const PlayWithOnline({super.key});

  @override
  State<PlayWithOnline> createState() => _PlayWithOnlineState();
}

class _PlayWithOnlineState extends State<PlayWithOnline>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  bool? _isPlayer1;
  bool opponentFound = false;
  bool isSearching = false;
  String? waitingId;
  Map<String, dynamic>? opponentData;
  String? matchId;
  Map<String, dynamic>? matchData;

  final FirebaseService _firebase = FirebaseService();
  final MatchmakingService _matchmaking = MatchmakingService();
  bool _isStartingGame = false;
  Timer? _searchTimer;
  static const int searchTimeoutSeconds = 120;

  Map<String, dynamic> playerData = {
    'name': '',
    'coins': '0',
    'flag': '🇵🇰',
    'color': Colors.red,
    'image': 'assets/avatar.png',
  };

  static const int minEntryFee = 10;
  static const int entryFeeStep = 1;

  int entryFee = minEntryFee;

  int get winPrize => entryFee + (entryFee ~/ 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadUserData();
    _cleanupExistingWaitingRoom();

    debugPrint('========== PLAY WITH ONLINE SCREEN LOADED ==========');
    debugPrint('Entry Fee: $entryFee coins');
  }

  void _showDepositFirstDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff2a0540), Color(0xff180128)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xfff7a900), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Color(0xfff7a900),
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                "Kindly Deposit First",
                style: TextStyle(
                  color: Color(0xfff7a900),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You need at least $entryFee coins to start this match.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 35,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cleanupSearch();
    }
  }

  Future<void> _cleanupExistingWaitingRoom() async {
    try {
      String? userId = _firebase.currentUserId;
      if (userId != null) {
        bool isInWaiting = await _firebase.isUserInWaitingRoom(userId);
        if (isInWaiting) {
          debugPrint(
            '🧹 Cleaning up existing waiting room entry for user: $userId',
          );
          await _firebase.cleanUserWaitingEntry(userId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error cleaning waiting room: $e');
    }
  }

  Future<void> _cleanupSearch() async {
    if (waitingId != null) {
      debugPrint('🧹 Cleaning up search with waitingId: $waitingId');
      await _matchmaking.cancelSearch(waitingId!);
      waitingId = null;
    }
    if (_searchTimer != null && _searchTimer!.isActive) {
      _searchTimer!.cancel();
      _searchTimer = null;
    }
    _matchmaking.dispose();
  }

  Future<void> _loadUserData() async {
    debugPrint('📱 Loading user data...');
    String? userId = _firebase.currentUserId;
    if (userId != null) {
      debugPrint('✅ User ID: $userId');
      Map<String, dynamic>? userData = await _firebase.getUserData(userId);
      if (userData != null) {
        setState(() {
          playerData = {
            'name': '${userData['firstName']} ${userData['lastName']}',
            'coins': userData['coins'].toString(),
            'flag': '🇵🇰',
            'color': Colors.red,
            'image': 'assets/avatar.png',
          };
        });
        debugPrint('💰 User Coins: ${playerData['coins']}');
        debugPrint('👤 User Name: ${playerData['name']}');
      } else {
        debugPrint('❌ User data not found in Firestore');
      }
    } else {
      debugPrint('❌ No user logged in');
    }
  }

  void _startSearchTimer() {
    debugPrint(
      '⏱️ Starting search timeout timer: $searchTimeoutSeconds seconds',
    );
    _searchTimer = Timer(Duration(seconds: searchTimeoutSeconds), () {
      if (mounted && isSearching) {
        debugPrint('⚠️ SEARCH TIMEOUT! No opponent found');
        _showToastMessage(
          "No opponent found after 2 minutes. Please try again.",
          isError: true,
        );
        _cancelSearch();
      }
    });
  }

  void _cancelSearchTimer() {
    if (_searchTimer != null && _searchTimer!.isActive) {
      debugPrint('⏹️ Cancelling search timeout timer');
      _searchTimer!.cancel();
      _searchTimer = null;
    }
  }

  Future<void> _startSearching() async {
    if (isSearching) {
      debugPrint('⚠️ Already searching, ignoring duplicate request');
      return;
    }

    await _cleanupExistingWaitingRoom();

    debugPrint('🔍 Starting opponent search...');
    setState(() {
      isSearching = true;
    });

    final String? userId = _firebase.currentUserId;
    if (userId == null) {
      setState(() {
        isSearching = false;
      });
      return;
    }

    final int currentCoins = await _firebase.getUserCoins(userId);

    if (!mounted) return;

    setState(() {
      playerData['coins'] = currentCoins.toString();
    });

    debugPrint(
      '💰 Fresh Play Online Coins Check: $currentCoins need: $entryFee',
    );

    if (currentCoins < entryFee) {
      debugPrint('❌ Insufficient coins!');
      _showDepositFirstDialog();

      setState(() {
        isSearching = false;
      });
      return;
    }

    _startSearchTimer();

    waitingId = await _matchmaking.startSearching(
      userId: userId,
      userName: playerData['name'],
      profileImage: playerData['image'],
      coins: currentCoins,
      entryFee: entryFee,
      onMatchFound: (matchData) {
        debugPrint('🎉 MATCH FOUND!');
        debugPrint('📊 Match ID: ${matchData['matchId']}');
        debugPrint('👥 Opponent: ${matchData['opponent']['userName']}');
        debugPrint('👑 Is Player 1: ${matchData['isPlayer1']}');

        final int matchedEntryFee =
            int.tryParse(matchData['entryFee']?.toString() ?? '') ?? entryFee;

        if (mounted) {
          _cancelSearchTimer();

          setState(() {
            opponentFound = true;
            isSearching = false;
            matchId = matchData['matchId'];
            opponentData = matchData['opponent'];
            _isPlayer1 = matchData['isPlayer1'];
            entryFee = matchedEntryFee < minEntryFee
                ? minEntryFee
                : matchedEntryFee;
            _controller.stop();
          });

          debugPrint('✅ Navigate to game board screen');
        }
      },
    );

    if (waitingId == null) {
      debugPrint('❌ Failed to start search');
      _showToastMessage(
        "Failed to start search. Please try again.",
        isError: true,
      );

      setState(() {
        isSearching = false;
      });

      _cancelSearchTimer();
    } else {
      debugPrint('✅ Added to waiting room. Waiting ID: $waitingId');
      debugPrint('🔄 Listening for opponent...');
    }
  }

  Future<void> _cancelSearch() async {
    debugPrint('🛑 Cancelling search...');
    _cancelSearchTimer();

    if (waitingId != null) {
      debugPrint('🗑️ Removing from waiting room: $waitingId');
      await _matchmaking.cancelSearch(waitingId!);
      waitingId = null;
    }

    await _cleanupExistingWaitingRoom();

    if (mounted) {
      setState(() {
        isSearching = false;
        opponentFound = false;
      });
      _controller.repeat();
    }
    debugPrint('✅ Search cancelled, back to start screen');
  }

  Future<void> _navigateToGameBoard() async {
    if (_isStartingGame) return;

    if (matchId == null || _isPlayer1 == null) return;

    setState(() {
      _isStartingGame = true;
    });

    try {
      debugPrint('🎮 Start Game clicked');

      final String currentPlayerId = _firebase.currentUserId!;
      final String opponentPlayerId = opponentData?['userId'] ?? '';

      final Map<String, dynamic>? currentMatchData = await _matchmaking
          .getMatchData(matchId!);

      final int matchEntryFee =
          int.tryParse(
            currentMatchData?['entryFee']?.toString() ?? entryFee.toString(),
          ) ??
          entryFee;

      final int matchWinPrize =
          int.tryParse(currentMatchData?['winPrize']?.toString() ?? '') ??
          (matchEntryFee + (matchEntryFee ~/ 2));

      debugPrint('🏆 Match win prize: $matchWinPrize coins');

      final bool deducted = await _firebase.deductEntryFeeOnceForMatch(
        matchId: matchId!,
        userId: currentPlayerId,
        entryFee: matchEntryFee,
      );

      if (!deducted) {
        debugPrint('❌ Entry fee not deducted. Stop navigation.');
        _showDepositFirstDialog();

        if (mounted) {
          final latestCoins = await _firebase.getUserCoins(currentPlayerId);
          setState(() {
            playerData['coins'] = latestCoins.toString();
            _isStartingGame = false;
          });
        }
        return;
      }

      debugPrint('✅ Entry fee deducted successfully');

      if (!mounted) return;

      if (currentMatchData != null) {
        final String player1Color = currentMatchData['player1Color'] ?? 'Red';
        final String player2Color =
            currentMatchData['player2Color'] ?? 'Yellow';

        final List<String> selectedTeams = [player1Color, player2Color];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameApp(
              selectedTeams: selectedTeams,
              isOnline: true,
              matchId: matchId!,
              currentPlayerId: currentPlayerId,
              opponentPlayerId: opponentPlayerId,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameApp(
              selectedTeams: _isPlayer1!
                  ? ['Red', 'Yellow']
                  : ['Yellow', 'Red'],
              isOnline: true,
              matchId: matchId!,
              currentPlayerId: currentPlayerId,
              opponentPlayerId: opponentPlayerId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Start game error: $e');

      if (mounted) {
        _showDepositFirstDialog();
        setState(() {
          _isStartingGame = false;
        });
      }
    }
  }

  void _showToastMessage(String message, {bool isError = false}) {
    debugPrint('📢 Toast: $message');

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error : Icons.info,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry?.remove());
  }

  @override
  void dispose() {
    debugPrint('♻️ Disposing PlayWithOnline screen');
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSearch();
    _controller.dispose();
    super.dispose();
  }

  // ==================== UI CODE (UNCHANGED) ====================
  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);
  final Color cardPurple = const Color(0xff220033);

  double get _scale {
    final size = MediaQuery.sizeOf(context);
    final widthScale = size.width / 390;
    final heightScale = size.height / 844;
    return min(widthScale, heightScale).clamp(0.72, 1.15).toDouble();
  }

  double _rs(num value) => value * _scale;

  Widget _fitStateContent(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(width: constraints.maxWidth, child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkPurple,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _rs(14)),
              child: Column(
                children: [
                  SizedBox(height: _rs(10)),
                  _topBar(),
                  SizedBox(height: _rs(22)),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: _rs(16),
                        vertical: _rs(18),
                      ),
                      decoration: BoxDecoration(
                        color: cardPurple.withOpacity(.95),
                        borderRadius: BorderRadius.circular(_rs(24)),
                        border: Border.all(color: gold, width: _rs(1.5)),
                      ),
                      child: _fitStateContent(
                        isSearching
                            ? _searchingUI()
                            : (opponentFound ? _opponentFoundUI() : _startUI()),
                      ),
                    ),
                  ),
                  SizedBox(height: _rs(14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            debugPrint('🔙 Back button pressed');

            await _cleanupSearch();

            if (!mounted) return;

            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: _topButton(Icons.arrow_back_ios_new_rounded),
        ),
        SizedBox(width: _rs(10)),
        Expanded(
          child: Container(
            height: _rs(42),
            decoration: BoxDecoration(
              color: const Color(0xff2d0b44),
              borderRadius: BorderRadius.circular(_rs(14)),
              border: Border.all(color: gold, width: _rs(1.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/dunyia.png', height: _rs(22)),
                SizedBox(width: _rs(8)),
                Text(
                  "Play Online",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: _rs(15),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: _rs(10)),
        _coinBox(),
      ],
    );
  }

  Widget _titlePill({required IconData icon, required String title}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _rs(14), vertical: _rs(8)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xfff7a900), Color(0xffffcb45)],
        ),
        borderRadius: BorderRadius.circular(_rs(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black, size: _rs(18)),
          SizedBox(width: _rs(8)),
          Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: _rs(13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _titlePill(icon: Icons.games, title: "ONLINE MATCH"),
        SizedBox(height: _rs(30)),
        Image.asset('assets/pawn.png', height: _rs(100)),
        SizedBox(height: _rs(30)),
        Container(
          padding: EdgeInsets.all(_rs(16)),
          decoration: BoxDecoration(
            color: const Color(0xff2a0d42),
            borderRadius: BorderRadius.circular(_rs(18)),
            border: Border.all(color: gold.withOpacity(.35)),
          ),
          child: Column(
            children: [
              _entryFeeSelector(),
              SizedBox(height: _rs(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Win Prize:",
                    style: TextStyle(color: Colors.white70, fontSize: _rs(14)),
                  ),
                  Row(
                    children: [
                      Image.asset('assets/coin.png', height: _rs(16)),
                      SizedBox(width: _rs(4)),
                      Text(
                        "$winPrize",
                        style: TextStyle(
                          color: const Color(0xfff7a900),
                          fontWeight: FontWeight.bold,
                          fontSize: _rs(14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: _rs(40)),
        GestureDetector(
          onTap: _startSearching,
          child: Container(
            height: _rs(55),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff3bdc62), Color(0xff19a83e)],
              ),
              borderRadius: BorderRadius.circular(_rs(16)),
            ),
            child: Center(
              child: Text(
                "FIND OPPONENT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: _rs(15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _entryFeeSelector() {
    return Container(
      height: _rs(48),
      padding: EdgeInsets.symmetric(horizontal: _rs(12)),
      decoration: BoxDecoration(
        color: const Color(0xff1e082d),
        borderRadius: BorderRadius.circular(_rs(14)),
        border: Border.all(color: gold.withOpacity(.55)),
      ),
      child: Row(
        children: [
          Text(
            "Entry Fee:",
            style: TextStyle(color: Colors.white70, fontSize: _rs(14)),
          ),
          const Spacer(),
          Image.asset('assets/coin.png', height: _rs(18)),
          SizedBox(width: _rs(5)),
          Text(
            "$entryFee",
            style: TextStyle(
              color: const Color(0xfff7a900),
              fontWeight: FontWeight.bold,
              fontSize: _rs(15),
            ),
          ),
          SizedBox(width: _rs(12)),
          _entryFeeButton(
            icon: Icons.remove,
            onTap: entryFee <= minEntryFee
                ? null
                : () {
                    setState(() {
                      entryFee -= entryFeeStep;
                    });
                  },
          ),
          SizedBox(width: _rs(8)),
          _entryFeeButton(
            icon: Icons.add,
            onTap: () {
              setState(() {
                entryFee += entryFeeStep;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _entryFeeButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final bool isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _rs(30),
        width: _rs(30),
        decoration: BoxDecoration(
          gradient: isDisabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xfff7a900), Color(0xffffcb45)],
                ),
          color: isDisabled ? Colors.white12 : null,
          borderRadius: BorderRadius.circular(_rs(10)),
          border: Border.all(
            color: isDisabled ? Colors.white24 : const Color(0xfff7a900),
          ),
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.white30 : Colors.black,
          size: _rs(18),
        ),
      ),
    );
  }

  Widget _searchingUI() {
    return Column(
      key: const ValueKey("searching"),
      mainAxisSize: MainAxisSize.min,
      children: [
        _titlePill(icon: Icons.people_alt_rounded, title: "ONLINE MATCH"),
        SizedBox(height: _rs(26)),
        Text(
          "Searching for opponents...",
          style: TextStyle(color: Colors.white70, fontSize: _rs(12)),
        ),
        SizedBox(height: _rs(10)),
        _SearchTimerWidget(
          duration: const Duration(seconds: searchTimeoutSeconds),
          scale: _scale,
          onTimerComplete: () {
            if (mounted && isSearching) {
              _showToastMessage(
                "No opponent found after 2 minutes. Please try again.",
                isError: true,
              );
              _cancelSearch();
            }
          },
        ),
        SizedBox(height: _rs(20)),
        _searchAnimation(),
        SizedBox(height: _rs(34)),
        Text(
          "Finding players...",
          style: TextStyle(
            color: const Color(0xfff7a900),
            fontSize: _rs(22),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: _rs(10)),
        Text(
          "Please wait while we find\nthe best match for you",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: _rs(12)),
        ),
        SizedBox(height: _rs(28)),
        _bottomStats(),
        SizedBox(height: _rs(28)),
        GestureDetector(
          onTap: _cancelSearch,
          child: Container(
            height: _rs(54),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff391154), Color(0xff26103d)],
              ),
              borderRadius: BorderRadius.circular(_rs(16)),
              border: Border.all(color: gold, width: _rs(1.2)),
            ),
            child: Center(
              child: Text(
                "CANCEL SEARCH",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: _rs(13),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _controller.value * 2 * pi,
              child: Container(
                height: _rs(190),
                width: _rs(190),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    startAngle: 0,
                    endAngle: 2 * pi,
                    colors: [
                      Colors.transparent,
                      Color(0xfff7a900),
                      Color(0xffffd54f),
                      Colors.orangeAccent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: -_controller.value * 2 * pi,
              child: Container(
                height: _rs(165),
                width: _rs(165),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gold.withOpacity(.25),
                    width: _rs(2),
                  ),
                ),
              ),
            ),
            Container(
              height: _rs(145),
              width: _rs(145),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xff34124d), Color(0xff1c062b)],
                ),
                border: Border.all(color: gold.withOpacity(.7), width: _rs(2)),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -_controller.value * 2 * pi,
                  child: Image.asset('assets/pawn.png', height: _rs(90)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _opponentFoundUI() {
    bool amIPlayer1 = _isPlayer1 ?? true;

    String myName = playerData['name'];
    String myCoins = playerData['coins'];
    String myImage = playerData['image'];
    String opponentName = opponentData?['userName'] ?? 'Opponent';
    String opponentCoins = opponentData?['coins'].toString() ?? '0';
    String opponentImage = opponentData?['profileImage'] ?? 'assets/avatar.png';

    return Column(
      key: const ValueKey("found"),
      mainAxisSize: MainAxisSize.min,
      children: [
        _titlePill(icon: Icons.people_alt_rounded, title: "ONLINE MATCH"),
        SizedBox(height: _rs(24)),
        Text(
          "Opponent Found!",
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: _rs(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: _rs(6)),
        Text(
          "Colors will be assigned automatically",
          style: TextStyle(color: Colors.white70, fontSize: _rs(11)),
        ),
        SizedBox(height: _rs(40)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _playerCard(
              image: amIPlayer1 ? myImage : opponentImage,
              name: amIPlayer1 ? myName : opponentName,
              coins: amIPlayer1 ? myCoins : opponentCoins,
              flag: '🇵🇰',
              isYou: amIPlayer1,
              playerNumber: 1,
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xfff7a900), Color(0xffffd54f)],
              ).createShader(bounds),
              child: Text(
                "VS",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: _rs(40),
                ),
              ),
            ),
            _playerCard(
              image: amIPlayer1 ? opponentImage : myImage,
              name: amIPlayer1 ? opponentName : myName,
              coins: amIPlayer1 ? opponentCoins : myCoins,
              flag: '🇮🇳',
              isYou: !amIPlayer1,
              playerNumber: 2,
            ),
          ],
        ),
        SizedBox(height: _rs(30)),
        Container(
          padding: EdgeInsets.all(_rs(14)),
          decoration: BoxDecoration(
            color: const Color(0xff2a0d42),
            borderRadius: BorderRadius.circular(_rs(18)),
            border: Border.all(color: gold.withOpacity(.35)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: const Color(0xfff7a900),
                    size: _rs(18),
                  ),
                  SizedBox(width: _rs(8)),
                  Text(
                    "Match Details",
                    style: TextStyle(
                      color: const Color(0xfff7a900),
                      fontWeight: FontWeight.bold,
                      fontSize: _rs(13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _rs(16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MatchInfo(
                    title: "Entry Fee",
                    value: "$entryFee Coins",
                    scale: _scale,
                  ),
                  _MatchInfo(
                    title: "Game Type",
                    value: "Classic",
                    scale: _scale,
                  ),
                  _MatchInfo(
                    title: "Win Prize",
                    value: "$winPrize Coins",
                    scale: _scale,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: _rs(34)),
        GestureDetector(
          onTap: _isStartingGame ? null : _navigateToGameBoard,
          child: Container(
            height: _rs(55),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff3bdc62), Color(0xff19a83e)],
              ),
              borderRadius: BorderRadius.circular(_rs(16)),
            ),
            child: Center(
              child: _isStartingGame
                  ? SizedBox(
                      width: _rs(24),
                      height: _rs(24),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      "START GAME",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: _rs(15),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playerCard({
    required String image,
    required String name,
    required String coins,
    required String flag,
    required bool isYou,
    required int playerNumber,
  }) {
    return Container(
      width: _rs(110),
      padding: EdgeInsets.symmetric(horizontal: _rs(8), vertical: _rs(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff5a1d7f), Color(0xff2a0d42)],
        ),
        borderRadius: BorderRadius.circular(_rs(20)),
        border: Border.all(color: const Color(0xfff7a900), width: _rs(1.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(_rs(3)),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xffffd54f), Color(0xfff7a900)],
              ),
            ),
            child: CircleAvatar(
              radius: _rs(32),
              backgroundImage: AssetImage(image),
            ),
          ),
          SizedBox(height: _rs(10)),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: _rs(10),
            ),
          ),
          SizedBox(height: _rs(8)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: _rs(8), vertical: _rs(5)),
            decoration: BoxDecoration(
              color: const Color(0xff1e082d),
              borderRadius: BorderRadius.circular(_rs(30)),
              border: Border.all(color: const Color(0xfff7a900)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: TextStyle(fontSize: _rs(11))),
                SizedBox(width: _rs(4)),
                Icon(
                  Icons.stars_rounded,
                  color: const Color(0xfff7a900),
                  size: _rs(13),
                ),
                SizedBox(width: _rs(3)),
                Text(
                  coins,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xfff7a900),
                    fontWeight: FontWeight.bold,
                    fontSize: _rs(9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: _rs(5)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: _rs(6), vertical: _rs(2)),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(_rs(10)),
            ),
            child: Text(
              "P$playerNumber",
              style: TextStyle(
                color: Colors.white70,
                fontSize: _rs(8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isYou) ...[
            SizedBox(height: _rs(3)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _rs(6),
                vertical: _rs(2),
              ),
              decoration: BoxDecoration(
                color: const Color(0xfff7a900).withOpacity(0.3),
                borderRadius: BorderRadius.circular(_rs(10)),
              ),
              child: Text(
                "YOU",
                style: TextStyle(
                  color: const Color(0xfff7a900),
                  fontSize: _rs(8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomStats() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _rs(14), horizontal: _rs(10)),
      decoration: BoxDecoration(
        color: const Color(0xff2a0d42),
        borderRadius: BorderRadius.circular(_rs(18)),
        border: Border.all(color: gold.withOpacity(.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoBox(
            icon: Icons.groups_rounded,
            title: "Players",
            value: "1,248",
            scale: _scale,
          ),
          _DividerLine(scale: _scale),
          _InfoBox(
            icon: Icons.access_time_rounded,
            title: "Estimate Time",
            value: "10 - 20s",
            scale: _scale,
          ),
          _DividerLine(scale: _scale),
          _InfoBox(
            icon: Icons.wifi_rounded,
            title: "Connection",
            value: "Good",
            scale: _scale,
          ),
        ],
      ),
    );
  }

  Widget _topButton(IconData icon) {
    return Container(
      height: _rs(38),
      width: _rs(38),
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(_rs(10)),
        border: Border.all(color: gold),
      ),
      child: Icon(icon, color: Colors.white, size: _rs(17)),
    );
  }

  Widget _coinBox() {
    return Container(
      height: _rs(38),
      constraints: BoxConstraints(minWidth: _rs(68)),
      padding: EdgeInsets.symmetric(horizontal: _rs(10)),
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(_rs(12)),
        border: Border.all(color: gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/coin.png', height: _rs(18)),
          SizedBox(width: _rs(5)),
          Text(
            playerData['coins'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: _rs(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTimerWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback onTimerComplete;
  final double scale;

  const _SearchTimerWidget({
    required this.duration,
    required this.onTimerComplete,
    this.scale = 1,
  });

  @override
  State<_SearchTimerWidget> createState() => _SearchTimerWidgetState();
}

class _SearchTimerWidgetState extends State<_SearchTimerWidget> {
  late Timer _timer;
  late Duration _remainingTime;

  double _s(num value) => value * widget.scale;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 1) {
        _timer.cancel();
        widget.onTimerComplete();
      } else {
        setState(
          () =>
              _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _s(16), vertical: _s(8)),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(_s(20)),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.redAccent, size: _s(18)),
          SizedBox(width: _s(8)),
          Text(
            'Time remaining: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.white70, fontSize: _s(12)),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double scale;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.value,
    this.scale = 1,
  });

  double _s(num value) => value * scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xfff7a900), size: _s(18)),
        SizedBox(height: _s(6)),
        Text(
          title,
          style: TextStyle(color: Colors.white60, fontSize: _s(9)),
        ),
        SizedBox(height: _s(5)),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: _s(11),
          ),
        ),
      ],
    );
  }
}

class _MatchInfo extends StatelessWidget {
  final String title;
  final String value;
  final double scale;

  const _MatchInfo({required this.title, required this.value, this.scale = 1});

  double _s(num value) => value * scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white60, fontSize: _s(9)),
        ),
        SizedBox(height: _s(6)),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xfff7a900),
            fontWeight: FontWeight.bold,
            fontSize: _s(10),
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  final double scale;

  const _DividerLine({this.scale = 1});

  double _s(num value) => value * scale;

  @override
  Widget build(BuildContext context) {
    return Container(height: _s(40), width: 1, color: Colors.white12);
  }
}
