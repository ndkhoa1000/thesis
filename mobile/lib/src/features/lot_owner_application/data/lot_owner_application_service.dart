import 'package:dio/dio.dart';

class LotOwnerApplication {
  const LotOwnerApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phoneNumber,
    required this.businessLicense,
    required this.documentReference,
    required this.status,
    this.notes,
    this.rejectionReason,
  });

  final int id;
  final int userId;
  final String fullName;
  final String phoneNumber;
  final String businessLicense;
  final String documentReference;
  final String status;
  final String? notes;
  final String? rejectionReason;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory LotOwnerApplication.fromJson(Map<String, dynamic> json) {
    return LotOwnerApplication(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      businessLicense: json['business_license'] as String,
      documentReference: json['document_reference'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

abstract class LotOwnerApplicationService {
  Future<LotOwnerApplication?> getMyApplication();

  Future<LotOwnerApplication> submitApplication({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  });
}

class BackendLotOwnerApplicationService implements LotOwnerApplicationService {
  BackendLotOwnerApplicationService({
    required Dio dio,
    required String accessToken,
  }) : _dio = dio,
       _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<LotOwnerApplication?> getMyApplication() async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/me/lot-owner-application',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw == null) {
        return null;
      }
      if (raw is! Map<String, dynamic>) {
        throw const LotOwnerApplicationException(
          'Phản hồi hồ sơ chủ bãi không hợp lệ.',
        );
      }
      return LotOwnerApplication.fromJson(raw);
    } on DioException catch (error) {
      throw LotOwnerApplicationException(_extractMessage(error));
    }
  }

  @override
  Future<LotOwnerApplication> submitApplication({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/user/me/lot-owner-application',
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'business_license': businessLicense,
          'document_reference': documentReference,
          'notes': notes,
        },
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const LotOwnerApplicationException(
          'Phản hồi gửi hồ sơ chủ bãi không hợp lệ.',
        );
      }
      return LotOwnerApplication.fromJson(raw);
    } on DioException catch (error) {
      throw LotOwnerApplicationException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Không thể xử lý hồ sơ chủ bãi lúc này. Vui lòng thử lại.';
  }
}

class LotOwnerApplicationException implements Exception {
  const LotOwnerApplicationException(this.message);

  final String message;

  @override
  String toString() => message;
}