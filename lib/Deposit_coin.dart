import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DepositCoin extends StatefulWidget {
  const DepositCoin({super.key});

  @override
  State<DepositCoin> createState() => _DepositCoinState();
}

class _DepositCoinState extends State<DepositCoin> {
  final TextEditingController _coinController = TextEditingController();
  final TextEditingController _transactionIdController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _calculatedPrice;
  String? _verificationMessage;
  bool _isVerificationSuccess = false;

  final String _easyPaisaNumber = "03495990390";

  @override
  void initState() {
    super.initState();
    _coinController.addListener(_updatePrice);
  }

  @override
  void dispose() {
    _coinController.removeListener(_updatePrice);
    _coinController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  // Responsive scale helper.
  // Base width is 390, so the original design stays the same on normal phones.
  double _scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 390).clamp(0.84, 1.16).toDouble();
  }

  double _sp(BuildContext context, double value) {
    return value * _scale(context);
  }

  double _font(BuildContext context, double value) {
    return (value * _scale(context))
        .clamp(value * 0.90, value * 1.18)
        .toDouble();
  }

  double _dialogWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.86).clamp(280.0, 420.0).toDouble();
  }

  void _updatePrice() {
    final String coinText = _coinController.text;
    if (coinText.isEmpty) {
      setState(() {
        _calculatedPrice = null;
      });
      return;
    }
    final int? coins = int.tryParse(coinText);
    if (coins != null && coins > 0) {
      setState(() {
        _calculatedPrice = "${coins * 10} PKR";
      });
    } else {
      setState(() {
        _calculatedPrice = null;
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final int coins = int.parse(_coinController.text);
    final String transactionId = _transactionIdController.text.trim();
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    setState(() {
      _isLoading = true;
      _verificationMessage = null;
    });

    try {
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': user.uid,
        'userEmail': user.email,
        'coins': coins,
        'amount': _calculatedPrice,
        'transactionId': transactionId,
        'paymentMethod': 'EasyPaisa',
        'status': 'PENDING',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _coinController.clear();
      _transactionIdController.clear();
      setState(() {
        _calculatedPrice = null;
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _verificationMessage = "❌ Error: ${e.toString().substring(0, 50)}";
        _isVerificationSuccess = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final scale = _scale(context);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _dialogWidth(context)),
            child: Container(
              padding: EdgeInsets.all(24 * scale),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff2a0540), Color(0xff180128)],
                ),
                borderRadius: BorderRadius.circular(20 * scale),
                border: Border.all(color: const Color(0xfff7a900), width: 2),
              ),
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
                  SizedBox(height: 20 * scale),
                  Text(
                    "Submitted!",
                    style: TextStyle(
                      color: const Color(0xfff7a900),
                      fontSize: _font(context, 24),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    "Your transaction has been submitted for verification.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _font(context, 14),
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    "We'll verify within 24 hours.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xfff7a900),
                      fontSize: _font(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close deposit screen
                    },
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
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = _scale(context);
    final horizontalPadding = (size.width * 0.035).clamp(10.0, 18.0).toDouble();
    final maxContentWidth = size.width >= 600 ? 540.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xff160021),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 8 * scale,
                      ),
                      child: Column(
                        children: [
                          // ================= TOP BAR =================
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: _topButton(
                                  Icons.arrow_back_ios_new_rounded,
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/coin.png',
                                      height: 38 * scale,
                                    ),
                                    SizedBox(width: 4 * scale),
                                    Flexible(
                                      child: Text(
                                        "Add Coins",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: _font(context, 16),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4 * scale),
                                    Image.asset(
                                      'assets/coin.png',
                                      height: 38 * scale,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              _topButton(Icons.question_mark_rounded),
                            ],
                          ),
                          SizedBox(height: 12 * scale),

                          // =====================================================
                          // 1. MANUAL COIN INPUT SECTION
                          // =====================================================
                          _sectionContainer(
                            child: Column(
                              children: [
                                _sectionTitle("💰 ENTER COIN AMOUNT"),
                                SizedBox(height: 12 * scale),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xff2d1047),
                                          borderRadius: BorderRadius.circular(
                                            14 * scale,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xfff7a900),
                                          ),
                                        ),
                                        child: TextFormField(
                                          controller: _coinController,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _font(context, 15),
                                          ),
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            prefixIcon: Padding(
                                              padding: EdgeInsets.all(
                                                10 * scale,
                                              ),
                                              child: Image.asset(
                                                'assets/coin.png',
                                                height: 18 * scale,
                                              ),
                                            ),
                                            hintText: "Enter coins",
                                            hintStyle: TextStyle(
                                              color: Colors.white38,
                                              fontSize: _font(context, 13),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 12 * scale,
                                                ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return "Enter coin amount";
                                            }
                                            final int? coins = int.tryParse(
                                              value,
                                            );
                                            if (coins == null || coins <= 0) {
                                              return "Enter valid number";
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(height: 10 * scale),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 5 * scale,
                                          horizontal: 10 * scale,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xff391154),
                                          borderRadius: BorderRadius.circular(
                                            16 * scale,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              color: const Color(0xfff7a900),
                                              size: 12 * scale,
                                            ),
                                            SizedBox(width: 4 * scale),
                                            Text(
                                              "1 Coin = 10 PKR",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: _font(context, 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_calculatedPrice != null) ...[
                                        SizedBox(height: 10 * scale),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8 * scale,
                                            horizontal: 14 * scale,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xfff8b300),
                                                Color(0xffffd34d),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24 * scale,
                                            ),
                                          ),
                                          child: Text(
                                            "Total: $_calculatedPrice",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: _font(context, 14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12 * scale),

                          // =====================================================
                          // 2. EASYPAISA PAYMENT SECTION
                          // =====================================================
                          _sectionContainer(
                            child: Column(
                              children: [
                                _sectionTitle("📱 EASYPAISA PAYMENT"),
                                SizedBox(height: 10 * scale),
                                Container(
                                  padding: EdgeInsets.all(12 * scale),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff2d1047),
                                    borderRadius: BorderRadius.circular(
                                      14 * scale,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xfff7a900),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Center(
                                            child: Image.asset(
                                              'assets/easypaisa.png',
                                              height: 32 * scale,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10 * scale),
                                      Text(
                                        "Send payment to:",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: _font(context, 11),
                                        ),
                                      ),
                                      SizedBox(height: 6 * scale),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 10 * scale,
                                          horizontal: 12 * scale,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xff451866),
                                          borderRadius: BorderRadius.circular(
                                            10 * scale,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.phone_android,
                                              color: const Color(0xfff7a900),
                                              size: 16 * scale,
                                            ),
                                            SizedBox(width: 6 * scale),
                                            Flexible(
                                              child: Text(
                                                _easyPaisaNumber,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: _font(context, 14),
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 6 * scale),
                                            GestureDetector(
                                              onTap: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      "Number copied!",
                                                    ),
                                                    duration: Duration(
                                                      seconds: 1,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Icon(
                                                Icons.copy,
                                                color: const Color(0xfff7a900),
                                                size: 14 * scale,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 8 * scale),
                                      const Divider(
                                        color: Color(0xfff7a900),
                                        height: 0.5,
                                      ),
                                      SizedBox(height: 8 * scale),
                                      Text(
                                        "After payment, enter Transaction ID:",
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: _font(context, 10),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12 * scale),

                          // =====================================================
                          // 3. TRANSACTION ID & VERIFICATION SECTION
                          // =====================================================
                          _sectionContainer(
                            child: Column(
                              children: [
                                _sectionTitle("🔐 TRANSACTION VERIFICATION"),
                                SizedBox(height: 12 * scale),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xff2d1047),
                                    borderRadius: BorderRadius.circular(
                                      14 * scale,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xfff7a900),
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: _transactionIdController,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _font(context, 13),
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: "Enter Transaction ID",
                                      hintStyle: TextStyle(
                                        color: Colors.white38,
                                        fontSize: _font(context, 12),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.receipt,
                                        color: const Color(0xfff7a900),
                                        size: 16 * scale,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 12 * scale,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Transaction ID required";
                                      }
                                      if (value.length < 6) {
                                        return "Enter valid ID";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(height: 14 * scale),
                                if (_verificationMessage != null)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(10 * scale),
                                    decoration: BoxDecoration(
                                      color: _isVerificationSuccess
                                          ? Colors.green.withOpacity(0.15)
                                          : Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                        10 * scale,
                                      ),
                                      border: Border.all(
                                        color: _isVerificationSuccess
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    child: Text(
                                      _verificationMessage!,
                                      style: TextStyle(
                                        color: _isVerificationSuccess
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontSize: _font(context, 11),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                SizedBox(height: 14 * scale),
                                GestureDetector(
                                  onTap: _isLoading ? null : _submitTransaction,
                                  child: Container(
                                    height: 44 * scale,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xfff7a900),
                                          Color(0xffffcb45),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        12 * scale,
                                      ),
                                    ),
                                    child: _isLoading
                                        ? Center(
                                            child: SizedBox(
                                              height: 20 * scale,
                                              width: 20 * scale,
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.black,
                                                  ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.verified,
                                                color: Colors.black,
                                                size: 16 * scale,
                                              ),
                                              SizedBox(width: 6 * scale),
                                              Text(
                                                "SUBMIT",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: _font(context, 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                SizedBox(height: 8 * scale),
                                Text(
                                  "🔒 Verified within 24 hours",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: _font(context, 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12 * scale),

                          // =====================================================
                          // 4. RECENT TRANSACTIONS SECTION
                          // =====================================================
                          _sectionContainer(
                            child: Column(
                              children: [
                                _sectionTitle("📜 RECENT TRANSACTIONS"),
                                SizedBox(height: 10 * scale),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('transactions')
                                      .where(
                                        'userId',
                                        isEqualTo: FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid,
                                      )
                                      .orderBy('timestamp', descending: true)
                                      .limit(5)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Padding(
                                        padding: EdgeInsets.all(16 * scale),
                                        child: Center(
                                          child: SizedBox(
                                            height: 24 * scale,
                                            width: 24 * scale,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (!snapshot.hasData ||
                                        snapshot.data!.docs.isEmpty) {
                                      return Padding(
                                        padding: EdgeInsets.all(16 * scale),
                                        child: Text(
                                          "No transactions yet",
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: _font(context, 11),
                                          ),
                                        ),
                                      );
                                    }
                                    final docs = snapshot.data!.docs;
                                    return Column(
                                      children: docs.map((doc) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        String status =
                                            data['status'] ?? 'PENDING';
                                        bool isSuccess = status == 'ACCEPTED';
                                        bool isRejected = status == 'REJECTED';
                                        return _transaction(
                                          "${data['coins']} Coins",
                                          data['amount'] ?? "0 PKR",
                                          status,
                                          isSuccess,
                                          isRejected,
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // COMMON SECTION CONTAINER
  // =========================================================
  Widget _sectionContainer({required Widget child}) {
    final scale = _scale(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: const Color(0xff220033).withOpacity(0.94),
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: const Color(0xfff7a900), width: 1),
      ),
      child: child,
    );
  }

  // =========================================================
  // TOP BUTTON
  // =========================================================
  Widget _topButton(IconData icon) {
    final scale = _scale(context);

    return Container(
      height: 30 * scale,
      width: 30 * scale,
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: const Color(0xfff7a900)),
      ),
      child: Icon(icon, color: Colors.white, size: 14 * scale),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================
  Widget _sectionTitle(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xfff7a900),
          fontSize: _font(context, 10),
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // =========================================================
  // TRANSACTION ITEM
  // =========================================================
  Widget _transaction(
    String title,
    String amount,
    String status,
    bool isSuccess,
    bool isRejected,
  ) {
    final scale = _scale(context);

    Color statusColor;
    IconData statusIcon;
    String displayStatus;

    if (isSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      displayStatus = "ACCEPTED";
    } else if (isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      displayStatus = "REJECTED";
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      displayStatus = "PENDING";
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8 * scale),
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xff2a0d42),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Row(
        children: [
          Container(
            height: 34 * scale,
            width: 34 * scale,
            decoration: BoxDecoration(
              color: const Color(0xff451866),
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Center(
              child: Image.asset('assets/coin.png', height: 18 * scale),
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: _font(context, 11),
                  ),
                ),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xfff7a900),
                    fontWeight: FontWeight.bold,
                    fontSize: _font(context, 9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8 * scale,
              vertical: 4 * scale,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16 * scale),
              border: Border.all(color: statusColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 10 * scale),
                SizedBox(width: 4 * scale),
                Text(
                  displayStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: _font(context, 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
