import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/driver_booking/data/driver_booking_service.dart';
import 'package:parking_app/src/features/lot_details/data/lot_details_service.dart';
import 'package:parking_app/src/features/lot_details/presentation/lot_details_sheet.dart';
import 'package:parking_app/src/features/vehicles/data/vehicle_service.dart';

class FakeLotDetailsService implements LotDetailsService {
  FakeLotDetailsService(this.detail);

  final DriverLotDetail detail;

  @override
  Future<DriverLotDetail> fetchLotDetail({required int lotId}) async => detail;
}

class FakeVehicleService implements VehicleService {
  FakeVehicleService(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  Future<Vehicle> createVehicle({
    required String licensePlate,
    required String vehicleType,
  }) async {
    return Vehicle(
      id: vehicles.length + 1,
      licensePlate: licensePlate,
      vehicleType: vehicleType,
    );
  }

  @override
  Future<void> deleteVehicle(int vehicleId) async {}

  @override
  Future<List<Vehicle>> listVehicles() async => List<Vehicle>.from(vehicles);
}

class FakeDriverBookingService implements DriverBookingService {
  FakeDriverBookingService({
    this.activeBooking,
    this.createError,
    this.cancelError,
  });

  DriverBooking? activeBooking;
  String? createError;
  String? cancelError;
  int? lastCreateLotId;
  int? lastCreateVehicleId;
  int? lastCancelledBookingId;

  @override
  Future<DriverBookingCancellation> cancelBooking({
    required int bookingId,
  }) async {
    lastCancelledBookingId = bookingId;
    if (cancelError != null) {
      throw DriverBookingException(cancelError!);
    }
    activeBooking = null;
    return const DriverBookingCancellation(
      bookingId: 51,
      status: 'CANCELLED',
      currentAvailable: 4,
    );
  }

  @override
  Future<DriverBooking> createBooking({
    required int parkingLotId,
    required int vehicleId,
  }) async {
    lastCreateLotId = parkingLotId;
    lastCreateVehicleId = vehicleId;
    if (createError != null) {
      throw DriverBookingException(createError!);
    }
    activeBooking = DriverBooking(
      bookingId: 51,
      parkingLotId: parkingLotId,
      parkingLotName: 'Bãi xe Lê Lợi',
      status: 'CONFIRMED',
      bookingTime: DateTime(2026, 3, 28, 9, 0),
      expectedArrival: DateTime(2026, 3, 28, 9, 30),
      expirationTime: DateTime(2026, 3, 28, 9, 30),
      expiresInSeconds: 1800,
      currentAvailable: 4,
      token: 'booking-token-51',
      vehicle: Vehicle(
        id: vehicleId,
        licensePlate: '59A-12345',
        vehicleType: 'MOTORBIKE',
      ),
      payment: const DriverBookingPayment(
        paymentId: 88,
        amount: 8000,
        finalAmount: 8000,
        paymentMethod: 'ONLINE',
        paymentStatus: 'COMPLETED',
      ),
    );
    return activeBooking!;
  }

  @override
  Future<DriverBooking?> getActiveBooking({required int parkingLotId}) async {
    return activeBooking;
  }
}

DriverLotDetail _detail({int currentAvailable = 5}) {
  return DriverLotDetail(
    id: 1,
    name: 'Bãi xe Lê Lợi',
    address: '45 Lê Lợi, Quận 1',
    latitude: 10.7729,
    longitude: 106.6983,
    currentAvailable: currentAvailable,
    status: 'APPROVED',
    totalCapacity: 20,
    openingTime: '07:00',
    closingTime: '22:00',
    pricingMode: 'SESSION',
    priceAmount: 8000,
    peakHours: const LotHistoricalTrend(
      status: 'INSUFFICIENT_DATA',
      lookbackDays: 30,
      totalSessions: 1,
      points: [],
    ),
  );
}

void main() {
  Widget buildSubject({
    required DriverBookingService bookingService,
    required VehicleService vehicleService,
    Future<void> Function()? onManageVehicles,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LotDetailsSheet(
          lotId: 1,
          lotName: 'Bãi xe Lê Lợi',
          lotDetailsService: FakeLotDetailsService(_detail()),
          driverBookingService: bookingService,
          vehicleService: vehicleService,
          onManageVehicles: onManageVehicles ?? () async {},
        ),
      ),
    );
  }

  testWidgets(
    'shows booking CTA when driver has vehicles and no active booking',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          bookingService: FakeDriverBookingService(),
          vehicleService: FakeVehicleService(const [
            Vehicle(id: 7, licensePlate: '59A-12345', vehicleType: 'MOTORBIKE'),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đặt chỗ trước'), findsOneWidget);
      expect(find.byKey(const ValueKey('bookLot:1')), findsOneWidget);
      expect(find.text('Đặt chỗ 30 phút'), findsOneWidget);
    },
  );

  testWidgets('renders backend booking confirmation after successful create', (
    tester,
  ) async {
    final bookingService = FakeDriverBookingService();

    await tester.pumpWidget(
      buildSubject(
        bookingService: bookingService,
        vehicleService: FakeVehicleService(const [
          Vehicle(id: 7, licensePlate: '59A-12345', vehicleType: 'MOTORBIKE'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bookLot:1')));
    await tester.pumpAndSettle();

    expect(bookingService.lastCreateLotId, 1);
    expect(bookingService.lastCreateVehicleId, 7);
    expect(find.text('Booking đang hoạt động'), findsOneWidget);
    expect(find.text('59A-12345'), findsWidgets);
    expect(find.textContaining('Phí giữ chỗ'), findsOneWidget);
  });

  testWidgets('allows driver to cancel an active booking from the lot sheet', (
    tester,
  ) async {
    final bookingService = FakeDriverBookingService(
      activeBooking: DriverBooking(
        bookingId: 51,
        parkingLotId: 1,
        parkingLotName: 'Bãi xe Lê Lợi',
        status: 'CONFIRMED',
        bookingTime: DateTime(2026, 3, 28, 9, 0),
        expectedArrival: DateTime(2026, 3, 28, 9, 30),
        expirationTime: DateTime(2026, 3, 28, 9, 30),
        expiresInSeconds: 1800,
        currentAvailable: 4,
        token: 'booking-token-51',
        vehicle: const Vehicle(
          id: 7,
          licensePlate: '59A-12345',
          vehicleType: 'MOTORBIKE',
        ),
        payment: const DriverBookingPayment(
          paymentId: 88,
          amount: 8000,
          finalAmount: 8000,
          paymentMethod: 'ONLINE',
          paymentStatus: 'COMPLETED',
        ),
      ),
    );

    await tester.pumpWidget(
      buildSubject(
        bookingService: bookingService,
        vehicleService: FakeVehicleService(const [
          Vehicle(id: 7, licensePlate: '59A-12345', vehicleType: 'MOTORBIKE'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('cancelBooking:51')));
    await tester.tap(find.byKey(const ValueKey('cancelBooking:51')));
    await tester.pumpAndSettle();

    expect(bookingService.lastCancelledBookingId, 51);
    expect(find.byKey(const ValueKey('bookLot:1')), findsOneWidget);
  });

  testWidgets('shows driver-facing booking error when create fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        bookingService: FakeDriverBookingService(
          createError: 'Lot is full - no available spots.',
        ),
        vehicleService: FakeVehicleService(const [
          Vehicle(id: 7, licensePlate: '59A-12345', vehicleType: 'MOTORBIKE'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bookLot:1')));
    await tester.pumpAndSettle();

    expect(find.text('Lot is full - no available spots.'), findsOneWidget);
  });
}
