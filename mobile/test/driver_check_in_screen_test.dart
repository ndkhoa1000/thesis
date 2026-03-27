import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/driver_check_in/data/driver_check_in_service.dart';
import 'package:parking_app/src/features/driver_check_in/presentation/driver_check_in_screen.dart';
import 'package:parking_app/src/features/vehicles/data/vehicle_service.dart';

class FakeVehicleService implements VehicleService {
  FakeVehicleService({List<Vehicle>? vehicles})
    : _vehicles = List<Vehicle>.from(vehicles ?? const []);

  final List<Vehicle> _vehicles;

  @override
  Future<Vehicle> createVehicle({
    required String licensePlate,
    required String vehicleType,
  }) async {
    final vehicle = Vehicle(
      id: _vehicles.length + 1,
      licensePlate: licensePlate,
      vehicleType: vehicleType,
    );
    _vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(int vehicleId) async {
    _vehicles.removeWhere((vehicle) => vehicle.id == vehicleId);
  }

  @override
  Future<List<Vehicle>> listVehicles() async => List<Vehicle>.from(_vehicles);
}

class FakeDriverCheckInService implements DriverCheckInService {
  FakeDriverCheckInService({
    this.errorMessage,
    this.response,
    this.activeSession,
    this.activeSessionErrorMessage,
    this.checkOutResponse,
    this.checkOutErrorMessage,
  });

  final String? errorMessage;
  final DriverCheckInQr? response;
  final DriverActiveSession? activeSession;
  final String? activeSessionErrorMessage;
  final DriverCheckOutQr? checkOutResponse;
  final String? checkOutErrorMessage;
  int? lastVehicleId;
  int get activeSessionCallCount => _activeSessionCallCount;
  int _activeSessionCallCount = 0;
  bool checkOutQrRequested = false;

  @override
  Future<DriverActiveSession?> getActiveSession() async {
    _activeSessionCallCount += 1;
    if (activeSessionErrorMessage != null) {
      throw DriverCheckInException(activeSessionErrorMessage!);
    }
    return activeSession;
  }

  @override
  Future<DriverCheckInQr> createCheckInQr({required int vehicleId}) async {
    lastVehicleId = vehicleId;
    if (errorMessage != null) {
      throw DriverCheckInException(errorMessage!);
    }
    return response ??
        DriverCheckInQr(
          token: 'signed-token-$vehicleId',
          expiresAt: DateTime(2026, 3, 27, 10, 30),
          expiresInSeconds: 300,
          vehicle: Vehicle(
            id: vehicleId,
            licensePlate: '59A-12345',
            vehicleType: 'MOTORBIKE',
          ),
        );
  }

