// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:ludo_game/FirstMainscreen.dart';
// import 'package:ludo_game/play_with_online/firebase_service.dart';
// import 'package:ludo_game/play_with_online/matchmaking_service.dart';

// class OnlineColorSelectionScreen extends StatefulWidget {
//   final String matchId;
//   final String playerName;
//   final String opponentName;
//   final String playerImage;
//   final String opponentImage;

//   const OnlineColorSelectionScreen({
//     super.key,
//     required this.matchId,
//     required this.playerName,
//     required this.opponentName,
//     required this.playerImage,
//     required this.opponentImage,
//   });

//   @override
//   State<OnlineColorSelectionScreen> createState() =>
//       _OnlineColorSelectionScreenState();
// }

// class _OnlineColorSelectionScreenState extends State<OnlineColorSelectionScreen>
//     with WidgetsBindingObserver {
//   bool gameStarting = false;
//   bool _isLoading = true;
//   String? _errorMessage;
//   String? myPlayerId;
//   String? opponentPlayerId;
//   String? myColor;
//   String? opponentColor;
//   String? currentTurn;

//   final MatchmakingService _matchmaking = MatchmakingService();
//   final FirebaseService _firebase = FirebaseService();
//   StreamSubscription? _matchSubscription;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _listenToMatch();

//     debugPrint('🎨 Color Selection Screen Loaded (Auto-assign)');
//     debugPrint('📋 Match ID: ${widget.matchId}');
//     debugPrint('👤 Player: ${widget.playerName}');
//     debugPrint('👥 Opponent: ${widget.opponentName}');
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       debugPrint('🔄 App resumed');
//     }
//   }

//   void _listenToMatch() {
//     _matchSubscription = _matchmaking.listenToMatch(widget.matchId).listen((
//       event,
//     ) {
//       if (event.snapshot.value != null && mounted) {
//         Map<String, dynamic> matchData = Map<String, dynamic>.from(
//           event.snapshot.value as Map,
//         );

//         debugPrint('📡 Match update received');
//         debugPrint('📊 Match Data: $matchData');

//         String currentUserId = _firebase.currentUserId!;

//         // Determine player roles
//         if (matchData['player1Id'] == currentUserId) {
//           myPlayerId = matchData['player1Id'];
//           opponentPlayerId = matchData['player2Id'];
//           myColor = matchData['player1Color'];
//           opponentColor = matchData['player2Color'];
//           debugPrint('✅ I am Player 1');
//         } else if (matchData['player2Id'] == currentUserId) {
//           myPlayerId = matchData['player2Id'];
//           opponentPlayerId = matchData['player1Id'];
//           myColor = matchData['player2Color'];
//           opponentColor = matchData['player1Color'];
//           debugPrint('✅ I am Player 2');
//         } else {
//           setState(() {
//             _errorMessage = "User not found in match. Please restart.";
//             _isLoading = false;
//           });
//           return;
//         }

//         currentTurn = matchData['currentTurn'];
//         String gameStatus = matchData['gameStatus'] ?? '';

//         debugPrint('🎨 My Color: $myColor');
//         debugPrint('🎨 Opponent Color: $opponentColor');
//         debugPrint('👑 Current Turn: $currentTurn');
//         debugPrint('📊 Game Status: $gameStatus');

//         setState(() {
//           _isLoading = false;
//         });

//         // Auto-start game when both colors are assigned and status is waiting_to_start
//         if (gameStatus == 'waiting_to_start' &&
//             myColor != null &&
//             opponentColor != null &&
//             myColor!.isNotEmpty &&
//             opponentColor!.isNotEmpty &&
//             !gameStarting) {
//           debugPrint('🎮 Both colors assigned! Auto-starting game...');
//           _startGame();
//         }
//       }
//     });
//   }

//   void _startGame() {
//     if (gameStarting) return;

//     debugPrint('🎮 Starting game...');
//     debugPrint('  My Color: $myColor');
//     debugPrint('  Opponent Color: $opponentColor');
//     debugPrint('  My Player ID: $myPlayerId');

//     setState(() {
//       gameStarting = true;
//     });

//     // Map color names to codes for GameApp
//     String myColorCode = _getColorCode(myColor ?? '');
//     String opponentColorCode = _getColorCode(opponentColor ?? '');

