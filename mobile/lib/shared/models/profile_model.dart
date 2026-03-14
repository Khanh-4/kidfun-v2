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
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['userId'] is int ? json['userId'] as int : int.tryParse(json['userId']?.toString() ?? '0') ?? 0,
      profileName: json['profileName']?.toString() ?? 'Unknown',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      avatarUrl: json['avatarUrl']?.toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
