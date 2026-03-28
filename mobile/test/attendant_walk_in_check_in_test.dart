import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeAttendantWalkInService implements AttendantCheckInService {
  FakeAttendantWalkInService({this.result, this.errorMessage});

  final AttendantCheckInResult? result;
  final String? errorMessage;
  String? lastVehicleType;
  String? lastPlateImagePath;
  String? lastOverviewImagePath;

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
      ],
    );
  }

  @override
  Future<AttendantCheckInResult> checkInDriver({required String token}) async {
    throw UnimplementedError();
  }

  Future<AttendantCheckInResult> checkInWalkIn({
    required String vehicleType,
    required String plateImagePath,
    String? overviewImagePath,
  }) async {
    lastVehicleType = vehicleType;
    lastPlateImagePath = plateImagePath;
    lastOverviewImagePath = overviewImagePath;

    if (errorMessage != null) {
      throw AttendantCheckInException(errorMessage!);
    }

    return result ??
        AttendantCheckInResult(
          sessionId: 301,
          parkingLotId: 13,
          currentAvailable: 3,
          licensePlate: 'WALK-IN-301',
          vehicleType: 'MOTORBIKE',
          checkedInAt: DateTime(2026, 3, 27, 11, 15),
        );
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

Widget _fakeScanner(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return const SizedBox.expand();
}

void main() {
  Future<String?> captureOverview() async => '/tmp/overview.jpg';
  Future<String?> capturePlate() async => '/tmp/plate.jpg';

  Widget buildSubject({
    required FakeAttendantWalkInService service,
    Future<String?> Function()? captureOverviewImage,
    Future<String?> Function()? capturePlateImage,
    bool startInWalkInMode = false,
  }) {
    return MaterialApp(
      home: AttendantCheckInScreen(
        attendantCheckInService: service,
        scannerBuilder: _fakeScanner,
        captureOverviewImage: captureOverviewImage ?? captureOverview,
        capturePlateImage: capturePlateImage ?? capturePlate,
        startInWalkInMode: startInWalkInMode,
      ),
    );
  }

  testWidgets('shows walk-in entry action from attendant workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(service: FakeAttendantWalkInService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xe vang lai'), findsOneWidget);
  });

  testWidgets('submits a successful walk-in check-in after capturing photos', (
    tester,
  ) async {
    final service = FakeAttendantWalkInService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('walk-in-entry-button')),
    );
    final walkInEntryButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('walk-in-entry-button')),
    );
    walkInEntryButton.onPressed!.call();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Chup anh toan canh'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Chup anh toan canh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Chup anh bien so'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Chup anh bien so'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Tao phien walk-in'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tao phien walk-in'));
    await tester.pumpAndSettle();

    expect(service.lastVehicleType, 'MOTORBIKE');
    expect(service.lastPlateImagePath, isNotNull);
    expect(find.text('Check-in thành công'), findsOneWidget);
    expect(find.textContaining('WALK-IN-301'), findsOneWidget);
  });

  testWidgets('shows validation when plate photo is missing', (tester) async {
    final service = FakeAttendantWalkInService();

    await tester.pumpWidget(
      buildSubject(service: service, startInWalkInMode: true),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tao phien walk-in'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Tao phien walk-in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Can chup anh bien so truoc khi tao phien walk-in.'),
      findsOneWidget,
    );
  });
}
