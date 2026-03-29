import 'package:dio/dio.dart';

enum OwnerRevenuePeriod {
  day('DAY', 'Ngày'),
  week('WEEK', 'Tuần'),
  month('MONTH', 'Tháng');

  const OwnerRevenuePeriod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class OwnerRevenueSummary {
  const OwnerRevenueSummary({
    required this.parkingLotId,
    required this.parkingLotName,
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.completedPaymentCount,
    required this.completedSessionCount,
    required this.hasData,
    this.leaseStatus,
    this.operatorName,
    this.revenueSharePercentage,
    this.leaseStartDate,
    this.leaseEndDate,
    this.grossRevenue,
    this.ownerShare,
    this.operatorShare,
    this.emptyReason,
    this.emptyMessage,
  });

  final int parkingLotId;
  final String parkingLotName;
  final OwnerRevenuePeriod period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String? leaseStatus;
  final String? operatorName;
  final double? revenueSharePercentage;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  final int completedPaymentCount;
  final int completedSessionCount;
  final bool hasData;
  final double? grossRevenue;
  final double? ownerShare;
  final double? operatorShare;
  final String? emptyReason;
  final String? emptyMessage;

  factory OwnerRevenueSummary.fromJson(Map<String, dynamic> json) {
    return OwnerRevenueSummary(
      parkingLotId: json['parking_lot_id'] as int,
      parkingLotName: json['parking_lot_name'] as String,
      period: OwnerRevenuePeriod.values.firstWhere(
        (item) => item.apiValue == json['period'],
      ),
      rangeStart: DateTime.parse(json['range_start'] as String),
      rangeEnd: DateTime.parse(json['range_end'] as String),
      leaseStatus: json['lease_status'] as String?,
      operatorName: json['operator_name'] as String?,
      revenueSharePercentage: _toDouble(json['revenue_share_percentage']),
      leaseStartDate: _parseDate(json['lease_start_date']),
      leaseEndDate: _parseDate(json['lease_end_date']),
      completedPaymentCount: json['completed_payment_count'] as int? ?? 0,
      completedSessionCount: json['completed_session_count'] as int? ?? 0,
      hasData: json['has_data'] as bool? ?? false,
      grossRevenue: _toDouble(json['gross_revenue']),
      ownerShare: _toDouble(json['owner_share']),
      operatorShare: _toDouble(json['operator_share']),
      emptyReason: json['empty_reason'] as String?,
      emptyMessage: json['empty_message'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}

abstract class OwnerRevenueDashboardService {
  Future<OwnerRevenueSummary> getOwnerRevenueSummary({
    required int parkingLotId,
    required OwnerRevenuePeriod period,
  });
}

class BackendOwnerRevenueDashboardService
    implements OwnerRevenueDashboardService {
  BackendOwnerRevenueDashboardService({
    required Dio dio,
    required String accessToken,
  }) : _dio = dio,
       _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<OwnerRevenueSummary> getOwnerRevenueSummary({
    required int parkingLotId,
    required OwnerRevenuePeriod period,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/reports/owner/parking-lots/$parkingLotId/revenue',
        queryParameters: {'period': period.apiValue},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const OwnerRevenueDashboardException(
          'Phản hồi doanh thu chủ bãi không hợp lệ.',
        );
      }
      return OwnerRevenueSummary.fromJson(raw);
    } on DioException catch (error) {
      throw OwnerRevenueDashboardException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
    }
    return 'Không thể tải dashboard doanh thu lúc này. Vui lòng thử lại.';
  }
}

class OwnerRevenueDashboardException implements Exception {
  const OwnerRevenueDashboardException(this.message);

  final String message;

  @override
  String toString() => message;
}
