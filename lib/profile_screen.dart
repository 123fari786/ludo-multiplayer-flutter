import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ludo_game/login.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color borderColor = const Color(0xFFFFB347);

  String userName = "";
  String userEmail = "";
  String userId = "";
  int userTotalCoins = 0;
  String userTotalMatches = "0";
  String userTotalWins = "0";
  String userTotalLosses = "0";
  String userWinPercentage = "0%";
  String userRank = "Bronze Player";

  File? _profileImage;
  String? _profileImageBase64;

  final ImagePicker _picker = ImagePicker();

  User? currentUser;

  bool _hasData = false;

  @override
  void initState() {
    super.initState();

    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      userId = "#LUDO${currentUser!.uid.substring(0, 8).toUpperCase()}";
    }

    _loadCachedData();
  }

  @override
  void dispose() {
    if (_profileImage != null && _profileImage!.path.contains('temporary')) {
      _profileImage!.delete();
    }
    super.dispose();
  }

  // ================= LOAD LOCAL CACHE =================

  Future<void> _loadCachedData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String? cachedData = prefs.getString('user_profile_data');

      if (cachedData != null) {
        Map<String, dynamic> userData = jsonDecode(cachedData);

        setState(() {
          _updateUserData(userData);
          _hasData = true;
        });
      }

      _fetchInitialData();
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  // ================= FETCH FIRESTORE =================

  Future<void> _fetchInitialData() async {
    if (currentUser == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (userDoc.exists && mounted) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Create a clean copy without Timestamp for caching
        Map<String, dynamic> cleanData = {};
        userData.forEach((key, value) {
          if (value is! Timestamp) {
            cleanData[key] = value;
          }
        });

        setState(() {
          _updateUserData(userData);
          _hasData = true;
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile_data', jsonEncode(cleanData));
      }
    } catch (e) {
      debugPrint("Firestore fetch error: $e");
    }
  }

  // ================= UPDATE USER DATA =================

  void _updateUserData(Map<String, dynamic> userData) {
    String firstName = userData['firstName'] ?? '';
    String lastName = userData['lastName'] ?? '';

    String fullName = "$firstName $lastName".trim();

    userName = fullName.isEmpty
        ? (currentUser?.email?.split('@')[0] ?? "User")
        : fullName;

    userEmail = userData['email'] ?? currentUser?.email ?? "No email";

    // Get coins from Firestore
    userTotalCoins = userData['coins'] ?? 0;

    _profileImageBase64 = userData['profileImageBase64'];

    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      _convertBase64ToImage(_profileImageBase64!);
    }

    // Default stats for now
    userTotalMatches = "0";
    userTotalWins = "0";
    userTotalLosses = "0";
    userWinPercentage = "0%";
    userRank = _calculateRank(userTotalCoins);
  }

  String _calculateRank(int coins) {
    if (coins >= 10000) return "Diamond Player";
    if (coins >= 5000) return "Platinum Player";
    if (coins >= 2000) return "Gold Player";
    if (coins >= 500) return "Silver Player";
    return "Bronze Player";
  }

  // ================= CONVERT BASE64 TO IMAGE =================

  Future<void> _convertBase64ToImage(String base64String) async {
    if (base64String.isEmpty) return;

    try {
      List<int> imageBytes = base64Decode(base64String);

      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/profile_${currentUser?.uid ?? DateTime.now().millisecondsSinceEpoch}.jpg';

      final File file = File(filePath);
      await file.writeAsBytes(imageBytes);

      if (await file.exists() && file.lengthSync() > 0) {
        if (mounted) {
          setState(() {
            _profileImage = file;
          });
        }
      } else {
        debugPrint("File written but empty or doesn't exist");
      }
    } catch (e) {
      debugPrint("Error converting Base64 to image: $e");
    }
  }

  // ================= PICK AND UPDATE IMAGE =================

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (image != null) {
        final File imageFile = File(image.path);

        List<int> imageBytes = await imageFile.readAsBytes();
        String base64String = base64Encode(imageBytes);

        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .update({'profileImageBase64': base64String});
        }

        setState(() {
          _profileImage = imageFile;
          _profileImageBase64 = base64String;
        });

        _showToastMessage("Profile picture updated!", isSuccess: true);
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
      _showToastMessage("Failed to update profile picture", isError: true);
    }
  }

  // ================= TOAST MESSAGE =================

  void _showToastMessage(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Colors.green
            : (isError ? Colors.red : Colors.orange),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= ATTRACTIVE LOGOUT DIALOG =================

  Future<void> _showLogoutDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A0A2E),
                    Color(0xFF2D1B4E),
                    Color(0xFF1A0A2E),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFFFB347), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFB347).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Logout?",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD54F),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFFFB347).withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      "Are you sure you want to logout?\nYou can always come back!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFFFFB347),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Your progress is saved securely",
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4A4A4A),
                                    Color(0xFF2D2D2D),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Cancel",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context);
                              await _logout();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6B6B),
                                    Color(0xFFEE5A24),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
        );
      },
    );
  }

  // ================= LOGOUT =================

  Future<void> _logout() async {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseAuth.instance.signOut();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile_data');

    if (mounted) {
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: currentUser != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  Map<String, dynamic> userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  _updateUserData(userData);

                  // Create clean copy without Timestamp for caching
                  Map<String, dynamic> cleanData = {};
                  userData.forEach((key, value) {
                    if (value is! Timestamp) {
                      cleanData[key] = value;
                    }
                  });

                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString('user_profile_data', jsonEncode(cleanData));
                  });
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 220,
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: const DecorationImage(
                                  image: AssetImage("assets/circle.png"),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: borderColor.withOpacity(.35),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 45,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFD54F),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _profileImage != null
                                      ? Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                debugPrint(
                                                  "Image file error: $error",
                                                );
                                                return Image.asset(
                                                  "assets/man.png",
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                        )
                                      : (_profileImageBase64 != null &&
                                            _profileImageBase64!.isNotEmpty)
                                      ? Image.memory(
                                          base64Decode(_profileImageBase64!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                debugPrint(
                                                  "Base64 decode error: $error",
                                                );
                                                return Image.asset(
                                                  "assets/man.png",
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                        )
                                      : Image.asset(
                                          "assets/man.png",
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 40,
                              right: 55,
                              child: GestureDetector(
                                onTap: _pickProfileImage,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFC44D),
                                        Color(0xFFB76A11),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        userName.isEmpty ? "User" : userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.badge,
                            color: Color(0xFFFFD54F),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "User ID: $userId",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.email,
                            color: Color(0xFFFFD54F),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            userEmail.isEmpty ? "No email" : userEmail,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _mainContainer(
                        child: Row(
                          children: [
                            Image.asset("assets/coin_dash.png", height: 45),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total Coins:",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userTotalCoins.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Matches",
                              userTotalMatches,
                              Icons.sports_esports,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Wins",
                              userTotalWins,
                              Icons.emoji_events,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              "Losses",
                              userTotalLosses,
                              Icons.trending_down,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statCard(
                              "Win %",
                              userWinPercentage,
                              Icons.bar_chart,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _mainContainer(
                        child: Row(
                          children: [
                            Image.asset(
                              "assets/rank.png",
                              width: 65,
                              height: 65,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                userRank,
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _showLogoutDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B4A16), Color(0xFF5A1B54)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFB347),
                              width: 2,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Color(0xFFFFD54F)),
                              SizedBox(width: 8),
                              Text(
                                "LOGOUT",
                                style: TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A3E12), Color(0xFF4A1248)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB347), width: 2),
      ),
      child: child,
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B4A16), Color(0xFF5A1B54)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD54F), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
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
