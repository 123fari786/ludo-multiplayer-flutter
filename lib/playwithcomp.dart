import 'package:flutter/material.dart';

import 'borad_game.dart'; // Add this import

class Playwithcomputer extends StatefulWidget {
  const Playwithcomputer({super.key});

  @override
  State<Playwithcomputer> createState() => _PlaywithcomputerState();
}

class _PlaywithcomputerState extends State<Playwithcomputer> {
  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);
  final Color cardPurple = const Color(0xff220033);

  // Player data
  final Map<String, dynamic> playerData = {
    'name': 'You',
    'coins': '1,250',
    'flag': '🇵🇰',
    'image': 'assets/avatar.png',
  };

  // Computer data
  final Map<String, dynamic> computerData = {
    'name': 'Computer',
    'coins': '5,000',
    'flag': '🤖',
    'image':
        'assets/robot.png', // You may need to add this asset or use an icon
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkPurple,
      body: Stack(
        children: [
          // ===================================================
          // BACKGROUND
          // ===================================================
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
                  // TOP HEADER
                  // ===================================================
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.smart_toy_rounded,
                                color: Color(0xfff7a900),
                                size: 20,
                              ),

                              const SizedBox(width: 8),

                              const Text(
                                "Play With Computer",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      _topButton(Icons.help_outline_rounded),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===================================================
                  // MAIN CARD
                  // ===================================================
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: cardPurple.withOpacity(.96),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: gold, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: gold.withOpacity(.15),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ===================================================
                            // IMAGE
                            // ===================================================
                            Image.asset(
                              'assets/playwithcomputer.png',
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),

                            const SizedBox(height: 10),

                            // ===================================================
                            // TITLE
                            // ===================================================
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xffffd54f),
                                    Color(0xfff7a900),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                "Choose Difficulty",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            const Text(
                              "Challenge the computer and test\nyour strategy skills!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ===================================================
                            // EASY BUTTON
                            // ===================================================
                            _difficultyCard(
                              icon: Icons.sentiment_very_satisfied_rounded,
                              title: "EASY",
                              subtitle: "Perfect for beginners\nand casual fun",
                              colors: const [
                                Color(0xff37d67a),
                                Color(0xff1fa855),
                              ],
                              difficulty: "easy",
                            ),

                            const SizedBox(height: 18),

                            // ===================================================
                            // HARD BUTTON
                            // ===================================================
                            _difficultyCard(
                              icon: Icons.local_fire_department_rounded,
                              title: "HARD",
                              subtitle: "For pro players\nand real masters",
                              colors: const [
                                Color(0xfff44336),
                                Color(0xffc62828),
                              ],
                              difficulty: "hard",
                            ),

                            const SizedBox(height: 24),

                            // ===================================================
                            // BOTTOM INFO
                            // ===================================================
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff2a0d42),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: gold.withOpacity(.4)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 38,
                                    width: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xfff7a900),
                                          Color(0xffffcb45),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.smart_toy_rounded,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  const Expanded(
                                    child: Text(
                                      "Play against intelligent AI opponents\nand improve your gameplay skills!",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        height: 1.5,
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
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // TOP BUTTON
  // ===============================================================

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

  // ===============================================================
  // DIFFICULTY CARD
  // ===============================================================

  Widget _difficultyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required String difficulty,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to board game with computer opponent
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => BoradGame(
        //       playerName: playerData['name'] as String,
        //       playerCoins: playerData['coins'] as String,
        //       playerFlag: playerData['flag'] as String,
        //       playerImage: playerData['image'] as String,
        //       opponentName: computerData['name'] as String,
        //       opponentCoins: computerData['coins'] as String,
        //       opponentFlag: computerData['flag'] as String,
        //       opponentImage: computerData['image'] as String,
        //       isComputerGame: true,
        //       difficulty: difficulty,
        //     ),
        //   ),
        // );
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff5c1b84), Color(0xff2b0d42)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: gold, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(.18),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            // ===================================================
            // ICON CONTAINER
            // ===================================================
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),

            const SizedBox(width: 16),

            // ===================================================
            // TEXT
            // ===================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: .8,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ===================================================
            // ARROW BUTTON
            // ===================================================
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
