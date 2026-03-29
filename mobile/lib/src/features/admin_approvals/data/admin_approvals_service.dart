import 'package:dio/dio.dart';

enum ApprovalSubjectType { lotOwner, operator, parkingLot }

class AdminApprovalItem {
  const AdminApprovalItem({
    required this.id,
    required this.type,
    required this.applicantName,
    required this.phoneNumber,
    required this.businessLicense,
    required this.documentReference,
    required this.status,
    this.notes,
    this.rejectionReason,
    this.parkingLotName,
    this.parkingLotAddress,
    this.coverImage,
  });

  final int id;
  final ApprovalSubjectType type;
  final String applicantName;
  final String phoneNumber;
  final String businessLicense;
  final String documentReference;
  final String status;
  final String? notes;
  final String? rejectionReason;
  final String? parkingLotName;
  final String? parkingLotAddress;
  final String? coverImage;

  bool get isPending => status == 'PENDING';

  String get title => switch (type) {
    ApprovalSubjectType.lotOwner => 'Hồ sơ chủ bãi xe',
    ApprovalSubjectType.operator => 'Hồ sơ vận hành',
    ApprovalSubjectType.parkingLot => 'Đăng ký bãi xe',
  };

  String get typeLabel => switch (type) {
    ApprovalSubjectType.lotOwner => 'Chủ bãi xe',
    ApprovalSubjectType.operator => 'Vận hành',
    ApprovalSubjectType.parkingLot => 'Bãi xe',
  };

