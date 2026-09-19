import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Leaderborad extends StatefulWidget {
  const Leaderborad({super.key});

  @override
  State<Leaderborad> createState() => _LeaderboradState();
}

class _LeaderboradState extends State<Leaderborad> {
  final Color gold = const Color(0xfff7a900);
  final Color darkPurple = const Color(0xff160021);
  final Color cardPurple = const Color(0xff220033);

  List<Map<String, dynamic>> leaderboard = [];
  int totalPlayers = 0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Fetch users from Firestore ordered by coins descending
      final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('coins', descending: true)
          .limit(100)
          .get();

      List<Map<String, dynamic>> tempLeaderboard = [];
      int rank = 1;

      for (var doc in userSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';
        String fullName = '$firstName $lastName'.trim();

        if (fullName.isEmpty || fullName == '') {
          final email = data['email'] ?? '';
          fullName = email.toString().split('@')[0];
        }

        if (fullName.isEmpty) {
          fullName = 'Player $rank';
        }

        final int coins = _parseInt(data['coins']);
        final int wins = _parseInt(data['wins']);
        final String profileImage =
            data['profileImageBase64']?.toString() ?? '';

        tempLeaderboard.add({
          'rank': rank.toString(),
          'name': fullName,
          'coins': _formatNumber(coins),
          'coinsRaw': coins,
          'wins': wins.toString(),
          'image': profileImage,
          'userId': doc.id,
        });

        rank++;
      }

