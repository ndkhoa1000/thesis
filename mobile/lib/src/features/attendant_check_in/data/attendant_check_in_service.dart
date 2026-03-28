import 'package:dio/dio.dart';

class AttendantOccupancyVehicleBreakdown {
  const AttendantOccupancyVehicleBreakdown({
    required this.vehicleType,
    required this.occupiedCount,
  });

  final String vehicleType;
  final int occupiedCount;

  factory AttendantOccupancyVehicleBreakdown.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendantOccupancyVehicleBreakdown(
      vehicleType: json['vehicle_type'] as String,
      occupiedCount: json['occupied_count'] as int? ?? 0,
    );
  }
}

class AttendantOccupancySummary {
  const AttendantOccupancySummary({
    required this.parkingLotId,
    required this.parkingLotName,
    required this.hasActiveCapacityConfig,
    required this.totalCapacity,
    required this.freeCount,
    required this.occupiedCount,
    required this.vehicleTypeBreakdown,
  });

  final int parkingLotId;
  final String parkingLotName;
  final bool hasActiveCapacityConfig;
  final int? totalCapacity;
  final int? freeCount;
  final int? occupiedCount;
  final List<AttendantOccupancyVehicleBreakdown> vehicleTypeBreakdown;

  factory AttendantOccupancySummary.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['vehicle_type_breakdown'];
    return AttendantOccupancySummary(
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      hasActiveCapacityConfig:
          json['has_active_capacity_config'] as bool? ?? false,
      totalCapacity: json['total_capacity'] as int?,
      freeCount: json['free_count'] as int?,
      occupiedCount: json['occupied_count'] as int?,
      vehicleTypeBreakdown: rawBreakdown is List
          ? rawBreakdown
                .whereType<Map<String, dynamic>>()
                .map(AttendantOccupancyVehicleBreakdown.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

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

class AttendantActiveSession {
  const AttendantActiveSession({
    required this.sessionId,
    required this.parkingLotId,
    required this.licensePlate,
    required this.vehicleType,
    required this.checkedInAt,
    required this.elapsedMinutes,
  });

  final int sessionId;
  final int parkingLotId;
  final String licensePlate;
  final String vehicleType;
  final DateTime checkedInAt;
  final int elapsedMinutes;

  factory AttendantActiveSession.fromJson(Map<String, dynamic> json) {
    return AttendantActiveSession(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      elapsedMinutes: json['elapsed_minutes'] as int? ?? 0,
    );
  }
}

class AttendantForceCloseTimeoutResult {
  const AttendantForceCloseTimeoutResult({
    required this.sessionId,
    required this.parkingLotId,
    required this.licensePlate,
    required this.vehicleType,
    required this.timeoutAt,
    required this.currentAvailable,
    required this.status,
    required this.reason,
  });

  final int sessionId;
  final int parkingLotId;
  final String licensePlate;
  final String vehicleType;
  final DateTime timeoutAt;
  final int currentAvailable;
  final String status;
  final String reason;

  factory AttendantForceCloseTimeoutResult.fromJson(Map<String, dynamic> json) {
    return AttendantForceCloseTimeoutResult(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      timeoutAt: DateTime.parse(json['timeout_at'] as String),
      currentAvailable: json['current_available'] as int,
      status: json['status'] as String,
      reason: json['reason'] as String,
    );
  }
}

class AttendantShiftHandoverStartResult {
  const AttendantShiftHandoverStartResult({
    required this.shiftId,
    required this.parkingLotId,
    required this.expectedCash,
    required this.token,
    required this.expiresAt,
    required this.expiresInSeconds,
  });

  final int shiftId;
  final int parkingLotId;
  final double expectedCash;
  final String token;
  final DateTime expiresAt;
  final int expiresInSeconds;

  factory AttendantShiftHandoverStartResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendantShiftHandoverStartResult(
      shiftId: json['shift_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      expectedCash: (json['expected_cash'] as num).toDouble(),
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      expiresInSeconds: json['expires_in_seconds'] as int,
    );
  }
}

class AttendantShiftHandoverFinalizeResult {
  const AttendantShiftHandoverFinalizeResult({
    required this.handoverId,
    required this.outgoingShiftId,
    required this.incomingShiftId,
    required this.expectedCash,
    required this.actualCash,
    required this.discrepancyFlagged,
    required this.completedAt,
  });

  final int handoverId;
  final int outgoingShiftId;
  final int incomingShiftId;
  final double expectedCash;
  final double actualCash;
  final bool discrepancyFlagged;
  final DateTime completedAt;

  factory AttendantShiftHandoverFinalizeResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendantShiftHandoverFinalizeResult(
      handoverId: json['handover_id'] as int,
      outgoingShiftId: json['outgoing_shift_id'] as int,
      incomingShiftId: json['incoming_shift_id'] as int,
      expectedCash: (json['expected_cash'] as num).toDouble(),
      actualCash: (json['actual_cash'] as num).toDouble(),
      discrepancyFlagged: json['discrepancy_flagged'] as bool? ?? false,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }
}

class AttendantFinalShiftCloseOutResult {
  const AttendantFinalShiftCloseOutResult({
    required this.closeOutId,
    required this.shiftId,
    required this.parkingLotId,
    required this.expectedCash,
    required this.currentAvailable,
    required this.activeSessionCount,
    required this.status,
    required this.requestedAt,
  });

  final int closeOutId;
  final int shiftId;
  final int parkingLotId;
  final double expectedCash;
  final int currentAvailable;
  final int activeSessionCount;
  final String status;
  final DateTime requestedAt;

  factory AttendantFinalShiftCloseOutResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendantFinalShiftCloseOutResult(
      closeOutId: json['close_out_id'] as int,
      shiftId: json['shift_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      expectedCash: (json['expected_cash'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      activeSessionCount: json['active_session_count'] as int? ?? 0,
      status: json['status'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String),
    );
  }
}

abstract class AttendantCheckInService {
  Future<AttendantOccupancySummary> getOccupancySummary();

  Future<List<AttendantActiveSession>> getActiveSessions();

  Future<AttendantShiftHandoverStartResult> prepareShiftHandover();

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
    required double quotedFinalFee,
  });

  Future<AttendantForceCloseTimeoutResult> forceCloseTimeout({
    required int sessionId,
    required String reason,
  });

  Future<AttendantShiftHandoverFinalizeResult> finalizeShiftHandover({
    required String token,
    required double actualCash,
    String? discrepancyReason,
  });

  Future<AttendantFinalShiftCloseOutResult> requestFinalShiftCloseOut() async {
    throw UnimplementedError();
  }

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

  T _parseResponse<T>(
    dynamic raw,
    T Function(Map<String, dynamic> json) parser,
    String invalidResponseMessage,
  ) {
    if (raw is! Map<String, dynamic>) {
      throw AttendantCheckInException(invalidResponseMessage);
    }

    try {
      return parser(raw);
    } on FormatException {
      throw AttendantCheckInException(invalidResponseMessage);
    } on TypeError {
      throw AttendantCheckInException(invalidResponseMessage);
    }
  }

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    try {
      final response = await _dio.get<dynamic>(
        '/sessions/attendant-occupancy-summary',
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantOccupancySummary.fromJson,
        'Phan hoi thong ke bai xe tu may chu khong hop le.',
      );
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<List<AttendantActiveSession>> getActiveSessions() async {
    try {
      final response = await _dio.get<dynamic>(
        '/sessions/attendant-active-sessions',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const AttendantCheckInException(
          'Phan hoi danh sach phien dang gui khong hop le.',
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(AttendantActiveSession.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantShiftHandoverStartResult> prepareShiftHandover() async {
    try {
      final response = await _dio.post<dynamic>(
        '/shifts/attendant-handover/start',
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantShiftHandoverStartResult.fromJson,
        'Phan hoi tao QR giao ca khong hop le.',
      );
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantFinalShiftCloseOutResult> requestFinalShiftCloseOut() async {
    try {
      final response = await _dio.post<dynamic>(
        '/shifts/attendant-final-close-out/request',
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantFinalShiftCloseOutResult.fromJson,
        'Phan hoi dong ca cuoi ngay khong hop le.',
      );
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantCheckInResult> checkInDriver({required String token}) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-check-in',
        data: {'token': token},
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantCheckInResult.fromJson,
        'Phản hồi check-in từ máy chủ không hợp lệ.',
      );
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
      return _parseResponse(
        response.data,
        AttendantCheckInResult.fromJson,
        'Phan hoi walk-in check-in tu may chu khong hop le.',
      );
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
      return _parseResponse(
        response.data,
        AttendantCheckOutPreviewResult.fromJson,
        'Phan hoi check-out tu may chu khong hop le.',
      );
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantCheckOutFinalizeResult> finalizeCheckOut({
    required int sessionId,
    required String paymentMethod,
    required double quotedFinalFee,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-check-out-finalize',
        data: {
          'session_id': sessionId,
          'payment_method': paymentMethod,
          'quoted_final_fee': quotedFinalFee,
        },
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantCheckOutFinalizeResult.fromJson,
        'Phan hoi finalize checkout tu may chu khong hop le.',
      );
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantForceCloseTimeoutResult> forceCloseTimeout({
    required int sessionId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/sessions/attendant-force-close-timeout',
        data: {'session_id': sessionId, 'reason': reason},
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantForceCloseTimeoutResult.fromJson,
        'Phan hoi timeout phien tu may chu khong hop le.',
      );
    } on DioException catch (error) {
      throw AttendantCheckInException(_extractMessage(error));
    }
  }

  @override
  Future<AttendantShiftHandoverFinalizeResult> finalizeShiftHandover({
    required String token,
    required double actualCash,
    String? discrepancyReason,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/shifts/attendant-handover/finalize',
        data: {
          'token': token,
          'actual_cash': actualCash,
          'discrepancy_reason': discrepancyReason,
        },
        options: _authOptions,
      );
      return _parseResponse(
        response.data,
        AttendantShiftHandoverFinalizeResult.fromJson,
        'Phan hoi hoan tat giao ca khong hop le.',
      );
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
      return _parseResponse(
        response.data,
        AttendantCheckOutUndoResult.fromJson,
        'Phan hoi undo checkout tu may chu khong hop le.',
      );
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
