class User {
  final String id;
  final String name;
  final String username;
  final String email;
  final String role;
  final String? profileImage;
  final String? phone;
  final String? department;
  final String? designation;
  final bool forcePasswordChange;

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    this.profileImage,
    this.phone,
    this.department,
    this.designation,
    this.forcePasswordChange = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['user_id'])?.toString() ?? '',
      name: json['name'] ?? json['user_name'] ?? 'User',
      username: json['username'] ?? json['user_code'] ?? '',
      email: json['email'] ?? '',
      // Normalize role to lowercase to ensure consistent comparison
      role: (json['role'] ?? json['user_type'] ?? 'employee').toString().toLowerCase(),
      profileImage: json['profile_image'] ?? json['profile_image_url'] ?? json['avatar_url'],
      phone: json['phone'] ?? json['phone_no'],
      department: json['department'] ?? json['dept_name'],
      designation: json['designation'] ?? json['desg_name'],
      forcePasswordChange: json['force_password_change'] == 1 ||
          json['force_password_change'] == true ||
          json['force_password_change'].toString().toLowerCase() == 'true',
    );
  }

  bool get isAdmin => role == 'admin' || role == 'hr';
  bool get isHr => role == 'hr';
  bool get isSystemAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
  
  // Alias for clarity as per API docs (user_code = Employee ID)
  String get employeeId => username;

  User copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? role,
    String? profileImage,
    String? phone,
    String? department,
    String? designation,
    bool? forcePasswordChange,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'role': role,
      'profile_image': profileImage,
      'phone': phone,
      'department': department,
      'designation': designation,
      'force_password_change': forcePasswordChange,
    };
  }
}
