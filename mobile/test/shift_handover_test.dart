import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeShiftHandoverService implements AttendantCheckInService {
  int prepareCallCount = 0;
  int finalizeCallCount = 0;
  String? lastFinalizeReason;

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    return const AttendantOccupancySummary(
      parkingLotId: 13,
      parkingLotName: 'Bai xe Nguyen Du',
      hasActiveCapacityConfig: true,
      totalCapacity: 12,
      freeCount: 5,
      occupiedCount: 7,
      vehicleTypeBreakdown: [
        AttendantOccupancyVehicleBreakdown(
          vehicleType: 'CAR',
          occupiedCount: 3,
        ),
      ],
    );
  }

  @override
  Future<List<AttendantActiveSession>> getActiveSessions() async {
    return const [];
  }

  @override
  Future<AttendantShiftHandoverStartResult> prepareShiftHandover() async {
    prepareCallCount += 1;
    return AttendantShiftHandoverStartResult(
      shiftId: 17,
      parkingLotId: 13,
      expectedCash: 85000,
      token: 'shift-token-17',
      expiresAt: DateTime(2026, 3, 28, 21, 30),
      expiresInSeconds: 300,
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
    finalizeCallCount += 1;
    lastFinalizeReason = discrepancyReason;
    if (actualCash != 85000 &&
        (discrepancyReason == null || discrepancyReason.isEmpty)) {
      throw const AttendantCheckInException(
        'Discrepancy reason is required before completing handover.',
      );
    }
    return AttendantShiftHandoverFinalizeResult(
      handoverId: 41,
      outgoingShiftId: 17,
      incomingShiftId: 18,
      expectedCash: 85000,
      actualCash: actualCash,
      discrepancyFlagged: actualCash != 85000,
      completedAt: DateTime(2026, 3, 28, 21, 10),
    );
  }

  @override
  Future<AttendantFinalShiftCloseOutResult> requestFinalShiftCloseOut() async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckOutUndoResult> undoCheckOut({
    required int sessionId,
  }) async {
    throw UnimplementedError();
  }
}

Widget _fakeScanner(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return Center(
    child: FilledButton(
      key: const ValueKey('fake-shift-scan-button'),
      onPressed: isBusy ? null : () => onDetect('shift-token-17'),
      child: const Text('Gia lap quet Shift QR'),
    ),
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

  testWidgets('attendant can generate QR and complete matching handover', (
    tester,
  ) async {
    final service = FakeShiftHandoverService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shift-handover-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('generate-shift-handover-qr-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shift-handover-qr')), findsOneWidget);
    expect(find.textContaining('85.000 VND'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('fake-shift-scan-button')).last,
    );
    await tester.tap(find.byKey(const ValueKey('fake-shift-scan-button')).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('shift-handover-actual-cash-field')),
      '85000',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('finalize-shift-handover-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('finalize-shift-handover-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.prepareCallCount, 1);
    expect(service.finalizeCallCount, 1);
    expect(find.text('Bàn giao ca thành công'), findsOneWidget);
  });

  testWidgets('cash mismatch triggers hard-blocking discrepancy flow', (
    tester,
  ) async {
    final service = FakeShiftHandoverService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shift-handover-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('fake-shift-scan-button')).last,
    );
    await tester.tap(find.byKey(const ValueKey('fake-shift-scan-button')).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('shift-handover-actual-cash-field')),
      '80000',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('finalize-shift-handover-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('finalize-shift-handover-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bao cao chenh lech giao ca'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('submit-shift-discrepancy-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ly do chenh lech la bat buoc'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('shift-discrepancy-reason-field')),
      'Lech quy sau khi doi tien mat dau ca.',
    );
    await tester.tap(
      find.byKey(const ValueKey('submit-shift-discrepancy-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.finalizeCallCount, 2);
    expect(service.lastFinalizeReason, 'Lech quy sau khi doi tien mat dau ca.');
    expect(find.text('Đã khóa ca và báo cáo chênh lệch'), findsOneWidget);
  });
}
