import 'dart:convert';

/// Serialisable metadata for a captured photo.
class PhotoModel {
  final String id;
  final String path;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final String userName;
  final String societyName;

  const PhotoModel({
    required this.id,
    required this.path,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.userName,
    required this.societyName,
  });

  PhotoModel copyWith({String? path, String? societyName}) => PhotoModel(
        id: id,
        path: path ?? this.path,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        userName: userName,
        societyName: societyName ?? this.societyName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'userName': userName,
        'societyName': societyName,
      };

  factory PhotoModel.fromJson(Map<String, dynamic> json) => PhotoModel(
        id: json['id'] as String,
        path: json['path'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        userName: json['userName'] as String? ?? '',
        societyName: json['societyName'] as String? ?? '',
      );

  static String encodeList(List<PhotoModel> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<PhotoModel> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((e) => PhotoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
