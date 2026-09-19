// import 'dart:math';

// import 'package:flutter/material.dart';

// enum GameState { rolling, moving, waiting }

// class BoradGame extends StatefulWidget {
//   // Add these parameters to receive player data
//   final String playerName;
//   final String playerCoins;
//   final String playerFlag;
//   final String playerImage;
//   final String opponentName;
//   final String opponentCoins;
//   final String opponentFlag;
//   final String opponentImage;
//   final bool isComputerGame;
//   final String difficulty;

//   const BoradGame({
//     super.key,
//     required this.playerName,
//     required this.playerCoins,
//     required this.playerFlag,
//     required this.playerImage,
//     required this.opponentName,
//     required this.opponentCoins,
//     required this.opponentFlag,
//     required this.opponentImage,
//     this.isComputerGame = false,
//     this.difficulty = "easy",
//   });

//   @override
//   State<BoradGame> createState() => _BoradGameState();
// }

// class _BoradGameState extends State<BoradGame> {
//   int _diceResult = 1;
//   bool _isRolling = false;
//   bool _isYourTurn = true;
//   bool _isComputerThinking = false;

//   GameState _gameState = GameState.waiting;

//   // ==================== DICE ====================

//   void rollDice() {
//     if (_isRolling || _gameState == GameState.moving || _isComputerThinking)
//       return;

//     // If it's computer's turn in computer game, don't allow rolling
//     if (widget.isComputerGame && !_isYourTurn) {
//       _showSnackBar("Wait for computer's turn!", Colors.orange);
//       return;
//     }

//     setState(() {
//       _isRolling = true;
//       _gameState = GameState.rolling;
//     });

//     Future.delayed(const Duration(milliseconds: 900), () {
//       final random = Random();
//       int newResult = random.nextInt(6) + 1;

//       setState(() {
//         _diceResult = newResult;
//         _isRolling = false;
//         _gameState = GameState.waiting;
//       });

//       _handleDiceResult(newResult);
//     });
//   }

//   void _handleDiceResult(int result) {
//     if (result == 6) {
//       _showSnackBar("🎲 You got 6! Extra turn!", Colors.green);
//     } else {
//       setState(() {
//         _isYourTurn = !_isYourTurn;
//       });

//       String nextPlayer = _isYourTurn
//           ? "Your Turn"
//           : (widget.isComputerGame ? "Computer's Turn" : "Opponent's Turn");

//       _showSnackBar("🎲 You got $result! $nextPlayer", Colors.orange);

//       // If it's computer game and now computer's turn, trigger computer move
//       if (widget.isComputerGame && !_isYourTurn) {
//         _computerMove();
//       }
//     }
//   }

//   void _computerMove() {
//     if (!widget.isComputerGame || _isYourTurn) return;

//     _isComputerThinking = true;
//     _showSnackBar("🤖 Computer is thinking...", Colors.purple);

//     // Add delay for computer "thinking"
//     Future.delayed(const Duration(milliseconds: 1500), () {
//       if (mounted && !_isYourTurn) {
//         final random = Random();
//         int computerDice = random.nextInt(6) + 1;

//         // Adjust difficulty
//         if (widget.difficulty == "hard") {
//           // Hard mode: computer gets better rolls (3-6)
//           computerDice = 3 + random.nextInt(4);
//         }

//         setState(() {
//           _diceResult = computerDice;
//           _isComputerThinking = false;
//         });

//         _handleComputerDiceResult(computerDice);
//       }
//     });
//   }

//   void _handleComputerDiceResult(int result) {
//     if (result == 6) {
//       _showSnackBar("🤖 Computer got 6! Extra turn!", Colors.red);
//       // Computer gets another turn
//       Future.delayed(const Duration(milliseconds: 1000), () {
//         if (mounted && !_isYourTurn) {
//           _computerMove();
//         }
//       });
//     } else {
//       setState(() {
//         _isYourTurn = !_isYourTurn;
//       });
//       _showSnackBar("🤖 Computer got $result! Your Turn!", Colors.green);
//     }
//   }

//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xff160021),
//       body: Stack(
//         children: [
//           Positioned.fill(
//             child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
//           ),

//           SafeArea(
//             child: Column(
//               children: [
//                 const SizedBox(height: 10),

