class DeviceModel {
  final int id;
  final int userId;
  final int? profileId;
  final String deviceName;
  final String deviceCode;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.userId,
    this.profileId,
    required this.deviceName,
    required this.deviceCode,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? 0,
      profileId: json['profileId'] as int?,
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      deviceCode: json['deviceCode'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen']) 
          : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  /// Copy with — dùng để cập nhật online/offline mà không gọi API lại
  DeviceModel copyWith({bool? isOnline, DateTime? lastSeen}) {
    return DeviceModel(
      id: id,
      userId: userId,
      profileId: profileId,
      deviceName: deviceName,
      deviceCode: deviceCode,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}