  factory AdminApprovalItem.fromLotOwnerJson(Map<String, dynamic> json) {
    return AdminApprovalItem(
      id: json['id'] as int,
      type: ApprovalSubjectType.lotOwner,
      applicantName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      businessLicense: json['business_license'] as String,
      documentReference: json['document_reference'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  factory AdminApprovalItem.fromOperatorJson(Map<String, dynamic> json) {
    return AdminApprovalItem(
      id: json['id'] as int,
      type: ApprovalSubjectType.operator,
      applicantName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      businessLicense: json['business_license'] as String,
      documentReference: json['document_reference'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  factory AdminApprovalItem.fromParkingLotJson(Map<String, dynamic> json) {
    return AdminApprovalItem(
      id: json['id'] as int,
      type: ApprovalSubjectType.parkingLot,
      applicantName: (json['owner_name'] as String?) ?? 'Lot Owner',
      phoneNumber: (json['owner_phone'] as String?) ?? 'Chưa có',
      businessLicense: (json['owner_business_license'] as String?) ?? 'Chưa có',
      documentReference: json['address'] as String,
      status: json['status'] as String,
      notes: json['description'] as String?,
      parkingLotName: json['name'] as String,
      parkingLotAddress: json['address'] as String,
      coverImage: json['cover_image'] as String?,
    );
  }
}

class AdminManagedUser {
  const AdminManagedUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.isSuperuser,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final bool isSuperuser;

  String get roleLabel => switch (role) {
    'ADMIN' => 'Quản trị viên',
    'ATTENDANT' => 'Nhân viên cổng',
    'MANAGER' => 'Vận hành',
    'LOT_OWNER' => 'Chủ bãi xe',
    _ => 'Tài xế',
  };

  factory AdminManagedUser.fromJson(Map<String, dynamic> json) {
    return AdminManagedUser(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isSuperuser: json['is_superuser'] as bool? ?? false,
    );
  }
}

class AdminManagedParkingLot {
  const AdminManagedParkingLot({
    required this.id,
    required this.lotOwnerId,
    required this.name,
    required this.address,
    required this.currentAvailable,
    required this.status,
    this.ownerName,
    this.ownerPhone,
    this.ownerBusinessLicense,
    this.description,
    this.coverImage,
  });

  final int id;
  final int lotOwnerId;
  final String name;
  final String address;
  final int currentAvailable;
  final String status;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerBusinessLicense;
  final String? description;
  final String? coverImage;

  bool get canSuspend => status == 'APPROVED';
  bool get canReopen => status == 'CLOSED';

  String get statusLabel => switch (status) {
    'APPROVED' => 'Đang hoạt động',
    'CLOSED' => 'Đã tạm dừng',
    'PENDING' => 'Chờ duyệt',
    'REJECTED' => 'Đã từ chối',
    _ => status,
  };

  factory AdminManagedParkingLot.fromJson(Map<String, dynamic> json) {
    return AdminManagedParkingLot(
      id: json['id'] as int,
      lotOwnerId: json['lot_owner_id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      currentAvailable: json['current_available'] as int? ?? 0,
      status: json['status'] as String,
      ownerName: json['owner_name'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      ownerBusinessLicense: json['owner_business_license'] as String?,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
    );
  }
}

class AdminApprovalsDashboard {
  const AdminApprovalsDashboard({
    required this.lotOwnerApplications,
    required this.operatorApplications,
    required this.parkingLotApplications,
    required this.managedUsers,
    required this.managedParkingLots,
  });

  final List<AdminApprovalItem> lotOwnerApplications;
  final List<AdminApprovalItem> operatorApplications;
  final List<AdminApprovalItem> parkingLotApplications;
  final List<AdminManagedUser> managedUsers;
  final List<AdminManagedParkingLot> managedParkingLots;
}

abstract class AdminApprovalsService {
  Future<AdminApprovalsDashboard> loadDashboard();

  Future<AdminApprovalItem> approve({
    required ApprovalSubjectType type,
    required int applicationId,
  });

  Future<AdminApprovalItem> reject({
    required ApprovalSubjectType type,
    required int applicationId,
    required String rejectionReason,
  });

  Future<AdminManagedUser> updateUserActivation({
    required int userId,
    required bool isActive,
  });

  Future<AdminManagedParkingLot> updateParkingLotStatus({
    required int parkingLotId,
    required String status,
  });
}

class BackendAdminApprovalsService implements AdminApprovalsService {
  BackendAdminApprovalsService({required Dio dio, required String accessToken})
    : _dio = dio,
      _accessToken = accessToken;

  final Dio _dio;
  final String _accessToken;

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_accessToken'});

  @override
  Future<AdminApprovalsDashboard> loadDashboard() async {
    try {
      final lotOwnerResponse = await _dio.get<dynamic>(
        '/admin/lot-owner-applications',
        options: _authOptions,
      );
      final operatorResponse = await _dio.get<dynamic>(
        '/admin/operator-applications',
        options: _authOptions,
      );
      final parkingLotResponse = await _dio.get<dynamic>(
        '/admin/parking-lots',
        options: _authOptions,
      );
      final userResponse = await _dio.get<dynamic>(
        '/admin/users',
        options: _authOptions,
      );

      final lotOwnerItems = _parseList(
        lotOwnerResponse.data,
        AdminApprovalItem.fromLotOwnerJson,
      ).where((item) => item.isPending).toList();
      final operatorItems = _parseList(
        operatorResponse.data,
        AdminApprovalItem.fromOperatorJson,
      ).where((item) => item.isPending).toList();
      final parkingLotItems = _parseList(
        parkingLotResponse.data,
        AdminApprovalItem.fromParkingLotJson,
      ).where((item) => item.isPending).toList();
      final managedUsers = _parseList(
        userResponse.data,
        AdminManagedUser.fromJson,
      );
      final managedParkingLots = _parseList(
        parkingLotResponse.data,
        AdminManagedParkingLot.fromJson,
      ).where((lot) => lot.canSuspend || lot.canReopen).toList(growable: false);

      return AdminApprovalsDashboard(
        lotOwnerApplications: lotOwnerItems,
        operatorApplications: operatorItems,
        parkingLotApplications: parkingLotItems,
        managedUsers: managedUsers,
        managedParkingLots: managedParkingLots,
      );
    } on DioException catch (error) {
      throw AdminApprovalsException(_extractMessage(error));
    }
  }

  @override
  Future<AdminApprovalItem> approve({
    required ApprovalSubjectType type,
    required int applicationId,
  }) {
    return _review(
      type: type,
      applicationId: applicationId,
      decision: 'APPROVED',
    );
  }

  @override
  Future<AdminApprovalItem> reject({
    required ApprovalSubjectType type,
    required int applicationId,
    required String rejectionReason,
  }) {
    return _review(
      type: type,
      applicationId: applicationId,
      decision: 'REJECTED',
      rejectionReason: rejectionReason,
    );
  }

  @override
  Future<AdminManagedUser> updateUserActivation({
    required int userId,
    required bool isActive,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/admin/users/$userId/activation',
        data: {'is_active': isActive},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AdminApprovalsException(
          'Phản hồi cập nhật tài khoản không hợp lệ.',
        );
      }
      return AdminManagedUser.fromJson(raw);
    } on DioException catch (error) {
      throw AdminApprovalsException(_extractMessage(error));
    }
  }

  @override
  Future<AdminManagedParkingLot> updateParkingLotStatus({
    required int parkingLotId,
    required String status,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        '/admin/parking-lots/$parkingLotId/status',
        data: {'status': status},
        options: _authOptions,
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AdminApprovalsException(
          'Phản hồi cập nhật trạng thái bãi xe không hợp lệ.',
        );
      }
      return AdminManagedParkingLot.fromJson(raw);
    } on DioException catch (error) {
      throw AdminApprovalsException(_extractMessage(error));
    }
  }

  Future<AdminApprovalItem> _review({
    required ApprovalSubjectType type,
    required int applicationId,
    required String decision,
    String? rejectionReason,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        _reviewPath(type, applicationId),
        data: {'decision': decision, 'rejection_reason': rejectionReason},
        options: _authOptions,
      );

      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw const AdminApprovalsException(
          'Phản hồi duyệt hồ sơ không hợp lệ.',
        );
      }
      return _fromJson(type, raw);
    } on DioException catch (error) {
      throw AdminApprovalsException(_extractMessage(error));
    }
  }

  List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parser) {
    if (raw is! List) {
      throw const AdminApprovalsException(
        'Phản hồi danh sách phê duyệt không hợp lệ.',
      );
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(parser)
        .toList(growable: false);
  }

  AdminApprovalItem _fromJson(
    ApprovalSubjectType type,
    Map<String, dynamic> json,
  ) {
    return switch (type) {
      ApprovalSubjectType.lotOwner => AdminApprovalItem.fromLotOwnerJson(json),
      ApprovalSubjectType.operator => AdminApprovalItem.fromOperatorJson(json),
      ApprovalSubjectType.parkingLot => AdminApprovalItem.fromParkingLotJson(
        json,
      ),
    };
  }

  String _reviewPath(ApprovalSubjectType type, int applicationId) {
    return switch (type) {
      ApprovalSubjectType.lotOwner =>
        '/admin/lot-owner-applications/$applicationId/review',
      ApprovalSubjectType.operator =>
        '/admin/operator-applications/$applicationId/review',
      ApprovalSubjectType.parkingLot =>
        '/admin/parking-lots/$applicationId/review',
    };
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
    return 'Không thể tải hoặc xử lý danh sách phê duyệt lúc này.';
  }
}

class AdminApprovalsException implements Exception {
  const AdminApprovalsException(this.message);

  final String message;

  @override
  String toString() => message;
}