//                 // ==================== TOP BAR ====================
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 14),
//                   child: Row(
//                     children: [
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.pop(context);
//                         },
//                         child: _topButton(Icons.arrow_back_ios_new_rounded),
//                       ),
//                       const Spacer(),
//                       SizedBox(
//                         height: 60,
//                         child: Image.asset(
//                           "assets/ludo.png",
//                           fit: BoxFit.contain,
//                         ),
//                       ),
//                       const Spacer(),
//                       _topButton(Icons.settings_rounded),
//                     ],
//                   ),
//                 ),

//                 const SizedBox(height: 18),

//                 // ==================== PLAYER CARDS (UPDATED WITH DATA) ====================
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 14),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: _playerCard(
//                           title: widget.playerName,
//                           color: Colors.red,
//                           isActive: _isYourTurn,
//                           coins: widget.playerCoins,
//                           flag: widget.playerFlag,
//                           image: widget.playerImage,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       const Text(
//                         "VS",
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 24,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: _playerCard(
//                           title: widget.opponentName,
//                           color: Colors.green,
//                           isActive: !_isYourTurn,
//                           coins: widget.opponentCoins,
//                           flag: widget.opponentFlag,
//                           image: widget.opponentImage,
//                           isComputer: widget.isComputerGame,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 const SizedBox(height: 16),

//                 // ==================== TURN INDICATOR ====================
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 24,
//                     vertical: 10,
//                   ),
//                   decoration: BoxDecoration(
//                     color: const Color(0xff2a063e),
//                     borderRadius: BorderRadius.circular(30),
//                     border: Border.all(
//                       color: const Color(0xfff7a900),
//                       width: 1.5,
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       CircleAvatar(
//                         radius: 6,
//                         backgroundColor: _isYourTurn
//                             ? const Color(0xfff7c42b)
//                             : Colors.grey,
//                       ),
//                       const SizedBox(width: 12),
//                       Text(
//                         _isYourTurn
//                             ? "${widget.playerName}'s Turn"
//                             : (widget.isComputerGame
//                                   ? "Computer's Turn"
//                                   : "${widget.opponentName}'s Turn"),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                       ),
//                       if (_isComputerThinking && !_isYourTurn) ...[
//                         const SizedBox(width: 10),
//                         const SizedBox(
//                           height: 16,
//                           width: 16,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             valueColor: AlwaysStoppedAnimation<Color>(
//                               Color(0xfff7a900),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),

//                 const SizedBox(height: 16),

//                 // ==================== BOARD ====================
//                 Expanded(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 10),
//                     child: LudoBoard(),
//                   ),
//                 ),

//                 const SizedBox(height: 16),

//                 // ==================== BOTTOM CONTROLS ====================
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Flexible(
//                         flex: 1,
//                         child: GestureDetector(
//                           onTap: () {
//                             _showSnackBar(
//                               "Undo feature coming soon!",
//                               Colors.grey,
//                             );
//                           },
//                           child: _bottomIcon(Icons.undo_rounded, "Undo"),
//                         ),
//                       ),

//                       const SizedBox(width: 8),

//                       Flexible(
//                         flex: 3,
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             // ==================== DICE ====================
//                             GestureDetector(
//                               onTap: !_isRolling && !_isComputerThinking
//                                   ? rollDice
//                                   : null,
//                               child: Container(
//                                 height: 102,
//                                 width: 102,
//                                 decoration: BoxDecoration(
//                                   color: const Color(0xff2b0b44),
//                                   borderRadius: BorderRadius.circular(26),
//                                   border: Border.all(
//                                     color: !_isRolling && !_isComputerThinking
//                                         ? const Color(0xfff7a900)
//                                         : Colors.grey,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 child: Center(
//                                   child: _isRolling
//                                       ? Image.asset(
//                                           'assets/draw.gif',
//                                           height: 68,
//                                           fit: BoxFit.contain,
//                                           errorBuilder:
//                                               (context, error, stackTrace) {
//                                                 return const Icon(
//                                                   Icons.casino,
//                                                   size: 50,
//                                                   color: Colors.white,
//                                                 );
//                                               },
//                                         )
//                                       : Image.asset(
//                                           'assets/$_diceResult.png',
//                                           height: 68,
//                                           fit: BoxFit.contain,
//                                           errorBuilder:
//                                               (context, error, stackTrace) {
//                                                 return Text(
//                                                   '$_diceResult',
//                                                   style: const TextStyle(
//                                                     fontSize: 40,
//                                                     color: Colors.white,
//                                                   ),
//                                                 );
//                                               },
//                                         ),
//                                 ),
//                               ),
//                             ),

//                             const SizedBox(height: 10),

//                             // ==================== ROLL BUTTON ====================
//                             GestureDetector(
//                               onTap: !_isRolling && !_isComputerThinking
//                                   ? rollDice
//                                   : null,
//                               child: Container(
//                                 height: 52,
//                                 decoration: BoxDecoration(
//                                   gradient: !_isRolling && !_isComputerThinking
//                                       ? const LinearGradient(
//                                           colors: [
//                                             Color(0xfff7a900),
//                                             Color(0xffffd34d),
//                                           ],
//                                         )
//                                       : const LinearGradient(
//                                           colors: [
//                                             Color(0xff666666),
//                                             Color(0xff888888),
//                                           ],
//                                         ),
//                                   borderRadius: BorderRadius.circular(18),
//                                 ),
//                                 child: const Center(
//                                   child: Text(
//                                     "ROLL DICE",
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.w900,
//                                       fontSize: 19,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),

//                       const SizedBox(width: 8),

//                       Flexible(
//                         flex: 1,
//                         child: GestureDetector(
//                           onTap: () {
//                             _showSnackBar(
//                               "Hint: Roll dice and move your pawns!",
//                               Colors.blue,
//                             );
//                           },
//                           child: _bottomIcon(Icons.lightbulb_rounded, "Hint"),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ==================== TOP BUTTON ====================

//   Widget _topButton(IconData icon) {
//     return Container(
//       height: 48,
//       width: 48,
//       decoration: BoxDecoration(
//         color: const Color(0xff2b0b44),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xfff7a900)),
//       ),
//       child: Icon(icon, color: Colors.white, size: 26),
//     );
//   }

//   // ==================== PLAYER CARD (UPDATED WITH DATA) ====================

//   Widget _playerCard({
//     required String title,
//     required Color color,
//     required bool isActive,
//     required String coins,
//     required String flag,
//     required String image,
//     bool isComputer = false,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: const Color(0xff2a063e),
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(
//           color: isActive ? const Color(0xfff7c42b) : color,
//           width: isActive ? 3 : 2,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           CircleAvatar(
//             radius: 16,
//             backgroundColor: Colors.white,
//             backgroundImage: isComputer ? null : AssetImage(image),
//             child: isComputer
//                 ? const Icon(
//                     Icons.smart_toy_rounded,
//                     color: Colors.green,
//                     size: 20,
//                   )
//                 : null,
//           ),

//           const SizedBox(width: 6),

//           Flexible(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 10,
//                   ),
//                 ),

//                 const SizedBox(height: 2),

//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(flag, style: const TextStyle(fontSize: 10)),
//                     const SizedBox(width: 2),
//                     const Icon(
//                       Icons.stars_rounded,
//                       color: Color(0xfff7a900),
//                       size: 10,
//                     ),
//                     const SizedBox(width: 1),
//                     Flexible(
//                       child: Text(
//                         coins,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(
//                           color: Color(0xfff7a900),
//                           fontWeight: FontWeight.bold,
//                           fontSize: 9,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ==================== BOTTOM ICON ====================

//   Widget _bottomIcon(IconData icon, String text) {
//     return Container(
//       height: 82,
//       width: 68,
//       decoration: BoxDecoration(
//         color: const Color(0xff2b0b44),
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: const Color(0xfff7a900)),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, color: Colors.white, size: 32),
//           const SizedBox(height: 4),
//           Text(
//             text,
//             style: const TextStyle(color: Colors.white, fontSize: 12.5),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ==================== SEPARATE LUDO BOARD WIDGET ====================

// class LudoBoard extends StatelessWidget {
//   const LudoBoard({super.key});

//   static const Color red = Color(0xFFE53935);
//   static const Color green = Color(0xFF43A047);
//   static const Color blue = Color(0xFF1E88E5);
//   static const Color yellow = Color(0xFFFDD835);

//   static const int gridSize = 15;

//   @override
//   Widget build(BuildContext context) {
//     return AspectRatio(
//       aspectRatio: 1,
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           final cellSize = constraints.maxWidth / gridSize;

//           return Stack(
//             children: [
//               /// BASE GRID
//               Column(
//                 children: List.generate(
//                   gridSize,
//                   (row) => Row(
//                     children: List.generate(
//                       gridSize,
//                       (col) => PathCell(
//                         size: cellSize,
//                         color: _getCellColor(row, col),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               /// HOME AREAS
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 child: HomeArea(size: cellSize * 6, color: red),
//               ),

//               Positioned(
//                 top: 0,
//                 right: 0,
//                 child: HomeArea(size: cellSize * 6, color: green),
//               ),

//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 child: HomeArea(size: cellSize * 6, color: blue),
//               ),

//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: HomeArea(size: cellSize * 6, color: yellow),
//               ),

//               /// CENTER DIAMOND
//               Positioned(
//                 left: cellSize * 6,
//                 top: cellSize * 6,
//                 child: CustomPaint(
//                   size: Size(cellSize * 3, cellSize * 3),
//                   painter: CenterPainter(),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Color _getCellColor(int row, int col) {
//     /// RED HOME LANE
//     if (col == 7 && row > 0 && row < 6) {
//       return red;
//     }

//     /// GREEN HOME LANE
//     if (row == 7 && col > 8 && col < 14) {
//       return green;
//     }

//     /// BLUE HOME LANE
//     if (col == 7 && row > 8 && row < 14) {
//       return blue;
//     }

//     /// YELLOW HOME LANE
//     if (row == 7 && col > 0 && col < 6) {
//       return yellow;
//     }

//     /// SAFE WHITE PATHS
//     if (_isPathCell(row, col)) {
//       return Colors.white;
//     }

//     /// HIDDEN UNDER HOME AREAS
//     return Colors.white;
//   }

//   bool _isPathCell(int row, int col) {
//     return
//     /// Vertical path
//     (col >= 6 && col <= 8) ||
//         /// Horizontal path
//         (row >= 6 && row <= 8);
//   }
// }

// class HomeArea extends StatelessWidget {
//   final double size;
//   final Color color;

//   const HomeArea({super.key, required this.size, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       color: color,
//       padding: EdgeInsets.all(size * 0.12),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border.all(color: Colors.black54, width: 1.5),
//         ),
//         child: Padding(
//           padding: EdgeInsets.all(size * 0.12),
//           child: GridView.count(
//             physics: const NeverScrollableScrollPhysics(),
//             crossAxisCount: 2,
//             mainAxisSpacing: size * 0.12,
//             crossAxisSpacing: size * 0.12,
//             children: List.generate(4, (_) => TokenWidget(color: color)),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class TokenWidget extends StatelessWidget {
//   final Color color;

//   const TokenWidget({super.key, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: color,
//         border: Border.all(color: Colors.black87, width: 1.2),
//         boxShadow: const [
//           BoxShadow(blurRadius: 4, offset: Offset(1, 2), color: Colors.black26),
//         ],
//       ),
//     );
//   }
// }

// class PathCell extends StatelessWidget {
//   final double size;
//   final Color color;

//   const PathCell({super.key, required this.size, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: color,
//         border: Border.all(color: Colors.black54, width: 0.6),
//       ),
//     );
//   }
// }

// class CenterPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint();

//     final center = Offset(size.width / 2, size.height / 2);

//     /// RED TRIANGLE
//     paint.color = const Color(0xFFE53935);

//     final redPath = Path()
//       ..moveTo(center.dx, center.dy)
//       ..lineTo(0, 0)
//       ..lineTo(size.width, 0)
//       ..close();

//     canvas.drawPath(redPath, paint);

//     /// GREEN TRIANGLE
//     paint.color = const Color(0xFF43A047);

//     final greenPath = Path()
//       ..moveTo(center.dx, center.dy)
//       ..lineTo(size.width, 0)
//       ..lineTo(size.width, size.height)
//       ..close();

//     canvas.drawPath(greenPath, paint);

//     /// YELLOW TRIANGLE
//     paint.color = const Color(0xFFFDD835);

//     final yellowPath = Path()
//       ..moveTo(center.dx, center.dy)
//       ..lineTo(0, size.height)
//       ..lineTo(size.width, size.height)
//       ..close();

//     canvas.drawPath(yellowPath, paint);

//     /// BLUE TRIANGLE
//     paint.color = const Color(0xFF1E88E5);

//     final bluePath = Path()
//       ..moveTo(center.dx, center.dy)
//       ..lineTo(0, 0)
//       ..lineTo(0, size.height)
//       ..close();

//     canvas.drawPath(bluePath, paint);

//     /// CENTER BORDER
//     final borderPaint = Paint()
//       ..color = Colors.black54
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1;

//     canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return false;
//   }
// }
