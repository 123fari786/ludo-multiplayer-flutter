// reward_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<int> _fixedRewards = const [1, 2, 3, 4, 5, 6, 7];

  // Get current user ID
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  List<Map<String, dynamic>> _buildWeekOneRewards() {
    return List.generate(
      7,
      (index) => {
        'day': index + 1,
        'rewardAmount': _fixedRewards[index],
        'status': index == 0 ? 'available' : 'locked',
        'claimedAt': null,
      },
    );
  }

  // Initialize reward data for new user
  Future<void> initializeUserRewards(String userId) async {
    try {
      final userRewardRef = _firestore.collection('user_rewards').doc(userId);
      final doc = await userRewardRef.get();

      print('Checking rewards for user: $userId');
      print('Document exists: ${doc.exists}');

      if (!doc.exists) {
        final rewardData = {
          'userId': userId,
          'currentWeek': 1,
          'currentDay': 1,
          'rewardsCompleted': false, // Day 7 ke baad true ho jayega
          'lastClaimDate': null,
          'weekStartDate': Timestamp.now(),
          'rewards': {'week1': _buildWeekOneRewards()},
          'totalCoinsEarned': 0,
          'streak': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await userRewardRef.set(rewardData);
        print('Rewards initialized for user: $userId');
      } else {
        print('Rewards already exist for user: $userId');
        await _updateRewardsIfNeeded(userId, doc.data()!);
      }
    } catch (e) {
      print('Error initializing rewards: $e');
      rethrow;
    }
  }

  // Update rewards if needed (for existing users)
  Future<void> _updateRewardsIfNeeded(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final userRewardRef = _firestore.collection('user_rewards').doc(userId);

      final updates = <String, dynamic>{};
      final rewards = Map<String, dynamic>.from(data['rewards'] ?? {});

      if (!rewards.containsKey('week1')) {
        rewards['week1'] = _buildWeekOneRewards();
        updates['rewards'] = rewards;
      } else {
        final weekRewards = List<Map<String, dynamic>>.from(rewards['week1']);

        for (var i = 0; i < weekRewards.length && i < 7; i++) {
          weekRewards[i]['rewardAmount'] = _fixedRewards[i];
        }

        rewards['week1'] = weekRewards;
        updates['rewards'] = rewards;
      }

      final week1Rewards = List<Map<String, dynamic>>.from(
        rewards['week1'] ?? [],
      );

      final bool weekOneCompleted =
          week1Rewards.length >= 7 &&
          week1Rewards.take(7).every((reward) => reward['status'] == 'claimed');

      final int currentWeek = data['currentWeek'] ?? 1;
      final int currentDay = data['currentDay'] ?? 1;

      // IMPORTANT:
      // Purane users ke liye bhi fix:
      // Agar bug ki wajah se week2/week3 start ho chuka hai,
      // to usay complete state par wapas lock kar do.
      if (weekOneCompleted ||
          currentWeek > 1 ||
          currentDay > 7 ||
          data['rewardsCompleted'] == true) {
        updates['currentWeek'] = 1;
        updates['currentDay'] = 8;
        updates['rewardsCompleted'] = true;
      } else if (!data.containsKey('rewardsCompleted')) {
        updates['rewardsCompleted'] = false;
      }

      if (updates.isNotEmpty) {
        await userRewardRef.update(updates);
        print('Rewards updated for user: $userId');
      }
    } catch (e) {
      print('Error updating rewards: $e');
    }
  }

  // Get user reward data stream
  Stream<DocumentSnapshot> getUserRewardsStream(String userId) {
    return _firestore.collection('user_rewards').doc(userId).snapshots();
  }

  // Claim reward for specific day
  Future<Map<String, dynamic>> claimReward(
    String userId,
    int week,
    int day,
  ) async {
    try {
      final userRewardRef = _firestore.collection('user_rewards').doc(userId);
      final userRef = _firestore.collection('users').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final rewardDoc = await transaction.get(userRewardRef);

        if (!rewardDoc.exists) {
          throw Exception('Reward data not found');
        }

        final data = rewardDoc.data()!;

        final bool rewardsCompleted =
            data['rewardsCompleted'] == true || (data['currentDay'] ?? 1) > 7;

        if (rewardsCompleted) {
          throw Exception('All 7 days rewards are already completed.');
        }

        // Sirf 7 days reward allow hai. Week 2 ya next cycle allowed nahi.
        if (week != 1) {
          throw Exception('No more rewards available after 7 days.');
        }

        if (day < 1 || day > 7) {
          throw Exception('Invalid day');
        }

        final rewards = Map<String, dynamic>.from(data['rewards'] ?? {});
        final weekKey = 'week1';

        if (!rewards.containsKey(weekKey)) {
          rewards[weekKey] = _buildWeekOneRewards();
        }

        final weekRewards = List<Map<String, dynamic>>.from(rewards[weekKey]);

        if (day > weekRewards.length) {
          throw Exception('Invalid day');
        }

        final int currentDay = data['currentDay'] ?? 1;

        if (day != currentDay) {
          throw Exception('Complete day $currentDay first');
        }

        final dayReward = Map<String, dynamic>.from(weekRewards[day - 1]);

        // Ensure reward amount is correct: Day 1 = 1 coin, Day 7 = 7 coins
        dayReward['rewardAmount'] = _fixedRewards[day - 1];

        if (dayReward['status'] == 'claimed') {
          throw Exception('Reward already claimed');
        }

        if (dayReward['status'] != 'available') {
          throw Exception(
            'Reward not available. Complete previous days first.',
          );
        }

        // 24 hours lock: next reward next day hi claim ho.
        final lastClaimDate = data['lastClaimDate'] as Timestamp?;
        if (lastClaimDate != null) {
          final lastClaim = lastClaimDate.toDate();
          final nextAvailable = DateTime(
            lastClaim.year,
            lastClaim.month,
            lastClaim.day + 1,
          );

          if (DateTime.now().isBefore(nextAvailable)) {
            throw Exception('Next reward will be available tomorrow.');
          }
        }

        final rewardAmount = dayReward['rewardAmount'] as int;

        // Update user's coins
        final userDoc = await transaction.get(userRef);
        int currentCoins = (userDoc.data()?['coins'] ?? 0) as int;
        int newCoins = currentCoins + rewardAmount;

        // Update reward status
        dayReward['status'] = 'claimed';
        dayReward['claimedAt'] = Timestamp.now();
        weekRewards[day - 1] = dayReward;
        rewards[weekKey] = weekRewards;

        bool allSevenDaysClaimed = weekRewards
            .take(7)
            .every((reward) => reward['status'] == 'claimed');

        int newCurrentDay = day + 1;
        bool newRewardsCompleted = false;

        // Day 7 ke baad koi new week / day 1 dobara create nahi hoga.
        if (day == 7 && allSevenDaysClaimed) {
          newCurrentDay = 8;
          newRewardsCompleted = true;
        } else if (day < 7) {
          final nextDayReward = Map<String, dynamic>.from(weekRewards[day]);
          if (nextDayReward['status'] == 'locked') {
            nextDayReward['status'] = 'available';
            weekRewards[day] = nextDayReward;
            rewards[weekKey] = weekRewards;
          }
        }

        // Update reward document
        transaction.update(userRewardRef, {
          'rewards': rewards,
          'currentDay': newCurrentDay,
          'currentWeek': 1,
          'rewardsCompleted': newRewardsCompleted,
          'lastClaimDate': Timestamp.now(),
          'totalCoinsEarned': FieldValue.increment(rewardAmount),
          'streak': FieldValue.increment(1),
        });

        // Update user coins
        transaction.update(userRef, {'coins': newCoins});

        return {
          'success': true,
          'rewardAmount': rewardAmount,
          'newCoins': newCoins,
          'message': newRewardsCompleted
              ? 'All 7 days rewards completed!'
              : 'Successfully claimed $rewardAmount coins!',
        };
      });
    } catch (e) {
      print('Error claiming reward: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Check and update daily availability (reset at midnight)
  Future<void> checkAndUpdateDailyRewards(String userId) async {
    try {
      final userRewardRef = _firestore.collection('user_rewards').doc(userId);
      final doc = await userRewardRef.get();

      if (!doc.exists) return;

      final data = doc.data()!;

      final bool rewardsCompleted =
          data['rewardsCompleted'] == true || (data['currentDay'] ?? 1) > 7;

      // 7 days complete ho gaye to dobara Day 1 available na karo.
      if (rewardsCompleted) {
        await userRewardRef.update({
          'currentWeek': 1,
          'currentDay': 8,
          'rewardsCompleted': true,
        });
        return;
      }

      final lastClaimDate = data['lastClaimDate'] as Timestamp?;
      final now = Timestamp.now();

      if (lastClaimDate != null) {
        final lastClaim = lastClaimDate.toDate();
        final current = now.toDate();

        // Check if it's a new day
        if (lastClaim.day != current.day ||
            lastClaim.month != current.month ||
            lastClaim.year != current.year) {
          final rewards = Map<String, dynamic>.from(data['rewards'] ?? {});
          const weekKey = 'week1';

          if (rewards.containsKey(weekKey)) {
            final weekRewards = List<Map<String, dynamic>>.from(
              rewards[weekKey],
            );
            final currentDay = data['currentDay'] ?? 1;

            // Make sure the current day is available if not claimed
            if (currentDay <= 7 &&
                weekRewards[currentDay - 1]['status'] == 'locked') {
              weekRewards[currentDay - 1]['status'] = 'available';
              rewards[weekKey] = weekRewards;
              await userRewardRef.update({
                'rewards': rewards,
                'currentWeek': 1,
                'rewardsCompleted': false,
              });
              print('Daily rewards updated for user: $userId');
            }
          }
        }
      }
    } catch (e) {
      print('Error checking daily rewards: $e');
    }
  }
}
