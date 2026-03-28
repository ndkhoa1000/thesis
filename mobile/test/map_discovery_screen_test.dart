import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  Widget buildSubject({
    required MapDiscoveryService mapDiscoveryService,
    required MapLocationPermissionService locationPermissionService,
    required DriverMapCanvasBuilder mapCanvasBuilder,
  }) {
    return MaterialApp(
      home: MapDiscoveryScreen(
        mapDiscoveryService: mapDiscoveryService,
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

    await tester.pumpWidget(
      buildSubject(
        mapDiscoveryService: service,
        locationPermissionService: FakeLocationPermissionService(true),
        mapCanvasBuilder: (context, viewData) {
          if (viewData.lots.isEmpty) {
            return const Text('markers:0');
          }
          return Column(
            children: [
              Text('markers:${viewData.lots.length}'),
              Text('cluster:${viewData.clusterEnabled}'),
              Text(viewData.lots.first.availabilityText),
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
    expect(find.text('Còn 14 chỗ'), findsOneWidget);
    expect(find.text('full'), findsOneWidget);
  });

  testWidgets('shows a default-city fallback notice when location is denied', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        mapDiscoveryService: FakeMapDiscoveryService(lots: const []),
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
}