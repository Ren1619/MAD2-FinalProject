class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final String createdAt;
  final String? companyId;
  final String? phone;
  final bool enableNotifications;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.companyId,
    this.phone,
    this.enableNotifications = true,
  });

  // Convert a User object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'createdAt': createdAt,
      'companyId': companyId,
      'phone': phone,
      'enableNotifications': enableNotifications ? 1 : 0,
    };
  }

  // Create a User object from a Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      status: map['status'] ?? '',
      createdAt: map['createdAt'] ?? '',
      companyId: map['companyId'],
      phone: map['phone'],
      enableNotifications: map['enableNotifications'] == 1,
    );
  }
}