//     List<String> selectedTeams;
//     if (myPlayerId == _firebase.currentUserId) {
//       // Check if I am Player 1 or Player 2
//       // Need to check who is player1 in the match
//       _firebase.matchesRef.child(widget.matchId).once().then((snapshot) {
//         if (snapshot.snapshot.value != null) {
//           Map<String, dynamic> matchData = Map<String, dynamic>.from(
//             snapshot.snapshot.value as Map,
//           );
//           bool amIPlayer1 = matchData['player1Id'] == _firebase.currentUserId;

//           if (amIPlayer1) {
//             selectedTeams = [myColorCode, opponentColorCode];
//             debugPrint(
//               '📋 Teams order: [My Color (Player1), Opponent Color (Player2)]',
//             );
//           } else {
//             selectedTeams = [opponentColorCode, myColorCode];
//             debugPrint(
//               '📋 Teams order: [Opponent Color (Player1), My Color (Player2)]',
//             );
//           }

//           String currentPlayerIdForGame = _firebase.currentUserId!;
//           String opponentPlayerIdForGame = opponentPlayerId ?? '';

//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => GameApp(
//                 selectedTeams: selectedTeams,
//                 isOnline: true,
//                 matchId: widget.matchId,
//                 currentPlayerId: currentPlayerIdForGame,
//                 opponentPlayerId: opponentPlayerIdForGame,
//               ),
//             ),
//           );
//         }
//       });
//     }
//   }

//   String _getColorCode(String colorName) {
//     switch (colorName.toLowerCase()) {
//       case 'red':
//         return 'RP';
//       case 'blue':
//         return 'BP';
//       case 'green':
//         return 'GP';
//       case 'yellow':
//         return 'YP';
//       default:
//         return 'RP';
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _matchSubscription?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final gold = const Color(0xfff7a900);

//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: const Color(0xff160021),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const CircularProgressIndicator(color: Color(0xfff7a900)),
//               const SizedBox(height: 20),
//               Text(
//                 "Loading match data...",
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     if (_errorMessage != null) {
//       return Scaffold(
//         backgroundColor: const Color(0xff160021),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error, color: Colors.red, size: 50),
//               const SizedBox(height: 20),
//               Text(
//                 _errorMessage!,
//                 style: const TextStyle(color: Colors.white70, fontSize: 14),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: () {
//                   _matchSubscription?.cancel();
//                   Navigator.pop(context);
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: gold,
//                   foregroundColor: Colors.black,
//                 ),
//                 child: const Text("Go Back"),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: const Color(0xff160021),
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
//           ),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 14),
//               child: Column(
//                 children: [
//                   const SizedBox(height: 10),
//                   Row(
//                     children: [
//                       GestureDetector(
//                         onTap: () {
//                           debugPrint('🔙 Back button pressed');
//                           _matchSubscription?.cancel();
//                           if (mounted) {
//                             Navigator.pop(context);
//                           }
//                         },
//                         child: Container(
//                           height: 38,
//                           width: 38,
//                           decoration: BoxDecoration(
//                             color: const Color(0xff2d0b44),
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(color: gold),
//                           ),
//                           child: const Icon(
//                             Icons.arrow_back_ios_new_rounded,
//                             color: Colors.white,
//                             size: 17,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: Container(
//                           height: 42,
//                           decoration: BoxDecoration(
//                             color: const Color(0xff2d0b44),
//                             borderRadius: BorderRadius.circular(14),
//                             border: Border.all(color: gold, width: 1.2),
//                           ),
//                           child: const Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(
//                                 Icons.color_lens,
//                                 color: Color(0xfff7a900),
//                                 size: 20,
//                               ),
//                               SizedBox(width: 8),
//                               Flexible(
//                                 child: Text(
//                                   "Assigning Colors...",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: 15,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Container(
//                         height: 38,
//                         padding: const EdgeInsets.symmetric(horizontal: 10),
//                         decoration: BoxDecoration(
//                           color: const Color(0xff2d0b44),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: gold),
//                         ),
//                         child: Row(
//                           children: [
//                             Image.asset('assets/coin.png', height: 18),
//                             const SizedBox(width: 5),
//                             const Text(
//                               "50",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 22),
//                   Expanded(
//                     child: SingleChildScrollView(
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 18,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(0xff220033).withOpacity(.95),
//                           borderRadius: BorderRadius.circular(24),
//                           border: Border.all(color: gold, width: 1.5),
//                         ),
//                         child: Column(
//                           children: [
//                             // Status Display
//                             Container(
//                               padding: const EdgeInsets.all(16),
//                               decoration: BoxDecoration(
//                                 color: const Color(0xff2a0d42),
//                                 borderRadius: BorderRadius.circular(18),
//                                 border: Border.all(
//                                   color: gold.withOpacity(.35),
//                                 ),
//                               ),
//                               child: Column(
//                                 children: [
//                                   const Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(
//                                         Icons.info_outline,
//                                         color: Color(0xfff7a900),
//                                         size: 20,
//                                       ),
//                                       SizedBox(width: 8),
//                                       Text(
//                                         "Auto Color Assignment",
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 20),
//                                   Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment.spaceAround,
//                                     children: [
//                                       _ColorDisplay(
//                                         label: "Your Color",
//                                         colorName: myColor ?? 'Assigning...',
//                                         isReady:
//                                             myColor != null &&
//                                             myColor!.isNotEmpty,
//                                       ),
//                                       _ColorDisplay(
//                                         label: "Opponent Color",
//                                         colorName:
//                                             opponentColor ?? 'Assigning...',
//                                         isReady:
//                                             opponentColor != null &&
//                                             opponentColor!.isNotEmpty,
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 16),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 12,
//                                       vertical: 8,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: Colors.green.withOpacity(0.2),
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                     child: Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         if (myColor == null ||
//                                             opponentColor == null ||
//                                             myColor!.isEmpty ||
//                                             opponentColor!.isEmpty)
//                                           const SizedBox(
//                                             width: 16,
//                                             height: 16,
//                                             child: CircularProgressIndicator(
//                                               strokeWidth: 2,
//                                               color: Color(0xfff7a900),
//                                             ),
//                                           )
//                                         else
//                                           const Icon(
//                                             Icons.check_circle,
//                                             color: Colors.green,
//                                             size: 16,
//                                           ),
//                                         const SizedBox(width: 8),
//                                         Text(
//                                           myColor == null ||
//                                                   opponentColor == null ||
//                                                   myColor!.isEmpty ||
//                                                   opponentColor!.isEmpty
//                                               ? "Assigning colors..."
//                                               : "Colors assigned! Starting game...",
//                                           style: const TextStyle(
//                                             color: Colors.white70,
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 30),

