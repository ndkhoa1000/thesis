import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeAttendantCheckInService implements AttendantCheckInService {
  FakeAttendantCheckInService({
    this.result,
    this.errorMessage,
    this.occupancySummary,
    this.occupancyErrorMessage,
  });

  final AttendantCheckInResult? result;
  final String? errorMessage;
  final AttendantOccupancySummary? occupancySummary;
  final String? occupancyErrorMessage;
  String? lastScannedToken;

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    if (occupancyErrorMessage != null) {
      throw AttendantCheckInException(occupancyErrorMessage!);
    }
    return occupancySummary ??
        const AttendantOccupancySummary(
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
  Future<List<AttendantActiveSession>> getActiveSessions() async {
    return const [];
  }

  @override
  Future<AttendantShiftHandoverStartResult> prepareShiftHandover() async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckInResult> checkInDriver({required String token}) async {
    lastScannedToken = token;
    if (errorMessage != null) {
      throw AttendantCheckInException(errorMessage!);
    }
    return result ??
        AttendantCheckInResult(
          sessionId: 101,
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

Widget _fakeScanner(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return FilledButton(
    key: const ValueKey('fake-attendant-scan-button'),
    onPressed: isBusy ? null : () => onDetect('driver-check-in-token'),
    child: const Text('Giả lập quét QR'),
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

  testWidgets('shows scanner-first attendant workspace', (tester) async {
    await tester.pumpWidget(
      buildSubject(service: FakeAttendantCheckInService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quét mã check-in'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fake-attendant-scan-button')),
      findsOneWidget,
    );
    expect(find.text('Sẵn sàng quét xe vào bãi'), findsOneWidget);
    expect(find.text('Bai xe Quan 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('occupancy-fact-Da gui')), findsOneWidget);
    expect(find.text('8/12'), findsOneWidget);
    expect(find.text('Xe máy: 6'), findsOneWidget);
    expect(find.text('Ô tô: 2'), findsOneWidget);
  });

  testWidgets('renders missing-capacity occupancy state explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        service: FakeAttendantCheckInService(
          occupancySummary: const AttendantOccupancySummary(
            parkingLotId: 13,
            parkingLotName: 'Bai xe Chua Cau hinh',
            hasActiveCapacityConfig: false,
            totalCapacity: null,
            freeCount: null,
            occupiedCount: null,
            vehicleTypeBreakdown: [
              AttendantOccupancyVehicleBreakdown(
                vehicleType: 'MOTORBIKE',
                occupiedCount: 2,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bai xe Chua Cau hinh'), findsOneWidget);
    expect(find.text('Chua cau hinh suc chua dang hoat dong'), findsOneWidget);
    expect(find.text('Xe máy: 2'), findsOneWidget);
  });

  testWidgets('renders occupancy load errors without breaking scanner flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        service: FakeAttendantCheckInService(
          occupancyErrorMessage: 'Khong the tai thong ke bai xe.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Khong the tai thong ke bai xe.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fake-attendant-scan-button')),
      findsOneWidget,
    );
  });

  testWidgets('renders success feedback after scan', (tester) async {
    final service = FakeAttendantCheckInService(
      result: AttendantCheckInResult(
        sessionId: 888,
        parkingLotId: 13,
        currentAvailable: 7,
        licensePlate: '30A-99999',
        vehicleType: 'CAR',
        checkedInAt: DateTime(2026, 3, 27, 9, 45),
      ),
    );

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fake-attendant-scan-button')));
    await tester.pumpAndSettle();

    expect(service.lastScannedToken, 'driver-check-in-token');
    expect(find.text('Check-in thành công'), findsOneWidget);
    expect(find.textContaining('30A-99999'), findsOneWidget);
    expect(find.textContaining('Còn 7 chỗ'), findsOneWidget);
  });

  testWidgets('renders failed-scan feedback', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        service: FakeAttendantCheckInService(
          errorMessage: 'Invalid QR code. Please try again.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fake-attendant-scan-button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid QR code. Please try again.'), findsOneWidget);
  });
}
