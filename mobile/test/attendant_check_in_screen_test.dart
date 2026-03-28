import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';

class FakeAttendantCheckInService implements AttendantCheckInService {
  FakeAttendantCheckInService({this.result, this.errorMessage});

  final AttendantCheckInResult? result;
  final String? errorMessage;
  String? lastScannedToken;

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
    double? quotedFinalFee,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendantCheckOutUndoResult> undoCheckOut({required int sessionId}) async {
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
