import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'src/core/auth/token_store.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/data/auth_service.dart';
import 'src/features/auth/presentation/auth_gate.dart';
import 'src/features/admin_approvals/data/admin_approvals_service.dart';
import 'src/features/admin_approvals/presentation/admin_approvals_screen.dart';
import 'src/features/attendant_check_in/data/attendant_check_in_service.dart';
import 'src/features/attendant_check_in/presentation/attendant_check_in_screen.dart';
import 'src/features/driver_booking/data/driver_booking_service.dart';
import 'src/features/driver_check_in/data/driver_check_in_service.dart';
import 'src/features/driver_check_in/presentation/driver_check_in_screen.dart';
import 'src/features/lot_owner_application/data/lot_owner_application_service.dart';
import 'src/features/lot_owner_application/presentation/lot_owner_application_screen.dart';
import 'src/features/lot_details/data/lot_details_service.dart';
import 'src/features/map_discovery/data/map_discovery_service.dart';
import 'src/features/map_discovery/presentation/map_discovery_screen.dart';
import 'src/features/parking_history/data/parking_history_service.dart';
import 'src/features/parking_history/presentation/parking_history_screen.dart';
import 'src/features/operator_application/data/operator_application_service.dart';
import 'src/features/operator_application/presentation/operator_application_screen.dart';
import 'src/features/operator_lot_management/data/operator_lot_management_service.dart';
import 'src/features/operator_lot_management/presentation/operator_lot_management_screen.dart';
import 'src/features/parking_lot_registration/data/parking_lot_service.dart';
import 'src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart';
import 'src/features/vehicles/data/vehicle_service.dart';
import 'src/features/vehicles/presentation/vehicle_screen.dart';

typedef VehicleServiceFactory = VehicleService Function(String accessToken);
typedef LotOwnerApplicationServiceFactory =
    LotOwnerApplicationService Function(String accessToken);
typedef OperatorApplicationServiceFactory =
    OperatorApplicationService Function(String accessToken);
typedef AdminApprovalsServiceFactory =
    AdminApprovalsService Function(String accessToken);
typedef ParkingLotServiceFactory =
    ParkingLotService Function(String accessToken);
typedef OperatorLotManagementServiceFactory =
    OperatorLotManagementService Function(String accessToken);
typedef DriverCheckInServiceFactory =
    DriverCheckInService Function(String accessToken);
typedef DriverBookingServiceFactory =
    DriverBookingService Function(String accessToken);
typedef AttendantCheckInServiceFactory =
    AttendantCheckInService Function(String accessToken);
typedef MapDiscoveryServiceFactory =
    MapDiscoveryService Function(String accessToken);
typedef LotDetailsServiceFactory =
    LotDetailsService Function(String accessToken);
typedef ParkingHistoryServiceFactory =
    ParkingHistoryService Function(String accessToken);

VehicleService defaultVehicleServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendVehicleService(dio: apiClient.client, accessToken: accessToken);
}

