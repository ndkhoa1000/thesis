import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeAttendantCheckOutService implements AttendantCheckInService {
  FakeAttendantCheckOutService({this.previewResult, this.previewErrorMessage});

  final AttendantCheckOutPreviewResult? previewResult;
  final String? previewErrorMessage;
  String? lastPreviewToken;

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
    lastPreviewToken = token;
    if (previewErrorMessage != null) {
      throw AttendantCheckInException(previewErrorMessage!);
    }

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

  testWidgets('enters checkout scan mode from attendant workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(service: FakeAttendantCheckOutService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('attendant-check-out-mode')));
    await tester.pumpAndSettle();

    expect(find.text('Quet ma check-out'), findsOneWidget);
    expect(find.text('San sang quet xe ra bai'), findsOneWidget);
  });

  testWidgets('renders oversized checkout summary after scan', (tester) async {
    final service = FakeAttendantCheckOutService();

    await tester.pumpWidget(buildSubject(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('attendant-check-out-mode')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fake-attendant-checkout-scan-button')),
    );
    await tester.pumpAndSettle();

    expect(service.lastPreviewToken, 'driver-check-out-token');
    expect(find.text('30A-99999'), findsOneWidget);
    expect(find.text('45.000 VND'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attendant-check-out-amount')),
      findsOneWidget,
    );
    expect(find.textContaining('125 phut'), findsOneWidget);
  });

  testWidgets('shows backend pricing error in checkout mode', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        service: FakeAttendantCheckOutService(
          previewErrorMessage:
              'No active pricing found for this parking session.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('attendant-check-out-mode')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fake-attendant-checkout-scan-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No active pricing found for this parking session.'),
      findsOneWidget,
    );
  });
}
