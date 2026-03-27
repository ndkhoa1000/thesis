import 'package:dio/dio.dart';

class OperatorApplication {
  const OperatorApplication({
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

  factory OperatorApplication.fromJson(Map<String, dynamic> json) {
    return OperatorApplication(
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

abstract class OperatorApplicationService {
  Future<OperatorApplication?> getMyApplication();

  Future<OperatorApplication> submitApplication({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  });
}

class BackendOperatorApplicationService implements OperatorApplicationService {
  BackendOperatorApplicationService({
    required Dio dio,
    required String accessToken,
  }) : _dio = dio,
       _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<OperatorApplication?> getMyApplication() async {
    try {
      final response = await _dio.get<dynamic>(
        '/user/me/operator-application',
        options: _authOptions,
      );
      final raw = response.data;
      if (raw == null) {
        return null;
      }
      if (raw is! Map<String, dynamic>) {
        throw const OperatorApplicationException(
          'Phản hồi hồ sơ operator không hợp lệ.',
        );
      }
      return OperatorApplication.fromJson(raw);
    } on DioException catch (error) {
      throw OperatorApplicationException(_extractMessage(error));
    }
  }

  @override
  Future<OperatorApplication> submitApplication({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/user/me/operator-application',
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
        throw const OperatorApplicationException(
          'Phản hồi gửi hồ sơ operator không hợp lệ.',
        );
      }
      return OperatorApplication.fromJson(raw);
    } on DioException catch (error) {
      throw OperatorApplicationException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'Không thể xử lý hồ sơ operator lúc này. Vui lòng thử lại.';
  }
}

class OperatorApplicationException implements Exception {
  const OperatorApplicationException(this.message);

  final String message;

  @override
  String toString() => message;
}
