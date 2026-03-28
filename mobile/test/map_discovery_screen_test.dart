import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/features/lot_details/data/lot_details_service.dart';
import 'package:parking_app/src/features/map_discovery/data/map_discovery_service.dart';
import 'package:parking_app/src/features/map_discovery/presentation/map_discovery_screen.dart';

class FakeMapDiscoveryService implements MapDiscoveryService {
  FakeMapDiscoveryService({required this.lots});

  final List<MapDiscoveryLotSummary> lots;
  bool fetchCalled = false;

  @override
  Future<List<MapDiscoveryLotSummary>> fetchActiveLots() async {
    fetchCalled = true;
    return lots;
  }
}

class FakeLocationPermissionService implements MapLocationPermissionService {
  FakeLocationPermissionService(this.isGranted);

  final bool isGranted;

  @override
  Future<bool> requestAccess() async => isGranted;
}

class FakeLotDetailsService implements LotDetailsService {
  FakeLotDetailsService({required this.detailsById});

  final Map<int, DriverLotDetail> detailsById;
  final List<int> requestedLotIds = [];

  @override
  Future<DriverLotDetail> fetchLotDetail({required int lotId}) async {
    requestedLotIds.add(lotId);
    return detailsById[lotId]!;
  }
}

void main() {
  Widget buildSubject({
    required MapDiscoveryService mapDiscoveryService,
    required LotDetailsService lotDetailsService,
    required MapLocationPermissionService locationPermissionService,
    required DriverMapCanvasBuilder mapCanvasBuilder,
  }) {
    return MaterialApp(
      home: MapDiscoveryScreen(
        mapDiscoveryService: mapDiscoveryService,
        lotDetailsService: lotDetailsService,
        locationPermissionService: locationPermissionService,
        mapCanvasBuilder: mapCanvasBuilder,
        onOpenDriverCheckIn: () async {},
        onOpenVehicles: () async {},
        onSignOut: () async {},
      ),
    );
  }

  testWidgets('loads active lots and enables clustered marker rendering', (
    tester,
  ) async {
    final service = FakeMapDiscoveryService(
      lots: const [
        MapDiscoveryLotSummary(
          id: 1,
          name: 'Bãi xe Lê Lợi',
          address: '45 Lê Lợi, Quận 1',
          latitude: 10.7729,
          longitude: 106.6983,
          currentAvailable: 14,
          status: 'APPROVED',
        ),
        MapDiscoveryLotSummary(
          id: 2,
          name: 'Bãi xe Nguyễn Huệ',
          address: '2 Nguyễn Huệ, Quận 1',
          latitude: 10.7735,
          longitude: 106.7032,
          currentAvailable: 0,
          status: 'APPROVED',
        ),
      ],
    );
    final lotDetailsService = FakeLotDetailsService(
      detailsById: {
        1: DriverLotDetail(
          id: 1,
          name: 'Bãi xe Lê Lợi',
          address: '45 Lê Lợi, Quận 1',
          latitude: 10.7729,
          longitude: 106.6983,
          currentAvailable: 14,
          status: 'APPROVED',
          peakHours: const LotHistoricalTrend(
            status: 'READY',
            lookbackDays: 30,
            totalSessions: 10,
            points: [LotPeakHourPoint(hour: 8, sessionCount: 4)],
          ),
        ),
        2: DriverLotDetail(
          id: 2,
          name: 'Bãi xe Nguyễn Huệ',
          address: '2 Nguyễn Huệ, Quận 1',
          latitude: 10.7735,
          longitude: 106.7032,
          currentAvailable: 0,
          status: 'APPROVED',
          peakHours: const LotHistoricalTrend(
            status: 'READY',
            lookbackDays: 30,
            totalSessions: 4,
            points: [LotPeakHourPoint(hour: 18, sessionCount: 4)],
          ),
        ),
      },
    );

    await tester.pumpWidget(
      buildSubject(
        mapDiscoveryService: service,
        lotDetailsService: lotDetailsService,
        locationPermissionService: FakeLocationPermissionService(true),
        mapCanvasBuilder: (context, viewData) {
          if (viewData.lots.isEmpty) {
            return const Text('markers:0');
          }
          return Column(
            children: [
              Text('markers:${viewData.lots.length}'),
              Text('cluster:${viewData.clusterEnabled}'),
              Text('first:${viewData.lots.first.availabilityText}'),
              Text(viewData.lots.last.availabilityState.name),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(service.fetchCalled, isTrue);
    expect(find.text('markers:2'), findsOneWidget);
    expect(find.text('cluster:true'), findsOneWidget);
    expect(find.text('first:Còn 14 chỗ'), findsOneWidget);
    expect(find.text('full'), findsOneWidget);
  });

  testWidgets('shows a default-city fallback notice when location is denied', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        mapDiscoveryService: FakeMapDiscoveryService(lots: const []),
        lotDetailsService: FakeLotDetailsService(detailsById: const {}),
        locationPermissionService: FakeLocationPermissionService(false),
        mapCanvasBuilder: (context, viewData) => const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bản đồ đang hiển thị vị trí mặc định của TP.HCM'),
      findsOneWidget,
    );
  });

  testWidgets('opens backend-backed lot details from the discovery rail', (
    tester,
  ) async {
    final lotDetailsService = FakeLotDetailsService(
      detailsById: {
        1: DriverLotDetail(
          id: 1,
          name: 'Bãi xe Lê Lợi',
          address: '45 Lê Lợi, Quận 1',
          latitude: 10.7729,
          longitude: 106.6983,
          currentAvailable: 3,
          status: 'APPROVED',
          totalCapacity: 24,
          openingTime: '07:00',
          closingTime: '22:00',
          pricingMode: 'HOURLY',
          priceAmount: 5000,
          tagLabels: const ['trung-tam'],
          featureLabels: const ['CAMERA'],
          peakHours: const LotHistoricalTrend(
            status: 'INSUFFICIENT_DATA',
            lookbackDays: 30,
            totalSessions: 1,
            points: [],
          ),
        ),
      },
    );

    await tester.pumpWidget(
      buildSubject(
        mapDiscoveryService: FakeMapDiscoveryService(
          lots: const [
            MapDiscoveryLotSummary(
              id: 1,
              name: 'Bãi xe Lê Lợi',
              address: '45 Lê Lợi, Quận 1',
              latitude: 10.7729,
              longitude: 106.6983,
              currentAvailable: 3,
              status: 'APPROVED',
            ),
          ],
        ),
        lotDetailsService: lotDetailsService,
        locationPermissionService: FakeLocationPermissionService(true),
        mapCanvasBuilder: (context, viewData) => const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lotCard:1')));
    await tester.pumpAndSettle();

    expect(lotDetailsService.requestedLotIds, [1]);
    expect(find.text('Theo giờ: 5000 VND'), findsOneWidget);
    expect(find.text('Còn 3 chỗ / 24 chỗ'), findsOneWidget);
    expect(
      find.text('Chưa đủ dữ liệu lịch sử để hiển thị peak hours cho bãi này.'),
      findsOneWidget,
    );
  });
}
