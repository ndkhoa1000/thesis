import 'package:dio/dio.dart';

class ParkingLotRegistration {
  const ParkingLotRegistration({
    required this.id,
    required this.lotOwnerId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currentAvailable,
    required this.status,
    this.description,
    this.coverImage,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int lotOwnerId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int currentAvailable;
  final String status;
  final String? description;
  final String? coverImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory ParkingLotRegistration.fromJson(Map<String, dynamic> json) {
    return ParkingLotRegistration(
      id: json['id'] as int,
      lotOwnerId: json['lot_owner_id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

abstract class ParkingLotService {
  Future<List<ParkingLotRegistration>> getMyParkingLots();

  Future<ParkingLotRegistration> createParkingLot({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    String? coverImage,
  });
}

class BackendParkingLotService implements ParkingLotService {
  BackendParkingLotService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<List<ParkingLotRegistration>> getMyParkingLots() async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/me/parking-lots',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const ParkingLotException(
          'Phản hồi danh sách bãi xe không hợp lệ.',
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ParkingLotRegistration.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ParkingLotException(_extractMessage(error));
    }
  }

  @override
  Future<ParkingLotRegistration> createParkingLot({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    String? coverImage,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/user/me/parking-lots',
        data: {
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          'cover_image': coverImage,
        },
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const ParkingLotException('Phản hồi tạo bãi xe không hợp lệ.');
      }
      return ParkingLotRegistration.fromJson(raw);
    } on DioException catch (error) {
      throw ParkingLotException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
    }
    return 'Không thể xử lý đăng ký bãi xe lúc này. Vui lòng thử lại.';
  }
}

class ParkingLotException implements Exception {
  const ParkingLotException(this.message);

  final String message;

  @override
  String toString() => message;
}