//                             if (gameStarting) ...[
//                               Container(
//                                 padding: const EdgeInsets.all(16),
//                                 decoration: BoxDecoration(
//                                   color: Colors.green.withOpacity(0.2),
//                                   borderRadius: BorderRadius.circular(16),
//                                 ),
//                                 child: const Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     SizedBox(
//                                       width: 20,
//                                       height: 20,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                     SizedBox(width: 12),
//                                     Text(
//                                       "Starting game...",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ColorDisplay extends StatelessWidget {
//   final String label;
//   final String colorName;
//   final bool isReady;

//   const _ColorDisplay({
//     required this.label,
//     required this.colorName,
//     required this.isReady,
//   });

//   @override
//   Widget build(BuildContext context) {
//     Color displayColor = Colors.grey;
//     switch (colorName.toLowerCase()) {
//       case 'red':
//         displayColor = Colors.red;
//         break;
//       case 'blue':
//         displayColor = Colors.blue;
//         break;
//       case 'green':
//         displayColor = Colors.green;
//         break;
//       case 'yellow':
//         displayColor = Colors.yellow;
//         break;
//       default:
//         displayColor = Colors.grey;
//     }

//     return Column(
//       children: [
//         Text(
//           label,
//           style: const TextStyle(color: Colors.white60, fontSize: 11),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           width: 50,
//           height: 50,
//           decoration: BoxDecoration(
//             color: isReady ? displayColor : Colors.grey.withOpacity(0.3),
//             shape: BoxShape.circle,
//             border: Border.all(
//               color: isReady ? Colors.white : Colors.grey,
//               width: 2,
//             ),
//           ),
//           child: isReady
//               ? const Icon(Icons.check, color: Colors.white, size: 20)
//               : const SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Color(0xfff7a900),
//                   ),
//                 ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           isReady ? colorName : '...',
//           style: TextStyle(
//             color: isReady ? Colors.white : Colors.white54,
//             fontSize: 10,
//             fontWeight: isReady ? FontWeight.bold : FontWeight.normal,
//           ),
//         ),
//       ],
//     );
//   }
// }
