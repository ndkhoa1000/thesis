import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'package:parking_app/src/features/lease_contract/data/lease_contract_models.dart';
import 'package:parking_app/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';
import 'package:parking_app/src/features/operator_lot_management/data/operator_lot_management_service.dart';
import 'package:parking_app/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart';

class FakeFinalShiftCloseOutAttendantService
    implements AttendantCheckInService {
  int requestCloseOutCalls = 0;

  @override
  Future<AttendantOccupancySummary> getOccupancySummary() async {
    return const AttendantOccupancySummary(
      parkingLotId: 13,
      parkingLotName: 'Bai xe Nguyen Du',
      hasActiveCapacityConfig: true,
      totalCapacity: 12,
      freeCount: 12,
      occupiedCount: 0,
      vehicleTypeBreakdown: [],
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
    throw UnimplementedError();
  }

  @override
  Future<AttendantFinalShiftCloseOutResult> requestFinalShiftCloseOut() async {
    requestCloseOutCalls += 1;
    return AttendantFinalShiftCloseOutResult(
      closeOutId: 31,
      shiftId: 17,
      parkingLotId: 13,
      expectedCash: 85000,
      currentAvailable: 12,
      activeSessionCount: 0,
      status: 'REQUESTED',
      requestedAt: DateTime(2026, 3, 28, 21, 0),
    );
  }

  @override
  Future<AttendantCheckOutUndoResult> undoCheckOut({
    required int sessionId,
  }) async {
    throw UnimplementedError();
  }
}

class FakeFinalShiftCloseOutOperatorService
    implements OperatorLotManagementService {
  int completeCalls = 0;

  @override
  Future<List<LeaseContractSummary>> getLeaseContracts() async {
    return const [];
  }

  @override
  Future<OperatorRevenueSummary> getRevenueSummary({
    required int parkingLotId,
    required OperatorRevenuePeriod period,
  }) async {
    return OperatorRevenueSummary(
      parkingLotId: parkingLotId,
      parkingLotName: 'Bai xe Nguyen Du',
      period: period,
      rangeStart: DateTime(2026, 3, 28),
      rangeEnd: DateTime(2026, 3, 28),
      leaseStatus: 'ACTIVE',
      ownerName: 'Nguyen Van A',
      completedPaymentCount: 0,
      completedSessionCount: 0,
      hasData: false,
      vehicleTypeBreakdown: const [],
      emptyReason: 'NO_COMPLETED_PAYMENTS',
      emptyMessage:
          'Không có phiên hoàn tất đã thanh toán trong khoảng thời gian đã chọn.',
    );
  }

  @override
  Future<LeaseContractSummary> acceptLeaseContract({
    required int leaseId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<OperatorManagedParkingLot>> getManagedParkingLots() async {
    return const [
      OperatorManagedParkingLot(
        id: 13,
        leaseId: 4,
        lotOwnerId: 2,
        name: 'Bai xe Nguyen Du',
        address: '1 Nguyen Du',
        latitude: 10.0,
        longitude: 106.0,
        currentAvailable: 12,
        status: 'APPROVED',
        occupiedCount: 0,
        totalCapacity: 12,
        openingTime: '06:00',
        closingTime: '22:00',
        pricingMode: 'SESSION',
        priceAmount: 3000,
      ),
    ];
  }

  @override
  Future<List<OperatorShiftAlert>> getShiftHandoverAlerts() async {
    return [
      OperatorShiftAlert(
        id: 501,
        title: 'Dong ca cuoi ngay tai Bai xe Nguyen Du',
        message: 'Attendant da gui dong ca cuoi ngay.',
        notificationType: 'FINAL_SHIFT_CLOSE_OUT_READY',
        referenceType: 'SHIFT_CLOSE_OUT',
        referenceId: 31,
        isRead: false,
        createdAt: DateTime(2026, 3, 28, 21, 0),
      ),
    ];
  }

  @override
  Future<OperatorFinalShiftCloseOutDetail> getFinalShiftCloseOutDetail({
    required int closeOutId,
  }) async {
    return OperatorFinalShiftCloseOutDetail(
      closeOutId: closeOutId,
      shiftId: 17,
      parkingLotId: 13,
      parkingLotName: 'Bai xe Nguyen Du',
      attendantId: 7,
      attendantName: 'Attendant A',
      expectedCash: 85000,
      currentAvailable: 12,
      activeSessionCount: 0,
      status: completeCalls > 0 ? 'COMPLETED' : 'REQUESTED',
      requestedAt: DateTime(2026, 3, 28, 21, 0),
      completedAt: completeCalls > 0 ? DateTime(2026, 3, 28, 21, 10) : null,
    );
  }

  @override
  Future<OperatorFinalShiftCloseOutDetail> completeFinalShiftCloseOut({
    required int closeOutId,
  }) async {
    completeCalls += 1;
    return getFinalShiftCloseOutDetail(closeOutId: closeOutId);
  }

  @override
  Future<List<OperatorLotAnnouncement>> getLotAnnouncements({
    required int parkingLotId,
  }) async {
    return const [];
  }

  @override
  Future<OperatorLotAnnouncement> createLotAnnouncement({
    required int parkingLotId,
    required String title,
    String? content,
    required String announcementType,
    required DateTime visibleFrom,
    DateTime? visibleUntil,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<OperatorLotAnnouncement> updateLotAnnouncement({
    required int parkingLotId,
    required int announcementId,
    required String title,
    String? content,
    required String announcementType,
    required DateTime visibleFrom,
    DateTime? visibleUntil,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<OperatorManagedAttendant>> getLotAttendants({
    required int parkingLotId,
  }) async {
    return const [];
  }

  @override
  Future<OperatorManagedAttendant> createLotAttendant({
    required int parkingLotId,
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeLotAttendant({
    required int parkingLotId,
    required int attendantId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<OperatorManagedParkingLot> updateManagedParkingLot({
    required int parkingLotId,
    required String name,
    required String address,
    required int totalCapacity,
    required String openingTime,
    required String closingTime,
    required String pricingMode,
    required double priceAmount,
    String? description,
    String? coverImage,
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
  testWidgets('attendant can request final shift close-out', (tester) async {
    final service = FakeFinalShiftCloseOutAttendantService();

    await tester.pumpWidget(
      MaterialApp(
        home: AttendantCheckInScreen(
          attendantCheckInService: service,
          scannerBuilder: _fakeScanner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shift-handover-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('request-final-shift-close-out-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.requestCloseOutCalls, 1);
    expect(find.text('Da gui dong ca cuoi ngay'), findsOneWidget);
    expect(find.textContaining('85.000 VND'), findsOneWidget);
  });

  testWidgets('operator can review and complete final shift close-out', (
    tester,
  ) async {
    final service = FakeFinalShiftCloseOutOperatorService();

    await tester.pumpWidget(
      MaterialApp(
        home: OperatorLotManagementScreen(
          lotManagementService: service,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('operator-shift-alerts-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('final-shift-close-out-alert-action-501')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dong ca cuoi ngay'), findsWidgets);
    expect(find.text('Bai xe Nguyen Du'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('complete-final-shift-close-out-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(service.completeCalls, 1);
    expect(
      find.text('Da hoan tat dong ca cuoi ngay cho Bai xe Nguyen Du.'),
      findsOneWidget,
    );
  });
}
