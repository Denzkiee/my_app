class User {
  final String? id;
  final String fullName;
  final String email;
  final String role;

  User({
    this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String?,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String? ?? 'user',
    );
  }
}
