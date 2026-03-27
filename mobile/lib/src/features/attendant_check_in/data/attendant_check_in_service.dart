import 'package:dio/dio.dart';

class AttendantCheckInResult {
  const AttendantCheckInResult({
    required this.sessionId,
    required this.parkingLotId,
    required this.currentAvailable,
    required this.licensePlate,
    required this.vehicleType,
    required this.checkedInAt,
  });

  final int sessionId;
  final int parkingLotId;
  final int currentAvailable;
  final String licensePlate;
  final String vehicleType;
  final DateTime checkedInAt;

  factory AttendantCheckInResult.fromJson(Map<String, dynamic> json) {
    return AttendantCheckInResult(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      currentAvailable: json['current_available'] as int,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
    );
  }
}

abstract class AttendantCheckInService {
  Future<AttendantCheckInResult> checkInDriver({required String token});
}

class BackendAttendantCheckInService implements AttendantCheckInService {
  BackendAttendantCheckInService({
    required Dio dio,
    required String accessToken,
  }) : _dio = dio,
       _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<AttendantCheckInResult> checkInDriver({required String token}) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-check-in',
        data: {'token': token},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AttendantCheckInException(
          'Phản hồi check-in từ máy chủ không hợp lệ.',
        );
      }
      return AttendantCheckInResult.fromJson(raw);
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Không thể xử lý check-in lúc này. Vui lòng thử lại.';
  }
}

class AttendantCheckInException implements Exception {
  const AttendantCheckInException(this.message);

  final String message;

  @override
  String toString() => message;
}
