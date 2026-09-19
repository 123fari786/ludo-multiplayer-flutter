import 'package:flutter/material.dart';
import 'package:ludo_game/community_screen.dart';
import 'package:ludo_game/homescreen.dart';
import 'package:ludo_game/profile_screen.dart';
import 'package:ludo_game/wallet.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CommunityScreen(),
    const Wallet(),
    const ProfileScreen(),
  ];

  final List<String> _labels = ["Home", "Community", "Wallet", "Profile"];

  final Color goldColor = const Color(0xfff7a900);
  final Color cardPurple = const Color(0xff2d0b44);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardPurple,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: cardPurple,
            elevation: 0,
            selectedItemColor: goldColor,
            unselectedItemColor: Colors.grey.shade500,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 11,
            ),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            enableFeedback: false,
            landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/home.png', height: 24, width: 24),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [goldColor, const Color(0xffffcb45)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/home.png',
                    height: 22,
                    width: 22,
                    color: Colors.black,
                  ),
                ),
                label: _labels[0],
              ),

              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/community.png',
                    height: 24,
                    width: 24,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [goldColor, const Color(0xffffcb45)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/community.png',
                    height: 22,
                    width: 22,
                    color: Colors.black,
                  ),
                ),
                label: _labels[1],
              ),

              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/wallet.png',
                    height: 24,
                    width: 24,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [goldColor, const Color(0xffffcb45)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/wallet.png',
                    height: 22,
                    width: 22,
                    color: Colors.black,
                  ),
                ),
                label: _labels[2],
              ),

              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/profile.png',
                    height: 24,
                    width: 24,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [goldColor, const Color(0xffffcb45)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/profile.png',
                    height: 22,
                    width: 22,
                    color: Colors.black,
                  ),
                ),
                label: _labels[3],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
