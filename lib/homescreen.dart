import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/Deposit_coin.dart';
import 'package:ludo_game/Reward/RewardService.dart';
import 'package:ludo_game/Rewardscree.dart';
import 'package:ludo_game/leaderborad.dart';
import 'package:ludo_game/notification.dart';
import 'package:ludo_game/play_with_online.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RewardService _rewardService = RewardService();
  String fullName = "Loading...";
  String userImage = "assets/avatar.png";
  int userCoins = 0;
  bool isLoading = true;
  String? _userId;
  bool _isDialogShowing = false;

  // Track processed transaction IDs to avoid duplicate adds
  Set<String> _processedTransactionIds = Set<String>();

  // Track rejected withdraw refunds to avoid duplicate returns
  Set<String> _processedWithdrawRefundIds = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      await _fetchUserData();
      await _listenToUserCoins();
      await _initializeRewards();
      await _checkAndShowDailyRewardDialog();
      await _loadProcessedTransactions();
      await _loadProcessedWithdrawRefunds();
      _listenForAcceptedTransactions();
      _listenForRejectedWithdraws();
    }
  }

  // Load already processed transactions from Firestore
  Future<void> _loadProcessedTransactions() async {
    if (_userId == null) return;

    try {
      final processedDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId!)
          .collection('processed_transactions')
          .get();

      for (var doc in processedDocs.docs) {
        _processedTransactionIds.add(doc.id);
      }
    } catch (e) {
      print('Error loading processed transactions: $e');
    }
  }

  // Load rejected withdraws that already returned coins.
  Future<void> _loadProcessedWithdrawRefunds() async {
    if (_userId == null) return;

    try {
      final processedDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId!)
          .collection('processed_withdraw_refunds')
          .get();

      for (var doc in processedDocs.docs) {
        _processedWithdrawRefundIds.add(doc.id);
      }
    } catch (e) {
      print('Error loading processed withdraw refunds: $e');
    }
  }

  // Listen for ACCEPTED transactions only
  void _listenForAcceptedTransactions() {
    if (_userId == null) return;

    FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: _userId)
        .where('status', isEqualTo: 'ACCEPTED')
        .snapshots()
        .listen((snapshot) {
          for (var docChange in snapshot.docChanges) {
            final transactionId = docChange.doc.id;
            final data = docChange.doc.data() as Map<String, dynamic>;
            final coins = data['coins'] ?? 0;

            // Check if this is a new ACCEPTED transaction
            if (docChange.type == DocumentChangeType.added) {
              if (!_processedTransactionIds.contains(transactionId) &&
                  coins > 0) {
                _addCoinsToUser(coins, transactionId);
              }
            }
          }
        });
  }

  // Add coins to user (adds to existing balance, doesn't replace)
  Future<void> _addCoinsToUser(int coinsToAdd, String transactionId) async {
    if (_userId == null) return;

    try {
      // Mark as processed first to prevent duplicate adds in case of error
      _processedTransactionIds.add(transactionId);

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId);

      // Use FieldValue.increment() to ADD coins (not replace)
      await userRef.update({'coins': FieldValue.increment(coinsToAdd)});

      // Mark transaction as processed in Firestore
      await userRef
          .collection('processed_transactions')
          .doc(transactionId)
          .set({
            'processedAt': FieldValue.serverTimestamp(),
            'coinsAdded': coinsToAdd,
            'transactionId': transactionId,
          });

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ +$coinsToAdd Coins added to your account!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print('✅ Added $coinsToAdd coins from transaction: $transactionId');
    } catch (e) {
      print('❌ Error adding coins: $e');
      // Remove from local set if failed so we can retry
      _processedTransactionIds.remove(transactionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error adding coins: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Listen for REJECTED withdraw requests and return coins only one time.
  void _listenForRejectedWithdraws() {
    if (_userId == null) return;

    FirebaseFirestore.instance
        .collection('withdraw')
        .where('userId', isEqualTo: _userId)
        .where('status', isEqualTo: 'REJECTED')
        .snapshots()
        .listen((snapshot) {
          for (var docChange in snapshot.docChanges) {
            if (docChange.type != DocumentChangeType.added &&
                docChange.type != DocumentChangeType.modified) {
              continue;
            }

            final withdrawId = docChange.doc.id;
            final data = docChange.doc.data() as Map<String, dynamic>;
            final coins = _parseCoins(data['coins']);

            if (!_processedWithdrawRefundIds.contains(withdrawId) &&
                coins > 0) {
              _refundRejectedWithdraw(coins, withdrawId);
            }
          }
        });
  }

  Future<void> _refundRejectedWithdraw(
    int coinsToRefund,
    String withdrawId,
  ) async {
    if (_userId == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    final processedRef = userRef
        .collection('processed_withdraw_refunds')
        .doc(withdrawId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final processedSnap = await transaction.get(processedRef);

        if (processedSnap.exists) {
          _processedWithdrawRefundIds.add(withdrawId);
          return;
        }

        transaction.update(userRef, {
          'coins': FieldValue.increment(coinsToRefund),
        });

        transaction.set(processedRef, {
          'processedAt': FieldValue.serverTimestamp(),
          'coinsRefunded': coinsToRefund,
          'withdrawId': withdrawId,
        });
      });

      _processedWithdrawRefundIds.add(withdrawId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '↩️ Withdraw rejected. $coinsToRefund coins returned.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print(
        '↩️ Refunded $coinsToRefund coins for rejected withdraw: $withdrawId',
      );
    } catch (e) {
      print('❌ Error refunding rejected withdraw: $e');
      _processedWithdrawRefundIds.remove(withdrawId);
    }
  }

  Future<void> _initializeRewards() async {
    if (_userId != null) {
      await _rewardService.initializeUserRewards(_userId!);
      await _rewardService.checkAndUpdateDailyRewards(_userId!);
    }
  }

  Future<void> _checkAndShowDailyRewardDialog() async {
    if (_userId == null || _isDialogShowing) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastClaimDateKey = 'last_claim_date_${_userId!}';
    String lastClaimDate = prefs.getString(lastClaimDateKey) ?? '';
    String today = DateTime.now().toIso8601String().split('T')[0];

    final doc = await FirebaseFirestore.instance
        .collection('user_rewards')
        .doc(_userId!)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final currentWeek = data['currentWeek'] ?? 1;
    final weekKey = 'week$currentWeek';
    final rewards = Map<String, dynamic>.from(data['rewards'] ?? {});

    if (!rewards.containsKey(weekKey)) return;

    final weekRewards = List<Map<String, dynamic>>.from(rewards[weekKey]);

    int availableDay = 0;
    int availableRewardAmount = 0;
    bool hasAvailableReward = false;

    for (int i = 0; i < weekRewards.length; i++) {
      if (weekRewards[i]['status'] == 'available') {
        hasAvailableReward = true;
        availableDay = weekRewards[i]['day'];
        availableRewardAmount = weekRewards[i]['rewardAmount'];
        break;
      }
    }

    final lastClaimDateFirestore = data['lastClaimDate'] as Timestamp?;
    bool claimedToday = false;
    if (lastClaimDateFirestore != null) {
      final lastClaim = lastClaimDateFirestore.toDate();
      final todayDate = DateTime.now();
      claimedToday =
          lastClaim.day == todayDate.day &&
          lastClaim.month == todayDate.month &&
          lastClaim.year == todayDate.year;
    }

    bool hasClaimedToday = lastClaimDate == today || claimedToday;

    if (hasAvailableReward && !hasClaimedToday) {
      String lastDialogShownKey = 'last_dialog_shown_${_userId!}';
      String lastDialogShown = prefs.getString(lastDialogShownKey) ?? '';

      if (lastDialogShown != today) {
        _isDialogShowing = true;
        await prefs.setString(lastDialogShownKey, today);
        _showDailyRewardReminder(
          availableDay,
          availableRewardAmount,
          currentWeek,
        );
      }
    }
  }

  double _scale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final widthScale = size.width / 390.0;
    final heightScale = size.height / 844.0;
    final rawScale = math.min(widthScale, heightScale);
    return rawScale.clamp(0.82, 1.18).toDouble();
  }

  double _font(BuildContext context, double size) {
    final scaledSize = size * _scale(context);
    return scaledSize.clamp(size * 0.88, size * 1.16).toDouble();
  }

  double _contentWidth(BoxConstraints constraints) {
    return constraints.maxWidth.clamp(0.0, 560.0).toDouble();
  }

  Widget _responsiveDialog({
    required BuildContext context,
    required Widget child,
    Color borderColor = const Color(0xfff7a900),
  }) {
    final size = MediaQuery.sizeOf(context);
    final scale = _scale(context);
    final dialogWidth = (size.width - (32 * scale))
        .clamp(280.0, 390.0)
        .toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 18 * scale,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: size.height * 0.88,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            width: dialogWidth,
            padding: EdgeInsets.all(22 * scale),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff2a0540), Color(0xff180128)],
              ),
              borderRadius: BorderRadius.circular(20 * scale),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _responsiveActionButtons({
    required BuildContext context,
    required Widget first,
    required Widget second,
  }) {
    final scale = _scale(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showColumn = constraints.maxWidth < 300;

        if (showColumn) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: first),
              SizedBox(height: 10 * scale),
              SizedBox(width: double.infinity, child: second),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: first),
            SizedBox(width: 12 * scale),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  void _showDailyRewardReminder(int day, int rewardAmount, int week) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final scale = _scale(context);

        return _responsiveDialog(
          context: context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/coin_dash.png', height: 70 * scale),
              SizedBox(height: 18 * scale),
              Text(
                "Day $day Reward!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xfff7a900),
                  fontSize: _font(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10 * scale),
              Text(
                "You have a reward waiting for you!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _font(context, 14),
                ),
              ),
              SizedBox(height: 15 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/coin_dash.png', height: 25 * scale),
                  SizedBox(width: 8 * scale),
                  Flexible(
                    child: Text(
                      "+$rewardAmount Coins",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _font(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24 * scale),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _saveReminderForLater(day);
                  _isDialogShowing = false;
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(25 * scale),
                    border: Border.all(
                      color: const Color(0xfff7a900),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    "MAYBE LATER",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xfff7a900),
                      fontSize: _font(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12 * scale),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _claimDailyReward(week, day, rewardAmount);
                  _isDialogShowing = false;
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xfff7a900), Color(0xffb36b00)],
                    ),
                    borderRadius: BorderRadius.circular(25 * scale),
                  ),
                  child: Text(
                    "CLAIM",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: _font(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  Future<void> _claimDailyReward(int week, int day, int rewardAmount) async {
    if (_userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _rewardService.claimReward(_userId!, week, day);
    Navigator.pop(context);

    if (result['success']) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_claim_date_${_userId!}', today);
      _showSuccessDialog(result['rewardAmount']);
    } else {
      _showErrorDialog(result['message']);
    }
  }

  void _showSuccessDialog(int rewardAmount) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final scale = _scale(context);

        return _responsiveDialog(
          context: context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16 * scale),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 20 * scale,
                      spreadRadius: 5 * scale,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 60 * scale,
                ),
              ),
              SizedBox(height: 18 * scale),
              Text(
                "Congratulations!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xfff7a900),
                  fontSize: _font(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10 * scale),
              Text(
                "Reward Successfully Claimed!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _font(context, 14),
                ),
              ),
              SizedBox(height: 10 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/coin_dash.png', height: 30 * scale),
                  SizedBox(width: 8 * scale),
                  Flexible(
                    child: Text(
                      "+$rewardAmount Coins",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _font(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20 * scale),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40 * scale,
                    vertical: 12 * scale,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25 * scale),
                  ),
                ),
                child: Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: _font(context, 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final scale = _scale(context);

        return _responsiveDialog(
          context: context,
          borderColor: Colors.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16 * scale),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error, color: Colors.white, size: 60 * scale),
              ),
              SizedBox(height: 18 * scale),
              Text(
                "Cannot Claim",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: _font(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10 * scale),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _font(context, 14),
                ),
              ),
              SizedBox(height: 20 * scale),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40 * scale,
                    vertical: 12 * scale,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25 * scale),
                  ),
                ),
                child: Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: _font(context, 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveReminderForLater(int day) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_day_${_userId!}', day.toString());
  }

  Future<void> _listenToUserCoins() async {
    if (_userId == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(_userId!)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              userCoins = _parseCoins(snapshot.data()?['coins']);
            });
          }
        });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          final data = userDoc.data();

          setState(() {
            final firstName = data?['firstName'] ?? '';
            final lastName = data?['lastName'] ?? '';

            if (firstName.isEmpty && lastName.isEmpty) {
              fullName = user.displayName ?? 'User';
            } else {
              fullName = '$firstName $lastName'.trim();
            }

            if (fullName.isEmpty || fullName == '') {
              final email = user.email ?? '';
              fullName = email.split('@')[0];
            }

            userCoins = _parseCoins(data?['coins']);
            userImage = data?['profileImageBase64'] ?? 'assets/avatar.png';
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        if (mounted) {
          setState(() {
            fullName = user.displayName ?? 'User';
            isLoading = false;
          });
        }
      }
    }
  }

  int _parseCoins(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<int> _getLatestCoinsFromFirestore(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!doc.exists) return 0;

    final data = doc.data();
    return _parseCoins(data?['coins']);
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final scale = _scale(context);

        return _responsiveDialog(
          context: context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16 * scale),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 20 * scale,
                      spreadRadius: 5 * scale,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 60 * scale,
                ),
              ),
              SizedBox(height: 18 * scale),
              Text(
                "Insufficient Coins!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xfff7a900),
                  fontSize: _font(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10 * scale),
              Text(
                "Kindly deposit first.\nYou need at least 10 coins to play online.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _font(context, 14),
                ),
              ),
              SizedBox(height: 10 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/coin_dash.png', height: 30 * scale),
                  SizedBox(width: 8 * scale),
                  Flexible(
                    child: Text(
                      'Your Balance: $userCoins Coins',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xfff7a900),
                        fontSize: _font(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20 * scale),
              _responsiveActionButtons(
                context: context,
                first: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 12 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25 * scale),
                    ),
                  ),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _font(context, 14),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                second: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DepositCoin(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff7a900),
                    padding: EdgeInsets.symmetric(vertical: 12 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25 * scale),
                    ),
                  ),
                  child: FittedBox(
                    child: Text(
                      "Deposit Now",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: _font(context, 14),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final scale = _scale(context);

        return _responsiveDialog(
          context: context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16 * scale),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 20 * scale,
                      spreadRadius: 5 * scale,
                    ),
                  ],
                ),
                child: Icon(Icons.build, color: Colors.white, size: 60 * scale),
              ),
              SizedBox(height: 18 * scale),
              Text(
                "Coming Soon!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xfff7a900),
                  fontSize: _font(context, 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10 * scale),
              Text(
                "This feature is currently under development.\nPlease wait for the next update.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _font(context, 14),
                ),
              ),
              SizedBox(height: 20 * scale),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff7a900),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40 * scale,
                    vertical: 12 * scale,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25 * scale),
                  ),
                ),
                child: Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: _font(context, 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePlayOnline() async {
    const int onlineEntryFee = 10;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final latestCoins = await _getLatestCoinsFromFirestore(user.uid);

      if (!mounted) return;

      setState(() {
        userCoins = latestCoins;
      });

      debugPrint('💰 Fresh Home Coins Check: $latestCoins');

      if (latestCoins < onlineEntryFee) {
        _showInsufficientCoinsDialog();
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlayWithOnline()),
      );
    } catch (e) {
      debugPrint('❌ Error checking latest coins: $e');
      _showInsufficientCoinsDialog();
    }
  }

  void _handlePlayWithComputer() {
    _showComingSoonDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = _scale(context);
                final screenWidth = constraints.maxWidth;
                final screenHeight = constraints.maxHeight;
                final contentMaxWidth = _contentWidth(constraints);

                final horizontalPadding = (screenWidth * 0.04)
                    .clamp(12.0, 24.0)
                    .toDouble();
                final profileSectionHeight = (screenHeight * 0.13)
                    .clamp(82.0 * scale, 112.0 * scale)
                    .toDouble();
                final coinSectionHeight = (screenHeight * 0.18)
                    .clamp(124.0 * scale, 168.0 * scale)
                    .toDouble();
                final sectionSpacing = (screenHeight * 0.015)
                    .clamp(8.0 * scale, 16.0 * scale)
                    .toDouble();

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: SizedBox(
                      height: screenHeight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: profileSectionHeight,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 8 * scale,
                                ),
                                child: _profileSection(context, scale),
                              ),
                            ),
                            SizedBox(
                              height: coinSectionHeight,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 6 * scale,
                                ),
                                child: _coinSection(context, scale),
                              ),
                            ),
                            SizedBox(height: sectionSpacing),
                            Expanded(child: _gamesGrid(context, scale)),
                            SizedBox(
                              height: (screenHeight * 0.018)
                                  .clamp(8.0, 16.0)
                                  .toDouble(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSection(BuildContext context, double scale) {
    final avatarSize = (MediaQuery.sizeOf(context).width * 0.12)
        .clamp(42.0 * scale, 60.0 * scale)
        .toDouble();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF3B2C6E),
        borderRadius: BorderRadius.circular(20 * scale),
      ),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.yellow, width: 2),
            ),
            child: ClipOval(child: _buildProfileImage()),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome,',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: _font(context, 12),
                  ),
                ),
                SizedBox(height: 2 * scale),
                Row(
                  children: [
                    isLoading
                        ? SizedBox(
                            width: 64 * scale,
                            height: 14 * scale,
                            child: const LinearProgressIndicator(),
                          )
                        : Flexible(
                            child: Text(
                              fullName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _font(context, 16),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    SizedBox(width: 4 * scale),
                    if (!isLoading)
                      Text(
                        '👋',
                        style: TextStyle(fontSize: _font(context, 14)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationScreen(),
              ),
            ),
            child: Image.asset(
              'assets/bell.png',
              height: (34 * scale).clamp(30.0, 44.0).toDouble(),
              width: (34 * scale).clamp(30.0, 44.0).toDouble(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coinSection(BuildContext context, double scale) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF7A3E1D),
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: const Color(0xFFFFD54F), width: 3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final coinIconSize = (constraints.maxHeight * 0.30)
              .clamp(26.0 * scale, 38.0 * scale)
              .toDouble();
          final cashIconSize = (constraints.maxHeight * 0.26)
              .clamp(24.0 * scale, 34.0 * scale)
              .toDouble();
          final buttonHeight = (constraints.maxHeight * 0.36)
              .clamp(40.0 * scale, 52.0 * scale)
              .toDouble();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/coin_dash.png',
                        height: coinIconSize,
                        width: coinIconSize,
                      ),
                      SizedBox(width: 8 * scale),
                      Text(
                        '$userCoins Coins',
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFFFFD54F),
                          fontSize: _font(context, 22),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Image.asset(
                        'assets/cash.png',
                        height: cashIconSize,
                        width: cashIconSize,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8 * scale),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DepositCoin()),
                ),
                child: Container(
                  width: double.infinity,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(12 * scale),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20 * scale),
                      SizedBox(width: 8 * scale),
                      Text(
                        'Deposit',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: _font(context, 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _gamesGrid(BuildContext context, double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = (constraints.maxWidth * 0.04)
            .clamp(8.0 * scale, 16.0 * scale)
            .toDouble();

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _handlePlayOnline,
                      child: _buildGameCard(
                        image: 'assets/dunyia.png',
                        title: 'Play Online',
                        scale: scale,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    child: GestureDetector(
                      onTap: _handlePlayWithComputer,
                      child: _buildGameCard(
                        image: 'assets/computer.png',
                        title: 'Play With\n Offline',
                        scale: scale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Rewardscreen(),
                        ),
                      ),
                      child: _buildGameCard(
                        image: 'assets/rewaard.png',
                        title: 'Earns Rewards',
                        scale: scale,
                        isRewardCard: true,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Leaderborad(),
                        ),
                      ),
                      child: _buildGameCard(
                        image: 'assets/leaderborad.png',
                        title: 'Leaderboard',
                        scale: scale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileImage() {
    final scale = _scale(context);

    if (isLoading) {
      return Center(
        child: SizedBox(
          width: 22 * scale,
          height: 22 * scale,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (userImage.isNotEmpty &&
        (userImage.startsWith('/9j/') || userImage.contains('base64'))) {
      try {
        return Image.memory(
          base64Decode(userImage),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              Image.asset('assets/avatar.png', fit: BoxFit.cover),
        );
      } catch (e) {
        return Image.asset('assets/avatar.png', fit: BoxFit.cover);
      }
    } else {
      return Image.asset(
        'assets/avatar.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.person, color: Colors.white, size: 40 * scale),
      );
    }
  }

  Widget _buildGameCard({
    required String image,
    required String title,
    required double scale,
    bool isRewardCard = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;

        final imageSize = math
            .min(cardWidth * 0.88, cardHeight * 0.68)
            .clamp(76.0 * scale, (isRewardCard ? 170.0 : 160.0) * scale)
            .toDouble();
        final imageOffset = imageSize * 0.34;
        final titleFont = (cardWidth * 0.14)
            .clamp(14.0 * scale, 20.0 * scale)
            .toDouble();
        final radius = 18 * scale;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: imageOffset,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  8 * scale,
                  imageSize * 0.42,
                  8 * scale,
                  10 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A3E1D),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 3),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFont,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: imageSize,
              child: Center(
                child: Image.asset(
                  image,
                  height: imageSize,
                  width: imageSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
