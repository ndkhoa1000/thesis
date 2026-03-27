import 'package:dio/dio.dart';

class OperatorManagedParkingLot {
  const OperatorManagedParkingLot({
    required this.id,
    required this.leaseId,
    required this.lotOwnerId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currentAvailable,
    required this.status,
    required this.occupiedCount,
    this.totalCapacity,
    this.description,
    this.coverImage,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int leaseId;
  final int lotOwnerId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int currentAvailable;
  final String status;
  final int occupiedCount;
  final int? totalCapacity;
  final String? description;
  final String? coverImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConfigured => totalCapacity != null;

  String get statusLabel => switch (status) {
    'APPROVED' => 'Đang vận hành',
    'CLOSED' => 'Đang tạm dừng',
    _ => status,
  };

  factory OperatorManagedParkingLot.fromJson(Map<String, dynamic> json) {
    return OperatorManagedParkingLot(
      id: json['id'] as int,
      leaseId: json['lease_id'] as int,
      lotOwnerId: json['lot_owner_id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      occupiedCount: json['occupied_count'] as int? ?? 0,
      totalCapacity: json['total_capacity'] as int?,
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

abstract class OperatorLotManagementService {
  Future<List<OperatorManagedParkingLot>> getManagedParkingLots();

  Future<OperatorManagedParkingLot> updateManagedParkingLot({
    required int parkingLotId,
    required String name,
    required String address,
    required int totalCapacity,
    String? description,
    String? coverImage,
  });
}

class BackendOperatorLotManagementService
    implements OperatorLotManagementService {
  BackendOperatorLotManagementService({
    required Dio dio,
    required String accessToken,
  }) : _dio = dio,
       _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<List<OperatorManagedParkingLot>> getManagedParkingLots() async {
    try {
      final response = await _dio.get<dynamic>(
        '/operator/parking-lots',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const OperatorLotManagementException(
          'Phản hồi danh sách bãi xe vận hành không hợp lệ.',
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(OperatorManagedParkingLot.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw OperatorLotManagementException(_extractMessage(error));
    }
  }

  @override
  Future<OperatorManagedParkingLot> updateManagedParkingLot({
    required int parkingLotId,
    required String name,
    required String address,
    required int totalCapacity,
    String? description,
    String? coverImage,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/operator/parking-lots/$parkingLotId',
        data: {
          'name': name,
          'address': address,
          'total_capacity': totalCapacity,
          'description': description,
          'cover_image': coverImage,
        },
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const OperatorLotManagementException(
          'Phản hồi cấu hình bãi xe không hợp lệ.',
        );
      }
      return OperatorManagedParkingLot.fromJson(raw);
    } on DioException catch (error) {
      throw OperatorLotManagementException(_extractMessage(error));
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
    return 'Không thể tải hoặc lưu cấu hình bãi xe lúc này.';
  }
}

class OperatorLotManagementException implements Exception {
  const OperatorLotManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