LotOwnerApplicationService defaultLotOwnerApplicationServiceFactory(
  String accessToken,
) {
  final apiClient = ApiClient();
  return BackendLotOwnerApplicationService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

OperatorApplicationService defaultOperatorApplicationServiceFactory(
  String accessToken,
) {
  final apiClient = ApiClient();
  return BackendOperatorApplicationService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

AdminApprovalsService defaultAdminApprovalsServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendAdminApprovalsService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

ParkingLotService defaultParkingLotServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendParkingLotService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

OperatorLotManagementService defaultOperatorLotManagementServiceFactory(
  String accessToken,
) {
  final apiClient = ApiClient();
  return BackendOperatorLotManagementService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

DriverCheckInService defaultDriverCheckInServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendDriverCheckInService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

DriverBookingService defaultDriverBookingServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendDriverBookingService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

AttendantCheckInService defaultAttendantCheckInServiceFactory(
  String accessToken,
) {
  final apiClient = ApiClient();
  return BackendAttendantCheckInService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

MapDiscoveryService defaultMapDiscoveryServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendMapDiscoveryService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

LotDetailsService defaultLotDetailsServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendLotDetailsService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

ParkingHistoryService defaultParkingHistoryServiceFactory(String accessToken) {
  final apiClient = ApiClient();
  return BackendParkingHistoryService(
    dio: apiClient.client,
    accessToken: accessToken,
  );
}

Future<void> openVehicleManagement(
  BuildContext context,
  AuthSession session, {
  VehicleServiceFactory vehicleServiceFactory = defaultVehicleServiceFactory,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => VehicleScreen(
        vehicleService: vehicleServiceFactory(session.accessToken),
      ),
    ),
  );
}

Future<void> openDriverCheckIn(
  BuildContext context,
  AuthSession session, {
  VehicleServiceFactory vehicleServiceFactory = defaultVehicleServiceFactory,
  DriverCheckInServiceFactory driverCheckInServiceFactory =
      defaultDriverCheckInServiceFactory,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => DriverCheckInScreen(
        vehicleService: vehicleServiceFactory(session.accessToken),
        driverCheckInService: driverCheckInServiceFactory(session.accessToken),
        onManageVehicles: () => openVehicleManagement(
          context,
          session,
          vehicleServiceFactory: vehicleServiceFactory,
        ),
      ),
    ),
  );
}

Future<void> openParkingHistory(
  BuildContext context,
  AuthSession session, {
  ParkingHistoryServiceFactory parkingHistoryServiceFactory =
      defaultParkingHistoryServiceFactory,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ParkingHistoryScreen(
        parkingHistoryService: parkingHistoryServiceFactory(
          session.accessToken,
        ),
      ),
    ),
  );
}

void openLotOwnerApplication(
  BuildContext context,
  AuthSession session, {
  required AuthService authService,
  required void Function(AuthSession session) onSessionUpdated,
  LotOwnerApplicationServiceFactory applicationServiceFactory =
      defaultLotOwnerApplicationServiceFactory,
}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => LotOwnerApplicationScreen(
        session: session,
        authService: authService,
        applicationService: applicationServiceFactory(session.accessToken),
        onSessionUpdated: onSessionUpdated,
      ),
    ),
  );
}

void openOperatorApplication(
  BuildContext context,
  AuthSession session, {
  required AuthService authService,
  required void Function(AuthSession session) onSessionUpdated,
  OperatorApplicationServiceFactory applicationServiceFactory =
      defaultOperatorApplicationServiceFactory,
}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => OperatorApplicationScreen(
        session: session,
        authService: authService,
        applicationService: applicationServiceFactory(session.accessToken),
        onSessionUpdated: onSessionUpdated,
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final mapboxToken =
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];

  if (mapboxToken != null && mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }

  runApp(
    MyApp(
      authService: BackendAuthService(
        apiClient: ApiClient(),
        tokenStore: SecureTokenStore(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authService,
    this.attendantCheckInServiceFactory = defaultAttendantCheckInServiceFactory,
    this.driverBookingServiceFactory = defaultDriverBookingServiceFactory,
    this.mapDiscoveryServiceFactory = defaultMapDiscoveryServiceFactory,
    this.lotDetailsServiceFactory = defaultLotDetailsServiceFactory,
    this.parkingHistoryServiceFactory = defaultParkingHistoryServiceFactory,
    this.mapLocationPermissionService =
        const DeviceMapLocationPermissionService(),
    this.attendantScannerBuilder = defaultAttendantScannerBuilder,
  });

  final AuthService authService;
  final AttendantCheckInServiceFactory attendantCheckInServiceFactory;
  final DriverBookingServiceFactory driverBookingServiceFactory;
  final MapDiscoveryServiceFactory mapDiscoveryServiceFactory;
  final LotDetailsServiceFactory lotDetailsServiceFactory;
  final ParkingHistoryServiceFactory parkingHistoryServiceFactory;
  final MapLocationPermissionService mapLocationPermissionService;
  final AttendantScannerBuilder attendantScannerBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkingApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: AuthGate(
        authService: authService,
        authenticatedBuilder: (_, session, onSignOut, onSessionUpdated) =>
            AuthenticatedHome(
              session: session,
              authService: authService,
              onSignOut: onSignOut,
              onSessionUpdated: onSessionUpdated,
              attendantCheckInServiceFactory: attendantCheckInServiceFactory,
              driverBookingServiceFactory: driverBookingServiceFactory,
              mapDiscoveryServiceFactory: mapDiscoveryServiceFactory,
              lotDetailsServiceFactory: lotDetailsServiceFactory,
              parkingHistoryServiceFactory: parkingHistoryServiceFactory,
              mapLocationPermissionService: mapLocationPermissionService,
              attendantScannerBuilder: attendantScannerBuilder,
            ),
      ),
    );
  }
}

