class User {
  final String id;
  final String fullName;
  final String username;
  final String role;  // "photographer" or "admin"
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == "admin";

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      username: json['username'] as String,
      role: json['role'] as String? ?? "photographer",
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
