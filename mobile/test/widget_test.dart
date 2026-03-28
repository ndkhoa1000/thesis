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
import 'package:parking_app/src/features/lot_details/data/lot_details_service.dart';
import 'package:parking_app/src/features/map_discovery/data/map_discovery_service.dart';
import 'package:parking_app/src/features/map_discovery/presentation/map_discovery_screen.dart';
import 'package:parking_app/src/features/operator_application/data/operator_application_service.dart';
import 'package:parking_app/src/features/operator_application/presentation/operator_application_screen.dart';
import 'package:parking_app/src/features/operator_lot_management/data/operator_lot_management_service.dart';
import 'package:parking_app/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart';
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
  FakeAttendantCheckInService({this.result, this.errorMessage});

  final AttendantCheckInResult? result;
  final String? errorMessage;

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
  Future<LeaseBootstrapAssignment> bootstrapLease({
    required int parkingLotId,
    required int managerUserId,
    double monthlyFee = 0,
  }) async {
    final operator = _operators.firstWhere(
      (item) => item.userId == managerUserId,
    );
    final index = _parkingLots.indexWhere((lot) => lot.id == parkingLotId);
    final current = _parkingLots[index];
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
      updatedAt: DateTime(2026, 3, 27),
      activeLeaseId: 88,
      activeLeaseStatus: 'ACTIVE',
      activeOperatorUserId: operator.userId,
      activeOperatorName: operator.name,
    );
    return LeaseBootstrapAssignment(
      leaseId: 88,
      parkingLotId: parkingLotId,
      managerId: operator.managerId,
      managerUserId: operator.userId,
      operatorName: operator.name,
      status: 'ACTIVE',
      monthlyFee: monthlyFee,
      startDate: DateTime(2026, 3, 27),
    );
  }
}

class FakeOperatorLotManagementService implements OperatorLotManagementService {
  FakeOperatorLotManagementService({
    List<OperatorManagedParkingLot>? initialLots,
    Map<int, List<OperatorManagedAttendant>>? attendantsByLot,
  }) : _parkingLots = List<OperatorManagedParkingLot>.from(
         initialLots ?? const [],
       ),
       _attendantsByLot = {
         for (final entry
             in (attendantsByLot ??
                     const <int, List<OperatorManagedAttendant>>{})
                 .entries)
           entry.key: List<OperatorManagedAttendant>.from(entry.value),
       };

  final List<OperatorManagedParkingLot> _parkingLots;
  final Map<int, List<OperatorManagedAttendant>> _attendantsByLot;
  int _nextAttendantId = 200;

  @override
  Future<List<OperatorManagedParkingLot>> getManagedParkingLots() async {
    return List<OperatorManagedParkingLot>.from(_parkingLots);
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
      status: current.status,
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

    expect(find.text('Quét mã check-in'), findsOneWidget);
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
    expect(find.text('Điều phối hệ thống'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
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
    expect(find.text('Điều hành bãi xe'), findsOneWidget);
    expect(find.text('Bai xe Le Thanh Ton'), findsOneWidget);
  });

  testWidgets(
    'ParkingApp routes operator-capable public session to operator workspace',
    (WidgetTester tester) async {
      final lotManagementService = FakeOperatorLotManagementService(
        initialLots: const [
          OperatorManagedParkingLot(
            id: 18,
            leaseId: 6,
            lotOwnerId: 4,
            name: 'Bai xe Mac Thi Buoi',
            address: '6 Mac Thi Buoi, Quan 1',
            latitude: 10.775,
            longitude: 106.704,
            currentAvailable: 5,
            status: 'APPROVED',
            occupiedCount: 1,
            totalCapacity: 6,
            openingTime: '05:30',
            closingTime: '21:30',
            pricingMode: 'SESSION',
            priceAmount: 25000,
          ),
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
      expect(find.text('Bai xe Mac Thi Buoi'), findsOneWidget);
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
    expect(find.text('Bãi xe của tôi'), findsOneWidget);
    expect(find.text('Bai xe Nguyen Hue'), findsOneWidget);
  });

  testWidgets(
    'Public multi-capability session shows workspace switcher bridge',
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
            id: 18,
            leaseId: 6,
            lotOwnerId: 4,
            name: 'Bai xe Mac Thi Buoi',
            address: '6 Mac Thi Buoi, Quan 1',
            latitude: 10.775,
            longitude: 106.704,
            currentAvailable: 5,
            status: 'APPROVED',
            occupiedCount: 1,
            totalCapacity: 6,
            openingTime: '05:30',
            closingTime: '21:30',
            pricingMode: 'SESSION',
            priceAmount: 25000,
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
                'operator': true,
                'attendant': false,
                'admin': false,
                'public_account': true,
              },
            ),
            authService: FakeAuthService(),
            onSignOut: () async {},
            onSessionUpdated: (_) {},
            parkingLotServiceFactory: (_) => parkingLotService,
            operatorLotManagementServiceFactory: (_) => lotManagementService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chọn không gian làm việc'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Chủ bãi'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Operator'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Operator'));
      await tester.pumpAndSettle();
      expect(find.byType(OperatorLotManagementScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Chủ bãi'));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingLotRegistrationScreen), findsOneWidget);
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
            mapLocationPermissionService:
                const FakeMapLocationPermissionService(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('chế độ fallback'), findsOneWidget);
      expect(find.byTooltip('Xe của tôi'), findsOneWidget);
      expect(find.byTooltip('Chủ bãi'), findsOneWidget);
      expect(find.byTooltip('Operator'), findsOneWidget);
      expect(find.byTooltip('Đăng xuất'), findsOneWidget);

      await tester.tap(find.byTooltip('Xe của tôi'));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleScreen), findsOneWidget);
      expect(find.text('59A-12345'), findsOneWidget);
    },
  );

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

    expect(find.byTooltip('Đăng xuất'), findsOneWidget);
    await tester.tap(find.byTooltip('Đăng xuất'));
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

    await tester.tap(find.byTooltip('Chủ bãi').first);
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

    await tester.tap(find.byTooltip('Operator').first);
    await tester.pumpAndSettle();

    expect(find.byType(OperatorApplicationScreen), findsOneWidget);
    expect(find.text('Nộp hồ sơ Operator'), findsWidgets);
  });

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

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingLotRegistrationScreen(
          parkingLotService: parkingLotService,
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

  testWidgets('Lot owner workspace can bootstrap an operator lease', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingLotRegistrationScreen(
          parkingLotService: parkingLotService,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Gán operator thử nghiệm'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tran Thi B'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kích hoạt điều hành'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Operator đang phụ trách'), findsOneWidget);
    expect(find.text('Tran Thi B'), findsWidgets);
    expect(find.text('Lease'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
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
}