class AuthenticatedHome extends StatelessWidget {
  const AuthenticatedHome({
    super.key,
    required this.session,
    required this.authService,
    required this.onSignOut,
    required this.onSessionUpdated,
    this.vehicleServiceFactory = defaultVehicleServiceFactory,
    this.applicationServiceFactory = defaultLotOwnerApplicationServiceFactory,
    this.operatorApplicationServiceFactory =
        defaultOperatorApplicationServiceFactory,
    this.adminApprovalsServiceFactory = defaultAdminApprovalsServiceFactory,
    this.parkingLotServiceFactory = defaultParkingLotServiceFactory,
    this.operatorLotManagementServiceFactory =
        defaultOperatorLotManagementServiceFactory,
    this.driverCheckInServiceFactory = defaultDriverCheckInServiceFactory,
    this.driverBookingServiceFactory = defaultDriverBookingServiceFactory,
    this.attendantCheckInServiceFactory = defaultAttendantCheckInServiceFactory,
    this.mapDiscoveryServiceFactory = defaultMapDiscoveryServiceFactory,
    this.lotDetailsServiceFactory = defaultLotDetailsServiceFactory,
    this.parkingHistoryServiceFactory = defaultParkingHistoryServiceFactory,
    this.mapLocationPermissionService =
        const DeviceMapLocationPermissionService(),
    this.attendantScannerBuilder = defaultAttendantScannerBuilder,
  });

  final AuthSession session;
  final AuthService authService;
  final Future<void> Function() onSignOut;
  final void Function(AuthSession session) onSessionUpdated;
  final VehicleServiceFactory vehicleServiceFactory;
  final LotOwnerApplicationServiceFactory applicationServiceFactory;
  final OperatorApplicationServiceFactory operatorApplicationServiceFactory;
  final AdminApprovalsServiceFactory adminApprovalsServiceFactory;
  final ParkingLotServiceFactory parkingLotServiceFactory;
  final OperatorLotManagementServiceFactory operatorLotManagementServiceFactory;
  final DriverCheckInServiceFactory driverCheckInServiceFactory;
  final DriverBookingServiceFactory driverBookingServiceFactory;
  final AttendantCheckInServiceFactory attendantCheckInServiceFactory;
  final MapDiscoveryServiceFactory mapDiscoveryServiceFactory;
  final LotDetailsServiceFactory lotDetailsServiceFactory;
  final ParkingHistoryServiceFactory parkingHistoryServiceFactory;
  final MapLocationPermissionService mapLocationPermissionService;
  final AttendantScannerBuilder attendantScannerBuilder;

  bool get _hasLotOwnerWorkspace =>
      (session.capabilities['lot_owner'] ?? false) ||
      session.role == 'LOT_OWNER';

  bool get _hasOperatorWorkspace =>
      (session.capabilities['operator'] ?? false) || session.role == 'MANAGER';

  bool get _needsPublicWorkspaceSwitcher =>
      session.isPublicAccount && _hasLotOwnerWorkspace && _hasOperatorWorkspace;

