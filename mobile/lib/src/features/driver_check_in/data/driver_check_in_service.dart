import 'package:dio/dio.dart';

import '../../vehicles/data/vehicle_service.dart';

class DriverCheckInQr {
  const DriverCheckInQr({
    required this.token,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.vehicle,
  });

  final String token;
  final DateTime expiresAt;
  final int expiresInSeconds;
  final Vehicle vehicle;

  factory DriverCheckInQr.fromJson(Map<String, dynamic> json) {
    final rawVehicle = json['vehicle'];
    if (rawVehicle is! Map<String, dynamic>) {
      throw const DriverCheckInException('Phản hồi xe không hợp lệ.');
    }

    return DriverCheckInQr(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      expiresInSeconds: json['expires_in_seconds'] as int,
      vehicle: Vehicle.fromJson(rawVehicle),
    );
  }
}

class DriverActiveSession {
  const DriverActiveSession({
    required this.sessionId,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.licensePlate,
    required this.vehicleType,
    required this.checkedInAt,
    required this.elapsedMinutes,
    required this.estimatedCost,
    required this.pricingMode,
  });

  final int sessionId;
  final int parkingLotId;
  final String parkingLotName;
  final String licensePlate;
  final String vehicleType;
  final DateTime checkedInAt;
  final int elapsedMinutes;
  final double estimatedCost;
  final String? pricingMode;

  factory DriverActiveSession.fromJson(Map<String, dynamic> json) {
    return DriverActiveSession(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      elapsedMinutes: json['elapsed_minutes'] as int,
      estimatedCost: (json['estimated_cost'] as num).toDouble(),
      pricingMode: json['pricing_mode'] as String?,
    );
  }
}

class DriverCheckOutQr {
  const DriverCheckOutQr({
    required this.token,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.sessionId,
    required this.licensePlate,
  });

  final String token;
  final DateTime expiresAt;
  final int expiresInSeconds;
  final int sessionId;
  final String licensePlate;

  factory DriverCheckOutQr.fromJson(Map<String, dynamic> json) {
    return DriverCheckOutQr(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      expiresInSeconds: json['expires_in_seconds'] as int,
      sessionId: json['session_id'] as int,
      licensePlate: json['license_plate'] as String,
    );
  }
}

abstract class DriverCheckInService {
  Future<DriverActiveSession?> getActiveSession();
  Future<DriverCheckInQr> createCheckInQr({required int vehicleId});
  Future<DriverCheckOutQr> createCheckOutQr();
}

class BackendDriverCheckInService implements DriverCheckInService {
  BackendDriverCheckInService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<DriverActiveSession?> getActiveSession() async {
    try {
      final response = await _dio.get<dynamic>(
        '/sessions/driver-active-session',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const DriverCheckInException('Phản hồi máy chủ không hợp lệ.');
      }
      return DriverActiveSession.fromJson(raw);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      throw DriverCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<DriverCheckInQr> createCheckInQr({required int vehicleId}) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/driver-check-in-token',
        data: {'vehicle_id': vehicleId},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const DriverCheckInException('Phản hồi máy chủ không hợp lệ.');
      }
      return DriverCheckInQr.fromJson(raw);
    } on DioException catch (error) {
      throw DriverCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<DriverCheckOutQr> createCheckOutQr() async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/driver-check-out-token',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const DriverCheckInException('Phản hồi máy chủ không hợp lệ.');
      }
      return DriverCheckOutQr.fromJson(raw);
    } on DioException catch (error) {
      throw DriverCheckInException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Không thể tạo mã check-in lúc này. Vui lòng thử lại.';
  }
}

class DriverCheckInException implements Exception {
  const DriverCheckInException(this.message);

  final String message;

  @override
  String toString() => message;
}
