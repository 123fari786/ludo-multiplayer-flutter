import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ludo_game/login.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starAnimations;
  late List<Offset> _starPositions;
  late List<double> _starSizes;
  final Random _random = Random();

  // Updated list with SOLID and ATTRACTIVE background colors per page
  final List<OnboardingData> _pages = [
    OnboardingData(
      title: "WELCOME BACK,\nCHAMPION!",
      subtitle:
          "Re-engage & Win, Champion!\nChallenge your best buddies in exclusive, high-stakes tournaments.",
      centerImageAsset: "assets/dice.png",
      primaryColor: const Color(0xFF6A1B9A), // Deep Purple
      solidBgColor: const Color(0xFF4A148C), // Solid Rich Purple
    ),
    OnboardingData(
      title: "EARN COINS!",
      subtitle:
          "Play Ludo Friends Club and accumulate in-game gold.\nReal-time Multiplayer! Join a table to compete for the highest stacks of coins.",
      centerImageAsset: "assets/freinds.png",
      primaryColor: const Color(0xFFFF8C00), // Deep Orange
      solidBgColor: const Color(0xFFE65100), // Solid Vibrant Orange
    ),
    OnboardingData(
      title: "REAL-TIME\nMULTIPLAYER",
      subtitle:
          "Play against players from around the world!\nJoin a table and connect with friends or random opponents instantly.",
      centerImageAsset: "assets/realtime.png",
      primaryColor: const Color(0xFF00BFFF), // Deep Sky Blue
      solidBgColor: const Color(0xFF0097A7), // Solid Teal/Blue
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _starControllers = List.generate(
      8,
      (_) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 700 + _random.nextInt(900)),
      )..repeat(reverse: true),
    );

    _starAnimations = _starControllers
        .map(
          (c) => Tween<double>(
            begin: 0.8,
            end: 1.25,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    _generateRandomPositions();
  }

  void _generateRandomPositions() {
    _starPositions = List.generate(
      8,
      (_) => Offset(
        0.05 + _random.nextDouble() * 0.9,
        0.05 + _random.nextDouble() * 0.85,
      ),
    );

    _starSizes = List.generate(8, (_) => 28.0 + _random.nextInt(48));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    for (var c in _starControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _pages[_currentPage];

    return Scaffold(
      body: Container(
        // SOLID BACKGROUND COLOR (Attractive and solid as requested)
        color: data.solidBgColor,
        child: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _generateRandomPositions();
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;

        return Stack(
          children: [
            // Background Stars (using ORIGINAL star.png WITHOUT any color filter)
            ...List.generate(8, (index) {
              return Positioned(
                left:
                    _starPositions[index].dx * width - (_starSizes[index] / 2),
                top:
                    _starPositions[index].dy * height - (_starSizes[index] / 2),
                child: ScaleTransition(
                  scale: _starAnimations[index],
                  child: Image.asset(
                    'assets/star.png',
                    height: _starSizes[index],
                    width: _starSizes[index],
                    // NO color parameter here -> keeps original star colors
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              );
            }),

            // Main Content
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.07),
              child: Column(
                children: [
                  SizedBox(height: height * 0.04),

                  // Top Icons (slightly adjusted colors to pop against solid bg)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTopIcon(
                        Icons.people_rounded,
                        const Color(0xFFD4AF37), // Gold for contrast
                      ),
                      _buildTopIcon(
                        Icons.monetization_on_rounded,
                        const Color(0xFFFFD700),
                      ),
                      _buildTopIcon(
                        Icons.sports_esports_rounded,
                        const Color(0xFFFF6B6B),
                      ),
                    ],
                  ),

                  SizedBox(height: height * 0.05),

                  // Center Image with 3D Effect
                  ScaleTransition(
                    scale: _bounceAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 25),
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 35,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        data.centerImageAsset,
                        height: height * 0.27,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            size: height * 0.27,
                            color: Colors.white70,
                          );
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: height * 0.04),

                  // Title with Golden Stroke (enhanced for solid backgrounds)
                  _buildTextWithStroke(data.title, fontSize: width * 0.082),

                  SizedBox(height: height * 0.025),

                  // Subtitle with better readability on solid colors
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      fontSize: width * 0.042,
                      height: 1.55,
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // Page Indicators (now with solid color friendly design)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: _currentPage == index ? 34 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _currentPage == index
                              ? const Color(0xFFFFD700)
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: height * 0.04),

                  // Get Started / Next Button (enhanced glow effect)
                  GestureDetector(
                    onTap: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.easeInOutCubic,
                        );
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: height * 0.075,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.7),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? "NEXT →"
                              : "GET STARTED",
                          style: TextStyle(
                            fontSize: width * 0.052,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: height * 0.04),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextWithStroke(String text, {required double fontSize}) {
    final lines = text.split('\n');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: lines
          .map(
            (line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Stack(
                children: [
                  // Stroke (white for better contrast on solid backgrounds)
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = fontSize * 0.09
                        ..color = Colors.white.withOpacity(0.95),
                    ),
                  ),
                  // Golden Fill with enhanced gradient
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [
                            Color(0xFFFFF176),
                            Color(0xFFFFD700),
                            Color(0xFFFFA500),
                            Color(0xFFFF8C00),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(Rect.fromLTWH(0, 0, 400, 100)),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTopIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 12),
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
        ],
      ),
      child: Icon(icon, size: 28, color: color),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String centerImageAsset;
  final Color primaryColor; // kept for reference if needed
  final Color solidBgColor; // new field for solid background

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.centerImageAsset,
    required this.primaryColor,
    required this.solidBgColor,
  });
}
