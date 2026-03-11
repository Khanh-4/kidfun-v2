class ProfileModel {
  final int id;
  final int userId;
  final String profileName;
  final DateTime? dateOfBirth;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.profileName,
    this.dateOfBirth,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      userId: json['userId'],
      profileName: json['profileName'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      avatarUrl: json['avatarUrl'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // Tính tuổi
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}
