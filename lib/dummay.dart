// pending_screen.dart
import 'package:flutter/material.dart';

class PendingScreen extends StatelessWidget {
  final String title;

  const PendingScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1433), // Dark background
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 90,
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              "$title is Coming Soon",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This feature will be available shortly",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
