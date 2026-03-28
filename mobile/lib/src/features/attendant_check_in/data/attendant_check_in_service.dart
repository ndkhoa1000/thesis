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

class AttendantCheckOutPreviewResult {
  const AttendantCheckOutPreviewResult({
    required this.sessionId,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.licensePlate,
    required this.vehicleType,
    required this.checkedInAt,
    required this.elapsedMinutes,
    required this.finalFee,
    required this.pricingMode,
  });

  final int sessionId;
  final int parkingLotId;
  final String parkingLotName;
  final String licensePlate;
  final String vehicleType;
  final DateTime checkedInAt;
  final int elapsedMinutes;
  final double finalFee;
  final String pricingMode;

  factory AttendantCheckOutPreviewResult.fromJson(Map<String, dynamic> json) {
    return AttendantCheckOutPreviewResult(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      elapsedMinutes: json['elapsed_minutes'] as int,
      finalFee: (json['final_fee'] as num).toDouble(),
      pricingMode: json['pricing_mode'] as String,
    );
  }
}

class AttendantCheckOutFinalizeResult {
  const AttendantCheckOutFinalizeResult({
    required this.sessionId,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.licensePlate,
    required this.vehicleType,
    required this.finalFee,
    required this.paymentMethod,
    required this.checkedOutAt,
    required this.currentAvailable,
  });

  final int sessionId;
  final int parkingLotId;
  final String parkingLotName;
  final String licensePlate;
  final String vehicleType;
  final double finalFee;
  final String paymentMethod;
  final DateTime checkedOutAt;
  final int currentAvailable;

  factory AttendantCheckOutFinalizeResult.fromJson(Map<String, dynamic> json) {
    return AttendantCheckOutFinalizeResult(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      finalFee: (json['final_fee'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      checkedOutAt: DateTime.parse(json['checked_out_at'] as String),
      currentAvailable: json['current_available'] as int,
    );
  }
}

class AttendantCheckOutUndoResult {
  const AttendantCheckOutUndoResult({
    required this.sessionId,
    required this.parkingLotId,
    required this.currentAvailable,
    required this.status,
  });

  final int sessionId;
  final int parkingLotId;
  final int currentAvailable;
  final String status;

  factory AttendantCheckOutUndoResult.fromJson(Map<String, dynamic> json) {
    return AttendantCheckOutUndoResult(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      currentAvailable: json['current_available'] as int,
      status: json['status'] as String,
    );
  }
}

abstract class AttendantCheckInService {
  Future<AttendantCheckInResult> checkInDriver({required String token});

  Future<AttendantCheckInResult> checkInWalkIn({
    required String vehicleType,
    required String plateImagePath,
    String? overviewImagePath,
  });

  Future<AttendantCheckOutPreviewResult> checkOutPreview({
    required String token,
  });

  Future<AttendantCheckOutFinalizeResult> finalizeCheckOut({
    required int sessionId,
    required String paymentMethod,
    double? quotedFinalFee,
  });

  Future<AttendantCheckOutUndoResult> undoCheckOut({required int sessionId});
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

  @override
  Future<AttendantCheckInResult> checkInWalkIn({
    required String vehicleType,
    required String plateImagePath,
    String? overviewImagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'vehicle_type': vehicleType,
        'plate_image': await MultipartFile.fromFile(
          plateImagePath,
          filename: plateImagePath.split('/').last,
        ),
        if (overviewImagePath != null)
          'overview_image': await MultipartFile.fromFile(
            overviewImagePath,
            filename: overviewImagePath.split('/').last,
          ),
      });

      final response = await _dio.post<dynamic>(
        '/sessions/attendant-walk-in-check-in',
        data: formData,
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AttendantCheckInException(
          'Phan hoi walk-in check-in tu may chu khong hop le.',
        );
      }
      return AttendantCheckInResult.fromJson(raw);
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantCheckOutPreviewResult> checkOutPreview({
    required String token,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-check-out-preview',
        data: {'token': token},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AttendantCheckInException(
          'Phan hoi check-out tu may chu khong hop le.',
        );
      }
      return AttendantCheckOutPreviewResult.fromJson(raw);
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantCheckOutFinalizeResult> finalizeCheckOut({
    required int sessionId,
    required String paymentMethod,
    double? quotedFinalFee,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-check-out-finalize',
        data: {
          'session_id': sessionId,
          'payment_method': paymentMethod,
          if (quotedFinalFee != null) 'quoted_final_fee': quotedFinalFee,
        },
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AttendantCheckInException(
          'Phan hoi finalize checkout tu may chu khong hop le.',
        );
      }
      return AttendantCheckOutFinalizeResult.fromJson(raw);
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantCheckOutUndoResult> undoCheckOut({
    required int sessionId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-check-out-undo',
        data: {'session_id': sessionId},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AttendantCheckInException(
          'Phan hoi undo checkout tu may chu khong hop le.',
        );
      }
      return AttendantCheckOutUndoResult.fromJson(raw);
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