  @override
  Widget build(BuildContext context) {
    if (session.isAdmin) {
      return AdminApprovalsScreen(
        approvalsService: adminApprovalsServiceFactory(session.accessToken),
        onSignOut: onSignOut,
      );
    }

    if (session.isAttendant) {
      return AttendantCheckInScreen(
        attendantCheckInService: attendantCheckInServiceFactory(
          session.accessToken,
        ),
        scannerBuilder: attendantScannerBuilder,
        onSignOut: onSignOut,
      );
    }

    if (_needsPublicWorkspaceSwitcher) {
      return _PublicWorkspaceSwitcherScreen(
        openLotOwnerWorkspace: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ParkingLotRegistrationScreen(
                parkingLotService: parkingLotServiceFactory(
                  session.accessToken,
                ),
                onSignOut: onSignOut,
              ),
            ),
          );
        },
        openOperatorWorkspace: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OperatorLotManagementScreen(
                lotManagementService: operatorLotManagementServiceFactory(
                  session.accessToken,
                ),
                onSignOut: onSignOut,
              ),
            ),
          );
        },
        onSignOut: onSignOut,
      );
    }

    if (_hasOperatorWorkspace) {
      return OperatorLotManagementScreen(
        lotManagementService: operatorLotManagementServiceFactory(
          session.accessToken,
        ),
        onSignOut: onSignOut,
      );
    }

    if (_hasLotOwnerWorkspace) {
      return ParkingLotRegistrationScreen(
        parkingLotService: parkingLotServiceFactory(session.accessToken),
        onSignOut: onSignOut,
      );
    }

    final mapboxToken =
        dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];
    final mapCanvasBuilder = mapboxToken == null || mapboxToken.isEmpty
        ? defaultDriverMapFallbackCanvasBuilder
        : defaultDriverMapCanvasBuilder;

    return MapDiscoveryScreen(
      mapDiscoveryService: mapDiscoveryServiceFactory(session.accessToken),
      lotDetailsService: lotDetailsServiceFactory(session.accessToken),
      driverBookingService: driverBookingServiceFactory(session.accessToken),
      vehicleService: vehicleServiceFactory(session.accessToken),
      onOpenParkingHistory: () => openParkingHistory(
        context,
        session,
        parkingHistoryServiceFactory: parkingHistoryServiceFactory,
      ),
      locationPermissionService: mapLocationPermissionService,
      mapCanvasBuilder: mapCanvasBuilder,
      onOpenDriverCheckIn: () => openDriverCheckIn(
        context,
        session,
        vehicleServiceFactory: vehicleServiceFactory,
        driverCheckInServiceFactory: driverCheckInServiceFactory,
      ),
      onOpenVehicles: () => openVehicleManagement(
        context,
        session,
        vehicleServiceFactory: vehicleServiceFactory,
      ),
      onOpenLotOwnerApplication: () => openLotOwnerApplication(
        context,
        session,
        authService: authService,
        onSessionUpdated: onSessionUpdated,
        applicationServiceFactory: applicationServiceFactory,
      ),
      onOpenOperatorApplication: () => openOperatorApplication(
        context,
        session,
        authService: authService,
        onSessionUpdated: onSessionUpdated,
        applicationServiceFactory: operatorApplicationServiceFactory,
      ),
      onSignOut: onSignOut,
    );
  }
}

class _PublicWorkspaceSwitcherScreen extends StatelessWidget {
  const _PublicWorkspaceSwitcherScreen({
    required this.openLotOwnerWorkspace,
    required this.openOperatorWorkspace,
    required this.onSignOut,
  });

  final VoidCallback openLotOwnerWorkspace;
  final VoidCallback openOperatorWorkspace;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn không gian làm việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: onSignOut,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tài khoản này có nhiều vai trò vận hành. Chọn workspace bạn muốn mở.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: openLotOwnerWorkspace,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Chủ bãi'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: openOperatorWorkspace,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: const Text('Operator'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
