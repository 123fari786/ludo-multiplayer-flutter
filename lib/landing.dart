import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/dashborad.dart';
import 'package:ludo_game/login.dart';
import 'package:ludo_game/onborading.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InternetCheckResult {
  final bool isConnected;
  final int responseMilliseconds;

  const _InternetCheckResult({
    required this.isConnected,
    required this.responseMilliseconds,
  });
}

class Landingpage extends StatefulWidget {
  const Landingpage({super.key});

  @override
  State<Landingpage> createState() => _LandingpageState();
}

class _LandingpageState extends State<Landingpage>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  String _statusText = "Launching Ludo Dice...";

  late AnimationController _boardController;
  late Animation<double> _boardScaleAnimation;
  late Animation<double> _boardBounceAnimation;

  Timer? _progressTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Smooth floating board animation
    _boardController = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..repeat(reverse: true);

    _boardScaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _boardController, curve: Curves.easeInOutSine),
    );

    _boardBounceAnimation = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _boardController, curve: Curves.easeInOut),
    );

    _startLoading();
  }

  Future<void> _startLoading() async {
    if (_progress < 0.12) {
      await _animateProgressTo(
        0.12,
        duration: const Duration(milliseconds: 700),
      );
    }

    while (mounted && !_isNavigating) {
      setState(() {
        _statusText = "Checking Internet...";
      });

      final internetResult = await _checkInternetConnection();

      if (!mounted || _isNavigating) return;

      if (!internetResult.isConnected) {
        setState(() {
          _statusText = "No Internet Connection...";
        });

        // Stop progress here until internet comes back.
        if (_progress < 0.22) {
          await _animateProgressTo(
            0.22,
            duration: const Duration(milliseconds: 500),
          );
        }

        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      final Duration speedBasedDuration = _getSpeedBasedDuration(
        internetResult.responseMilliseconds,
      );

      setState(() {
        _statusText = "Internet Connected...";
      });

      await _animateProgressTo(0.48, duration: speedBasedDuration);

      setState(() {
        _statusText = "Syncing Game Data...";
      });

      final bool appReady = await _prepareAppBeforeNavigation();

      if (!mounted || _isNavigating) return;

      if (!appReady) {
        setState(() {
          _statusText = "Slow Connection. Retrying...";
        });

        if (_progress < 0.55) {
          await _animateProgressTo(
            0.55,
            duration: const Duration(milliseconds: 600),
          );
        }

        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      setState(() {
        _statusText = "Almost Ready...";
      });

      await _animateProgressTo(
        0.82,
        duration: Duration(
          milliseconds: (speedBasedDuration.inMilliseconds * 0.65).toInt(),
        ),
      );

      await _animateProgressTo(
        1.0,
        duration: Duration(
          milliseconds: (speedBasedDuration.inMilliseconds * 0.45)
              .clamp(350, 1300)
              .toInt(),
        ),
      );

      await _navigateToNextScreen();
      break;
    }
  }

  Future<_InternetCheckResult> _checkInternetConnection() async {
    final stopwatch = Stopwatch()..start();

    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 6));

      stopwatch.stop();

      final bool connected =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;

      return _InternetCheckResult(
        isConnected: connected,
        responseMilliseconds: stopwatch.elapsedMilliseconds,
      );
    } on SocketException {
      stopwatch.stop();
      return _InternetCheckResult(
        isConnected: false,
        responseMilliseconds: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      stopwatch.stop();
      return _InternetCheckResult(
        isConnected: false,
        responseMilliseconds: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      stopwatch.stop();
      return _InternetCheckResult(
        isConnected: false,
        responseMilliseconds: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Duration _getSpeedBasedDuration(int responseMilliseconds) {
    if (responseMilliseconds <= 450) {
      return const Duration(milliseconds: 650);
    } else if (responseMilliseconds <= 1300) {
      return const Duration(milliseconds: 1200);
    } else if (responseMilliseconds <= 3000) {
      return const Duration(milliseconds: 2100);
    } else {
      return const Duration(milliseconds: 3200);
    }
  }

  Future<bool> _prepareAppBeforeNavigation() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      // If user is logged in, reload checks Firebase with internet.
      // This prevents navigation when internet is not actually working.
      if (currentUser != null) {
        await currentUser.reload().timeout(const Duration(seconds: 8));
      }

      await SharedPreferences.getInstance().timeout(const Duration(seconds: 5));

      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return false;
      }

      // Other auth errors are not internet errors, so app can continue routing.
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _animateProgressTo(
    double targetProgress, {
    required Duration duration,
  }) async {
    _progressTimer?.cancel();

    if (!mounted) return;

    final double startProgress = _progress;
    final double endProgress = targetProgress < startProgress
        ? startProgress
        : targetProgress.clamp(0.0, 1.0);
    final int totalTicks = max(1, duration.inMilliseconds ~/ 30);
    int currentTick = 0;

    final Completer<void> completer = Completer<void>();

    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      currentTick++;
      final double tickValue = (currentTick / totalTicks).clamp(0.0, 1.0);
      final double easedValue = Curves.easeOutCubic.transform(tickValue);

      setState(() {
        _progress =
            startProgress + ((endProgress - startProgress) * easedValue);
      });

      if (tickValue >= 1.0) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });

    return completer.future;
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted || _isNavigating) return;

    _isNavigating = true;
    _progressTimer?.cancel();

    // Final safety check: if internet drops before navigation, stay on loading.
    final internetResult = await _checkInternetConnection();

    if (!mounted) return;

    if (!internetResult.isConnected) {
      _isNavigating = false;
      setState(() {
        _statusText = "No Internet Connection...";
        _progress = _progress > 0.96 ? 0.96 : _progress;
      });
      _startLoading();
      return;
    }

    // Check if user is already logged in
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // User is logged in - Directly go to Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
      );
    } else {
      // User is not logged in - Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (hasSeenOnboarding) {
        // User has seen onboarding before - Go to Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        // First time user - Show onboarding
        await prefs.setBool('hasSeenOnboarding', true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Onboarding()),
        );
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _boardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    final imageWidth = isTablet ? screenWidth * 0.57 : screenWidth * 0.78;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.6,
            colors: [
              Color(0xFFFF5500),
              Color(0xFFCC0000),
              Color(0xFF2C0033),
              Color(0xFF0F001A),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Enhanced Sunburst Background
            CustomPaint(
              size: Size.infinite,
              painter: EnhancedSunburstPainter(),
            ),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // LUDO Text
                  Text(
                    'LUDO',
                    style: TextStyle(
                      fontSize: isTablet ? 145 : 108,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 10,
                      height: 0.92,
                      shadows: const [
                        Shadow(
                          color: Color(0xFFFFE600),
                          blurRadius: 45,
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          color: Color(0xFFFFA500),
                          blurRadius: 30,
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 55,
                          offset: Offset(8, 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // DICE Text
                  Text(
                    'DICE',
                    style: TextStyle(
                      fontSize: isTablet ? 78 : 55,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFE600),
                      letterSpacing: 22,
                      height: 1.0,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 30,
                          offset: Offset(5, 10),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.045),

                  // Animated Ludo Board
                  AnimatedBuilder(
                    animation: _boardController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _boardBounceAnimation.value),
                        child: Transform.scale(
                          scale: _boardScaleAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.75),
                                  blurRadius: 70,
                                  offset: const Offset(0, 30),
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFE600,
                                  ).withOpacity(0.35),
                                  blurRadius: 50,
                                  offset: const Offset(0, -12),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/land.png',
                              width: imageWidth,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: screenHeight * 0.055),

                  // Loading Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        // Glowing Loading Bar
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.9),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFE600).withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFE600),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: isTablet ? 21 : 17.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: 3.5,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: isTablet ? 24 : 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFE600),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Sunburst Painter
class EnhancedSunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final mainPaint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    const rayCount = 52;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 360 / rayCount) * (pi / 180);
      final innerRadius = 120.0 + (i % 7) * 9;
      final outerRadius = size.width * 0.92;

      final x1 = center.dx + innerRadius * cos(angle);
      final y1 = center.dy + innerRadius * sin(angle);
      final x2 = center.dx + outerRadius * cos(angle);
      final y2 = center.dy + outerRadius * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), mainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
