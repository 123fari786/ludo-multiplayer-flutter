import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ludo_game/Reward/RewardService.dart';
import 'package:ludo_game/login.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Controllers for form fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Profile image
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Focus nodes for better UX
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  // Error messages for each field
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _profileImageError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<String?> _convertImageToBase64() async {
    if (_profileImage == null) return null;

    try {
      List<int> imageBytes = await _profileImage!.readAsBytes();
      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      debugPrint("Error converting image to Base64: $e");
      return null;
    }
  }

  // Toast message function
  void _showToastMessage(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSuccess
                  ? Colors.green
                  : (isError ? Colors.red : Colors.orange),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isSuccess
                      ? Icons.check_circle
                      : (isError ? Icons.error : Icons.info),
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry?.remove();
    });
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _profileImageError = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _clearFieldErrors() {
    setState(() {
      _firstNameError = null;
      _lastNameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _profileImageError = null;
    });
  }

  bool _isValidPassword(String password) {
    // Check if password contains at least one letter and one number
    bool hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    bool hasNumber = RegExp(r'[0-9]').hasMatch(password);
    return hasLetter && hasNumber;
  }

  bool _validateFields() {
    _clearFieldErrors();
    bool isValid = true;

    // Profile Image Validation
    if (_profileImage == null) {
      setState(() {
        _profileImageError = "Please select a profile image";
      });
      isValid = false;
    }
    // First Name Validation
    else if (_firstNameController.text.trim().isEmpty) {
      setState(() {
        _firstNameError = "First name is required";
      });
      _firstNameFocus.requestFocus();
      isValid = false;
    }
    // Last Name Validation
    else if (_lastNameController.text.trim().isEmpty) {
      setState(() {
        _lastNameError = "Last name is required";
      });
      _lastNameFocus.requestFocus();
      isValid = false;
    }
    // Email Validation
    else if (_emailController.text.trim().isEmpty) {
      setState(() {
        _emailError = "Email address is required";
      });
      _emailFocus.requestFocus();
      isValid = false;
    } else if (!_isValidEmail(_emailController.text.trim())) {
      setState(() {
        _emailError =
            "Please enter a valid email address (e.g., name@example.com)";
      });
      _emailFocus.requestFocus();
      isValid = false;
    }
    // Password Validation
    else if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _passwordError = "Password is required";
      });
      _passwordFocus.requestFocus();
      isValid = false;
    } else if (_passwordController.text.trim().length < 6) {
      setState(() {
        _passwordError = "Password must be at least 6 characters";
      });
      _passwordFocus.requestFocus();
      isValid = false;
    } else if (!_isValidPassword(_passwordController.text.trim())) {
      setState(() {
        _passwordError =
            "Password must contain at least one letter and one number";
      });
      _passwordFocus.requestFocus();
      isValid = false;
    }
    // Confirm Password Validation
    else if (_confirmPasswordController.text.trim().isEmpty) {
      setState(() {
        _confirmPasswordError = "Please confirm your password";
      });
      _confirmPasswordFocus.requestFocus();
      isValid = false;
    } else if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() {
        _confirmPasswordError = "Passwords do not match";
      });
      _confirmPasswordFocus.requestFocus();
      isValid = false;
    }

    return isValid;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _showNoInternetError() {
    const message =
        "No internet connection. Please connect to the internet and try again.";
    _showToastMessage(message, isError: true);
    _showErrorDialog(message);
  }

  void _moveToDashboard() {
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _signup() async {
    if (!_validateFields()) {
      return;
    }

    final bool hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      _showNoInternetError();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Show loading dialog like logout
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
        ),
      );
    }

    try {
      // Create user with email and password
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          )
          .timeout(const Duration(seconds: 20));

      String userId = userCredential.user!.uid;

      // Convert profile image to Base64
      String? base64Image = await _convertImageToBase64();

      // Check size
      if (base64Image != null && base64Image.length > 900000) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        _showToastMessage(
          "Image is too large! Please select smaller image.",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      Map<String, dynamic> userData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'coins': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'profileImageBase64': base64Image ?? '',
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData)
          .timeout(const Duration(seconds: 15));
      await RewardService().initializeUserRewards(userId);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      _showToastMessage("Signup Successful! 🎉", isSuccess: true);
      _showSuccessDialog();
    } on TimeoutException catch (_) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      const errorMessage =
          "No internet connection. Please check your internet connection and try again.";
      _showToastMessage(errorMessage, isError: true);
      _showErrorDialog(errorMessage);
    } on SocketException catch (_) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showNoInternetError();
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          _showAlreadyRegisteredDialog();
          return;

        case 'invalid-email':
          errorMessage = "Invalid email address format";
          setState(() {
            _emailError = errorMessage;
          });
          _emailFocus.requestFocus();
          _showToastMessage(errorMessage, isError: true);
          break;

        case 'weak-password':
          errorMessage =
              "Password is too weak. Use at least 6 characters with letters and numbers";
          setState(() {
            _passwordError = errorMessage;
          });
          _passwordFocus.requestFocus();
          _showToastMessage(errorMessage, isError: true);
          break;

        case 'network-request-failed':
          errorMessage =
              "No internet connection. Please check your internet connection.";
          _showToastMessage(errorMessage, isError: true);
          _showErrorDialog(errorMessage);
          break;

        case 'operation-not-allowed':
          errorMessage =
              "Email/password sign up is not enabled. Please contact support.";
          _showToastMessage(errorMessage, isError: true);
          _showErrorDialog(errorMessage);
          break;

        default:
          errorMessage = "Signup failed: ${e.message ?? e.code}";
          _showToastMessage(errorMessage, isError: true);
          _showErrorDialog(errorMessage);
      }
    } on FirebaseException catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = "Permission denied. Please check your Firebase rules.";
          break;
        case 'unavailable':
        case 'deadline-exceeded':
          errorMessage =
              "No internet connection. Please check your internet connection.";
          break;
        default:
          errorMessage = "Signup failed: ${e.message ?? e.code}";
      }

      _showToastMessage(errorMessage, isError: true);
      _showErrorDialog(errorMessage);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      final errorText = e.toString().toLowerCase();
      final String errorMsg =
          errorText.contains('network') || errorText.contains('socket')
          ? "No internet connection. Please check your internet connection."
          : "An unexpected error occurred: $e";

      _showToastMessage(errorMsg, isError: true);
      _showErrorDialog(errorMsg);
      debugPrint("Signup error: $e");
    }
  }

  void _showAlreadyRegisteredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff2a0540), Color(0xff180128)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xfff7a900), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_remove_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Error!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xfff7a900),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    "An account with this email already exists.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Please login to continue",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff7a900),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    "Login Now",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
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
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Error!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Something went wrong",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff7a900),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    "Try again",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff2a0540), Color(0xff180128)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xfff7a900), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
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
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "All done!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xfff7a900),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    "You're all set and ready to start",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Opening dashboard...",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1400), _moveToDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final safeHeight =
        screenHeight - mediaQuery.padding.top - mediaQuery.padding.bottom;
    final blockHeight = safeHeight / 100;
    final blockWidth = screenWidth / 100;
    final formWidth = screenWidth >= 600 ? 430.0 : screenWidth * 0.85;
    final buttonWidth = screenWidth >= 600 ? 250.0 : screenWidth * 0.5;
    final buttonHeight = (blockHeight * 5).clamp(44.0, 54.0).toDouble();

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/sign_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade900,
                        Colors.purple.shade700,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: blockHeight * 2),

                    Image.asset(
                      'assets/ludo_signupp.png',
                      height: screenHeight * 0.12,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          "LUDO\nSIGNUP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(offset: Offset(2, 2), blurRadius: 4),
                            ],
                          ),
                        );
                      },
                    ),

                    SizedBox(height: blockHeight * 1.5),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade800.withOpacity(0.8),
                            Colors.deepPurple.shade800.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "SIGN UP TO PLAY!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: blockHeight * 2),

                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: (blockWidth * 22)
                                .clamp(82.0, 104.0)
                                .toDouble(),
                            height: (blockWidth * 22)
                                .clamp(82.0, 104.0)
                                .toDouble(),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.red.shade400,
                                  Colors.purple.shade400,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: ClipOval(
                                  child: _profileImage != null
                                      ? Image.file(
                                          _profileImage!,
                                          width: (blockWidth * 22)
                                              .clamp(82.0, 104.0)
                                              .toDouble(),
                                          height: (blockWidth * 22)
                                              .clamp(82.0, 104.0)
                                              .toDouble(),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: const Color(0xFF7A3E00),
                                          child: Icon(
                                            Icons.person,
                                            size: blockWidth * 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6EDCFF), Color(0xFF0072FF)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: blockWidth * 3.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_profileImageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _profileImageError!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: blockHeight * 1.5),

                    Center(
                      child: SizedBox(
                        width: formWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFieldWithCornerImage(
                              hint: "First Name *",
                              icon: Icons.person_outline,
                              cornerImagePath: 'assets/yellow.png',
                              cornerPosition: 'top-right',
                              blockWidth: blockWidth,
                              blockHeight: blockHeight,
                              controller: _firstNameController,
                              focusNode: _firstNameFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _lastNameFocus.requestFocus(),
                              hasError: _firstNameError != null,
                            ),
                            if (_firstNameError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  _firstNameError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: blockHeight * 1),

                    Center(
                      child: SizedBox(
                        width: formWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFieldWithCornerImage(
                              hint: "Last Name *",
                              icon: Icons.person_outline,
                              cornerImagePath: 'assets/yellow.png',
                              cornerPosition: 'top-left',
                              blockWidth: blockWidth,
                              blockHeight: blockHeight,
                              controller: _lastNameController,
                              focusNode: _lastNameFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _emailFocus.requestFocus(),
                              hasError: _lastNameError != null,
                            ),
                            if (_lastNameError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  _lastNameError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: blockHeight * 1),

                    Center(
                      child: SizedBox(
                        width: formWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFieldWithTwoCornerImages(
                              hint: "Email Address *",
                              icon: Icons.email_outlined,
                              leftCornerImagePath: 'assets/red_got.png',
                              rightCornerImagePath: 'assets/blue.png',
                              blockWidth: blockWidth,
                              blockHeight: blockHeight,
                              controller: _emailController,
                              focusNode: _emailFocus,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              hasError: _emailError != null,
                            ),
                            if (_emailError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  _emailError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: blockHeight * 1),

                    Center(
                      child: SizedBox(
                        width: formWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFieldWithCornerImage(
                              hint: "Password *",
                              icon: Icons.lock_outline,
                              isPassword: true,
                              cornerImagePath: 'assets/small green.png',
                              cornerPosition: 'top-left',
                              blockWidth: blockWidth,
                              blockHeight: blockHeight,
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _confirmPasswordFocus.requestFocus(),
                              hasError: _passwordError != null,
                            ),
                            if (_passwordError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  _passwordError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: blockHeight * 1),

                    Center(
                      child: SizedBox(
                        width: formWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildConfirmPasswordField(
                              hint: "Confirm Password *",
                              icon: Icons.lock_outline,
                              isPassword: true,
                              cornerImagePath: 'assets/small green.png',
                              cornerPosition: 'top-right',
                              blockWidth: blockWidth,
                              blockHeight: blockHeight,
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _signup(),
                              hasError: _confirmPasswordError != null,
                            ),
                            if (_confirmPasswordError != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  _confirmPasswordError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B6B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: blockHeight * 2),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/small green.png',
                            height: blockHeight * 4,
                            width: blockWidth * 10,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return SizedBox(width: blockWidth * 10);
                            },
                          ),
                          SizedBox(width: blockWidth * 1),

                          SizedBox(
                            width: buttonWidth,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signup,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6EDCFF),
                                      Color(0xFF0072FF),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    "SIGNUP",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: blockWidth * 1),
                          Image.asset(
                            'assets/coins.png',
                            height: buttonHeight,
                            width: blockWidth * 14,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return SizedBox(width: blockWidth * 14);
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: blockHeight * 1.5),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: blockWidth * 5),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Divider(color: Colors.white54, thickness: 1),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "OR SIGN UP WITH",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: Colors.white54, thickness: 1),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: blockHeight * 1),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: ClipOval(
                            child: Container(
                              width: (blockWidth * 10)
                                  .clamp(38.0, 50.0)
                                  .toDouble(),
                              height: (blockWidth * 10)
                                  .clamp(38.0, 50.0)
                                  .toDouble(),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/facebook.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.facebook,
                                      size: 25,
                                      color: Color(0xFF1877F2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: blockWidth * 4),
                        GestureDetector(
                          onTap: () {},
                          child: ClipOval(
                            child: Container(
                              width: (blockWidth * 10)
                                  .clamp(38.0, 50.0)
                                  .toDouble(),
                              height: (blockWidth * 10)
                                  .clamp(38.0, 50.0)
                                  .toDouble(),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/googl.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text(
                                      "G",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDB4437),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: blockWidth * 4),
                        GestureDetector(
                          onTap: () {},
                          child: ClipOval(
                            child: Container(
                              width: (blockWidth * 10)
                                  .clamp(38.0, 50.0)
                                  .toDouble(),
                              height: (blockWidth * 10)
                                  .clamp(38.0, 50.0)
                                  .toDouble(),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/apple.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.apple,
                                      size: 28,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: blockHeight * 2),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already Have An Account? ",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: blockHeight * 3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWithCornerImage({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required String cornerImagePath,
    required String cornerPosition,
    required double blockWidth,
    required double blockHeight,
    TextEditingController? controller,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
    bool hasError = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: (blockHeight * 5.5).clamp(48.0, 58.0).toDouble(),
            decoration: BoxDecoration(
              color: const Color(0xFF7A3E00).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? const Color(0xFFFF6B6B) : Colors.orangeAccent,
                width: hasError ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: isPassword ? _obscurePassword : false,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              onChanged: (value) {
                if (hasError) {
                  setState(() {
                    if (focusNode == _firstNameFocus) _firstNameError = null;
                    if (focusNode == _lastNameFocus) _lastNameError = null;
                    if (focusNode == _emailFocus) _emailError = null;
                    if (focusNode == _passwordFocus) _passwordError = null;
                  });
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                prefixIcon: Icon(icon, color: Colors.white, size: 18),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Positioned(
            top: -blockHeight * 2.5,
            left: cornerPosition == 'top-left' ? -blockWidth * 8 : null,
            right: cornerPosition == 'top-right' ? -blockWidth * 8 : null,
            child: Image.asset(
              cornerImagePath,
              width: blockWidth * 14,
              height: blockHeight * 4,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: cornerPosition == 'top-left'
                        ? Colors.green
                        : Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required String cornerImagePath,
    required String cornerPosition,
    required double blockWidth,
    required double blockHeight,
    TextEditingController? controller,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
    bool hasError = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: (blockHeight * 5.5).clamp(48.0, 58.0).toDouble(),
            decoration: BoxDecoration(
              color: const Color(0xFF7A3E00).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? const Color(0xFFFF6B6B) : Colors.orangeAccent,
                width: hasError ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              onChanged: (value) {
                if (hasError) {
                  setState(() {
                    if (focusNode == _confirmPasswordFocus)
                      _confirmPasswordError = null;
                  });
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                prefixIcon: Icon(icon, color: Colors.white, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Positioned(
            top: -blockHeight * 2.5,
            left: cornerPosition == 'top-left' ? -blockWidth * 8 : null,
            right: cornerPosition == 'top-right' ? -blockWidth * 8 : null,
            child: Image.asset(
              cornerImagePath,
              width: blockWidth * 14,
              height: blockHeight * 4,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: cornerPosition == 'top-left'
                        ? Colors.green
                        : Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWithTwoCornerImages({
    required String hint,
    required IconData icon,
    required String leftCornerImagePath,
    required String rightCornerImagePath,
    required double blockWidth,
    required double blockHeight,
    TextEditingController? controller,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    Function(String)? onSubmitted,
    bool hasError = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: (blockHeight * 5.5).clamp(48.0, 58.0).toDouble(),
            decoration: BoxDecoration(
              color: const Color(0xFF7A3E00).withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? const Color(0xFFFF6B6B) : Colors.orangeAccent,
                width: hasError ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              onSubmitted: onSubmitted,
              onChanged: (value) {
                if (hasError) {
                  setState(() {
                    if (focusNode == _emailFocus) _emailError = null;
                  });
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                prefixIcon: Icon(icon, color: Colors.white, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Positioned(
            top: -blockHeight * 2.5,
            left: -blockWidth * 8,
            child: Image.asset(
              leftCornerImagePath,
              width: blockWidth * 14,
              height: blockHeight * 4,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: -blockHeight * 2.5,
            right: -blockWidth * 8,
            child: Image.asset(
              rightCornerImagePath,
              width: blockWidth * 14,
              height: blockHeight * 4,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// TimeoutException class
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
