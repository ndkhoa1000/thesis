import 'package:dio/dio.dart';

enum MapDiscoveryAvailabilityState { available, limited, full }

class MapDiscoveryLotSummary {
  const MapDiscoveryLotSummary({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currentAvailable,
    required this.status,
    this.description,
    this.coverImage,
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int currentAvailable;
  final String status;
  final String? description;
  final String? coverImage;

  bool get isFull => currentAvailable <= 0;

  MapDiscoveryAvailabilityState get availabilityState {
    if (currentAvailable <= 0) {
      return MapDiscoveryAvailabilityState.full;
    }
    if (currentAvailable <= 5) {
      return MapDiscoveryAvailabilityState.limited;
    }
    return MapDiscoveryAvailabilityState.available;
  }

  String get availabilityText => isFull ? 'Đầy' : 'Còn $currentAvailable chỗ';

  String get markerCountLabel => isFull ? '0' : '$currentAvailable';

  factory MapDiscoveryLotSummary.fromJson(Map<String, dynamic> json) {
    return MapDiscoveryLotSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
    );
  }
}

abstract class MapDiscoveryService {
  Future<List<MapDiscoveryLotSummary>> fetchActiveLots();
}

class BackendMapDiscoveryService implements MapDiscoveryService {
  BackendMapDiscoveryService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<List<MapDiscoveryLotSummary>> fetchActiveLots() async {
    try {
      final response = await _dio.get<dynamic>('/lots', options: _authOptions);
      final raw = response.data;
      if (raw is! List) {
        throw const MapDiscoveryException(
          'Phản hồi danh sách bãi xe không hợp lệ.',
        );
      }

      return raw
          .whereType<Map<String, dynamic>>()
          .map(MapDiscoveryLotSummary.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw MapDiscoveryException(_extractMessage(error));
    } on TypeError {
      throw const MapDiscoveryException(
        'Không thể đọc dữ liệu bãi xe từ máy chủ.',
      );
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return 'Không thể tải danh sách bãi xe lúc này.';
  }
}

class MapDiscoveryException implements Exception {
  const MapDiscoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}
