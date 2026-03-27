import 'package:dio/dio.dart';

// ─── Domain model ────────────────────────────────────────────────────────────

class Vehicle {
  const Vehicle({
    required this.id,
    required this.licensePlate,
    required this.vehicleType,
  });

  final int id;
  final String licensePlate;
  final String vehicleType;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as int,
    licensePlate: json['license_plate'] as String,
    vehicleType: json['vehicle_type'] as String,
  );
}

// ─── Abstract contract ────────────────────────────────────────────────────────

abstract class VehicleService {
  Future<List<Vehicle>> listVehicles();
  Future<Vehicle> createVehicle({
    required String licensePlate,
    required String vehicleType,
  });
  Future<void> deleteVehicle(int vehicleId);
}

// ─── Backend implementation ───────────────────────────────────────────────────

class BackendVehicleService implements VehicleService {
  BackendVehicleService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<List<Vehicle>> listVehicles() async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/me/vehicles',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Vehicle.fromJson)
          .toList();
    } on DioException catch (e) {
      throw VehicleException(_extractMessage(e));
    }
  }

  @override
  Future<Vehicle> createVehicle({
    required String licensePlate,
    required String vehicleType,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/user/me/vehicles',
        data: {'license_plate': licensePlate, 'vehicle_type': vehicleType},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const VehicleException('Phản hồi máy chủ không hợp lệ.');
      }
      return Vehicle.fromJson(raw);
    } on DioException catch (e) {
      throw VehicleException(_extractMessage(e));
    }
  }

  @override
  Future<void> deleteVehicle(int vehicleId) async {
    try {
      await _dio.delete<dynamic>(
        '/user/me/vehicles/$vehicleId',
        options: _authOptions,
      );
    } on DioException catch (e) {
      throw VehicleException(_extractMessage(e));
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Lỗi kết nối máy chủ. Vui lòng thử lại.';
  }
}

// ─── Exception ────────────────────────────────────────────────────────────────

class VehicleException implements Exception {
  const VehicleException(this.message);
  final String message;
  @override
  String toString() => message;
}
