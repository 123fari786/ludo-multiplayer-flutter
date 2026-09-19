import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Withdraw extends StatefulWidget {
  const Withdraw({super.key});

  @override
  State<Withdraw> createState() => _WithdrawState();
}

class _WithdrawState extends State<Withdraw> {
  final _formKey = GlobalKey<FormState>();

  int selectedMethod = 0;
  int userCoins = 0;
  bool _isLoading = false;
  String? _userId;

  static const int coinToPkrRate = 10; // Same as Deposit: 1 Coin = 10 PKR.

  final List<Map<String, dynamic>> methods = [
    {"name": "JazzCash", "image": "assets/jazzcash.png"},
    {"name": "EasyPaisa", "image": "assets/easypaisa.png"},
  ];

  final TextEditingController coinController = TextEditingController();
  final TextEditingController accountNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();

  int withdrawAmountPkr = 0;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _listenToUserCoins();

    coinController.addListener(() {
      final coins = int.tryParse(coinController.text.trim()) ?? 0;
      if (mounted) {
        setState(() {
          withdrawAmountPkr = coins * coinToPkrRate;
        });
      }
    });
  }

  @override
  void dispose() {
    coinController.dispose();
    accountNameController.dispose();
    accountNumberController.dispose();
    super.dispose();
  }

  void _listenToUserCoins() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) return;

          setState(() {
            userCoins = _parseCoins(snapshot.data()?['coins']);
          });
        });
  }

  int _parseCoins(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) return '${(coins / 1000000).toStringAsFixed(1)}M';
    if (coins >= 1000) return '${(coins / 1000).toStringAsFixed(1)}K';
    return coins.toString();
  }

  Future<void> _submitWithdrawRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (_userId == null || _userId != user?.uid) {
      setState(() {
        _userId = user?.uid;
      });
    }
    if (user == null) {
      _showSnack("Please login first", Colors.red);
      return;
    }

    final int coins = int.parse(coinController.text.trim());
    final String paymentMethod = methods[selectedMethod]['name'].toString();
    final String accountName = accountNameController.text.trim();
    final String accountNumber = accountNumberController.text.trim();

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(user.uid);
      final withdrawRef = firestore.collection('withdraw').doc();

      await firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);

        if (!userSnap.exists) {
          throw Exception("USER_NOT_FOUND");
        }

        final latestCoins = _parseCoins(userSnap.data()?['coins']);

        if (latestCoins < coins) {
          throw Exception("INSUFFICIENT_COINS");
        }

        transaction.update(userRef, {'coins': FieldValue.increment(-coins)});

        transaction.set(withdrawRef, {
          'withdrawId': withdrawRef.id,
          'userId': user.uid,
          'userEmail': user.email,
          'coins': coins,
          'amountPkr': withdrawAmountPkr,
          'amount': '$withdrawAmountPkr PKR',
          'paymentMethod': paymentMethod,
          'accountName': accountName,
          'accountNumber': accountNumber,
          'status': 'PENDING',
          'isDeducted': true,
          'isRefunded': false,
          'timestamp': FieldValue.serverTimestamp(),
          'submittedAt': FieldValue.serverTimestamp(),
        });
      });

      coinController.clear();
      accountNameController.clear();
      accountNumberController.clear();

      if (mounted) {
        setState(() {
          withdrawAmountPkr = 0;
          _isLoading = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      final error = e.toString();
      if (error.contains("INSUFFICIENT_COINS")) {
        _showSnack(
          "You cannot withdraw more than your current balance ($userCoins coins).",
          Colors.red,
        );
      } else if (error.contains("USER_NOT_FOUND")) {
        _showSnack("User data not found.", Colors.red);
      } else {
        _showSnack("Withdraw request failed: $e", Colors.red);
      }
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
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
                const SizedBox(height: 18),
                const Text(
                  "Request Submitted!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xfff7a900),
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your coins have been deducted and your withdraw request is pending.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  "If rejected, coins will return to your balance.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xfff7a900),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff7a900),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 38,
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    final date = timestamp.toDate();
    return "${date.day} ${_getMonthAbbr(date.month)} ${date.year}";
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

  @override
  Widget build(BuildContext context) {
    final selectedMethodName = methods[selectedMethod]['name'].toString();

    return Scaffold(
      backgroundColor: const Color(0xff160021),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        child: _topButton(Icons.arrow_back_ios_new_rounded),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Image.asset('assets/coin.png', height: 40),
                          const SizedBox(width: 6),
                          const Text(
                            "Withdraw",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Image.asset('assets/coin.png', height: 40),
                        ],
                      ),
                      const Spacer(),
                      _topButton(Icons.question_mark_rounded),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===================================================
                  // AVAILABLE COINS CONTAINER
                  // ===================================================
                  _sectionContainer(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff6a2ea1), Color(0xff3f1462)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xfff7a900)),
                      ),
                      child: Row(
                        children: [
                          Image.asset('assets/wallets.png', height: 66),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Your Available Coins",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCoins(userCoins),
                                  style: const TextStyle(
                                    color: Color(0xfff7c42b),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Withdraw any amount from your available coins",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff2d0d45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xfff7a900),
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: Color(0xfff7a900),
                                  size: 18,
                                ),
                                SizedBox(height: 5),
                                Text(
                                  "Withdraw\nHistory",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ===================================================
                        // SECTION 1
                        // ===================================================
                        _sectionContainer(
                          child: Column(
                            children: [
                              _sectionTitle("1. ENTER COINS AMOUNT"),
                              const SizedBox(height: 16),
                              _customField(
                                controller: coinController,
                                hint: "Enter coins amount",
                                suffix: "Coins",
                                keyboard: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Enter coin amount";
                                  }

                                  final coins = int.tryParse(value.trim());
                                  if (coins == null || coins <= 0) {
                                    return "Enter valid coins";
                                  }

                                  if (coins > userCoins) {
                                    return "You cannot withdraw more than your balance";
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xff2b0f43),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xff4b2368),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          "You will receive approx:",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xfff7a900),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            "PKR $withdrawAmountPkr",
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          height: 7,
                                          width: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xfff7a900),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "1 Coin = 10 PKR",
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
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

                        // ===================================================
                        // SECTION 2
                        // ===================================================
                        _sectionContainer(
                          child: Column(
                            children: [
                              _sectionTitle("2. SELECT ACCOUNT METHOD"),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _paymentMethod(
                                      index: 0,
                                      image: methods[0]['image'],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _paymentMethod(
                                      index: 1,
                                      image: methods[1]['image'],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ===================================================
                        // SECTION 3
                        // ===================================================
                        _sectionContainer(
                          child: Column(
                            children: [
                              _sectionTitle("3. ENTER RECEIVER DETAILS"),
                              const SizedBox(height: 16),
                              _receiverField(
                                title: "$selectedMethodName Account Name",
                                icon: Icons.person_rounded,
                                controller: accountNameController,
                                hint: "Enter account holder name",
                                keyboardType: TextInputType.name,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Account name required";
                                  }
                                  if (value.trim().length < 3) {
                                    return "Enter valid account name";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _receiverField(
                                title: "$selectedMethodName Number",
                                icon: selectedMethod == 0
                                    ? Icons.phone_android_rounded
                                    : Icons.account_balance_wallet_rounded,
                                controller: accountNumberController,
                                hint: "Enter $selectedMethodName number",
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return "$selectedMethodName number required";
                                  }
                                  if (text.length < 10 || text.length > 13) {
                                    return "Enter valid mobile number";
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===================================================
                  // NOTE CONTAINER
                  // ===================================================
                  _sectionContainer(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff40205d), Color(0xff2c0d45)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xfff7a900)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xfff7a900),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),

                          Image.asset('assets/coin.png', height: 36),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ===================================================
                  // BUTTON CONTAINER
                  // ===================================================
                  _sectionContainer(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _submitWithdrawRequest,
                          child: Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isLoading
                                    ? [Colors.grey, Colors.grey.shade600]
                                    : const [
                                        Color(0xfff7a900),
                                        Color(0xffffcf4d),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoading)
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.send_rounded,
                                    color: Colors.black,
                                  ),
                                const SizedBox(width: 10),
                                Text(
                                  _isLoading ? "SUBMITTING..." : "SEND REQUEST",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Your request will be reviewed and the amount will be transferred to your selected account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===================================================
                  // WITHDRAW HISTORY
                  // ===================================================
                  _sectionContainer(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              color: Color(0xfff7a900),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Withdraw History",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "Latest",
                              style: TextStyle(
                                color: const Color(
                                  0xfff7a900,
                                ).withOpacity(0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _withdrawHistoryList(),
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
    );
  }

  Widget _withdrawHistoryList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? uid = _userId ?? currentUser?.uid;

    if (uid == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Please login first",
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdraw')
          .where('userId', isEqualTo: uid)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              "History error: ${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              "No withdraw request yet",
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          );
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final Timestamp? aTime =
              aData['timestamp'] as Timestamp? ??
              aData['submittedAt'] as Timestamp?;
          final Timestamp? bTime =
              bData['timestamp'] as Timestamp? ??
              bData['submittedAt'] as Timestamp?;

          final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
          final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;

          return bMillis.compareTo(aMillis);
        });

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'PENDING').toString();
            final coins = _parseCoins(data['coins']);
            final method = (data['paymentMethod'] ?? 'Withdraw').toString();
            final accountNumber = (data['accountNumber'] ?? '').toString();
            final timestamp =
                data['timestamp'] as Timestamp? ??
                data['submittedAt'] as Timestamp?;

            return _historyTile(
              title: "$method Withdraw",
              subtitle: "$accountNumber • ${_formatDate(timestamp)}",
              coins: coins,
              status: status,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _historyTile({
    required String title,
    required String subtitle,
    required int coins,
    required String status,
  }) {
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff2b0f43),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff4b2368)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.upload_rounded, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "-${_formatCoins(coins)}",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================
  // COMMON SECTION CONTAINER
  // ===================================================

  Widget _sectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff220033).withOpacity(.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xfff7a900), width: 1.2),
      ),
      child: child,
    );
  }

  // ===================================================
  // TOP BUTTON
  // ===================================================

  Widget _topButton(IconData icon) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xfff7a900)),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  // ===================================================
  // SECTION TITLE
  // ===================================================

  Widget _sectionTitle(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xfff7a900), Color(0xffffcf4d)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ===================================================
  // CUSTOM FIELD
  // ===================================================

  Widget _customField({
    required TextEditingController controller,
    required String hint,
    required String suffix,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xff2b0f43),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        errorStyle: const TextStyle(color: Colors.redAccent),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        suffixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xfff7a900),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              suffix,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xff4b2368)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xfff7a900)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  // ===================================================
  // PAYMENT METHOD
  // ===================================================

  Widget _paymentMethod({required int index, required String image}) {
    final bool selected = selectedMethod == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMethod = index;
          accountNumberController.clear();
        });
      },
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xfff7a900) : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(image, height: 28),
            if (selected)
              const Positioned(
                top: 5,
                right: 5,
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xfff7a900),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // RECEIVER FIELD
  // ===================================================

  Widget _receiverField({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff2b0f43),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff4b2368)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xff3d165d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xfff7a900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                labelText: title,
                labelStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
