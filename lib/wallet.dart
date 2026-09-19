import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ludo_game/Deposit_coin.dart';
import 'package:ludo_game/Withdraw.dart';

class Wallet extends StatefulWidget {
  const Wallet({super.key});

  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);

  int userCoins = 0;
  int totalWon = 0;
  int totalSpent = 0;
  int totalDeposit = 0;
  int totalWithdraw = 0;
  bool isLoading = true;
  String? _userId;

  // ✅ Fixed rate: 1 Coin = 10 PKR
  static const double coinToPkrRate = 10.0;

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
      await _fetchWalletStats();
      await _fetchTotalDeposit();
      await _fetchTotalWithdraw();
    }
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
          setState(() {
            userCoins = userDoc.data()?['coins'] ?? 0;
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
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
              userCoins = snapshot.data()?['coins'] ?? 0;
            });
          }
        });
  }

  Future<void> _fetchWalletStats() async {
    if (_userId == null) return;

    try {
      // Fetch total won from matches won
      final matchesWon = await FirebaseFirestore.instance
          .collection('matches')
          .where('winnerId', isEqualTo: _userId)
          .where('status', isEqualTo: 'completed')
          .get();

      int wonCoins = 0;
      for (var doc in matchesWon.docs) {
        final winAmount = doc.data()['winAmount'];
        wonCoins += (winAmount is num ? winAmount.toInt() : 0);
      }

      // Fetch total spent from match entries
      final matchesPlayed = await FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: _userId)
          .where('status', isEqualTo: 'completed')
          .get();

      int spentCoins = 0;
      for (var doc in matchesPlayed.docs) {
        final entryFee = doc.data()['entryFee'];
        spentCoins += (entryFee is num ? entryFee.toInt() : 0);
      }

      if (mounted) {
        setState(() {
          totalWon = wonCoins;
          totalSpent = spentCoins;
        });
      }
    } catch (e) {
      print('Error fetching wallet stats: $e');
    }
  }

  Future<void> _fetchTotalDeposit() async {
    if (_userId == null) return;

    try {
      // Fetch all accepted transactions (deposits)
      final transactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: _userId)
          .where('status', isEqualTo: 'ACCEPTED')
          .get();

      int depositCoins = 0;
      for (var doc in transactions.docs) {
        final coins = doc.data()['coins'];
        depositCoins += (coins is num ? coins.toInt() : 0);
      }

      // Also listen for real-time updates
      FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: _userId)
          .where('status', isEqualTo: 'ACCEPTED')
          .snapshots()
          .listen((snapshot) {
            int newDepositCoins = 0;
            for (var doc in snapshot.docs) {
              final coins = doc.data()['coins'];
              newDepositCoins += (coins is num ? coins.toInt() : 0);
            }
            if (mounted) {
              setState(() {
                totalDeposit = newDepositCoins;
              });
            }
          });

      if (mounted) {
        setState(() {
          totalDeposit = depositCoins;
        });
      }
    } catch (e) {
      print('Error fetching total deposit: $e');
    }
  }

  Future<void> _fetchTotalWithdraw() async {
    if (_userId == null) return;

    try {
      // ✅ No orderBy here. This avoids Firestore composite index error.
      FirebaseFirestore.instance
          .collection('withdraw')
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .listen(
            (snapshot) {
              int withdrawCoins = 0;

              for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? 'PENDING')
                    .toString()
                    .toUpperCase();

                // ✅ Total Withdraw me sirf approved/accepted requests count hongi.
                if (status == 'ACCEPTED' || status == 'APPROVED') {
                  withdrawCoins += _parseCoins(data['coins']);
                }
              }

              if (mounted) {
                setState(() {
                  totalWithdraw = withdrawCoins;
                });
              }
            },
            onError: (e) {
              debugPrint('Error listening total withdraw: $e');
            },
          );
    } catch (e) {
      debugPrint('Error fetching total withdraw: $e');
    }
  }

  String _getFormattedCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }

  // ✅ New method: Convert coins to PKR (1 Coin = 10 PKR)
  String _coinsToPkr(int coins) {
    double pkr = coins * coinToPkrRate;
    return pkr.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 380;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: darkPurple,
      body: Stack(
        children: [
          // Full screen background image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/back_dash.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // ===================================================
                  // TOP BAR
                  // ===================================================
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: _topButton(
                          Icons.arrow_back_ios_new_rounded,
                          isSmallScreen,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Image.asset(
                            'assets/coin.png',
                            height: isSmallScreen ? 28 : 34,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Wallet",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _historyButton(isSmallScreen),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===================================================
                  // TOTAL BALANCE CONTAINER
                  // ===================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gold,
                          gold.withOpacity(0.5),
                          const Color(0xff5d1f92),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff2c0d45), Color(0xff1a0530)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: gold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: gold.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: gold,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        "Total Balance",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: isSmallScreen ? 8 : 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    isLoading
                                        ? const SizedBox(
                                            width: 60,
                                            height: 30,
                                            child: LinearProgressIndicator(),
                                          )
                                        : Text(
                                            _getFormattedCoins(userCoins),
                                            style: TextStyle(
                                              color: gold,
                                              fontSize: isSmallScreen ? 28 : 36,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  color: gold.withOpacity(0.5),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                    const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        "Coins",
                                        style: TextStyle(
                                          color: gold,
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        gold.withOpacity(0.2),
                                        const Color(
                                          0xff5d1f92,
                                        ).withOpacity(0.4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: gold.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.attach_money,
                                        color: gold,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        // ✅ Fixed: 1 Coin = 10 PKR
                                        "≈ ${_coinsToPkr(userCoins)} PKR",
                                        style: TextStyle(
                                          color: const Color(0xfff7c42b),
                                          fontSize: isSmallScreen ? 9 : 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      "User ID: #LUDO${_userId?.substring(0, 6) ?? "1023"}",
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: isSmallScreen ? 9 : 10,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text("ID Copied!"),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: gold.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          color: gold,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Image.asset(
                                'assets/wallets.png',
                                height: isSmallScreen ? 100 : 130,
                                width: isSmallScreen ? 85 : 110,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===================================================
                  // DEPOSIT + WITHDRAW BUTTONS
                  // ===================================================
                  Row(
                    children: [
                      Expanded(
                        child: _walletActionButton(
                          title: "WITHDRAW",
                          icon: Icons.upload_rounded,
                          gradientColors: const [
                            Color(0xffff5a5a),
                            Color(0xffb31313),
                          ],
                          shadowColor: Colors.red,
                          isSmallScreen: isSmallScreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Withdraw(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _walletActionButton(
                          title: "DEPOSIT",
                          icon: Icons.add,
                          gradientColors: const [
                            Color(0xff1dc74f),
                            Color(0xff0f8d34),
                          ],
                          shadowColor: Colors.green,
                          isSmallScreen: isSmallScreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DepositCoin(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===================================================
                  // WALLET SUMMARY
                  // ===================================================
                  _sectionContainer(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: gold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Wallet Summary",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _summaryItem(
                                color: Colors.blueAccent,
                                icon: Icons.download_done_rounded,
                                title: "Deposit",
                                amount: _getFormattedCoins(totalDeposit),
                                isSmallScreen: isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _summaryItem(
                                color: Colors.orangeAccent,
                                icon: Icons.upload_rounded,
                                title: "Withdraw",
                                amount: _getFormattedCoins(totalWithdraw),
                                isSmallScreen: isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _summaryItem(
                                color: Colors.purpleAccent,
                                icon: Icons.emoji_events_rounded,
                                title: "Won",
                                amount: _getFormattedCoins(totalWon),
                                isSmallScreen: isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _summaryItem(
                                color: Colors.red,
                                icon: Icons.arrow_upward_rounded,
                                title: "Spent",
                                amount: _getFormattedCoins(totalSpent),
                                isSmallScreen: isSmallScreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    isSmallScreen: isSmallScreen,
                  ),

                  const SizedBox(height: 12),

                  // ===================================================
                  // RECENT TRANSACTIONS
                  // ===================================================
                  _sectionContainer(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: gold, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Recent Transactions",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "View All",
                              style: TextStyle(
                                color: const Color(0xfff7c42b),
                                fontSize: isSmallScreen ? 9 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildRecentTransactions(isSmallScreen),
                      ],
                    ),
                    isSmallScreen: isSmallScreen,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    final date = timestamp.toDate();
    return "${date.day} ${_getMonthAbbr(date.month)}\n${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _walletActionButton({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required Color shadowColor,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isSmallScreen ? 48 : 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Image.asset('assets/coin.png', height: isSmallScreen ? 17 : 21),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(bool isSmallScreen) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? uid = _userId ?? currentUser?.uid;

    if (uid == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "Please login first",
          style: TextStyle(
            color: Colors.white54,
            fontSize: isSmallScreen ? 10 : 11,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      // ✅ No orderBy here. Sorting is done below in Dart.
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, depositSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          // ✅ No orderBy here. This fixes the withdraw composite index error.
          stream: FirebaseFirestore.instance
              .collection('withdraw')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, withdrawSnapshot) {
            if (depositSnapshot.hasError || withdrawSnapshot.hasError) {
              final errorText = depositSnapshot.error ?? withdrawSnapshot.error;
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  "Transaction error: $errorText",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: isSmallScreen ? 9 : 10,
                  ),
                ),
              );
            }

            final bool isWaiting =
                depositSnapshot.connectionState == ConnectionState.waiting &&
                withdrawSnapshot.connectionState == ConnectionState.waiting;

            if (isWaiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final List<_WalletTransactionItem> items = [];

            if (depositSnapshot.hasData) {
              for (final doc in depositSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final int coins = _parseCoins(data['coins']);
                final Timestamp? timestamp =
                    data['timestamp'] as Timestamp? ??
                    data['submittedAt'] as Timestamp?;

                final method = (data['paymentMethod'] ?? 'EasyPaisa')
                    .toString();
                final amount = (data['amount'] ?? '${coins * 10} PKR')
                    .toString();

                items.add(
                  _WalletTransactionItem(
                    type: 'deposit',
                    coins: coins,
                    amountText: '+${_getFormattedCoins(coins)}',
                    title: 'Deposit Request',
                    subtitle: '$method • $amount',
                    status: (data['status'] ?? 'PENDING').toString(),
                    timestamp: timestamp,
                  ),
                );
              }
            }

            if (withdrawSnapshot.hasData) {
              for (final doc in withdrawSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final int coins = _parseCoins(data['coins']);
                final Timestamp? timestamp =
                    data['timestamp'] as Timestamp? ??
                    data['submittedAt'] as Timestamp?;

                final method = (data['paymentMethod'] ?? 'Account').toString();
                final accountNumber = (data['accountNumber'] ?? '').toString();
                final accountName = (data['accountName'] ?? '').toString();

                items.add(
                  _WalletTransactionItem(
                    type: 'withdraw',
                    coins: coins,
                    amountText: '-${_getFormattedCoins(coins)}',
                    title: 'Withdraw Request',
                    subtitle: accountNumber.isNotEmpty
                        ? '$method • $accountNumber • ${_getFormattedCoins(coins)} Coins'
                        : '$method • $accountName • ${_getFormattedCoins(coins)} Coins',
                    status: (data['status'] ?? 'PENDING').toString(),
                    timestamp: timestamp,
                  ),
                );
              }
            }

            items.sort((a, b) {
              final aDate = a.timestamp?.toDate() ?? DateTime(1970);
              final bDate = b.timestamp?.toDate() ?? DateTime(1970);
              return bDate.compareTo(aDate);
            });

            final latestItems = items.take(5).toList();

            if (latestItems.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "No transactions yet",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isSmallScreen ? 10 : 11,
                  ),
                ),
              );
            }

            return Column(
              children: latestItems.map((item) {
                final isWithdraw = item.type == 'withdraw';
                final statusColor = _statusColor(item.status);

                return _transactionTile(
                  icon: isWithdraw
                      ? Icons.upload_rounded
                      : Icons.download_done_rounded,
                  iconColor: isWithdraw ? Colors.orangeAccent : Colors.green,
                  title: item.title,
                  subtitle: item.subtitle,
                  amount: item.amountText,
                  status: item.status,
                  statusColor: statusColor,
                  date: _formatDate(item.timestamp),
                  isSmallScreen: isSmallScreen,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  int _parseCoins(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Color _statusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'ACCEPTED' || upperStatus == 'APPROVED') {
      return Colors.green;
    }
    if (upperStatus == 'REJECTED') {
      return Colors.red;
    }
    return Colors.orange;
  }

  // ===================================================
  // SECTION CONTAINER
  // ===================================================

  Widget _sectionContainer({
    required Widget child,
    required bool isSmallScreen,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xff220033).withOpacity(.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 1),
      ),
      child: child,
    );
  }

  // ===================================================
  // TOP BUTTON
  // ===================================================

  Widget _topButton(IconData icon, bool isSmallScreen) {
    return Container(
      height: isSmallScreen ? 32 : 36,
      width: isSmallScreen ? 32 : 36,
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gold),
      ),
      child: Icon(icon, color: Colors.white, size: isSmallScreen ? 14 : 16),
    );
  }

  // ===================================================
  // HISTORY BUTTON
  // ===================================================

  Widget _historyButton(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 10,
        vertical: isSmallScreen ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: gold, size: isSmallScreen ? 12 : 14),
          if (!isSmallScreen) const SizedBox(width: 4),
          if (!isSmallScreen)
            Text(
              "History",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // ===================================================
  // SUMMARY ITEM
  // ===================================================

  Widget _summaryItem({
    required Color color,
    required IconData icon,
    required String title,
    required String amount,
    required bool isSmallScreen,
  }) {
    return Column(
      children: [
        Container(
          height: isSmallScreen ? 38 : 44,
          width: isSmallScreen ? 38 : 44,
          decoration: BoxDecoration(
            color: color.withOpacity(.15),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 8 : 9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        Text(
          "Coins",
          style: TextStyle(
            color: Colors.white60,
            fontSize: isSmallScreen ? 8 : 9,
          ),
        ),
      ],
    );
  }

  // ===================================================
  // TRANSACTION TILE
  // ===================================================

  Widget _transactionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required Color statusColor,
    required String date,
    required bool isSmallScreen,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: isSmallScreen ? 34 : 38,
            width: isSmallScreen ? 34 : 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: isSmallScreen ? 16 : 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 10 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: isSmallScreen ? 8 : 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      color: amount.contains("+")
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 12 : 13,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Image.asset(
                    'assets/coin.png',
                    height: isSmallScreen ? 10 : 12,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: isSmallScreen ? 7 : 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              date,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white54,
                fontSize: isSmallScreen ? 7 : 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTransactionItem {
  final String type;
  final int coins;
  final String amountText;
  final String title;
  final String subtitle;
  final String status;
  final Timestamp? timestamp;

  const _WalletTransactionItem({
    required this.type,
    required this.coins,
    required this.amountText,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.timestamp,
  });
}
