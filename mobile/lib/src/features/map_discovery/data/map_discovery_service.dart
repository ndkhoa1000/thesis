import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

enum MapDiscoveryAvailabilityState { available, limited, full }

class MapDiscoveryAvailabilityUpdate {
  const MapDiscoveryAvailabilityUpdate({
    required this.lotId,
    required this.currentAvailable,
    required this.previousCurrentAvailable,
    required this.isFull,
    required this.wasFull,
    required this.source,
    required this.occurredAt,
  });

  final int lotId;
  final int currentAvailable;
  final int previousCurrentAvailable;
  final bool isFull;
  final bool wasFull;
  final String source;
  final DateTime occurredAt;

  factory MapDiscoveryAvailabilityUpdate.fromJson(Map<String, dynamic> json) {
    final currentAvailable = json['current_available'] as int? ?? 0;
    final previousCurrentAvailable =
        json['previous_current_available'] as int? ?? currentAvailable;
    return MapDiscoveryAvailabilityUpdate(
      lotId: json['lot_id'] as int,
      currentAvailable: currentAvailable,
      previousCurrentAvailable: previousCurrentAvailable,
      isFull: json['is_full'] as bool? ?? currentAvailable <= 0,
      wasFull: json['was_full'] as bool? ?? previousCurrentAvailable <= 0,
      source: json['source'] as String? ?? 'unknown',
      occurredAt:
          DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MapDiscoveryLotSummary {
  const MapDiscoveryLotSummary({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currentAvailable,
    required this.status,
    this.description,
    this.coverImage,
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

  bool get isFull => currentAvailable <= 0;

  MapDiscoveryAvailabilityState get availabilityState {
    if (currentAvailable <= 0) {
      return MapDiscoveryAvailabilityState.full;
    }
    if (currentAvailable <= 5) {
      return MapDiscoveryAvailabilityState.limited;
    }
    return MapDiscoveryAvailabilityState.available;
  }

  String get availabilityText => isFull ? 'Đầy' : 'Còn $currentAvailable chỗ';

  String get markerCountLabel => isFull ? '0' : '$currentAvailable';

  MapDiscoveryLotSummary copyWith({int? currentAvailable}) {
    return MapDiscoveryLotSummary(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      currentAvailable: currentAvailable ?? this.currentAvailable,
      status: status,
      description: description,
      coverImage: coverImage,
    );
  }

  factory MapDiscoveryLotSummary.fromJson(Map<String, dynamic> json) {
    return MapDiscoveryLotSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
    );
  }
}

abstract class MapDiscoveryService {
  Future<List<MapDiscoveryLotSummary>> fetchActiveLots();

  Stream<MapDiscoveryAvailabilityUpdate> watchAvailability();
}

class BackendMapDiscoveryService implements MapDiscoveryService {
  BackendMapDiscoveryService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  Uri get _availabilityStreamUri {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final pathSegments = [
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      'lots',
      'availability',
      'stream',
    ];
    return baseUri.replace(
      scheme: scheme,
      pathSegments: pathSegments,
      queryParameters: null,
      fragment: null,
    );
  }

  @override
  Future<List<MapDiscoveryLotSummary>> fetchActiveLots() async {
    try {
      final response = await _dio.get<dynamic>('/lots', options: _authOptions);
      final raw = response.data;
      if (raw is! List) {
        throw const MapDiscoveryException(
          'Phản hồi danh sách bãi xe không hợp lệ.',
        );
      }

      return raw
          .whereType<Map<String, dynamic>>()
          .map(MapDiscoveryLotSummary.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw MapDiscoveryException(_extractMessage(error));
    } on TypeError {
      throw const MapDiscoveryException(
        'Không thể đọc dữ liệu bãi xe từ máy chủ.',
      );
    }
  }

  @override
  Stream<MapDiscoveryAvailabilityUpdate> watchAvailability() async* {
    WebSocket? socket;
    try {
      socket = await WebSocket.connect(
        _availabilityStreamUri.toString(),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      await for (final message in socket) {
        yield MapDiscoveryAvailabilityUpdate.fromJson(
          _decodeAvailabilityMessage(message),
        );
      }
    } on WebSocketException {
      throw const MapDiscoveryException(
        'Không thể kết nối kênh cập nhật bãi xe.',
      );
    } on FormatException {
      throw const MapDiscoveryException(
        'Dữ liệu cập nhật bãi xe không hợp lệ.',
      );
    } finally {
      await socket?.close();
    }
  }

  Map<String, dynamic> _decodeAvailabilityMessage(dynamic message) {
    final dynamic decoded;
    if (message is String) {
      decoded = jsonDecode(message);
    } else if (message is List<int>) {
      decoded = jsonDecode(utf8.decode(message));
    } else {
      throw const FormatException('Unsupported websocket payload');
    }

    if (decoded is! Map) {
      throw const FormatException('Availability payload must be an object');
    }

    return Map<String, dynamic>.from(decoded);
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

    return 'Không thể tải danh sách bãi xe lúc này.';
  }
}

class MapDiscoveryException implements Exception {
  const MapDiscoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}
