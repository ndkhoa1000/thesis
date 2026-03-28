import 'package:dio/dio.dart';

class DriverParkingHistoryEntry {
  const DriverParkingHistoryEntry({
    required this.sessionId,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.licensePlate,
    required this.vehicleType,
    required this.checkedInAt,
    required this.checkedOutAt,
    required this.durationMinutes,
    this.amountPaid,
    this.paymentMethod,
  });

  final int sessionId;
  final int parkingLotId;
  final String parkingLotName;
  final String licensePlate;
  final String vehicleType;
  final DateTime checkedInAt;
  final DateTime checkedOutAt;
  final int durationMinutes;
  final double? amountPaid;
  final String? paymentMethod;

  String get durationLabel {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours <= 0) {
      return '${minutes} phút';
    }
    if (minutes == 0) {
      return '${hours} giờ';
    }
    return '${hours} giờ ${minutes} phút';
  }

  String get amountLabel {
    if (amountPaid == null) {
      return 'Chưa có dữ liệu thanh toán';
    }
    final normalizedAmount = amountPaid == amountPaid!.roundToDouble()
        ? amountPaid!.round().toString()
        : amountPaid!.toStringAsFixed(2);
    return '$normalizedAmount VND';
  }

  String get paymentMethodLabel => switch (paymentMethod) {
    'ONLINE' => 'Thanh toán online',
    'CASH' => 'Tiền mặt',
    _ => 'Chưa rõ phương thức',
  };

  factory DriverParkingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DriverParkingHistoryEntry(
      sessionId: json['session_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      checkedOutAt: DateTime.parse(json['checked_out_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] as String?,
    );
  }
}

abstract class ParkingHistoryService {
  Future<List<DriverParkingHistoryEntry>> fetchHistory();
}

class BackendParkingHistoryService implements ParkingHistoryService {
  BackendParkingHistoryService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<List<DriverParkingHistoryEntry>> fetchHistory() async {
    try {
      final response = await _dio.get<dynamic>(
        '/sessions/driver-history',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const ParkingHistoryException(
          'Phản hồi lịch sử gửi xe không hợp lệ.',
        );
      }

      return raw
          .whereType<Map<String, dynamic>>()
          .map(DriverParkingHistoryEntry.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ParkingHistoryException(_extractMessage(error));
    } on TypeError {
      throw const ParkingHistoryException(
        'Không thể đọc dữ liệu lịch sử gửi xe từ máy chủ.',
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

    return 'Không thể tải lịch sử gửi xe lúc này.';
  }
}

class ParkingHistoryException implements Exception {
  const ParkingHistoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
