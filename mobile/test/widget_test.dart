import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';
import 'package:parking_app/src/features/auth/data/auth_service.dart';
import 'package:parking_app/src/features/lot_owner_application/data/lot_owner_application_service.dart';
import 'package:parking_app/src/features/lot_owner_application/presentation/lot_owner_application_screen.dart';
import 'package:parking_app/src/features/operator_application/data/operator_application_service.dart';
import 'package:parking_app/src/features/operator_application/presentation/operator_application_screen.dart';
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
}
