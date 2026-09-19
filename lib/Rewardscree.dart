// reward_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/Reward/RewardService.dart';

class Rewardscreen extends StatefulWidget {
  const Rewardscreen({super.key});

  @override
  State<Rewardscreen> createState() => _RewardscreenState();
}

class _RewardscreenState extends State<Rewardscreen> {
  final RewardService _rewardService = RewardService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeRewards();
  }

  Future<void> _initializeRewards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      await _rewardService.initializeUserRewards(_userId!);
      await _rewardService.checkAndUpdateDailyRewards(_userId!);

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _claimReward(int week, int day, int rewardAmount) async {
    if (_userId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _rewardService.claimReward(_userId!, week, day);

    // Close loading dialog
    Navigator.pop(context);

    if (result['success']) {
      _showRewardClaimedDialog(result['rewardAmount']);
    } else {
      _showErrorDialog(result['message']);
    }
  }

  void _showRewardClaimedDialog(int rewardAmount) {
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Congratulations!",
                style: TextStyle(
                  color: Color(0xfff7a900),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Reward Successfully Claimed!",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/coin_dash.png', height: 30),
                  const SizedBox(width: 8),
                  Text(
                    "+$rewardAmount Coins",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
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
                    fontSize: 16,
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

  void _showErrorDialog(String message) {
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
            border: Border.all(color: Colors.red, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error, color: Colors.white, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Cannot Claim",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
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
                    fontSize: 16,
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

  void _showMissedDayDialog() {
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
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.white, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "You Missed This Day!",
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "You cannot claim rewards for missed days. Complete available days to continue your streak.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Got It",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
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

  String _getTimeRemaining(Timestamp? lastClaimDate) {
    if (lastClaimDate == null) return "Available Now";

    final now = DateTime.now();
    final lastClaim = lastClaimDate.toDate();
    final nextAvailable = DateTime(
      lastClaim.year,
      lastClaim.month,
      lastClaim.day + 1,
    );

    if (now.isAfter(nextAvailable)) {
      return "Available Now";
    }

    final difference = nextAvailable.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else if (minutes > 0) {
      return "${minutes}m";
    } else {
      return "Available Now";
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color gold = const Color(0xfff7a900);
    final Color darkPurple = const Color(0xff160021);

    if (_userId == null) {
      return Scaffold(
        backgroundColor: darkPurple,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: darkPurple,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _rewardService.getUserRewardsStream(_userId!),
        builder: (context, snapshot) {
          final bool isLoading =
              !snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting;

          if (isLoading) {
            return _buildSkeletonUI(gold, darkPurple);
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Error loading rewards",
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      _initializeRewards();
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null || !data.containsKey('rewards')) {
            return _buildSkeletonUI(gold, darkPurple);
          }

          final currentWeek = data['currentWeek'] ?? 1;
          final weekKey = 'week$currentWeek';
          final rewards = Map<String, dynamic>.from(data['rewards'] ?? {});

          List<Map<String, dynamic>> weekRewards = [];
          if (rewards.containsKey(weekKey)) {
            weekRewards = List<Map<String, dynamic>>.from(rewards[weekKey]);
          } else {
            // UPDATED: Rewards from 1 to 7 coins
            List<int> defaultRewards = [1, 2, 3, 4, 5, 6, 7];
            weekRewards = List.generate(
              7,
              (index) => {
                'day': index + 1,
                'rewardAmount': defaultRewards[index],
                'status': index == 0 ? 'available' : 'locked',
                'claimedAt': null,
              },
            );
          }

          final currentDay = data['currentDay'] ?? 1;
          final lastClaimDate = data['lastClaimDate'] as Timestamp?;
          final streak = data['streak'] ?? 0;

          int completedDays = 0;
          for (var i = 0; i < weekRewards.length; i++) {
            if (weekRewards[i]['status'] == 'claimed') {
              completedDays++;
            }
          }

          final bool rewardsCompleted =
              data['rewardsCompleted'] == true ||
              currentWeek > 1 ||
              currentDay > 7 ||
              completedDays >= 7;

          if (rewardsCompleted && completedDays < 7) {
            completedDays = 7;
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  "assets/back_dash.png",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: darkPurple),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // === MAIN HEADER ===
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xff2a0540), Color(0xff180128)],
                        ),
                        border: Border.all(color: gold.withOpacity(.45)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: gold),
                                color: const Color(0xff2d0b44),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: gold, width: 1.5),
                            ),
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xff2d0b44),
                              child: Icon(
                                Icons.card_giftcard,
                                color: Color(0xfff7a900),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Daily Rewards",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xfff7a900),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rewardsCompleted
                                          ? "All 7 days completed"
                                          : "Week $currentWeek • Day ${currentDay > 7 ? 7 : currentDay}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Login Streak + Weekly Progress Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff2a0540),
                                    Color(0xff180128),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: gold.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "LOGIN STREAK",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        color: Color(0xfff7a900),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$streak Days",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff2a0540),
                                    Color(0xff180128),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: gold.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "WEEKLY PROGRESS",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: List.generate(7, (index) {
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              color: index < completedDays
                                                  ? gold
                                                  : Colors.white24,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "$completedDays/7 Days Completed",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Rewards Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: weekRewards.length,
                          itemBuilder: (context, index) {
                            final reward = weekRewards[index];
                            final status = rewardsCompleted
                                ? 'claimed'
                                : reward['status'];
                            final rewardAmount = reward['rewardAmount'];
                            final isLocked = status == 'locked';
                            final isClaimed = status == 'claimed';
                            final isAvailable = status == 'available';
                            final isMissed = status == 'missed';

                            final dayNum = reward['day'];

                            // Check if reward is time-locked
                            bool isTimeLocked = false;
                            if (lastClaimDate != null &&
                                !isClaimed &&
                                dayNum > completedDays &&
                                dayNum == currentDay) {
                              final now = DateTime.now();
                              final lastClaim = lastClaimDate.toDate();
                              final nextAvailable = DateTime(
                                lastClaim.year,
                                lastClaim.month,
                                lastClaim.day + 1,
                              );
                              if (now.isBefore(nextAvailable)) {
                                isTimeLocked = true;
                              }
                            }

                            final canClaim =
                                isAvailable &&
                                !isTimeLocked &&
                                !rewardsCompleted;

                            return GestureDetector(
                              onTap: () {
                                if (rewardsCompleted) {
                                  _showErrorDialog(
                                    "All 7 days rewards are completed. No more rewards available.",
                                  );
                                } else if (canClaim) {
                                  _claimReward(
                                    currentWeek,
                                    dayNum,
                                    rewardAmount,
                                  );
                                } else if (isMissed) {
                                  _showMissedDayDialog();
                                } else if (isTimeLocked) {
                                  _showErrorDialog(
                                    "Next reward will be available in ${_getTimeRemaining(lastClaimDate)}",
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: canClaim
                                        ? [
                                            const Color(0xfff7a900),
                                            const Color(0xffb36b00),
                                          ]
                                        : isLocked || isTimeLocked
                                        ? [
                                            const Color(0xff1a0a24),
                                            const Color(0xff120618),
                                          ]
                                        : isClaimed
                                        ? [
                                            const Color(0xff1a4a1a),
                                            const Color(0xff0d2e0d),
                                          ]
                                        : [
                                            const Color(0xff2a0540),
                                            const Color(0xff1f0430),
                                          ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: canClaim
                                        ? gold
                                        : isLocked || isTimeLocked
                                        ? Colors.white24
                                        : isClaimed
                                        ? Colors.green
                                        : gold.withOpacity(0.4),
                                    width: canClaim ? 2.5 : 1,
                                  ),
                                  boxShadow: canClaim
                                      ? [
                                          BoxShadow(
                                            color: gold.withOpacity(0.5),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "DAY $dayNum",
                                          style: TextStyle(
                                            color: isLocked || isTimeLocked
                                                ? Colors.white38
                                                : gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/coin_dash.png',
                                              height: 24,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.monetization_on,
                                                      color: Colors.white,
                                                      size: 24,
                                                    );
                                                  },
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$rewardAmount",
                                              style: TextStyle(
                                                color: isLocked || isTimeLocked
                                                    ? Colors.white38
                                                    : Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if ((isAvailable || isTimeLocked) &&
                                            !isClaimed)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: gold.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(color: gold),
                                            ),
                                            child: Text(
                                              canClaim
                                                  ? "CLAIM"
                                                  : _getTimeRemaining(
                                                      lastClaimDate,
                                                    ),
                                              style: TextStyle(
                                                color: canClaim
                                                    ? Colors.black
                                                    : Colors.white70,
                                                fontSize: 9,
                                                fontWeight: canClaim
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        if (isClaimed)
                                          const Text(
                                            "CLAIMED",
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isClaimed)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    if (isLocked || isTimeLocked)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.lock,
                                            color: Colors.white54,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    if (isMissed && !isLocked && !isClaimed)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            color: Colors.orange.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.warning,
                                            color: Colors.orange,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Next Reward Timer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff2a0540), Color(0xff180128)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: gold.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              rewardsCompleted
                                  ? Icons.check_circle
                                  : Icons.hourglass_bottom,
                              color: rewardsCompleted
                                  ? Colors.green
                                  : Colors.amber,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              rewardsCompleted
                                  ? "ALL REWARDS CLAIMED"
                                  : "NEXT REWARD IN:",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            if (!rewardsCompleted) ...[
                              const SizedBox(width: 8),
                              Text(
                                _getTimeRemaining(lastClaimDate),
                                style: TextStyle(
                                  color: gold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonUI(Color gold, Color darkPurple) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/back_dash.png",
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: darkPurple),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xff2a0540), Color(0xff180128)],
                  ),
                  border: Border.all(color: gold.withOpacity(.45)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gold),
                        color: const Color(0xff2d0b44),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: gold, width: 1.5),
                      ),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xff2d0b44),
                        child: Icon(
                          Icons.card_giftcard,
                          color: Color(0xfff7a900),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Daily Rewards",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Color(0xfff7a900),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Loading...",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff2a0540), Color(0xff180128)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: gold.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "LOGIN STREAK",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  color: Color(0xfff7a900),
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 40,
                                  height: 16,
                                  color: Colors.white24,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff2a0540), Color(0xff180128)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: gold.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "WEEKLY PROGRESS",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: List.generate(7, (index) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Container(
                                      height: 6,
                                      color: Colors.white24,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff1a0a24), Color(0xff120618)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock,
                            color: Colors.white38,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
