import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';
import 'package:parking_app/src/features/admin_approvals/data/admin_approvals_service.dart';
import 'package:parking_app/src/features/admin_approvals/presentation/admin_approvals_screen.dart';
import 'package:parking_app/src/features/auth/data/auth_service.dart';
import 'package:parking_app/src/features/lot_owner_application/data/lot_owner_application_service.dart';
import 'package:parking_app/src/features/lot_owner_application/presentation/lot_owner_application_screen.dart';
import 'package:parking_app/src/features/operator_application/data/operator_application_service.dart';
import 'package:parking_app/src/features/operator_application/presentation/operator_application_screen.dart';
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

  @override
  Future<AdminApprovalsDashboard> loadDashboard() async {
    return AdminApprovalsDashboard(
      lotOwnerApplications: List<AdminApprovalItem>.from(_lotOwnerApplications),
      operatorApplications: List<AdminApprovalItem>.from(_operatorApplications),
      parkingLotApplications: List<AdminApprovalItem>.from(
        _parkingLotApplications,
      ),
      managedUsers: List<AdminManagedUser>.from(_managedUsers),
      managedParkingLots: List<AdminManagedParkingLot>.from(
        _managedParkingLots,
      ),
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: '');
  });

  testWidgets('ParkingApp shows login screen without session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: FakeAuthService()));
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

    await tester.pumpWidget(MyApp(authService: authService));
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendant Workspace'), findsOneWidget);
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('quản lý xe của mình'), findsOneWidget);
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

    await tester.pumpWidget(MyApp(authService: authService));
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
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vĩ độ'),
      '10.772900',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kinh độ'),
      '106.698300',
    );
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
}
