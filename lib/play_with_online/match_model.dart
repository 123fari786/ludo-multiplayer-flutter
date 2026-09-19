class MatchPlayer {
  final String userId;
  final String userName;
  final String profileImage;
  final int coins;
  bool colorSelected;
  String? color;

  MatchPlayer({
    required this.userId,
    required this.userName,
    required this.profileImage,
    required this.coins,
    this.colorSelected = false,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'profileImage': profileImage,
    'coins': coins,
    'colorSelected': colorSelected,
    'color': color,
  };

  factory MatchPlayer.fromJson(Map<String, dynamic> json) => MatchPlayer(
    userId: json['userId'],
    userName: json['userName'],
    profileImage: json['profileImage'],
    coins: json['coins'],
    colorSelected: json['colorSelected'] ?? false,
    color: json['color'],
  );
}

class MatchData {
  final String matchId;
  final MatchPlayer player1;
  final MatchPlayer player2;
  final int entryFee;
  String status;
  final DateTime createdAt;
  String? winner;

  MatchData({
    required this.matchId,
    required this.player1,
    required this.player2,
    required this.entryFee,
    required this.status,
    required this.createdAt,
    this.winner,
  });

  factory MatchData.fromJson(String matchId, Map<String, dynamic> json) =>
      MatchData(
        matchId: matchId,
        player1: MatchPlayer.fromJson(json['player1']),
        player2: MatchPlayer.fromJson(json['player2']),
        entryFee: json['entryFee'],
        status: json['status'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
        winner: json['winner'],
      );
}
