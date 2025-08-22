class PasswordEntry {
  final int? id;
  final int userId;
  final String title;
  final String username;
  final String encryptedPassword; // 加密后的密码
  final String? website;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PasswordEntry({
    this.id,
    required this.userId,
    required this.title,
    required this.username,
    required this.encryptedPassword,
    this.website,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'username': username,
      'password': encryptedPassword,
      'website': website,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory PasswordEntry.fromMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      username: map['username'],
      encryptedPassword: map['password'],
      website: map['website'],
      note: map['note'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  PasswordEntry copyWith({
    int? id,
    int? userId,
    String? title,
    String? username,
    String? encryptedPassword,
    String? website,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      username: username ?? this.username,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      website: website ?? this.website,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
