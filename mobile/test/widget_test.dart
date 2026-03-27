import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';
import 'package:parking_app/src/features/auth/data/auth_service.dart';
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
            onSignOut: () async {},
            vehicleServiceFactory: (_) => vehicleService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('quản lý xe của mình'), findsOneWidget);
      expect(find.byTooltip('Xe của tôi'), findsOneWidget);
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
}
