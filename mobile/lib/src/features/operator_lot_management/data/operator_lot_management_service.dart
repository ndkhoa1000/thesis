import 'package:dio/dio.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _normalizeTime(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value.length >= 5 ? value.substring(0, 5) : value;
}

class OperatorManagedAttendant {
  const OperatorManagedAttendant({
    required this.id,
    required this.userId,
    required this.parkingLotId,
    required this.name,
    required this.username,
    required this.email,
    required this.isActive,
    this.phone,
    this.hiredAt,
  });

  final int id;
  final int userId;
  final int parkingLotId;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final bool isActive;
  final DateTime? hiredAt;

  factory OperatorManagedAttendant.fromJson(Map<String, dynamic> json) {
    return OperatorManagedAttendant(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      hiredAt: _parseDateTime(json['hired_at']),
    );
  }
}

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
    this.openingTime,
    this.closingTime,
    this.pricingMode,
    this.priceAmount,
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
  final String? openingTime;
  final String? closingTime;
  final String? pricingMode;
  final double? priceAmount;
  final String? description;
  final String? coverImage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isConfigured => totalCapacity != null;

  String get operatingHoursLabel {
    if (openingTime == null || closingTime == null) {
      return 'Chưa cấu hình giờ hoạt động';
    }
    return '$openingTime - $closingTime';
  }

  String get pricingLabel {
    if (pricingMode == null || priceAmount == null) {
      return 'Chưa cấu hình giá';
    }

    final normalizedAmount = priceAmount == priceAmount!.roundToDouble()
        ? priceAmount!.round().toString()
        : priceAmount!.toStringAsFixed(2);
    final modeLabel = switch (pricingMode) {
      'HOURLY' => 'Theo giờ',
      'SESSION' => 'Theo lượt',
      _ => pricingMode,
    };
    return '$modeLabel: $normalizedAmount VND';
  }

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
      openingTime: _normalizeTime(json['opening_time']),
      closingTime: _normalizeTime(json['closing_time']),
      pricingMode: json['pricing_mode'] as String?,
      priceAmount: (json['price_amount'] as num?)?.toDouble(),
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

abstract class OperatorLotManagementService {
  Future<List<OperatorManagedParkingLot>> getManagedParkingLots();

  Future<List<OperatorManagedAttendant>> getLotAttendants({
    required int parkingLotId,
  });

  Future<OperatorManagedAttendant> createLotAttendant({
    required int parkingLotId,
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  });

  Future<void> removeLotAttendant({
    required int parkingLotId,
    required int attendantId,
  });

  Future<OperatorManagedParkingLot> updateManagedParkingLot({
    required int parkingLotId,
    required String name,
    required String address,
    required int totalCapacity,
    required String openingTime,
    required String closingTime,
    required String pricingMode,
    required double priceAmount,
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
  Future<List<OperatorManagedAttendant>> getLotAttendants({
    required int parkingLotId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/operator/parking-lots/$parkingLotId/attendants',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const OperatorLotManagementException(
          'Phản hồi danh sách attendant không hợp lệ.',
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(OperatorManagedAttendant.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw OperatorLotManagementException(_extractMessage(error));
    }
  }

  @override
  Future<OperatorManagedAttendant> createLotAttendant({
    required int parkingLotId,
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/operator/parking-lots/$parkingLotId/attendants',
        data: {
          'name': name,
          'username': username,
          'email': email,
          'password': password,
          'phone': phone,
        },
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const OperatorLotManagementException(
          'Phản hồi tạo tài khoản attendant không hợp lệ.',
        );
      }
      return OperatorManagedAttendant.fromJson(raw);
    } on DioException catch (error) {
      throw OperatorLotManagementException(_extractMessage(error));
    }
  }

  @override
  Future<void> removeLotAttendant({
    required int parkingLotId,
    required int attendantId,
  }) async {
    try {
      await _dio.delete<dynamic>(
        '/operator/parking-lots/$parkingLotId/attendants/$attendantId',
        options: _authOptions,
      );
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
    required String openingTime,
    required String closingTime,
    required String pricingMode,
    required double priceAmount,
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
          'opening_time': '$openingTime:00',
          'closing_time': '$closingTime:00',
          'pricing_mode': pricingMode,
          'price_amount': priceAmount,
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
