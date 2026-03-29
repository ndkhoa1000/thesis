import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';
import 'package:parking_app/src/features/admin_approvals/data/admin_approvals_service.dart';
import 'package:parking_app/src/features/admin_approvals/presentation/admin_approvals_screen.dart';
import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/auth/data/auth_service.dart';
import 'package:parking_app/src/features/lot_owner_application/data/lot_owner_application_service.dart';
import 'package:parking_app/src/features/lot_owner_application/presentation/lot_owner_application_screen.dart';
import 'package:parking_app/src/features/lease_contract/data/lease_contract_models.dart';
import 'package:parking_app/src/features/lot_details/data/lot_details_service.dart';
import 'package:parking_app/src/features/map_discovery/data/map_discovery_service.dart';
import 'package:parking_app/src/features/map_discovery/presentation/map_discovery_screen.dart';
import 'package:parking_app/src/features/parking_history/data/parking_history_service.dart';
import 'package:parking_app/src/features/parking_history/presentation/parking_history_screen.dart';
import 'package:parking_app/src/features/operator_application/data/operator_application_service.dart';
import 'package:parking_app/src/features/operator_application/presentation/operator_application_screen.dart';
import 'package:parking_app/src/features/operator_lot_management/data/operator_lot_management_service.dart';
import 'package:parking_app/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart';
import 'package:parking_app/src/features/owner_revenue_dashboard/data/owner_revenue_dashboard_service.dart';
import 'package:parking_app/src/features/parking_lot_registration/data/parking_lot_service.dart';
import 'package:parking_app/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart';
import 'package:parking_app/src/features/vehicles/data/vehicle_service.dart';
import 'package:parking_app/src/features/vehicles/presentation/vehicle_screen.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.session});

  final AuthSession? session;
  bool signOutCalled = false;
  bool lastRememberSession = false;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<AuthSession?> refreshSession() async => session;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    bool rememberSession = false,
  }) async =>
      session ??
      const AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        role: 'DRIVER',
        capabilities: {
          'driver': true,
          'lot_owner': false,
          'operator': false,
          'attendant': false,
          'admin': false,
          'public_account': true,
        },
      );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberSession = false,
  }) async => () {
    lastRememberSession = rememberSession;
    return session ??
        const AuthSession(
          accessToken: 'access',
          refreshToken: 'refresh',
          role: 'DRIVER',
          capabilities: {
            'driver': true,
            'lot_owner': false,
            'operator': false,
            'attendant': false,
            'admin': false,
            'public_account': true,
          },
        );
  }();

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class FakeVehicleService implements VehicleService {
  FakeVehicleService({List<Vehicle>? initialVehicles})
    : _vehicles = List<Vehicle>.from(initialVehicles ?? const []);

  final List<Vehicle> _vehicles;
  int _nextId = 100;

  @override
  Future<Vehicle> createVehicle({
    required String licensePlate,
    required String vehicleType,
  }) async {
    final vehicle = Vehicle(
      id: _nextId++,
      licensePlate: licensePlate.toUpperCase(),
      vehicleType: vehicleType,
    );
    _vehicles.insert(0, vehicle);
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(int vehicleId) async {
    _vehicles.removeWhere((vehicle) => vehicle.id == vehicleId);
  }

  @override
  Future<List<Vehicle>> listVehicles() async => List<Vehicle>.from(_vehicles);
}

class FakeAttendantCheckInService implements AttendantCheckInService {
  FakeAttendantCheckInService({
    this.result,
    this.errorMessage,
    this.parkingLotName = 'Bãi xe Quận 1',
  });

  final AttendantCheckInResult? result;
  final String? errorMessage;
  final String parkingLotName;

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    return AttendantOccupancySummary(
      parkingLotId: 13,
      parkingLotName: parkingLotName,
      hasActiveCapacityConfig: true,
      totalCapacity: 12,
      freeCount: 4,
      occupiedCount: 8,
      vehicleTypeBreakdown: [
        AttendantOccupancyVehicleBreakdown(
          vehicleType: 'MOTORBIKE',
          occupiedCount: 6,
        ),
      ],
    );
  }

  @override
  Future<AttendantFinalShiftCloseOutResult> requestFinalShiftCloseOut() async {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendantActiveSession>> getActiveSessions() async {
    return const [];
  }

  @override
  Future<AttendantShiftHandoverStartResult> prepareShiftHandover() async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckInResult> checkInDriver({required String token}) async {
    if (errorMessage != null) {
      throw AttendantCheckInException(errorMessage!);
    }

    return result ??
        AttendantCheckInResult(
          sessionId: 901,
          parkingLotId: 13,
          currentAvailable: 4,
          licensePlate: '59A-12345',
          vehicleType: 'MOTORBIKE',
          checkedInAt: DateTime(2026, 3, 27, 8, 30),
        );
  }

  @override
  Future<AttendantCheckInResult> checkInWalkIn({
    required String vehicleType,
    required String plateImagePath,
    String? overviewImagePath,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckOutPreviewResult> checkOutPreview({
    required String token,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckOutFinalizeResult> finalizeCheckOut({
    required int sessionId,
    required String paymentMethod,
    required double quotedFinalFee,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantForceCloseTimeoutResult> forceCloseTimeout({
    required int sessionId,
    required String reason,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantShiftHandoverFinalizeResult> finalizeShiftHandover({
    required String token,
    required double actualCash,
    String? discrepancyReason,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckOutUndoResult> undoCheckOut({
    required int sessionId,
  }) async {
    throw UnimplementedError();
  }
}

class FakeMapDiscoveryService implements MapDiscoveryService {
  FakeMapDiscoveryService({this.lots = const []});

  final List<MapDiscoveryLotSummary> lots;

  @override
  Future<List<MapDiscoveryLotSummary>> fetchActiveLots() async => lots;

  @override
  Stream<MapDiscoveryAvailabilityUpdate> watchAvailability() =>
      const Stream.empty();
}

class FakeLotDetailsService implements LotDetailsService {
  @override
  Future<DriverLotDetail> fetchLotDetail({required int lotId}) async {
    return DriverLotDetail(
      id: lotId,
      name: 'Bãi xe $lotId',
      address: '1 Nguyen Hue, Quan 1',
      latitude: 10.7732,
      longitude: 106.7041,
      currentAvailable: 8,
      status: 'APPROVED',
      peakHours: const LotHistoricalTrend(
        status: 'INSUFFICIENT_DATA',
        lookbackDays: 30,
        totalSessions: 0,
        points: [],
      ),
    );
  }
}

class FakeParkingHistoryService implements ParkingHistoryService {
  FakeParkingHistoryService({this.entries = const []});

  final List<DriverParkingHistoryEntry> entries;

  @override
  Future<List<DriverParkingHistoryEntry>> fetchHistory() async => entries;
}

class FakeMapLocationPermissionService implements MapLocationPermissionService {
  const FakeMapLocationPermissionService(this.isGranted);

  final bool isGranted;

  @override
  Future<bool> requestAccess() async => isGranted;
}

Widget _fakeAttendantScannerBuilder(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return const SizedBox.expand();
}

class FakeLotOwnerApplicationService implements LotOwnerApplicationService {
  FakeLotOwnerApplicationService({this.application});

  LotOwnerApplication? application;

  @override
  Future<LotOwnerApplication?> getMyApplication() async => application;

  @override
  Future<LotOwnerApplication> submitApplication({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  }) async {
    application = LotOwnerApplication(
      id: 1,
      userId: 1,
      fullName: fullName,
      phoneNumber: phoneNumber,
      businessLicense: businessLicense,
      documentReference: documentReference,
      status: 'PENDING',
      notes: notes,
    );
    return application!;
  }
}

class FakeOperatorApplicationService implements OperatorApplicationService {
  FakeOperatorApplicationService({this.application});

  OperatorApplication? application;

  @override
  Future<OperatorApplication?> getMyApplication() async => application;

  @override
  Future<OperatorApplication> submitApplication({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  }) async {
    application = OperatorApplication(
      id: 1,
      userId: 1,
      fullName: fullName,
      phoneNumber: phoneNumber,
      businessLicense: businessLicense,
      documentReference: documentReference,
      status: 'PENDING',
      notes: notes,
    );
    return application!;
  }
}

class FakeAdminApprovalsService implements AdminApprovalsService {
  FakeAdminApprovalsService({
    List<AdminApprovalItem>? lotOwnerApplications,
    List<AdminApprovalItem>? operatorApplications,
    List<AdminApprovalItem>? parkingLotApplications,
    List<AdminManagedUser>? managedUsers,
    List<AdminManagedParkingLot>? managedParkingLots,
    this.userActivationCompleter,
    this.parkingLotStatusCompleter,
  }) : _lotOwnerApplications = List<AdminApprovalItem>.from(
         lotOwnerApplications ?? const [],
       ),
       _operatorApplications = List<AdminApprovalItem>.from(
         operatorApplications ?? const [],
       ),
       _parkingLotApplications = List<AdminApprovalItem>.from(
         parkingLotApplications ?? const [],
       ),
       _managedUsers = List<AdminManagedUser>.from(managedUsers ?? const []),
       _managedParkingLots = List<AdminManagedParkingLot>.from(
         managedParkingLots ?? const [],
       );

  final List<AdminApprovalItem> _lotOwnerApplications;
  final List<AdminApprovalItem> _operatorApplications;
  final List<AdminApprovalItem> _parkingLotApplications;
  final List<AdminManagedUser> _managedUsers;
  final List<AdminManagedParkingLot> _managedParkingLots;
  final Completer<void>? userActivationCompleter;
  final Completer<void>? parkingLotStatusCompleter;
  int userActivationCallCount = 0;
  int parkingLotStatusCallCount = 0;

  @override
  Future<AdminApprovalsDashboard> loadDashboard() async {
    return AdminApprovalsDashboard(
      lotOwnerApplications: List<AdminApprovalItem>.from(_lotOwnerApplications),
      operatorApplications: List<AdminApprovalItem>.from(_operatorApplications),
      parkingLotApplications: List<AdminApprovalItem>.from(
        _parkingLotApplications,
      ),
      managedUsers: List<AdminManagedUser>.from(_managedUsers),
      managedParkingLots: _managedParkingLots
          .where((lot) => lot.canSuspend || lot.canReopen)
          .toList(growable: false),
    );
  }

  @override
  Future<AdminApprovalItem> approve({
    required ApprovalSubjectType type,
    required int applicationId,
  }) async {
    final item = _removeItem(type, applicationId);
    return item;
  }

  @override
  Future<AdminApprovalItem> reject({
    required ApprovalSubjectType type,
    required int applicationId,
    required String rejectionReason,
  }) async {
    final item = _removeItem(type, applicationId);
    return item;
  }

  @override
  Future<AdminManagedUser> updateUserActivation({
    required int userId,
    required bool isActive,
  }) async {
    userActivationCallCount += 1;
    if (userActivationCompleter != null) {
      await userActivationCompleter!.future;
    }
    final index = _managedUsers.indexWhere((user) => user.id == userId);
    final current = _managedUsers[index];
    final updated = AdminManagedUser(
      id: current.id,
      name: current.name,
      username: current.username,
      email: current.email,
      phone: current.phone,
      role: current.role,
      isActive: isActive,
      isSuperuser: current.isSuperuser,
    );
    _managedUsers[index] = updated;
    return updated;
  }

  @override
  Future<AdminManagedParkingLot> updateParkingLotStatus({
    required int parkingLotId,
    required String status,
  }) async {
    parkingLotStatusCallCount += 1;
    if (parkingLotStatusCompleter != null) {
      await parkingLotStatusCompleter!.future;
    }
    final index = _managedParkingLots.indexWhere(
      (lot) => lot.id == parkingLotId,
    );
    final current = _managedParkingLots[index];
    final updated = AdminManagedParkingLot(
      id: current.id,
      lotOwnerId: current.lotOwnerId,
      name: current.name,
      address: current.address,
      currentAvailable: current.currentAvailable,
      status: status,
      ownerName: current.ownerName,
      ownerPhone: current.ownerPhone,
      ownerBusinessLicense: current.ownerBusinessLicense,
      description: current.description,
      coverImage: current.coverImage,
    );
    _managedParkingLots[index] = updated;
    return updated;
  }

  AdminApprovalItem _removeItem(ApprovalSubjectType type, int applicationId) {
    final source = switch (type) {
      ApprovalSubjectType.lotOwner => _lotOwnerApplications,
      ApprovalSubjectType.operator => _operatorApplications,
      ApprovalSubjectType.parkingLot => _parkingLotApplications,
    };
    final index = source.indexWhere((item) => item.id == applicationId);
    return source.removeAt(index);
  }
}

class FakeParkingLotService implements ParkingLotService {
  FakeParkingLotService({List<ParkingLotRegistration>? initialLots})
    : _parkingLots = List<ParkingLotRegistration>.from(initialLots ?? const []);

  final List<ParkingLotRegistration> _parkingLots;
  final List<AvailableOperatorOption> _operators = <AvailableOperatorOption>[
    const AvailableOperatorOption(
      managerId: 4,
      userId: 9,
      name: 'Tran Thi B',
      email: 'operator@test.com',
      phone: '0909555666',
      businessLicense: 'OP-001',
    ),
  ];
  int _nextLeaseId = 88;
  int _nextContractId = 120;
  int _nextId = 100;

  @override
  Future<ParkingLotRegistration> createParkingLot({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    String? coverImage,
  }) async {
    final parkingLot = ParkingLotRegistration(
      id: _nextId++,
      lotOwnerId: 1,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      currentAvailable: 0,
      status: 'PENDING',
      description: description,
      coverImage: coverImage,
    );
    _parkingLots.insert(0, parkingLot);
    return parkingLot;
  }

  @override
  Future<List<ParkingLotRegistration>> getMyParkingLots() async {
    return List<ParkingLotRegistration>.from(_parkingLots);
  }

  @override
  Future<List<AvailableOperatorOption>> getAvailableOperators() async {
    return List<AvailableOperatorOption>.from(_operators);
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
    final operator = _operators.firstWhere(
      (item) => item.userId == managerUserId,
    );
    final index = _parkingLots.indexWhere((lot) => lot.id == parkingLotId);
    final current = _parkingLots[index];
    final leaseId = _nextLeaseId++;
    _parkingLots[index] = ParkingLotRegistration(
      id: current.id,
      lotOwnerId: current.lotOwnerId,
      name: current.name,
      address: current.address,
      latitude: current.latitude,
      longitude: current.longitude,
      currentAvailable: current.currentAvailable,
      status: current.status,
      description: current.description,
      coverImage: current.coverImage,
      createdAt: current.createdAt,
      updatedAt: DateTime(2026, 3, 28),
      activeLeaseId: leaseId,
      activeLeaseStatus: 'PENDING',
      activeOperatorUserId: operator.userId,
      activeOperatorName: operator.name,
    );
    return LeaseContractSummary(
      contractId: _nextContractId++,
      leaseId: leaseId,
      parkingLotId: parkingLotId,
      parkingLotName: current.name,
      managerId: operator.managerId,
      managerUserId: operator.userId,
      operatorName: operator.name,
      operatorEmail: operator.email,
      ownerName: 'Nguyen Van A',
      ownerEmail: 'owner@test.com',
      leaseStatus: 'PENDING',
      contractStatus: 'DRAFT',
      monthlyFee: monthlyFee,
      revenueSharePercentage: revenueSharePercentage,
      termMonths: termMonths,
      contractNumber: 'LC-$parkingLotId-$leaseId',
      content: additionalTerms,
      generatedAt: DateTime(2026, 3, 28),
    );
  }
}

class FakeOwnerRevenueDashboardService implements OwnerRevenueDashboardService {
  FakeOwnerRevenueDashboardService({
    Map<int, Map<OwnerRevenuePeriod, OwnerRevenueSummary>>? reportsByLot,
  }) : _reportsByLot = reportsByLot ?? const {};

  final Map<int, Map<OwnerRevenuePeriod, OwnerRevenueSummary>> _reportsByLot;

  @override
  Future<OwnerRevenueSummary> getOwnerRevenueSummary({
    required int parkingLotId,
    required OwnerRevenuePeriod period,
  }) async {
    final lotReports = _reportsByLot[parkingLotId];
    if (lotReports != null && lotReports.containsKey(period)) {
      return lotReports[period]!;
    }

    return OwnerRevenueSummary(
      parkingLotId: parkingLotId,
      parkingLotName: 'Bai xe Nguyen Hue',
      period: period,
      rangeStart: DateTime(2026, 3, 29),
      rangeEnd: DateTime(2026, 3, 29),
      leaseStatus: 'PENDING',
      completedPaymentCount: 0,
      completedSessionCount: 0,
      hasData: false,
      emptyReason: 'NO_ACCEPTED_LEASE',
      emptyMessage:
          'Bãi xe chưa có hợp đồng đã được operator chấp nhận nên chưa thể tổng hợp doanh thu.',
    );
  }
}

class FakeOperatorLotManagementService implements OperatorLotManagementService {
  FakeOperatorLotManagementService({
    List<OperatorManagedParkingLot>? initialLots,
    List<LeaseContractSummary>? initialContracts,
    Map<int, List<OperatorManagedAttendant>>? attendantsByLot,
    Map<int, List<OperatorLotAnnouncement>>? announcementsByLot,
    Map<int, Map<OperatorRevenuePeriod, OperatorRevenueSummary>>? revenueByLot,
  }) : _parkingLots = List<OperatorManagedParkingLot>.from(
         initialLots ?? const [],
       ),
       _contracts = List<LeaseContractSummary>.from(
         initialContracts ?? const [],
       ),
       _attendantsByLot = {
         for (final entry
             in (attendantsByLot ??
                     const <int, List<OperatorManagedAttendant>>{})
                 .entries)
           entry.key: List<OperatorManagedAttendant>.from(entry.value),
       },
       _announcementsByLot = {
         for (final entry
             in (announcementsByLot ??
                     const <int, List<OperatorLotAnnouncement>>{})
                 .entries)
           entry.key: List<OperatorLotAnnouncement>.from(entry.value),
       },
       _revenueByLot = revenueByLot ?? const {};

  final List<OperatorManagedParkingLot> _parkingLots;
  final List<LeaseContractSummary> _contracts;
  final Map<int, List<OperatorManagedAttendant>> _attendantsByLot;
  final Map<int, List<OperatorLotAnnouncement>> _announcementsByLot;
  final Map<int, Map<OperatorRevenuePeriod, OperatorRevenueSummary>>
  _revenueByLot;
  int _nextAttendantId = 200;
  int _nextAnnouncementId = 300;

  @override
  Future<List<OperatorManagedParkingLot>> getManagedParkingLots() async {
    return List<OperatorManagedParkingLot>.from(_parkingLots);
  }

  @override
  Future<List<LeaseContractSummary>> getLeaseContracts() async {
    return List<LeaseContractSummary>.from(_contracts);
  }

  @override
  Future<OperatorRevenueSummary> getRevenueSummary({
    required int parkingLotId,
    required OperatorRevenuePeriod period,
  }) async {
    final lotReports = _revenueByLot[parkingLotId];
    if (lotReports != null && lotReports.containsKey(period)) {
      return lotReports[period]!;
    }

    return OperatorRevenueSummary(
      parkingLotId: parkingLotId,
      parkingLotName: 'Bai xe Nguyen Hue',
      period: period,
      rangeStart: DateTime(2026, 3, 29),
      rangeEnd: DateTime(2026, 3, 29),
      leaseStatus: 'ACTIVE',
      ownerName: 'Nguyen Van A',
      completedPaymentCount: 0,
      completedSessionCount: 0,
      hasData: false,
      vehicleTypeBreakdown: const [],
      emptyReason: 'NO_COMPLETED_PAYMENTS',
      emptyMessage:
          'Không có phiên hoàn tất đã thanh toán trong khoảng thời gian đã chọn.',
    );
  }

  @override
  Future<LeaseContractSummary> acceptLeaseContract({
    required int leaseId,
  }) async {
    final index = _contracts.indexWhere((item) => item.leaseId == leaseId);
    final current = _contracts[index];
    final accepted = LeaseContractSummary(
      contractId: current.contractId,
      leaseId: current.leaseId,
      parkingLotId: current.parkingLotId,
      parkingLotName: current.parkingLotName,
      managerId: current.managerId,
      managerUserId: current.managerUserId,
      operatorName: current.operatorName,
      operatorEmail: current.operatorEmail,
      ownerName: current.ownerName,
      ownerEmail: current.ownerEmail,
      leaseStatus: 'ACTIVE',
      contractStatus: 'ACTIVE',
      monthlyFee: current.monthlyFee,
      revenueSharePercentage: current.revenueSharePercentage,
      termMonths: current.termMonths,
      contractNumber: current.contractNumber,
      content: current.content,
      generatedAt: current.generatedAt,
      startDate: DateTime(2026, 3, 28),
      endDate: DateTime(2026, 9, 28),
    );
    _contracts[index] = accepted;
    _parkingLots.insert(
      0,
      OperatorManagedParkingLot(
        id: current.parkingLotId,
        leaseId: current.leaseId,
        lotOwnerId: 1,
        name: current.parkingLotName,
        address: '1 Nguyen Hue, Quan 1',
        latitude: 10.7732,
        longitude: 106.7041,
        currentAvailable: 0,
        status: 'APPROVED',
        occupiedCount: 0,
      ),
    );
    return accepted;
  }

  @override
  Future<List<OperatorShiftAlert>> getShiftHandoverAlerts() async {
    return const [];
  }

  @override
  Future<OperatorFinalShiftCloseOutDetail> getFinalShiftCloseOutDetail({
    required int closeOutId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<OperatorFinalShiftCloseOutDetail> completeFinalShiftCloseOut({
    required int closeOutId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<OperatorLotAnnouncement>> getLotAnnouncements({
    required int parkingLotId,
  }) async {
    return List<OperatorLotAnnouncement>.from(
      _announcementsByLot[parkingLotId] ?? const <OperatorLotAnnouncement>[],
    );
  }

  @override
  Future<OperatorLotAnnouncement> createLotAnnouncement({
    required int parkingLotId,
    required String title,
    String? content,
    required String announcementType,
    required DateTime visibleFrom,
    DateTime? visibleUntil,
  }) async {
    final announcement = OperatorLotAnnouncement(
      id: _nextAnnouncementId++,
      parkingLotId: parkingLotId,
      postedBy: 8,
      title: title,
      content: content,
      announcementType: announcementType,
      visibleFrom: visibleFrom,
      visibleUntil: visibleUntil,
      createdAt: DateTime(2026, 3, 28),
    );
    final announcements = _announcementsByLot.putIfAbsent(
      parkingLotId,
      () => <OperatorLotAnnouncement>[],
    );
    announcements.insert(0, announcement);
    return announcement;
  }

  @override
  Future<OperatorLotAnnouncement> updateLotAnnouncement({
    required int parkingLotId,
    required int announcementId,
    required String title,
    String? content,
    required String announcementType,
    required DateTime visibleFrom,
    DateTime? visibleUntil,
  }) async {
    final announcements = _announcementsByLot.putIfAbsent(
      parkingLotId,
      () => <OperatorLotAnnouncement>[],
    );
    final index = announcements.indexWhere((item) => item.id == announcementId);
    final current = announcements[index];
    final updated = OperatorLotAnnouncement(
      id: current.id,
      parkingLotId: current.parkingLotId,
      postedBy: current.postedBy,
      title: title,
      content: content,
      announcementType: announcementType,
      visibleFrom: visibleFrom,
      visibleUntil: visibleUntil,
      createdAt: current.createdAt,
    );
    announcements[index] = updated;
    return updated;
  }

  @override
  Future<List<OperatorManagedAttendant>> getLotAttendants({
    required int parkingLotId,
  }) async {
    return List<OperatorManagedAttendant>.from(
      _attendantsByLot[parkingLotId] ?? const <OperatorManagedAttendant>[],
    );
  }

  @override
  Future<OperatorManagedAttendant> createLotAttendant({
    required int parkingLotId,
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    final attendant = OperatorManagedAttendant(
      id: _nextAttendantId++,
      userId: _nextAttendantId + 100,
      parkingLotId: parkingLotId,
      name: name,
      username: username,
      email: email,
      phone: phone,
      isActive: true,
      hiredAt: DateTime(2026, 3, 27),
    );
    final attendants = _attendantsByLot.putIfAbsent(
      parkingLotId,
      () => <OperatorManagedAttendant>[],
    );
    attendants.insert(0, attendant);
    return attendant;
  }

  @override
  Future<void> removeLotAttendant({
    required int parkingLotId,
    required int attendantId,
  }) async {
    _attendantsByLot[parkingLotId]?.removeWhere(
      (attendant) => attendant.id == attendantId,
    );
  }

  @override
  Future<OperatorManagedParkingLot> updateManagedParkingLot({
    required int parkingLotId,
    required String name,
    required String address,
    required int totalCapacity,
    required String openingTime,
    required String closingTime,
    required String pricingMode,
    required double priceAmount,
    String? description,
    String? coverImage,
  }) async {
    final index = _parkingLots.indexWhere((lot) => lot.id == parkingLotId);
    final current = _parkingLots[index];
    final isFirstTimeSetupLot =
        current.status == 'CLOSED' &&
        current.totalCapacity == null &&
        current.pricingMode == null;
    final updated = OperatorManagedParkingLot(
      id: current.id,
      leaseId: current.leaseId,
      lotOwnerId: current.lotOwnerId,
      name: name,
      address: address,
      latitude: current.latitude,
      longitude: current.longitude,
      currentAvailable: totalCapacity > current.occupiedCount
          ? totalCapacity - current.occupiedCount
          : 0,
      status: isFirstTimeSetupLot ? 'APPROVED' : current.status,
      occupiedCount: current.occupiedCount,
      totalCapacity: totalCapacity,
      openingTime: openingTime,
      closingTime: closingTime,
      pricingMode: pricingMode,
      priceAmount: priceAmount,
      description: description,
      coverImage: coverImage,
      createdAt: current.createdAt,
      updatedAt: DateTime(2026, 3, 27),
    );
    _parkingLots[index] = updated;
    return updated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: '');
  });

  testWidgets('ParkingApp shows login screen without session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        authService: FakeAuthService(),
        mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
        lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
        parkingHistoryServiceFactory: (_) => FakeParkingHistoryService(),
        mapLocationPermissionService: const FakeMapLocationPermissionService(
          true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ParkingApp'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Lưu đăng nhập trong 1 ngày'), findsOneWidget);
  });

  testWidgets('Login screen passes remember-session selection', (
    WidgetTester tester,
  ) async {
    final authService = FakeAuthService();

    await tester.pumpWidget(
      MyApp(
        authService: authService,
        mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
        lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
        parkingHistoryServiceFactory: (_) => FakeParkingHistoryService(),
        mapLocationPermissionService: const FakeMapLocationPermissionService(
          true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'driver@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'Str1ngst!123',
    );
    await tester.tap(find.text('Lưu đăng nhập trong 1 ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(authService.lastRememberSession, isTrue);
  });

  testWidgets('ParkingApp routes attendant session to dedicated workspace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        authService: FakeAuthService(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'ATTENDANT',
            capabilities: {
              'driver': false,
              'lot_owner': false,
              'operator': false,
              'attendant': true,
              'admin': false,
              'public_account': false,
            },
          ),
        ),
        attendantCheckInServiceFactory: (_) => FakeAttendantCheckInService(),
        attendantScannerBuilder: _fakeAttendantScannerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BÃI XE — Bãi xe Quận 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attendant-shell-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attendant-shell-top-zone')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attendant-shell-bottom-zone')),
      findsOneWidget,
    );
    expect(find.text('Sẵn sàng quét xe vào bãi'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    final attendantTheme = Theme.of(
      tester.element(find.byKey(const ValueKey('attendant-shell-header'))),
    );
    expect(attendantTheme.scaffoldBackgroundColor, const Color(0xFF121212));
  });

  testWidgets('Attendant shell keeps honest fallback lot header', (
    WidgetTester tester,
  ) async {
    final attendantService = FakeAttendantCheckInService(parkingLotName: '');

    await tester.pumpWidget(
      MyApp(
        authService: FakeAuthService(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'ATTENDANT',
            capabilities: {
              'driver': false,
              'lot_owner': false,
              'operator': false,
              'attendant': true,
              'admin': false,
              'public_account': false,
            },
          ),
        ),
        attendantCheckInServiceFactory: (_) => attendantService,
        attendantScannerBuilder: _fakeAttendantScannerBuilder,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BÃI XE — CHƯA GÁN'), findsOneWidget);
  });

  testWidgets('ParkingApp routes admin session to approvals dashboard', (
    WidgetTester tester,
  ) async {
    final approvalsService = FakeAdminApprovalsService(
      lotOwnerApplications: const [
        AdminApprovalItem(
          id: 1,
          type: ApprovalSubjectType.lotOwner,
          applicantName: 'Nguyen Van A',
          phoneNumber: '0909123456',
          businessLicense: 'BL-001',
          documentReference: 'https://example.com/doc.pdf',
          status: 'PENDING',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'ADMIN',
            capabilities: {
              'driver': false,
              'lot_owner': false,
              'operator': false,
              'attendant': false,
              'admin': true,
              'public_account': false,
            },
          ),
          authService: FakeAuthService(),
          onSignOut: () async {},
          onSessionUpdated: (_) {},
          adminApprovalsServiceFactory: (_) => approvalsService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminApprovalsScreen), findsOneWidget);
    expect(find.text('Duyệt hồ sơ'), findsOneWidget);
    expect(find.text('Người dùng'), findsWidgets);
    expect(find.text('Bãi xe'), findsWidgets);
    expect(find.text('Điều phối hệ thống'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);

    await tester.tap(find.text('Người dùng').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Quản lý người dùng sẽ được gom về workspace riêng'),
      findsOneWidget,
    );

    await tester.tap(find.text('Bãi xe').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Điều phối bãi xe đang bám vào dashboard approvals'),
      findsOneWidget,
    );
  });

  testWidgets('ParkingApp routes manager session to operator lot workspace', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 11,
          leaseId: 3,
          lotOwnerId: 7,
          name: 'Bai xe Le Thanh Ton',
          address: '8 Le Thanh Ton, Quan 1',
          latitude: 10.777,
          longitude: 106.705,
          currentAvailable: 16,
          status: 'APPROVED',
          occupiedCount: 4,
          totalCapacity: 20,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 15000,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'MANAGER',
            capabilities: {
              'driver': true,
              'lot_owner': false,
              'operator': true,
              'attendant': false,
              'admin': false,
              'public_account': true,
            },
          ),
          authService: FakeAuthService(),
          onSignOut: () async {},
          onSessionUpdated: (_) {},
          operatorLotManagementServiceFactory: (_) => lotManagementService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OperatorLotManagementScreen), findsOneWidget);
    expect(find.text('Bãi xe'), findsOneWidget);
    expect(find.text('Nhân viên'), findsOneWidget);
    expect(find.text('Doanh thu'), findsWidgets);
    expect(find.text('Điều hành bãi xe'), findsOneWidget);
    expect(find.text('Bai xe Le Thanh Ton'), findsOneWidget);

    await tester.tap(find.text('Nhân viên'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nhân viên trực đang gắn với từng bãi xe'),
      findsOneWidget,
    );

    await tester.tap(find.text('Doanh thu').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Doanh thu operator hiện mở theo từng bãi xe'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ParkingApp keeps operator-capable public session on driver workspace when primary role is driver',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(
            session: const AuthSession(
              accessToken: 'access',
              refreshToken: 'refresh',
              role: 'DRIVER',
              capabilities: {
                'driver': true,
                'lot_owner': false,
                'operator': true,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
          ),
          mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
          lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
          parkingHistoryServiceFactory: (_) => FakeParkingHistoryService(),
          mapLocationPermissionService: const FakeMapLocationPermissionService(
            true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MapDiscoveryScreen), findsOneWidget);
      expect(find.textContaining('chế độ fallback'), findsOneWidget);
      expect(find.byType(OperatorLotManagementScreen), findsNothing);

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Không gian Operator'), findsOneWidget);
      expect(find.text('Nộp hồ sơ Operator'), findsNothing);
    },
  );

  testWidgets('ParkingApp routes lot owner session to parking lot workspace', (
    WidgetTester tester,
  ) async {
    final parkingLotService = FakeParkingLotService(
      initialLots: const [
        ParkingLotRegistration(
          id: 7,
          lotOwnerId: 1,
          name: 'Bai xe Nguyen Hue',
          address: '1 Nguyen Hue, Quan 1',
          latitude: 10.7732,
          longitude: 106.7041,
          currentAvailable: 0,
          status: 'PENDING',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'LOT_OWNER',
            capabilities: {
              'driver': true,
              'lot_owner': true,
              'operator': false,
              'attendant': false,
              'admin': false,
              'public_account': true,
            },
          ),
          authService: FakeAuthService(),
          onSignOut: () async {},
          onSessionUpdated: (_) {},
          parkingLotServiceFactory: (_) => parkingLotService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ParkingLotRegistrationScreen), findsOneWidget);
    expect(find.text('Bãi của tôi'), findsOneWidget);
    expect(find.text('Hợp đồng'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Bãi xe của tôi'), findsOneWidget);
    expect(find.text('Bai xe Nguyen Hue'), findsOneWidget);

    await tester.tap(find.text('Hợp đồng'));
    await tester.pumpAndSettle();
    expect(
      find.text('Hợp đồng vẫn được khởi tạo từ từng bãi đã duyệt'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Public multi-capability session lands in primary role workspace without switcher bridge',
    (WidgetTester tester) async {
      final parkingLotService = FakeParkingLotService(
        initialLots: const [
          ParkingLotRegistration(
            id: 7,
            lotOwnerId: 1,
            name: 'Bai xe Nguyen Hue',
            address: '1 Nguyen Hue, Quan 1',
            latitude: 10.7732,
            longitude: 106.7041,
            currentAvailable: 0,
            status: 'APPROVED',
          ),
        ],
      );

      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(
            session: const AuthSession(
              accessToken: 'access',
              refreshToken: 'refresh',
              role: 'LOT_OWNER',
              capabilities: {
                'driver': true,
                'lot_owner': true,
                'operator': true,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
          ),
          parkingLotServiceFactory: (_) => parkingLotService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ParkingLotRegistrationScreen), findsOneWidget);
      expect(find.text('Bãi của tôi'), findsOneWidget);
      expect(find.text('Bãi xe của tôi'), findsOneWidget);
      expect(find.text('Chọn không gian làm việc'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Operator'), findsNothing);

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Mở không gian Operator'), findsOneWidget);
    },
  );

  testWidgets(
    'Multi-capability public account can deliberately enter operator shell',
    (WidgetTester tester) async {
      final parkingLotService = FakeParkingLotService(
        initialLots: const [
          ParkingLotRegistration(
            id: 7,
            lotOwnerId: 1,
            name: 'Bai xe Nguyen Hue',
            address: '1 Nguyen Hue, Quan 1',
            latitude: 10.7732,
            longitude: 106.7041,
            currentAvailable: 0,
            status: 'APPROVED',
          ),
        ],
      );
      final lotManagementService = FakeOperatorLotManagementService(
        initialLots: const [
          OperatorManagedParkingLot(
            id: 11,
            leaseId: 3,
            lotOwnerId: 7,
            name: 'Bai xe Le Thanh Ton',
            address: '8 Le Thanh Ton, Quan 1',
            latitude: 10.777,
            longitude: 106.705,
            currentAvailable: 16,
            status: 'APPROVED',
            occupiedCount: 4,
            totalCapacity: 20,
            openingTime: '06:00',
            closingTime: '22:00',
            pricingMode: 'HOURLY',
            priceAmount: 15000,
          ),
        ],
      );

      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(
            session: const AuthSession(
              accessToken: 'access',
              refreshToken: 'refresh',
              role: 'LOT_OWNER',
              capabilities: {
                'driver': true,
                'lot_owner': true,
                'operator': true,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
          ),
          parkingLotServiceFactory: (_) => parkingLotService,
          operatorLotManagementServiceFactory: (_) => lotManagementService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bãi xe của tôi'), findsOneWidget);

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở không gian Operator'));
      await tester.pumpAndSettle();

      expect(find.text('Bãi xe'), findsOneWidget);
      expect(find.text('Nhân viên'), findsOneWidget);
      expect(find.text('Doanh thu'), findsWidgets);
      expect(find.text('Bai xe Le Thanh Ton'), findsOneWidget);
    },
  );

  testWidgets(
    'Public workspace exposes vehicle management without Mapbox token',
    (WidgetTester tester) async {
      final vehicleService = FakeVehicleService(
        initialVehicles: const [
          Vehicle(id: 1, licensePlate: '59A-12345', vehicleType: 'MOTORBIKE'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedHome(
            session: const AuthSession(
              accessToken: 'access',
              refreshToken: 'refresh',
              role: 'DRIVER',
              capabilities: {
                'driver': true,
                'lot_owner': false,
                'operator': false,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
            authService: FakeAuthService(),
            onSignOut: () async {},
            onSessionUpdated: (_) {},
            vehicleServiceFactory: (_) => vehicleService,
            mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
            lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
            parkingHistoryServiceFactory: (_) => FakeParkingHistoryService(),
            mapLocationPermissionService:
                const FakeMapLocationPermissionService(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
      expect(find.textContaining('chế độ fallback'), findsOneWidget);

      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Chưa có lượt gửi xe đã hoàn tất'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Mã check-in'), findsOneWidget);
      expect(find.text('Xe của tôi'), findsOneWidget);
      expect(find.text('Nộp hồ sơ Chủ bãi'), findsOneWidget);
      expect(find.text('Nộp hồ sơ Operator'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);

      await tester.tap(find.text('Xe của tôi'));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleScreen), findsOneWidget);
      expect(find.text('59A-12345'), findsOneWidget);
    },
  );

  testWidgets('Parking history screen renders completed sessions', (
    WidgetTester tester,
  ) async {
    final parkingHistoryService = FakeParkingHistoryService(
      entries: [
        DriverParkingHistoryEntry(
          sessionId: 101,
          parkingLotId: 13,
          parkingLotName: 'Bai xe Nguyen Hue',
          licensePlate: '59A-88888',
          vehicleType: 'CAR',
          checkedInAt: DateTime(2026, 3, 28, 8, 0),
          checkedOutAt: DateTime(2026, 3, 28, 9, 30),
          durationMinutes: 90,
          amountPaid: 25000,
          paymentMethod: 'CASH',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingHistoryScreen(
          parkingHistoryService: parkingHistoryService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Nguyen Hue'), findsOneWidget);
    expect(find.text('59A-88888'), findsOneWidget);
    expect(find.text('1 giờ 30 phút'), findsOneWidget);
    expect(find.text('25000 VND'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsOneWidget);
  });

  testWidgets('Vehicle screen lets driver add and remove a plate', (
    WidgetTester tester,
  ) async {
    final vehicleService = FakeVehicleService();

    await tester.pumpWidget(
      MaterialApp(home: VehicleScreen(vehicleService: vehicleService)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có xe nào'), findsOneWidget);

    await tester.tap(find.byTooltip('Thêm biển số'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Biển số xe'),
      '59a-67890',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('59A-67890'), findsOneWidget);

    await tester.tap(find.byTooltip('Xoá biển số'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('59A-67890'), findsNothing);
    expect(find.textContaining('Chưa có xe nào'), findsOneWidget);
  });

  testWidgets('Authenticated user can log out back to login screen', (
    WidgetTester tester,
  ) async {
    final authService = FakeAuthService(
      session: const AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        role: 'DRIVER',
        capabilities: {
          'driver': true,
          'lot_owner': false,
          'operator': false,
          'attendant': false,
          'admin': false,
          'public_account': true,
        },
      ),
    );

    await tester.pumpWidget(
      MyApp(
        authService: authService,
        mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
        lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
        mapLocationPermissionService: const FakeMapLocationPermissionService(
          true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng xuất'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(authService.signOutCalled, isTrue);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets('Public workspace can open lot owner application screen', (
    WidgetTester tester,
  ) async {
    final applicationService = FakeLotOwnerApplicationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'DRIVER',
            capabilities: {
              'driver': true,
              'lot_owner': false,
              'operator': false,
              'attendant': false,
              'admin': false,
              'public_account': true,
            },
          ),
          authService: FakeAuthService(),
          onSignOut: () async {},
          onSessionUpdated: (_) {},
          applicationServiceFactory: (_) => applicationService,
          mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
          lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
          mapLocationPermissionService: const FakeMapLocationPermissionService(
            true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nộp hồ sơ Chủ bãi').first);
    await tester.pumpAndSettle();

    expect(find.byType(LotOwnerApplicationScreen), findsOneWidget);
    expect(find.text('Nộp hồ sơ Chủ bãi'), findsWidgets);
  });

  testWidgets('Lot owner application screen submits and shows pending status', (
    WidgetTester tester,
  ) async {
    final applicationService = FakeLotOwnerApplicationService();

    await tester.pumpWidget(
      MaterialApp(
        home: LotOwnerApplicationScreen(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'DRIVER',
            capabilities: {
              'driver': true,
              'lot_owner': false,
              'operator': false,
              'attendant': false,
              'admin': false,
              'public_account': true,
            },
          ),
          authService: FakeAuthService(),
          applicationService: applicationService,
          onSessionUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nộp hồ sơ Chủ bãi').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Nguyen Van A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '0909123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giấy phép kinh doanh / sở hữu'),
      'BL-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Link tài liệu xác minh'),
      'https://example.com/doc.pdf',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi hồ sơ'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ duyệt'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
  });

  testWidgets('Public workspace can open operator application screen', (
    WidgetTester tester,
  ) async {
    final applicationService = FakeOperatorApplicationService();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedHome(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'DRIVER',
            capabilities: {
              'driver': true,
              'lot_owner': false,
              'operator': false,
              'attendant': false,
              'admin': false,
              'public_account': true,
            },
          ),
          authService: FakeAuthService(),
          onSignOut: () async {},
          onSessionUpdated: (_) {},
          operatorApplicationServiceFactory: (_) => applicationService,
          mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
          lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
          mapLocationPermissionService: const FakeMapLocationPermissionService(
            true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nộp hồ sơ Operator').first);
    await tester.pumpAndSettle();

    expect(find.byType(OperatorApplicationScreen), findsOneWidget);
    expect(find.text('Nộp hồ sơ Operator'), findsWidgets);
  });

  testWidgets(
    'Driver workspace shell switches between map history and profile tabs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MyApp(
          authService: FakeAuthService(
            session: const AuthSession(
              accessToken: 'access',
              refreshToken: 'refresh',
              role: 'DRIVER',
              capabilities: {
                'driver': true,
                'lot_owner': false,
                'operator': false,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
          ),
          mapDiscoveryServiceFactory: (_) => FakeMapDiscoveryService(),
          lotDetailsServiceFactory: (_) => FakeLotDetailsService(),
          parkingHistoryServiceFactory: (_) => FakeParkingHistoryService(),
          mapLocationPermissionService: const FakeMapLocationPermissionService(
            true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MapDiscoveryScreen), findsOneWidget);
      expect(find.byTooltip('Lịch sử gửi xe'), findsNothing);
      expect(find.byTooltip('Xe của tôi'), findsNothing);

      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingHistoryScreen), findsOneWidget);

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Mã check-in'), findsOneWidget);
      expect(find.text('Xe của tôi'), findsOneWidget);
    },
  );

  testWidgets('Operator application screen submits and shows pending status', (
    WidgetTester tester,
  ) async {
    final applicationService = FakeOperatorApplicationService();

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorApplicationScreen(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'DRIVER',
            capabilities: {
              'driver': true,
              'lot_owner': false,
              'operator': false,
              'attendant': false,
              'admin': false,
              'public_account': true,
            },
          ),
          authService: FakeAuthService(),
          applicationService: applicationService,
          onSessionUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nộp hồ sơ Operator').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Nguyen Van B',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '0909555666',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giấy phép kinh doanh / mã số thuế'),
      'OP-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Link tài liệu xác minh'),
      'https://example.com/operator.pdf',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi hồ sơ'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ duyệt'), findsOneWidget);
    expect(find.text('Nguyen Van B'), findsOneWidget);
  });

  testWidgets(
    'Operator application form blocks values shorter than backend rules',
    (WidgetTester tester) async {
      final applicationService = FakeOperatorApplicationService();

      await tester.pumpWidget(
        MaterialApp(
          home: OperatorApplicationScreen(
            session: const AuthSession(
              accessToken: 'access',
              refreshToken: 'refresh',
              role: 'DRIVER',
              capabilities: {
                'driver': true,
                'lot_owner': false,
                'operator': false,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
            authService: FakeAuthService(),
            applicationService: applicationService,
            onSessionUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nộp hồ sơ Operator').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Họ và tên'),
        'A',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại'),
        '1234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Giấy phép kinh doanh / mã số thuế'),
        'OP1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Link tài liệu xác minh'),
        'abc',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi hồ sơ'));
      await tester.pumpAndSettle();

      expect(find.text('Họ và tên phải có ít nhất 2 ký tự'), findsOneWidget);
      expect(
        find.text('Số điện thoại phải có ít nhất 8 ký tự'),
        findsOneWidget,
      );
      expect(
        find.text('Giấy phép kinh doanh phải có ít nhất 4 ký tự'),
        findsOneWidget,
      );
      expect(
        find.text('Link tài liệu phải có ít nhất 4 ký tự'),
        findsOneWidget,
      );
      expect(applicationService.application, isNull);
    },
  );

  testWidgets('Admin approvals dashboard can approve a pending application', (
    WidgetTester tester,
  ) async {
    final approvalsService = FakeAdminApprovalsService(
      operatorApplications: const [
        AdminApprovalItem(
          id: 9,
          type: ApprovalSubjectType.operator,
          applicantName: 'Tran Thi B',
          phoneNumber: '0909555666',
          businessLicense: 'OP-001',
          documentReference: 'https://example.com/operator.pdf',
          status: 'PENDING',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminApprovalsScreen(
          approvalsService: approvalsService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Operator'));
    await tester.pumpAndSettle();

    expect(find.text('Tran Thi B'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Tran Thi B'), findsNothing);
    expect(find.text('Không có hồ sơ Operator chờ duyệt'), findsOneWidget);
  });

  testWidgets('Lot owner workspace can submit a new parking lot', (
    WidgetTester tester,
  ) async {
    final parkingLotService = FakeParkingLotService();
    final ownerRevenueDashboardService = FakeOwnerRevenueDashboardService();

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingLotRegistrationScreen(
          parkingLotService: parkingLotService,
          ownerRevenueDashboardService: ownerRevenueDashboardService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có bãi xe nào được khai báo'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo hồ sơ bãi xe'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên bãi xe'),
      'Bai xe Ben Thanh',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Địa chỉ'),
      '45 Le Loi, Quan 1',
    );
    await tester.tap(find.byKey(const ValueKey('openLocationPickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fallbackLocationPickerCanvas')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmLocationPickerButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mô tả'),
      'Co camera va che mua',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đăng ký'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Ben Thanh'), findsOneWidget);
    expect(find.text('Đang chờ duyệt'), findsOneWidget);
  });

  testWidgets('Lot owner workspace can create a lease contract draft', (
    WidgetTester tester,
  ) async {
    final parkingLotService = FakeParkingLotService(
      initialLots: const [
        ParkingLotRegistration(
          id: 7,
          lotOwnerId: 1,
          name: 'Bai xe Nguyen Hue',
          address: '1 Nguyen Hue, Quan 1',
          latitude: 10.7732,
          longitude: 106.7041,
          currentAvailable: 0,
          status: 'APPROVED',
        ),
      ],
    );
    final ownerRevenueDashboardService = FakeOwnerRevenueDashboardService();

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingLotRegistrationScreen(
          parkingLotService: parkingLotService,
          ownerRevenueDashboardService: ownerRevenueDashboardService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo hợp đồng thuê'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tran Thi B'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Phí thuê hàng tháng (VND)'),
      '15000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tỷ lệ doanh thu cho chủ bãi (%)'),
      '35',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Thời hạn hợp đồng (tháng)'),
      '6',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Gửi hợp đồng cho operator'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Operator đang phụ trách'), findsOneWidget);
    expect(find.text('Tran Thi B'), findsWidgets);
    expect(find.text('Lease'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets(
    'Lot owner revenue dashboard shows metrics and period switching',
    (WidgetTester tester) async {
      final parkingLotService = FakeParkingLotService(
        initialLots: const [
          ParkingLotRegistration(
            id: 7,
            lotOwnerId: 1,
            name: 'Bai xe Nguyen Hue',
            address: '1 Nguyen Hue, Quan 1',
            latitude: 10.7732,
            longitude: 106.7041,
            currentAvailable: 0,
            status: 'APPROVED',
            activeLeaseId: 88,
            activeLeaseStatus: 'ACTIVE',
            activeOperatorUserId: 9,
            activeOperatorName: 'Tran Thi B',
          ),
        ],
      );
      final ownerRevenueDashboardService = FakeOwnerRevenueDashboardService(
        reportsByLot: {
          7: {
            OwnerRevenuePeriod.day: OwnerRevenueSummary(
              parkingLotId: 7,
              parkingLotName: 'Bai xe Nguyen Hue',
              period: OwnerRevenuePeriod.day,
              rangeStart: DateTime(2026, 3, 29),
              rangeEnd: DateTime(2026, 3, 29),
              leaseStatus: 'ACTIVE',
              operatorName: 'Tran Thi B',
              revenueSharePercentage: 35,
              leaseStartDate: DateTime(2026, 3, 1),
              leaseEndDate: DateTime(2026, 9, 1),
              completedPaymentCount: 2,
              completedSessionCount: 2,
              hasData: true,
              grossRevenue: 400000,
              ownerShare: 140000,
              operatorShare: 260000,
            ),
            OwnerRevenuePeriod.week: OwnerRevenueSummary(
              parkingLotId: 7,
              parkingLotName: 'Bai xe Nguyen Hue',
              period: OwnerRevenuePeriod.week,
              rangeStart: DateTime(2026, 3, 23),
              rangeEnd: DateTime(2026, 3, 29),
              leaseStatus: 'ACTIVE',
              operatorName: 'Tran Thi B',
              revenueSharePercentage: 35,
              leaseStartDate: DateTime(2026, 3, 1),
              leaseEndDate: DateTime(2026, 9, 1),
              completedPaymentCount: 5,
              completedSessionCount: 5,
              hasData: true,
              grossRevenue: 900000,
              ownerShare: 315000,
              operatorShare: 585000,
            ),
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ParkingLotRegistrationScreen(
            parkingLotService: parkingLotService,
            ownerRevenueDashboardService: ownerRevenueDashboardService,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Xem doanh thu'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Dashboard doanh thu'), findsOneWidget);
      expect(find.text('400000 VND'), findsOneWidget);
      expect(find.text('140000 VND'), findsOneWidget);

      await tester.tap(find.text('Tuần'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('900000 VND'), findsOneWidget);
      expect(find.text('315000 VND'), findsOneWidget);
    },
  );

  testWidgets('Lot owner revenue dashboard shows empty state for expired lease', (
    WidgetTester tester,
  ) async {
    final parkingLotService = FakeParkingLotService(
      initialLots: const [
        ParkingLotRegistration(
          id: 9,
          lotOwnerId: 1,
          name: 'Bai xe Ben Thanh',
          address: '45 Le Loi, Quan 1',
          latitude: 10.7719,
          longitude: 106.6983,
          currentAvailable: 0,
          status: 'APPROVED',
          activeLeaseId: 91,
          activeLeaseStatus: 'EXPIRED',
          activeOperatorUserId: 12,
          activeOperatorName: 'Le Van C',
        ),
      ],
    );
    final ownerRevenueDashboardService = FakeOwnerRevenueDashboardService(
      reportsByLot: {
        9: {
          OwnerRevenuePeriod.day: OwnerRevenueSummary(
            parkingLotId: 9,
            parkingLotName: 'Bai xe Ben Thanh',
            period: OwnerRevenuePeriod.day,
            rangeStart: DateTime(2026, 3, 29),
            rangeEnd: DateTime(2026, 3, 29),
            leaseStatus: 'EXPIRED',
            operatorName: 'Le Van C',
            revenueSharePercentage: 35,
            leaseStartDate: DateTime(2025, 9, 1),
            leaseEndDate: DateTime(2026, 3, 28),
            completedPaymentCount: 0,
            completedSessionCount: 0,
            hasData: false,
            emptyReason: 'NO_COMPLETED_PAYMENTS',
            emptyMessage:
                'Không có phiên gửi xe đã thanh toán hoàn tất trong khoảng thời gian đã chọn.',
          ),
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingLotRegistrationScreen(
          parkingLotService: parkingLotService,
          ownerRevenueDashboardService: ownerRevenueDashboardService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Xem doanh thu'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('EXPIRED'), findsWidgets);
    expect(find.text('Chưa có dữ liệu doanh thu'), findsOneWidget);
    expect(
      find.text(
        'Không có phiên gửi xe đã thanh toán hoàn tất trong khoảng thời gian đã chọn.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Operator workspace can accept a pending lease contract', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialContracts: [
        LeaseContractSummary(
          contractId: 120,
          leaseId: 88,
          parkingLotId: 7,
          parkingLotName: 'Bai xe Nguyen Hue',
          managerId: 4,
          managerUserId: 9,
          operatorName: 'Tran Thi B',
          operatorEmail: 'operator@test.com',
          ownerName: 'Nguyen Van A',
          ownerEmail: 'owner@test.com',
          leaseStatus: 'PENDING',
          contractStatus: 'DRAFT',
          monthlyFee: 15000000,
          revenueSharePercentage: 35,
          termMonths: 6,
          contractNumber: 'LC-7-88',
          content: 'Operator manages the lot under owner oversight.',
          generatedAt: DateTime(2026, 3, 28),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hợp đồng chờ xác nhận'), findsOneWidget);
    expect(find.text('Bai xe Nguyen Hue'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Chấp nhận hợp đồng'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Hợp đồng chờ xác nhận'), findsNothing);
    expect(find.text('Bai xe Nguyen Hue'), findsOneWidget);
  });

  testWidgets('Operator revenue dashboard shows metrics and period switching', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 7,
          leaseId: 88,
          lotOwnerId: 1,
          name: 'Bai xe Nguyen Hue',
          address: '1 Nguyen Hue, Quan 1',
          latitude: 10.7732,
          longitude: 106.7041,
          currentAvailable: 5,
          status: 'APPROVED',
          occupiedCount: 3,
          totalCapacity: 20,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 15000,
        ),
      ],
      revenueByLot: {
        7: {
          OperatorRevenuePeriod.day: OperatorRevenueSummary(
            parkingLotId: 7,
            parkingLotName: 'Bai xe Nguyen Hue',
            period: OperatorRevenuePeriod.day,
            rangeStart: DateTime(2026, 3, 29),
            rangeEnd: DateTime(2026, 3, 29),
            leaseStatus: 'ACTIVE',
            ownerName: 'Nguyen Van A',
            revenueSharePercentage: 35,
            totalCapacity: 20,
            occupancyRatePercentage: 5.0,
            completedPaymentCount: 2,
            completedSessionCount: 2,
            hasData: true,
            grossRevenue: 400000,
            ownerShare: 140000,
            operatorShare: 260000,
            vehicleTypeBreakdown: const [
              OperatorRevenueVehicleBreakdown(
                vehicleType: 'CAR',
                sessionCount: 1,
              ),
              OperatorRevenueVehicleBreakdown(
                vehicleType: 'MOTORBIKE',
                sessionCount: 1,
              ),
            ],
          ),
          OperatorRevenuePeriod.week: OperatorRevenueSummary(
            parkingLotId: 7,
            parkingLotName: 'Bai xe Nguyen Hue',
            period: OperatorRevenuePeriod.week,
            rangeStart: DateTime(2026, 3, 23),
            rangeEnd: DateTime(2026, 3, 29),
            leaseStatus: 'ACTIVE',
            ownerName: 'Nguyen Van A',
            revenueSharePercentage: 35,
            totalCapacity: 20,
            occupancyRatePercentage: 14.0,
            completedPaymentCount: 5,
            completedSessionCount: 5,
            hasData: true,
            grossRevenue: 900000,
            ownerShare: 315000,
            operatorShare: 585000,
            vehicleTypeBreakdown: const [
              OperatorRevenueVehicleBreakdown(
                vehicleType: 'CAR',
                sessionCount: 3,
              ),
              OperatorRevenueVehicleBreakdown(
                vehicleType: 'MOTORBIKE',
                sessionCount: 2,
              ),
            ],
          ),
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Doanh thu'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Dashboard operator'), findsOneWidget);
    expect(find.text('260000 VND'), findsOneWidget);
    expect(find.text('5.0%'), findsOneWidget);
    expect(find.text('CAR'), findsOneWidget);

    await tester.tap(find.text('Tuần'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('585000 VND'), findsOneWidget);
    expect(find.text('14.0%'), findsOneWidget);
    expect(find.text('3 phiên'), findsOneWidget);
  });

  testWidgets('Operator revenue dashboard shows empty state for expired lease', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 9,
          leaseId: 91,
          lotOwnerId: 1,
          name: 'Bai xe Ben Thanh',
          address: '45 Le Loi, Quan 1',
          latitude: 10.7719,
          longitude: 106.6983,
          currentAvailable: 8,
          status: 'APPROVED',
          occupiedCount: 0,
          totalCapacity: 10,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'SESSION',
          priceAmount: 12000,
        ),
      ],
      revenueByLot: {
        9: {
          OperatorRevenuePeriod.day: OperatorRevenueSummary(
            parkingLotId: 9,
            parkingLotName: 'Bai xe Ben Thanh',
            period: OperatorRevenuePeriod.day,
            rangeStart: DateTime(2026, 3, 29),
            rangeEnd: DateTime(2026, 3, 29),
            leaseStatus: 'EXPIRED',
            ownerName: 'Nguyen Van A',
            revenueSharePercentage: 35,
            totalCapacity: 10,
            completedPaymentCount: 0,
            completedSessionCount: 0,
            hasData: false,
            vehicleTypeBreakdown: const [],
            emptyReason: 'NO_COMPLETED_PAYMENTS',
            emptyMessage:
                'Không có phiên hoàn tất đã thanh toán trong khoảng thời gian đã chọn.',
          ),
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Doanh thu'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('EXPIRED'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu vận hành'), findsOneWidget);
    expect(
      find.text(
        'Không có phiên hoàn tất đã thanh toán trong khoảng thời gian đã chọn.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Admin dashboard can approve a pending parking lot', (
    WidgetTester tester,
  ) async {
    final approvalsService = FakeAdminApprovalsService(
      parkingLotApplications: const [
        AdminApprovalItem(
          id: 12,
          type: ApprovalSubjectType.parkingLot,
          applicantName: 'Nguyen Van A',
          phoneNumber: '0909123456',
          businessLicense: 'BL-001',
          documentReference: '1 Nguyen Hue, Quan 1',
          status: 'PENDING',
          parkingLotName: 'Bai xe Nguyen Hue',
          parkingLotAddress: '1 Nguyen Hue, Quan 1',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminApprovalsScreen(
          approvalsService: approvalsService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bãi xe'));
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Nguyen Hue'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Nguyen Hue'), findsNothing);
    expect(find.text('Không có đăng ký bãi xe chờ duyệt'), findsOneWidget);
  });

  testWidgets('Admin dashboard can deactivate and reactivate a user', (
    WidgetTester tester,
  ) async {
    final approvalsService = FakeAdminApprovalsService(
      managedUsers: const [
        AdminManagedUser(
          id: 5,
          name: 'Le Thi C',
          username: 'lethic',
          email: 'c@example.com',
          phone: '0909888777',
          role: 'LOT_OWNER',
          isActive: true,
          isSuperuser: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminApprovalsScreen(
          approvalsService: approvalsService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Người dùng'));
    await tester.pumpAndSettle();

    expect(find.text('Le Thi C'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Vô hiệu hóa'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đã khóa'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kích hoạt lại'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Kích hoạt lại'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đang hoạt động'), findsOneWidget);
  });

  testWidgets('Admin dashboard can suspend and reopen a parking lot', (
    WidgetTester tester,
  ) async {
    final approvalsService = FakeAdminApprovalsService(
      managedParkingLots: const [
        AdminManagedParkingLot(
          id: 14,
          lotOwnerId: 2,
          name: 'Bai xe Ham Nghi',
          address: '12 Ham Nghi, Quan 1',
          currentAvailable: 8,
          status: 'APPROVED',
          ownerName: 'Pham Van D',
          ownerPhone: '0909444555',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminApprovalsScreen(
          approvalsService: approvalsService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vận hành bãi'));
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Ham Nghi'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tạm dừng bãi xe'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đã tạm dừng'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Mở lại bãi xe'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Mở lại bãi xe'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Đang hoạt động'), findsOneWidget);
  });

  testWidgets('Admin operations tab excludes pending and rejected lots', (
    WidgetTester tester,
  ) async {
    final approvalsService = FakeAdminApprovalsService(
      managedParkingLots: const [
        AdminManagedParkingLot(
          id: 14,
          lotOwnerId: 2,
          name: 'Bai xe Ham Nghi',
          address: '12 Ham Nghi, Quan 1',
          currentAvailable: 8,
          status: 'APPROVED',
          ownerName: 'Pham Van D',
          ownerPhone: '0909444555',
        ),
        AdminManagedParkingLot(
          id: 15,
          lotOwnerId: 2,
          name: 'Bai xe Pending',
          address: '15 Ham Nghi, Quan 1',
          currentAvailable: 0,
          status: 'PENDING',
          ownerName: 'Pham Van D',
        ),
        AdminManagedParkingLot(
          id: 16,
          lotOwnerId: 2,
          name: 'Bai xe Rejected',
          address: '16 Ham Nghi, Quan 1',
          currentAvailable: 0,
          status: 'REJECTED',
          ownerName: 'Pham Van D',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminApprovalsScreen(
          approvalsService: approvalsService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vận hành bãi'));
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Ham Nghi'), findsOneWidget);
    expect(find.text('Bai xe Pending'), findsNothing);
    expect(find.text('Bai xe Rejected'), findsNothing);
  });

  testWidgets('Admin user action is disabled while request is pending', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    final approvalsService = FakeAdminApprovalsService(
      managedUsers: const [
        AdminManagedUser(
          id: 5,
          name: 'Le Thi C',
          username: 'lethic',
          email: 'c@example.com',
          phone: '0909888777',
          role: 'LOT_OWNER',
          isActive: true,
          isSuperuser: false,
        ),
      ],
      userActivationCompleter: completer,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminApprovalsScreen(
          approvalsService: approvalsService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Người dùng'));
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, 'Vô hiệu hóa');
    await tester.tap(buttonFinder);
    await tester.pump();

    final button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNull);
    expect(approvalsService.userActivationCallCount, 1);

    await tester.tap(buttonFinder, warnIfMissed: false);
    await tester.pump();
    expect(approvalsService.userActivationCallCount, 1);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Đã khóa'), findsOneWidget);
  });

  testWidgets('Operator workspace can update lot details and capacity', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 21,
          leaseId: 9,
          lotOwnerId: 5,
          name: 'Bai xe Dong Khoi',
          address: '18 Dong Khoi, Quan 1',
          latitude: 10.776,
          longitude: 106.703,
          currentAvailable: 12,
          status: 'APPROVED',
          occupiedCount: 3,
          totalCapacity: 15,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 18000,
          description: 'Gan trung tam thuong mai',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Dong Khoi'), findsOneWidget);
    expect(find.text('3/15 xe đang trong bãi'), findsOneWidget);
    expect(find.text('06:00 - 22:00'), findsOneWidget);
    expect(find.text('Theo giờ: 18000 VND'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Cập nhật cấu hình'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên bãi xe'),
      'Bai xe Dong Khoi Mo Rong',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tổng sức chứa tối đa'),
      '25',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giờ mở cửa (HH:mm)'),
      '5:00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giờ đóng cửa (HH:mm)'),
      '23:30',
    );
    await tester.tap(find.text('Theo giờ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theo lượt').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giá hiện hành (VND)'),
      '30000',
    );
    final saveButton = find.widgetWithText(FilledButton, 'Lưu cấu hình');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Dong Khoi Mo Rong'), findsOneWidget);
    expect(find.text('3/25 xe đang trong bãi'), findsOneWidget);
    expect(find.text('22 xe'), findsOneWidget);
    expect(find.text('05:00 - 23:30'), findsOneWidget);
    expect(find.text('Theo lượt: 30000 VND'), findsOneWidget);
  });

  testWidgets('Operator workspace can create and remove attendant accounts', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 23,
          leaseId: 11,
          lotOwnerId: 5,
          name: 'Bai xe Pasteur',
          address: '12 Pasteur, Quan 1',
          latitude: 10.779,
          longitude: 106.699,
          currentAvailable: 10,
          status: 'APPROVED',
          occupiedCount: 2,
          totalCapacity: 12,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 15000,
        ),
      ],
      attendantsByLot: {
        23: const [
          OperatorManagedAttendant(
            id: 51,
            userId: 301,
            parkingLotId: 23,
            name: 'Tran Van Truc',
            username: 'tranvantruc',
            email: 'truc@parking.vn',
            phone: '0909888777',
            isActive: true,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Nhân viên trực'));
    await tester.pumpAndSettle();

    expect(find.text('Tran Van Truc'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Tạo tài khoản Attendant'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Le Thi Hoa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên đăng nhập'),
      'lethihoa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'hoa@parking.vn',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu tạm thời'),
      'Str1ngst!123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại (tuỳ chọn)'),
      '0909111222',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final createAttendantButton = find.widgetWithText(
      FilledButton,
      'Tạo tài khoản',
    );
    await tester.scrollUntilVisible(
      createAttendantButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(createAttendantButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Le Thi Hoa'), findsOneWidget);
    expect(find.text('hoa@parking.vn'), findsOneWidget);

    final revokeButton = find
        .widgetWithText(OutlinedButton, 'Thu hồi tài khoản')
        .last;
    await tester.dragUntilVisible(
      revokeButton,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    final revokeAction = tester.widget<OutlinedButton>(revokeButton).onPressed;
    expect(revokeAction, isNotNull);
    revokeAction!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Tran Van Truc'), findsNothing);
    expect(find.text('Le Thi Hoa'), findsOneWidget);
  });

  testWidgets('Operator workspace can create and update lot announcements', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 24,
          leaseId: 12,
          lotOwnerId: 5,
          name: 'Bai xe Hai Ba Trung',
          address: '88 Hai Ba Trung, Quan 1',
          latitude: 10.779,
          longitude: 106.703,
          currentAvailable: 7,
          status: 'APPROVED',
          occupiedCount: 5,
          totalCapacity: 12,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 15000,
        ),
      ],
      announcementsByLot: {
        24: [
          OperatorLotAnnouncement(
            id: 401,
            parkingLotId: 24,
            postedBy: 8,
            title: 'Thong bao hien co',
            content: 'Su dung cong chinh o mat truoc.',
            announcementType: 'GENERAL',
            visibleFrom: DateTime(2026, 3, 28, 7, 0),
            visibleUntil: DateTime(2026, 3, 29, 22, 0),
            createdAt: DateTime(2026, 3, 28, 7, 0),
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Thong bao hien co'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo thông báo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tiêu đề'),
      'Bao tri cong 2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nội dung (tuỳ chọn)'),
      'Su dung loi vao phia sau trong khung gio cao diem.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bắt đầu hiển thị (YYYY-MM-DD HH:mm)'),
      '2026-03-29 07:30',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kết thúc hiển thị (tuỳ chọn)'),
      '2026-03-30 22:00',
    );
    final saveAnnouncementButton = find.widgetWithText(
      FilledButton,
      'Lưu thông báo',
    );
    await tester.ensureVisible(saveAnnouncementButton);
    await tester.tap(saveAnnouncementButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bao tri cong 2'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Cập nhật thông báo').first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tiêu đề'),
      'Bao tri cong 2 cap nhat',
    );
    await tester.ensureVisible(saveAnnouncementButton);
    await tester.tap(saveAnnouncementButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bao tri cong 2 cap nhat'), findsOneWidget);
    expect(find.text('Bao tri cong 2'), findsNothing);
  });

  testWidgets('Operator workspace rejects impossible announcement dates', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 24,
          leaseId: 12,
          lotOwnerId: 5,
          name: 'Bai xe Hai Ba Trung',
          address: '88 Hai Ba Trung, Quan 1',
          latitude: 10.779,
          longitude: 106.703,
          currentAvailable: 7,
          status: 'APPROVED',
          occupiedCount: 5,
          totalCapacity: 12,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 15000,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Thông báo'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo thông báo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tiêu đề'),
      'Thong bao ngay sai',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bắt đầu hiển thị (YYYY-MM-DD HH:mm)'),
      '2026-02-31 07:30',
    );

    final saveAnnouncementButton = find.widgetWithText(
      FilledButton,
      'Lưu thông báo',
    );
    await tester.ensureVisible(saveAnnouncementButton);
    await tester.tap(saveAnnouncementButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Nhập theo định dạng YYYY-MM-DD HH:mm'), findsOneWidget);
    expect(find.text('Thong bao ngay sai'), findsOneWidget);
  });

  testWidgets('Operator workspace floors available slots at zero', (
    WidgetTester tester,
  ) async {
    final lotManagementService = FakeOperatorLotManagementService(
      initialLots: const [
        OperatorManagedParkingLot(
          id: 22,
          leaseId: 10,
          lotOwnerId: 5,
          name: 'Bai xe Le Loi',
          address: '45 Le Loi, Quan 1',
          latitude: 10.7729,
          longitude: 106.6983,
          currentAvailable: 1,
          status: 'APPROVED',
          occupiedCount: 3,
          totalCapacity: 4,
          openingTime: '06:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 12000,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: lotManagementService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Cập nhật cấu hình'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tổng sức chứa tối đa'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giờ mở cửa (HH:mm)'),
      '06:00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Giờ đóng cửa (HH:mm)'),
      '22:00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mức giá hiện hành (VND)'),
      '12000',
    );
    final saveButton = find.widgetWithText(FilledButton, 'Lưu cấu hình');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('3/2 xe đang trong bãi'), findsOneWidget);
    expect(find.text('0 xe'), findsOneWidget);
  });

  testWidgets(
    'Operator first-time setup lot reopens after successful configuration',
    (WidgetTester tester) async {
      final lotManagementService = FakeOperatorLotManagementService(
        initialLots: const [
          OperatorManagedParkingLot(
            id: 30,
            leaseId: 14,
            lotOwnerId: 5,
            name: 'Bai xe Thiet Lap',
            address: '45 Le Loi, Quan 1',
            latitude: 10.7729,
            longitude: 106.6983,
            currentAvailable: 0,
            status: 'CLOSED',
            occupiedCount: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OperatorLotManagementScreen(
            lotManagementService: lotManagementService,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đang tạm dừng'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Thiết lập sức chứa'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tổng sức chứa tối đa'),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Giờ mở cửa (HH:mm)'),
        '07:00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Giờ đóng cửa (HH:mm)'),
        '22:30',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mức giá hiện hành (VND)'),
        '12000',
      );
      final saveButton = find.widgetWithText(FilledButton, 'Lưu cấu hình');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Đang vận hành'), findsOneWidget);
      expect(find.text('12 xe'), findsOneWidget);
    },
  );
}
