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

class LotPeakHourPoint {
  const LotPeakHourPoint({required this.hour, required this.sessionCount});

  final int hour;
  final int sessionCount;

  String get label => '${hour.toString().padLeft(2, '0')}h';

  factory LotPeakHourPoint.fromJson(Map<String, dynamic> json) {
    return LotPeakHourPoint(
      hour: json['hour'] as int,
      sessionCount: json['session_count'] as int? ?? 0,
    );
  }
}

class LotHistoricalTrend {
  const LotHistoricalTrend({
    required this.status,
    required this.lookbackDays,
    required this.totalSessions,
    required this.points,
  });

  final String status;
  final int lookbackDays;
  final int totalSessions;
  final List<LotPeakHourPoint> points;

  bool get hasData => status == 'READY' && points.isNotEmpty;

  factory LotHistoricalTrend.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return LotHistoricalTrend(
      status: json['status'] as String? ?? 'INSUFFICIENT_DATA',
      lookbackDays: json['lookback_days'] as int? ?? 30,
      totalSessions: json['total_sessions'] as int? ?? 0,
      points: rawPoints is List
          ? rawPoints
                .whereType<Map<String, dynamic>>()
                .map(LotPeakHourPoint.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class DriverLotAnnouncement {
  const DriverLotAnnouncement({
    required this.id,
    required this.title,
    required this.announcementType,
    required this.visibleFrom,
    this.content,
    this.visibleUntil,
  });

  final int id;
  final String title;
  final String? content;
  final String announcementType;
  final DateTime visibleFrom;
  final DateTime? visibleUntil;

  factory DriverLotAnnouncement.fromJson(Map<String, dynamic> json) {
    return DriverLotAnnouncement(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String?,
      announcementType: json['announcement_type'] as String? ?? 'GENERAL',
      visibleFrom: DateTime.parse(json['visible_from'] as String),
      visibleUntil: _parseDateTime(json['visible_until']),
    );
  }
}

class DriverLotDetail {
  const DriverLotDetail({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currentAvailable,
    required this.status,
    required this.peakHours,
    this.announcements = const [],
    this.description,
    this.coverImage,
    this.totalCapacity,
    this.openingTime,
    this.closingTime,
    this.pricingMode,
    this.priceAmount,
    this.featureLabels = const [],
    this.tagLabels = const [],
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int currentAvailable;
  final String status;
  final String? description;
  final String? coverImage;
  final int? totalCapacity;
  final String? openingTime;
  final String? closingTime;
  final String? pricingMode;
  final double? priceAmount;
  final List<String> featureLabels;
  final List<String> tagLabels;
  final List<DriverLotAnnouncement> announcements;
  final LotHistoricalTrend peakHours;

  bool get isFull => currentAvailable <= 0;

  String get availabilityText => isFull ? 'Đầy' : 'Còn $currentAvailable chỗ';

  String get operatingHoursLabel {
    if (openingTime == null || closingTime == null) {
      return 'Chưa công bố giờ hoạt động';
    }
    return '$openingTime - $closingTime';
  }

  String get pricingLabel {
    if (pricingMode == null || priceAmount == null) {
      return 'Chưa công bố giá';
    }

    final normalizedAmount = priceAmount == priceAmount!.roundToDouble()
        ? priceAmount!.round().toString()
        : priceAmount!.toStringAsFixed(2);
    final modeLabel = switch (pricingMode) {
      'HOURLY' => 'Theo giờ',
      'SESSION' => 'Theo lượt',
      'DAILY' => 'Theo ngày',
      'MONTHLY' => 'Theo tháng',
      _ => pricingMode,
    };
    return '$modeLabel: $normalizedAmount VND';
  }

  String get capacityLabel {
    if (totalCapacity == null) {
      return availabilityText;
    }
    return '$availabilityText / $totalCapacity chỗ';
  }

  factory DriverLotDetail.fromJson(Map<String, dynamic> json) {
    return DriverLotDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      totalCapacity: json['total_capacity'] as int?,
      openingTime: _normalizeTime(json['opening_time']),
      closingTime: _normalizeTime(json['closing_time']),
      pricingMode: json['pricing_mode'] as String?,
      priceAmount: (json['price_amount'] as num?)?.toDouble(),
      featureLabels: (json['feature_labels'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      tagLabels: (json['tag_labels'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      announcements: (json['announcements'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DriverLotAnnouncement.fromJson)
          .toList(growable: false),
      peakHours: LotHistoricalTrend.fromJson(
        json['peak_hours'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

abstract class LotDetailsService {
  Future<DriverLotDetail> fetchLotDetail({required int lotId});
}

class BackendLotDetailsService implements LotDetailsService {
  BackendLotDetailsService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<DriverLotDetail> fetchLotDetail({required int lotId}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/lots/$lotId',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const LotDetailsException(
          'Phản hồi chi tiết bãi xe không hợp lệ.',
        );
      }
      return DriverLotDetail.fromJson(raw);
    } on DioException catch (error) {
      throw LotDetailsException(_extractMessage(error));
    } on TypeError {
      throw const LotDetailsException(
        'Không thể đọc dữ liệu chi tiết bãi xe từ máy chủ.',
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

    return 'Không thể tải chi tiết bãi xe lúc này.';
  }
}

class LotDetailsException implements Exception {
  const LotDetailsException(this.message);

  final String message;

  @override
  String toString() => message;
}