      if (mounted) {
        setState(() {
          leaderboard = tempLeaderboard;
          totalPlayers = tempLeaderboard.length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Unable to load leaderboard';
        });
      }
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _formatNumber(int number) {
    if (number >= 1000 && number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    return number.toString();
  }

  double _scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 390).clamp(0.82, 1.18).toDouble();
  }

  double _heightScale(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return (height / 844).clamp(0.78, 1.14).toDouble();
  }

  double _textScale(BuildContext context) {
    final widthScale = _scale(context);
    final heightScale = _heightScale(context);
    return ((widthScale + heightScale) / 2).clamp(0.84, 1.12).toDouble();
  }

  bool _isShortScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 700;
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final hs = _heightScale(context);
    final ts = _textScale(context);
    final isShort = _isShortScreen(context);

    return Scaffold(
      backgroundColor: darkPurple,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/back_dash.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    _buildTopHeader(s, ts),
                    SizedBox(height: (isShort ? 4 : 8) * hs),
                    Expanded(
                      child: RefreshIndicator(
                        color: gold,
                        backgroundColor: cardPurple,
                        onRefresh: _fetchLeaderboardData,
                        child: isLoading
                            ? _buildLoadingState(s, ts)
                            : errorMessage != null
                            ? _buildErrorState(s, ts)
                            : leaderboard.isEmpty
                            ? _buildEmptyState(s, ts)
                            : _buildLeaderboardContent(s, hs, ts, isShort),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(double s, double ts) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _topButton(Icons.arrow_back_ios_new_rounded, s),
          ),
          SizedBox(width: 10 * s),
          Expanded(
            child: Container(
              height: 42 * s,
              decoration: BoxDecoration(
                color: const Color(0xff2d0b44),
                borderRadius: BorderRadius.circular(14 * s),
                border: Border.all(color: gold, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_rounded, color: gold, size: 20 * s),
                  SizedBox(width: 8 * s),
                  Text(
                    "Leaderboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14 * ts,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10 * s),
          _topButton(Icons.help_outline_rounded, s),
        ],
      ),
    );
  }

  Widget _topButton(IconData icon, double s) {
    return Container(
      height: 38 * s,
      width: 38 * s,
      decoration: BoxDecoration(
        color: const Color(0xff2d0b44),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: gold),
      ),
      child: Icon(icon, color: Colors.white, size: 17 * s),
    );
  }

  Widget _buildLeaderboardContent(
    double s,
    double hs,
    double ts,
    bool isShort,
  ) {
    final podiumHorizontalMargin = 16 * s;
    final podiumPadding = (isShort ? 10 : 14) * s;
    final listPadding = 16 * s;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: podiumHorizontalMargin,
              vertical: (isShort ? 4 : 8) * hs,
            ),
            padding: EdgeInsets.all(podiumPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cardPurple.withOpacity(0.95),
                  darkPurple.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(24 * s),
              border: Border.all(color: gold.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (leaderboard.length >= 2)
                  Expanded(
                    child: _buildPodiumItem(
                      rank: leaderboard[1]["rank"],
                      name: leaderboard[1]["name"],
                      image: leaderboard[1]["image"],
                      coins: leaderboard[1]["coins"],
                      isGold: false,
                      rankColor: Colors.grey,
                      scale: s,
                      textScale: ts,
                      compact: isShort,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                Expanded(
                  child: _buildPodiumItem(
                    rank: leaderboard[0]["rank"],
                    name: leaderboard[0]["name"],
                    image: leaderboard[0]["image"],
                    coins: leaderboard[0]["coins"],
                    isGold: true,
                    rankColor: gold,
                    scale: s,
                    textScale: ts,
                    compact: isShort,
                  ),
                ),
                if (leaderboard.length >= 3)
                  Expanded(
                    child: _buildPodiumItem(
                      rank: leaderboard[2]["rank"],
                      name: leaderboard[2]["name"],
                      image: leaderboard[2]["image"],
                      coins: leaderboard[2]["coins"],
                      isGold: false,
                      rankColor: const Color(0xffcd7f32),
                      scale: s,
                      textScale: ts,
                      compact: isShort,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: (isShort ? 4 : 8) * hs)),
        SliverToBoxAdapter(child: _buildStatsSummary(s, ts)),
        SliverToBoxAdapter(child: SizedBox(height: (isShort ? 12 : 16) * hs)),
        SliverToBoxAdapter(child: _buildListTitle(s, ts)),
        SliverToBoxAdapter(child: SizedBox(height: 12 * hs)),
        if (leaderboard.length <= 3)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24 * s),
                child: Text(
                  "More players will appear here",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13 * ts,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: listPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final playerIndex = index + 3;
                final player = leaderboard[playerIndex];

                return _buildLeaderboardTile(
                  player: player,
                  scale: s,
                  textScale: ts,
                  compact: isShort,
                );
              }, childCount: leaderboard.length - 3),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 16 * hs)),
      ],
    );
  }

  Widget _buildStatsSummary(double s, double ts) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16 * s),
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: gold.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.people_rounded,
              "Total Players",
              totalPlayers.toString(),
              s,
              ts,
            ),
          ),
          Container(height: 30 * s, width: 1, color: gold.withOpacity(0.3)),
          Expanded(
            child: _buildStatItem(
              Icons.emoji_events_rounded,
              "Top Prize",
              leaderboard.isNotEmpty ? leaderboard[0]["coins"] : "0",
              s,
              ts,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTitle(double s, double ts) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * s),
      child: Row(
        children: [
          Container(
            width: 3 * s,
            height: 20 * s,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(2 * s),
            ),
          ),
          SizedBox(width: 8 * s),
          Text(
            "ALL PLAYERS",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14 * ts,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20 * s),
              border: Border.all(color: gold.withOpacity(0.3)),
            ),
            child: Text(
              "${leaderboard.length} Players",
              style: TextStyle(
                color: gold,
                fontSize: 11 * ts,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile({
    required Map<String, dynamic> player,
    required double scale,
    required double textScale,
    required bool compact,
  }) {
    final s = scale;
    final ts = textScale;
    final avatarRadius = compact ? 22 * s : 25 * s;
    final rankBox = compact ? 44 * s : 50 * s;

    return Container(
      margin: EdgeInsets.only(bottom: 12 * s),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardPurple.withOpacity(0.95), darkPurple.withOpacity(0.95)],
        ),
        borderRadius: BorderRadius.circular(20 * s),
        border: Border.all(color: gold.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8 * s,
            offset: Offset(0, 2 * s),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 * s : 12 * s),
        child: Row(
          children: [
            Container(
              width: rankBox,
              height: rankBox,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(15 * s),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: FittedBox(
                  child: Text(
                    player["rank"],
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 20 * ts,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12 * s),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2.5 * s),
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: cardPurple,
                backgroundImage: _getProfileImage(player["image"]),
                onBackgroundImageError: (_, __) {},
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player["name"],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15 * ts,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6 * s),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * s,
                      vertical: 4 * s,
                    ),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12 * s),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: gold.withOpacity(0.8),
                          size: 12 * s,
                        ),
                        SizedBox(width: 4 * s),
                        Text(
                          "${player["wins"]} wins",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11 * ts,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8 * s),
            Container(
              constraints: BoxConstraints(maxWidth: 92 * s),
              padding: EdgeInsets.symmetric(
                horizontal: 10 * s,
                vertical: 8 * s,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(25 * s),
                border: Border.all(color: gold.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: gold, size: 16 * s),
                  SizedBox(width: 4 * s),
                  Flexible(
                    child: Text(
                      player["coins"],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12 * ts,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(double s, double ts) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
        Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: gold),
              SizedBox(height: 14 * s),
              Text(
                "Loading leaderboard...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14 * ts,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(double s, double ts) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24 * s),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.24),
        Container(
          padding: EdgeInsets.all(20 * s),
          decoration: BoxDecoration(
            color: cardPurple.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20 * s),
            border: Border.all(color: gold.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(Icons.lock_outline_rounded, color: gold, size: 42 * s),
              SizedBox(height: 12 * s),
              Text(
                errorMessage ?? "Unable to load leaderboard",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gold,
                  fontSize: 18 * ts,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                "Please check Firestore rules for users list permission.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12 * ts),
              ),
              SizedBox(height: 18 * s),
              GestureDetector(
                onTap: _fetchLeaderboardData,
                child: Container(
                  height: 44 * s,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xfff7a900), Color(0xffffcb45)],
                    ),
                    borderRadius: BorderRadius.circular(14 * s),
                  ),
                  child: Center(
                    child: Text(
                      "TRY AGAIN",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13 * ts,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(double s, double ts) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24 * s),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
        Container(
          padding: EdgeInsets.all(20 * s),
          decoration: BoxDecoration(
            color: cardPurple.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20 * s),
            border: Border.all(color: gold.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(Icons.emoji_events_outlined, color: gold, size: 48 * s),
              SizedBox(height: 12 * s),
              Text(
                "No players found",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gold,
                  fontSize: 18 * ts,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                "Leaderboard will show users here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12 * ts),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ImageProvider _getProfileImage(String imageData) {
    if (imageData.isNotEmpty &&
        (imageData.startsWith('/9j/') ||
            imageData.startsWith('data:image') ||
            imageData.contains('base64'))) {
      try {
        final cleanImage = imageData.contains(',')
            ? imageData.split(',').last
            : imageData;
        return MemoryImage(base64Decode(cleanImage));
      } catch (e) {
        return const AssetImage('assets/avatar.png');
      }
    }
    return const AssetImage('assets/avatar.png');
  }

  Widget _buildPodiumItem({
    required String rank,
    required String name,
    required String image,
    required String coins,
    required bool isGold,
    required Color rankColor,
    required double scale,
    required double textScale,
    required bool compact,
  }) {
    final s = scale;
    final ts = textScale;
    final avatarRadius = isGold
        ? (compact ? 32 * s : 36 * s)
        : (compact ? 28 * s : 32 * s);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isGold ? gold : rankColor,
              width: isGold ? 3 * s : 2 * s,
            ),
            boxShadow: isGold
                ? [
                    BoxShadow(
                      color: gold.withOpacity(0.5),
                      blurRadius: 10 * s,
                      spreadRadius: 2 * s,
                    ),
                  ]
                : null,
          ),
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: cardPurple,
            backgroundImage: _getProfileImage(image),
            onBackgroundImageError: (_, __) {},
          ),
        ),
        SizedBox(height: 8 * s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20 * s),
          ),
          child: Text(
            "#$rank",
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.bold,
              fontSize: 12 * ts,
            ),
          ),
        ),
        SizedBox(height: 4 * s),
        SizedBox(
          width: 82 * s,
          child: Text(
            name.split(" ")[0],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isGold ? FontWeight.bold : FontWeight.normal,
              fontSize: 12 * ts,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: 2 * s),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, color: gold, size: 12 * s),
            SizedBox(width: 2 * s),
            Flexible(
              child: Text(
                coins,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: gold,
                  fontSize: 10 * ts,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    double scale,
    double textScale,
  ) {
    final s = scale;
    final ts = textScale;

    return Column(
      children: [
        Icon(icon, color: gold.withOpacity(0.7), size: 20 * s),
        SizedBox(height: 4 * s),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16 * ts,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white54, fontSize: 10 * ts),
        ),
      ],
    );
  }
}
