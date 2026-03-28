import 'package:dio/dio.dart';

import '../../vehicles/data/vehicle_service.dart';

class DriverBookingPayment {
  const DriverBookingPayment({
    required this.paymentId,
    required this.amount,
    required this.finalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  final int paymentId;
  final double amount;
  final double finalAmount;
  final String paymentMethod;
  final String paymentStatus;

  factory DriverBookingPayment.fromJson(Map<String, dynamic> json) {
    return DriverBookingPayment(
      paymentId: json['payment_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      finalAmount: (json['final_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
    );
  }
}

class DriverBooking {
  const DriverBooking({
    required this.bookingId,
    required this.parkingLotId,
    required this.parkingLotName,
    required this.status,
    required this.bookingTime,
    required this.expectedArrival,
    required this.expirationTime,
    required this.expiresInSeconds,
    required this.currentAvailable,
    required this.token,
    required this.vehicle,
    required this.payment,
  });

  final int bookingId;
  final int parkingLotId;
  final String parkingLotName;
  final String status;
  final DateTime bookingTime;
  final DateTime? expectedArrival;
  final DateTime? expirationTime;
  final int expiresInSeconds;
  final int currentAvailable;
  final String token;
  final Vehicle vehicle;
  final DriverBookingPayment payment;

  factory DriverBooking.fromJson(Map<String, dynamic> json) {
    final rawVehicle = json['vehicle'];
    final rawPayment = json['payment'];
    if (rawVehicle is! Map<String, dynamic> ||
        rawPayment is! Map<String, dynamic>) {
      throw const DriverBookingException('Phản hồi booking không hợp lệ.');
    }

    return DriverBooking(
      bookingId: json['booking_id'] as int,
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      status: json['status'] as String,
      bookingTime: DateTime.parse(json['booking_time'] as String),
      expectedArrival: _parseDateTime(json['expected_arrival']),
      expirationTime: _parseDateTime(json['expiration_time']),
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 0,
      currentAvailable: json['current_available'] as int? ?? 0,
      token: json['token'] as String,
      vehicle: Vehicle.fromJson(rawVehicle),
      payment: DriverBookingPayment.fromJson(rawPayment),
    );
  }
}

class DriverBookingCancellation {
  const DriverBookingCancellation({
    required this.bookingId,
    required this.status,
    required this.currentAvailable,
  });

  final int bookingId;
  final String status;
  final int currentAvailable;

  factory DriverBookingCancellation.fromJson(Map<String, dynamic> json) {
    return DriverBookingCancellation(
      bookingId: json['booking_id'] as int,
      status: json['status'] as String,
      currentAvailable: json['current_available'] as int? ?? 0,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

abstract class DriverBookingService {
  Future<DriverBooking?> getActiveBooking({required int parkingLotId});
  Future<DriverBooking> createBooking({
    required int parkingLotId,
    required int vehicleId,
  });
  Future<DriverBookingCancellation> cancelBooking({required int bookingId});
}

class BackendDriverBookingService implements DriverBookingService {
  BackendDriverBookingService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<DriverBooking?> getActiveBooking({required int parkingLotId}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/bookings/driver-active',
        queryParameters: {'parking_lot_id': parkingLotId},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const DriverBookingException('Phản hồi booking không hợp lệ.');
      }
      return DriverBooking.fromJson(raw);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      throw DriverBookingException(_extractMessage(error));
    }
  }

  @override
  Future<DriverBooking> createBooking({
    required int parkingLotId,
    required int vehicleId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/bookings',
        data: {'parking_lot_id': parkingLotId, 'vehicle_id': vehicleId},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const DriverBookingException('Phản hồi booking không hợp lệ.');
      }
      return DriverBooking.fromJson(raw);
    } on DioException catch (error) {
      throw DriverBookingException(_extractMessage(error));
    }
  }

  @override
  Future<DriverBookingCancellation> cancelBooking({
    required int bookingId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/bookings/$bookingId/cancel',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const DriverBookingException(
          'Phản hồi hủy booking không hợp lệ.',
        );
      }
      return DriverBookingCancellation.fromJson(raw);
    } on DioException catch (error) {
      throw DriverBookingException(_extractMessage(error));
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
    return 'Không thể xử lý booking lúc này.';
  }
}

class DriverBookingException implements Exception {
  const DriverBookingException(this.message);

  final String message;

  @override
  String toString() => message;
}
