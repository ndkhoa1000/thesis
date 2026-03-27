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

abstract class DriverCheckInService {
  Future<DriverCheckInQr> createCheckInQr({required int vehicleId});
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
