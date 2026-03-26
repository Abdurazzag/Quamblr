class User {
  final int userId;
  final String username;

  const User({
    required this.userId,
    required this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: (json['userId'] as num).toInt(),
      username: json['username']?.toString() ?? '',
    );
  }
}