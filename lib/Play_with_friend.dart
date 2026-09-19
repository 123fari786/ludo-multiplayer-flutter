import 'package:flutter/material.dart';

class Playwithfriend extends StatefulWidget {
  const Playwithfriend({super.key});

  @override
  State<Playwithfriend> createState() => _PlaywithfriendState();
}

class _PlaywithfriendState extends State<Playwithfriend> {
  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);
  final Color cardPurple = const Color(0xff220033);

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
                                Icons.group,
                                color: Color(0xfff7a900),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Play With Friends",
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
                          Image.asset(
                            'assets/playwithfriend.png',
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            "Create or join a room and play\nwith your friends!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          // =================================================
                          // CREATE ROOM
                          // =================================================
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateRoomScreen(),
                                ),
                              );
                            },
                            child: _actionCard(
                              icon: Icons.group_add_rounded,
                              title: "CREATE ROOM",
                              subtitle:
                                  "Create a room and invite\nyour friends!",
                            ),
                          ),
                          const SizedBox(height: 18),
                          // =================================================
                          // JOIN ROOM
                          // =================================================
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const JoinRoomScreen(),
                                ),
                              );
                            },
                            child: _actionCard(
                              icon: Icons.groups_rounded,
                              title: "JOIN ROOM",
                              subtitle: "Join a friend's room\nusing room code",
                            ),
                          ),
                          const Spacer(),
                          // =================================================
                          // BOTTOM INFO
                          // =================================================
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
                                    Icons.emoji_events_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Play private matches with your friends\nand enjoy a fun gaming experience!",
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
  // ACTION CARD
  // ===============================================================

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
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
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffffd54f), Color(0xfff7a900)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: gold.withOpacity(.4), blurRadius: 12),
              ],
            ),
            child: Icon(icon, color: const Color(0xff2a0d42), size: 32),
          ),
          const SizedBox(width: 16),
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
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xfff7a900), Color(0xffffd54f)],
              ),
              boxShadow: [
                BoxShadow(color: gold.withOpacity(.35), blurRadius: 10),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================================
// CREATE ROOM SCREEN
// ===============================================================

class CreateRoomScreen extends StatelessWidget {
  const CreateRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color gold = const Color(0xFFFFD54F);
    final Color borderColor = const Color(0xFFFFB347);
    final Color cardPurple = const Color(0xFF6D3B68);
    final Color darkPurple = const Color(0xFF4A234D);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // ================= TOP HEADER =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A3A65), Color(0xFF4B234D)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_ios_new,
                                color: Color(0xFFFFD54F),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Back",
                                style: TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Create Room",
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 80), // For balance
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ================= MAIN CONTENT =================
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Success Message Container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6D3B68), Color(0xFF4A234D)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 2),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD54F),
                                    Color(0xFFFFB347),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Text(
                                "Room Created Successfully!",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Room Code Container (WITH CROWN IMAGE INSIDE)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6D3B68), Color(0xFF4A234D)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 2),
                          ),
                          child: Column(
                            children: [
                              // Crown Image at the top of container
                              Image.asset(
                                'assets/crown.png',
                                height: 120,
                                width: 120,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Your Room Code",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Room Code Box
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C1F4D),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: gold, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "ABCD12",
                                      style: TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 28,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        // Copy to clipboard
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Room code copied!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      child: const Icon(
                                        Icons.copy_rounded,
                                        color: Color(0xFFFFD54F),
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Share this code with your friends\nto join the room",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Room Settings Container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6D3B68), Color(0xFF4A234D)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 2),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Room Settings",
                                style: TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSettingRow(
                                Icons.sports_esports,
                                "Game Type",
                                "Classic",
                              ),
                              const Divider(color: Colors.white24, height: 20),
                              _buildSettingRow(
                                Icons.monetization_on,
                                "Entry Fee",
                                "100 Coins",
                              ),
                              const Divider(color: Colors.white24, height: 20),
                              _buildSettingRow(
                                Icons.emoji_events,
                                "Win Prize",
                                "400 Coins",
                              ),
                              const Divider(color: Colors.white24, height: 20),
                              _buildSettingRow(
                                Icons.people,
                                "Players",
                                "2 Players",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Share Button Container
                        GestureDetector(
                          onTap: () {
                            // Share room code
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sharing room code...'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "SHARE ROOM CODE",
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
                        const SizedBox(height: 12),
                        // Start Game Button Container
                        GestureDetector(
                          onTap: () {
                            // Start game logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Starting game...'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6A3A65), Color(0xFF4B234D)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  color: Color(0xFFFFD54F),
                                  size: 24,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "START GAME",
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Info Text
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.white54,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Only players with this code can join.",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD54F), size: 22),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
      ],
    );
  }
}

// ===============================================================
// JOIN ROOM SCREEN
// ===============================================================

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController roomCodeController = TextEditingController();

  final Color gold = const Color(0xFFFFD54F);
  final Color borderColor = const Color(0xFFFFB347);
  final Color cardPurple = const Color(0xFF6D3B68);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // =====================================================
          // BACKGROUND
          // =====================================================
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // =====================================================
                // TOP HEADER
                // =====================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A3A65), Color(0xFF4B234D)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Color(0xFFFFD54F),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A3A65), Color(0xFF4B234D)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.groups_rounded,
                                color: Color(0xFFFFD54F),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Join Room",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A3A65), Color(0xFF4B234D)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFFFFD54F),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // =====================================================
                // MAIN CONTAINER (FIX OVERFLOW)
                // =====================================================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6D3B68), Color(0xFF4A234D)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // =================================================
                            // DOOR IMAGE
                            // =================================================
                            Image.asset(
                              'assets/joinroom.png',
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 10),
                            // =================================================
                            // TITLE
                            // =================================================
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD54F),
                                    Color(0xFFFFB347),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                "Enter Room Code",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Ask your friend for the room code\nand enter it below.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            // =================================================
                            // TEXTFIELD
                            // =================================================
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1F4D),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.5,
                                ),
                              ),
                              child: TextField(
                                controller: roomCodeController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFFFFD54F),
                                  ),
                                  hintText: "Enter Room Code",
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // =================================================
                            // JOIN BUTTON
                            // =================================================
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                height: 58,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFF2E7D32),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "JOIN ROOM",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            // =================================================
                            // HOW IT WORKS
                            // =================================================
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1F4D),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: borderColor.withOpacity(.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Center(
                                    child: Text(
                                      "How it works?",
                                      style: TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _howItWorksTile(
                                    Icons.looks_one_rounded,
                                    "Get the room code from your friend\nwho created the room.",
                                  ),
                                  const SizedBox(height: 14),
                                  _howItWorksTile(
                                    Icons.looks_two_rounded,
                                    "Enter the code above and click on\n'Join Room' to start playing.",
                                  ),
                                  const SizedBox(height: 14),
                                  _howItWorksTile(
                                    Icons.looks_3_rounded,
                                    "Make sure you enter the correct code\nto join the room.",
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // =================================================
                            // BOTTOM NOTE
                            // =================================================
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Secure private room connection",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // HOW IT WORKS TILE
  // ===============================================================

  Widget _howItWorksTile(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD54F), Color(0xFFFFB347)],
            ),
          ),
          child: Icon(icon, color: Colors.black, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
