import 'package:dio/dio.dart';

import '../../../shared/media/media_picker_service.dart';
import '../../lease_contract/data/lease_contract_models.dart';

class ParkingLotRegistration {
  const ParkingLotRegistration({
    required this.id,
    required this.lotOwnerId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.currentAvailable,
    required this.status,
    this.description,
    this.coverImage,
    this.activeLeaseId,
    this.activeLeaseStatus,
    this.activeOperatorUserId,
    this.activeOperatorName,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int lotOwnerId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int currentAvailable;
  final String status;
  final String? description;
  final String? coverImage;
  final int? activeLeaseId;
  final String? activeLeaseStatus;
  final int? activeOperatorUserId;
  final String? activeOperatorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory ParkingLotRegistration.fromJson(Map<String, dynamic> json) {
    return ParkingLotRegistration(
      id: json['id'] as int,
      lotOwnerId: json['lot_owner_id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      activeLeaseId: json['active_lease_id'] as int?,
      activeLeaseStatus: json['active_lease_status'] as String?,
      activeOperatorUserId: json['active_operator_user_id'] as int?,
      activeOperatorName: json['active_operator_name'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AvailableOperatorOption {
  const AvailableOperatorOption({
    required this.managerId,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.businessLicense,
  });

  final int managerId;
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final String? businessLicense;

  factory AvailableOperatorOption.fromJson(Map<String, dynamic> json) {
    return AvailableOperatorOption(
      managerId: json['manager_id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      businessLicense: json['business_license'] as String?,
    );
  }
}

abstract class ParkingLotService {
  Future<List<ParkingLotRegistration>> getMyParkingLots();

  Future<List<AvailableOperatorOption>> getAvailableOperators();

  Future<LeaseContractSummary> createLeaseContract({
    required int parkingLotId,
    required int managerUserId,
    required double monthlyFee,
    required double revenueSharePercentage,
    required int termMonths,
    String? additionalTerms,
  });

  Future<ParkingLotRegistration> createParkingLot({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    SelectedMediaFile? coverImageFile,
    String? coverImage,
  });
}

class BackendParkingLotService implements ParkingLotService {
  BackendParkingLotService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<List<ParkingLotRegistration>> getMyParkingLots() async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/me/parking-lots',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const ParkingLotException(
          'Phản hồi danh sách bãi xe không hợp lệ.',
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ParkingLotRegistration.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ParkingLotException(_extractMessage(error));
    }
  }

  @override
  Future<List<AvailableOperatorOption>> getAvailableOperators() async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/me/operators',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! List) {
        throw const ParkingLotException(
          'Phản hồi danh sách operator không hợp lệ.',
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(AvailableOperatorOption.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ParkingLotException(_extractMessage(error));
    }
  }

  @override
  Future<LeaseContractSummary> createLeaseContract({
    required int parkingLotId,
    required int managerUserId,
    required double monthlyFee,
    required double revenueSharePercentage,
    required int termMonths,
    String? additionalTerms,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/leases/owner/parking-lots/$parkingLotId/contracts',
        data: {
          'manager_user_id': managerUserId,
          'monthly_fee': monthlyFee,
          'revenue_share_percentage': revenueSharePercentage,
          'term_months': termMonths,
          'additional_terms': additionalTerms,
        },
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const ParkingLotException(
          'Phản hồi tạo hợp đồng thuê không hợp lệ.',
        );
      }
      return LeaseContractSummary.fromJson(raw);
    } on DioException catch (error) {
      throw ParkingLotException(_extractMessage(error));
    }
  }

  @override
  Future<ParkingLotRegistration> createParkingLot({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    SelectedMediaFile? coverImageFile,
    String? coverImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'address': address,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        if (description != null) 'description': description,
        if (coverImage != null) 'cover_image': coverImage,
        if (coverImageFile != null)
          'cover_image_file': await MultipartFile.fromFile(
            coverImageFile.path,
            filename: coverImageFile.fileName,
          ),
      });

      final response = await _dio.post<dynamic>(
        '/user/me/parking-lots',
        data: formData,
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const ParkingLotException('Phản hồi tạo bãi xe không hợp lệ.');
      }
      return ParkingLotRegistration.fromJson(raw);
    } on DioException catch (error) {
      throw ParkingLotException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
    }
    return 'Không thể xử lý đăng ký bãi xe lúc này. Vui lòng thử lại.';
  }
}

class ParkingLotException implements Exception {
  const ParkingLotException(this.message);

  final String message;

  @override
  String toString() => message;
}