  @override
  Future<DriverCheckOutQr> createCheckOutQr() async {
    checkOutQrRequested = true;
    if (checkOutErrorMessage != null) {
      throw DriverCheckInException(checkOutErrorMessage!);
    }
    return checkOutResponse ??
        DriverCheckOutQr(
          token: 'checkout-token',
          expiresAt: DateTime(2026, 3, 27, 11, 15),
          expiresInSeconds: 300,
          sessionId: 88,
          licensePlate: '30A-99999',
        );
  }
}

void main() {
  Widget buildSubject({
    required VehicleService vehicleService,
    required DriverCheckInService driverCheckInService,
    required Future<void> Function() onManageVehicles,
  }) {
    return MaterialApp(
      home: DriverCheckInScreen(
        vehicleService: vehicleService,
        driverCheckInService: driverCheckInService,
        onManageVehicles: onManageVehicles,
      ),
    );
  }

  testWidgets('guides driver to vehicle management when no vehicles exist', (
    tester,
  ) async {
    var manageVehiclesCalled = false;

    await tester.pumpWidget(
      buildSubject(
        vehicleService: FakeVehicleService(),
        driverCheckInService: FakeDriverCheckInService(),
        onManageVehicles: () async {
          manageVehiclesCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn cần đăng ký ít nhất một xe trước khi tạo mã check-in.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Quản lý xe của tôi'));
    await tester.pumpAndSettle();

    expect(manageVehiclesCalled, isTrue);
  });

  testWidgets('shows backend block when an active session already exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        vehicleService: FakeVehicleService(
          vehicles: const [
            Vehicle(id: 1, licensePlate: '59A-12345', vehicleType: 'MOTORBIKE'),
          ],
        ),
        driverCheckInService: FakeDriverCheckInService(
          errorMessage: 'Current parking session is already in progress',
        ),
        onManageVehicles: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Current parking session is already in progress'),
      findsOneWidget,
    );
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('renders QR after successful token issuance', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        vehicleService: FakeVehicleService(
          vehicles: const [
            Vehicle(id: 2, licensePlate: '30A-99999', vehicleType: 'CAR'),
          ],
        ),
        driverCheckInService: FakeDriverCheckInService(
          response: DriverCheckInQr(
            token: 'signed-token-2',
            expiresAt: DateTime(2026, 3, 27, 8, 45),
            expiresInSeconds: 300,
            vehicle: const Vehicle(
              id: 2,
              licensePlate: '30A-99999',
              vehicleType: 'CAR',
            ),
          ),
        ),
        onManageVehicles: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('30A-99999'), findsAtLeastNWidgets(1));
    expect(find.text('Ô tô'), findsOneWidget);
    expect(find.textContaining('Mã có hiệu lực đến'), findsOneWidget);
  });

  testWidgets('renders active session summary and checkout QR action', (
    tester,
  ) async {
    final driverService = FakeDriverCheckInService(
      activeSession: DriverActiveSession(
        sessionId: 88,
        parkingLotId: 13,
        parkingLotName: 'Bãi xe Lê Lợi',
        licensePlate: '30A-99999',
        vehicleType: 'CAR',
        checkedInAt: DateTime(2026, 3, 27, 8, 0),
        elapsedMinutes: 95,
        estimatedCost: 30000,
        pricingMode: 'HOURLY',
      ),
    );

    await tester.pumpWidget(
      buildSubject(
        vehicleService: FakeVehicleService(
          vehicles: const [
            Vehicle(id: 2, licensePlate: '30A-99999', vehicleType: 'CAR'),
          ],
        ),
        driverCheckInService: driverService,
        onManageVehicles: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phiên gửi xe đang hoạt động'), findsOneWidget);
    expect(find.text('Bãi xe Lê Lợi'), findsOneWidget);
    expect(find.text('30A-99999'), findsWidgets);
    expect(find.textContaining('95 phút'), findsOneWidget);
    expect(find.textContaining('30.000'), findsOneWidget);

    await tester.tap(find.text('Hiện mã check-out'));
    await tester.pumpAndSettle();

    expect(driverService.checkOutQrRequested, isTrue);
    expect(find.textContaining('Mã có hiệu lực đến'), findsOneWidget);
  });

  testWidgets('falls back to check-in flow when no active session exists', (
    tester,
  ) async {
    final driverService = FakeDriverCheckInService(
      response: DriverCheckInQr(
        token: 'signed-token-2',
        expiresAt: DateTime(2026, 3, 27, 8, 45),
        expiresInSeconds: 300,
        vehicle: const Vehicle(
          id: 2,
          licensePlate: '30A-99999',
          vehicleType: 'CAR',
        ),
      ),
    );

    await tester.pumpWidget(
      buildSubject(
        vehicleService: FakeVehicleService(
          vehicles: const [
            Vehicle(id: 2, licensePlate: '30A-99999', vehicleType: 'CAR'),
          ],
        ),
        driverCheckInService: driverService,
        onManageVehicles: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(driverService.activeSessionCallCount, 1);
    expect(find.text('Tạo lại mã QR'), findsOneWidget);
    expect(
      find.textContaining('Đưa mã này cho attendant quét'),
      findsOneWidget,
    );
  });
}
