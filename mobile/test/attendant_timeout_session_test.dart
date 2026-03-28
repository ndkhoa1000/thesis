import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeAttendantTimeoutService implements AttendantCheckInService {
  FakeAttendantTimeoutService({List<AttendantActiveSession>? activeSessions})
    : _activeSessions = List<AttendantActiveSession>.from(
        activeSessions ??
            [
              AttendantActiveSession(
                sessionId: 701,
                parkingLotId: 13,
                licensePlate: '30A-99999',
                vehicleType: 'CAR',
                checkedInAt: DateTime(2026, 3, 28, 8, 15),
                elapsedMinutes: 125,
              ),
            ],
      );

  final List<AttendantActiveSession> _activeSessions;
  int occupancyCallCount = 0;
  int? lastTimedOutSessionId;
  String? lastTimeoutReason;

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    occupancyCallCount += 1;
    return AttendantOccupancySummary(
      parkingLotId: 13,
      parkingLotName: 'Bai xe Quan 1',
      hasActiveCapacityConfig: true,
      totalCapacity: 12,
      freeCount: 4 + (lastTimedOutSessionId == null ? 0 : 1),
      occupiedCount: 8 - (lastTimedOutSessionId == null ? 0 : 1),
      vehicleTypeBreakdown: const [
        AttendantOccupancyVehicleBreakdown(
          vehicleType: 'CAR',
          occupiedCount: 2,
        ),
      ],
    );
  }

  @override
  Future<List<AttendantActiveSession>> getActiveSessions() async {
    return List<AttendantActiveSession>.from(_activeSessions);
  }

  @override
  Future<AttendantShiftHandoverStartResult> prepareShiftHandover() async {
    throw UnimplementedError();
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
    lastTimedOutSessionId = sessionId;
    lastTimeoutReason = reason;
    _activeSessions.removeWhere((session) => session.sessionId == sessionId);
    return AttendantForceCloseTimeoutResult(
      sessionId: sessionId,
      parkingLotId: 13,
      licensePlate: '30A-99999',
      vehicleType: 'CAR',
      timeoutAt: DateTime(2026, 3, 28, 10, 30),
      currentAvailable: 5,
      status: 'TIMEOUT',
      reason: reason,
    );
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

Widget _fakeScanner(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return const SizedBox.expand();
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

  testWidgets('stale-session management requires a timeout reason', (
    tester,
  ) async {
    final service = FakeAttendantTimeoutService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('active-session-management-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('30A-99999'), findsOneWidget);
    expect(find.textContaining('Dang gui:'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Timeout phien'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Xac nhan timeout'));
    await tester.pumpAndSettle();

    expect(find.text('Ly do timeout la bat buoc'), findsOneWidget);
    expect(service.lastTimedOutSessionId, isNull);
  });

  testWidgets(
    'successful timeout refreshes occupancy and removes the session',
    (tester) async {
      final service = FakeAttendantTimeoutService();

      await tester.pumpWidget(buildSubject(service: service));
      await tester.pumpAndSettle();

      expect(service.occupancyCallCount, 1);

      await tester.tap(
        find.byKey(const ValueKey('active-session-management-button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Timeout phien'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ly do timeout bat buoc'),
        'Xe da roi bai nhung session van con treo.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Xac nhan timeout'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(service.lastTimedOutSessionId, 701);
      expect(
        service.lastTimeoutReason,
        'Xe da roi bai nhung session van con treo.',
      );
      expect(service.occupancyCallCount, 2);
      expect(
        find.text('Khong con phien dang gui nao can xu ly.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Da timeout phien 30A-99999.'),
        findsOneWidget,
      );
    },
  );
}
