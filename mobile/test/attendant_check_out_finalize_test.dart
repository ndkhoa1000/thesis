import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeAttendantCheckOutFinalizeService implements AttendantCheckInService {
  FakeAttendantCheckOutFinalizeService({
    this.previewResult,
    this.finalizeResult,
    this.undoResult,
  });

  final AttendantCheckOutPreviewResult? previewResult;
  final AttendantCheckOutFinalizeResult? finalizeResult;
  final AttendantCheckOutUndoResult? undoResult;
  final List<String> paymentMethods = <String>[];
  final List<int> undoSessionIds = <int>[];

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    return const AttendantOccupancySummary(
      parkingLotId: 13,
      parkingLotName: 'Bai xe Quan 1',
      hasActiveCapacityConfig: true,
      totalCapacity: 12,
      freeCount: 4,
      occupiedCount: 8,
      vehicleTypeBreakdown: [
        AttendantOccupancyVehicleBreakdown(
          vehicleType: 'MOTORBIKE',
          occupiedCount: 6,
        ),
        AttendantOccupancyVehicleBreakdown(
          vehicleType: 'CAR',
          occupiedCount: 2,
        ),
      ],
    );
  }

  @override
  Future<AttendantCheckInResult> checkInDriver({required String token}) async {
    throw UnimplementedError();
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
    return previewResult ??
        AttendantCheckOutPreviewResult(
          sessionId: 404,
          parkingLotId: 13,
          parkingLotName: 'Bai xe Quan 1',
          licensePlate: '30A-99999',
          vehicleType: 'CAR',
          checkedInAt: DateTime(2026, 3, 28, 8, 15),
          elapsedMinutes: 125,
          finalFee: 45000,
          pricingMode: 'HOURLY',
        );
  }

  @override
  Future<AttendantCheckOutFinalizeResult> finalizeCheckOut({
    required int sessionId,
    required String paymentMethod,
    required double quotedFinalFee,
  }) async {
    paymentMethods.add(paymentMethod);
    return finalizeResult ??
        AttendantCheckOutFinalizeResult(
          sessionId: sessionId,
          parkingLotId: 13,
          parkingLotName: 'Bai xe Quan 1',
          licensePlate: '30A-99999',
          vehicleType: 'CAR',
          finalFee: quotedFinalFee,
          paymentMethod: paymentMethod,
          checkedOutAt: DateTime(2026, 3, 28, 10, 20),
          currentAvailable: 8,
        );
  }

  @override
  Future<AttendantCheckOutUndoResult> undoCheckOut({
    required int sessionId,
  }) async {
    undoSessionIds.add(sessionId);
    return undoResult ??
        AttendantCheckOutUndoResult(
          sessionId: sessionId,
          parkingLotId: 13,
          currentAvailable: 7,
          status: 'CHECKED_IN',
        );
  }
}

Widget _fakeScanner(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return FilledButton(
    key: const ValueKey('fake-attendant-checkout-scan-button'),
    onPressed: isBusy ? null : () => onDetect('driver-check-out-token'),
    child: const Text('Gia lap quet QR checkout'),
  );
}

void main() {
  Widget buildSubject({required AttendantCheckInService service}) {
    return MaterialApp(
      home: AttendantCheckInScreen(
        attendantCheckInService: service,
        scannerBuilder: _fakeScanner,
      ),
    );
  }

  testWidgets('swipe settlement finalizes as cash and returns to standby', (
    tester,
  ) async {
    final service = FakeAttendantCheckOutFinalizeService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('attendant-check-out-mode')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fake-attendant-checkout-scan-button')),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('attendant-check-out-settlement-zone')),
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();

    expect(service.paymentMethods, <String>['CASH']);
    expect(find.text('San sang quet xe ra bai'), findsOneWidget);
    expect(find.text('Hoan tat xe ra'), findsOneWidget);
    expect(find.text('Hoan tac'), findsOneWidget);
  });

  testWidgets('undo affordance restores the checkout preview', (tester) async {
    final service = FakeAttendantCheckOutFinalizeService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('attendant-check-out-mode')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fake-attendant-checkout-scan-button')),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('attendant-check-out-settlement-zone')),
      const Offset(420, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Hoan tac'));
    await tester.pumpAndSettle();

    expect(service.paymentMethods, <String>['ONLINE']);
    expect(service.undoSessionIds, <int>[404]);
    expect(
      find.byKey(const ValueKey('attendant-check-out-settlement-zone')),
      findsOneWidget,
    );
    expect(find.text('45.000 VND'), findsOneWidget);
  });
}
