class DeviceModel {
  final int id;
  final int profileId;
  final String deviceName;
  final String deviceIdentifier;
  final String status;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.profileId,
    required this.deviceName,
    required this.deviceIdentifier,
    required this.status,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] ?? 0,
      profileId: json['profileId'] ?? 0,
      deviceName: json['deviceName'] ?? '',
      deviceIdentifier: json['deviceIdentifier'] ?? '',
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
