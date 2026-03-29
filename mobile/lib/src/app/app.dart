import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

import '../core/network/api_client.dart';
import '../features/admin_approvals/data/admin_approvals_service.dart';
import '../features/admin_approvals/presentation/admin_approvals_screen.dart';
import '../features/attendant_check_in/data/attendant_check_in_service.dart';
import '../features/attendant_check_in/presentation/attendant_check_in_screen.dart';
import '../features/attendant_workspace/presentation/attendant_workspace_shell.dart';
import '../features/auth/data/auth_service.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/driver_booking/data/driver_booking_service.dart';
import '../features/driver_check_in/data/driver_check_in_service.dart';
import '../features/driver_check_in/presentation/driver_check_in_screen.dart';
import '../features/driver_workspace/presentation/driver_workspace_shell.dart';
import '../features/lot_details/data/lot_details_service.dart';
import '../features/lot_owner_application/data/lot_owner_application_service.dart';
import '../features/lot_owner_application/presentation/lot_owner_application_screen.dart';
import '../features/map_discovery/data/map_discovery_service.dart';
import '../features/map_discovery/presentation/map_discovery_screen.dart';
import '../features/management_workspace/presentation/management_workspace_shell.dart';
import '../features/operator_application/data/operator_application_service.dart';
import '../features/operator_application/presentation/operator_application_screen.dart';
import '../features/operator_lot_management/data/operator_lot_management_service.dart';
import '../features/operator_lot_management/presentation/operator_lot_management_screen.dart';
import '../features/owner_revenue_dashboard/data/owner_revenue_dashboard_service.dart';
import '../features/parking_history/data/parking_history_service.dart';
import '../features/parking_history/presentation/parking_history_screen.dart';
import '../features/parking_lot_registration/data/parking_lot_service.dart';
import '../features/parking_lot_registration/presentation/parking_lot_registration_screen.dart';
import '../features/vehicles/data/vehicle_service.dart';
import '../features/vehicles/presentation/vehicle_screen.dart';
import 'app_router.dart';
import 'app_theme.dart';

typedef VehicleServiceFactory = VehicleService Function(String accessToken);
typedef LotOwnerApplicationServiceFactory =
    LotOwnerApplicationService Function(String accessToken);
typedef OperatorApplicationServiceFactory =
    OperatorApplicationService Function(String accessToken);
typedef AdminApprovalsServiceFactory =
    AdminApprovalsService Function(String accessToken);
typedef ParkingLotServiceFactory =
    ParkingLotService Function(String accessToken);
typedef OwnerRevenueDashboardServiceFactory =
    OwnerRevenueDashboardService Function(String accessToken);
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

OwnerRevenueDashboardService defaultOwnerRevenueDashboardServiceFactory(
  String accessToken,
) {
  final apiClient = ApiClient();
  return BackendOwnerRevenueDashboardService(
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

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.authService,
    this.vehicleServiceFactory = defaultVehicleServiceFactory,
    this.applicationServiceFactory = defaultLotOwnerApplicationServiceFactory,
    this.operatorApplicationServiceFactory =
        defaultOperatorApplicationServiceFactory,
    this.adminApprovalsServiceFactory = defaultAdminApprovalsServiceFactory,
    this.parkingLotServiceFactory = defaultParkingLotServiceFactory,
    this.ownerRevenueDashboardServiceFactory =
        defaultOwnerRevenueDashboardServiceFactory,
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

  final AuthService authService;
  final VehicleServiceFactory vehicleServiceFactory;
  final LotOwnerApplicationServiceFactory applicationServiceFactory;
  final OperatorApplicationServiceFactory operatorApplicationServiceFactory;
  final AdminApprovalsServiceFactory adminApprovalsServiceFactory;
  final ParkingLotServiceFactory parkingLotServiceFactory;
  final OwnerRevenueDashboardServiceFactory ownerRevenueDashboardServiceFactory;
  final OperatorLotManagementServiceFactory operatorLotManagementServiceFactory;
  final DriverCheckInServiceFactory driverCheckInServiceFactory;
  final DriverBookingServiceFactory driverBookingServiceFactory;
  final AttendantCheckInServiceFactory attendantCheckInServiceFactory;
  final MapDiscoveryServiceFactory mapDiscoveryServiceFactory;
  final LotDetailsServiceFactory lotDetailsServiceFactory;
  final ParkingHistoryServiceFactory parkingHistoryServiceFactory;
  final MapLocationPermissionService mapLocationPermissionService;
  final AttendantScannerBuilder attendantScannerBuilder;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<int> _routerRefresh = ValueNotifier<int>(0);
  AuthSession? _session;
  bool _suppressAuthRestore = false;

  late final GoRouter _router = GoRouter(
    initialLocation: AppRouter.authPath,
    refreshListenable: _routerRefresh,
    redirect: (context, state) {
      final session = _session;
      if (session == null) {
        return state.matchedLocation == AppRouter.authPath
            ? null
            : AppRouter.authPath;
      }

      if (AppRouter.canAccessLocation(session, state.matchedLocation)) {
        return null;
      }

      return AppRouter.locationForSession(session);
    },
    routes: [
      GoRoute(
        name: AppRouter.authName,
        path: AppRouter.authPath,
        builder: (context, state) => AuthGate(
          authService: _GuardedAuthService(
            delegate: widget.authService,
            suppressRestore: _suppressAuthRestore,
          ),
          authenticatedBuilder:
              (context, session, onSignOut, onSessionUpdated) => _AuthRouteSync(
                session: session,
                onAuthenticated: _handleAuthenticated,
              ),
        ),
      ),
      GoRoute(
        name: AppRouter.driverName,
        path: AppRouter.driverPath,
        builder: (context, state) => _buildWorkspace(AppRouter.driverPath),
      ),
      GoRoute(
        name: AppRouter.operatorName,
        path: AppRouter.operatorPath,
        builder: (context, state) => _buildWorkspace(AppRouter.operatorPath),
      ),
      GoRoute(
        name: AppRouter.lotOwnerName,
        path: AppRouter.lotOwnerPath,
        builder: (context, state) => _buildWorkspace(AppRouter.lotOwnerPath),
      ),
      GoRoute(
        name: AppRouter.attendantName,
        path: AppRouter.attendantPath,
        builder: (context, state) => _buildWorkspace(AppRouter.attendantPath),
      ),
      GoRoute(
        name: AppRouter.adminName,
        path: AppRouter.adminPath,
        builder: (context, state) => _buildWorkspace(AppRouter.adminPath),
      ),
    ],
  );

  void _refreshRouter() {
    _routerRefresh.value++;
  }

  void _handleAuthenticated(AuthSession session) {
    if (_session == session) {
      return;
    }
    setState(() {
      _session = session;
      _suppressAuthRestore = false;
    });
    _refreshRouter();
  }

  void _handleSessionUpdated(AuthSession session) {
    setState(() {
      _session = session;
      _suppressAuthRestore = false;
    });
    _refreshRouter();
  }

  Future<void> _handleSignOut() async {
    await widget.authService.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _suppressAuthRestore = true;
    });
    _refreshRouter();
  }

  Widget _buildWorkspace(String workspacePath) {
    final session = _session;
    if (session == null) {
      return const SizedBox.shrink();
    }

    return AuthenticatedHome(
      workspacePath: workspacePath,
      session: session,
      authService: widget.authService,
      onSignOut: _handleSignOut,
      onSessionUpdated: _handleSessionUpdated,
      vehicleServiceFactory: widget.vehicleServiceFactory,
      applicationServiceFactory: widget.applicationServiceFactory,
      operatorApplicationServiceFactory:
          widget.operatorApplicationServiceFactory,
      adminApprovalsServiceFactory: widget.adminApprovalsServiceFactory,
      parkingLotServiceFactory: widget.parkingLotServiceFactory,
      ownerRevenueDashboardServiceFactory:
          widget.ownerRevenueDashboardServiceFactory,
      operatorLotManagementServiceFactory:
          widget.operatorLotManagementServiceFactory,
      driverCheckInServiceFactory: widget.driverCheckInServiceFactory,
      driverBookingServiceFactory: widget.driverBookingServiceFactory,
      attendantCheckInServiceFactory: widget.attendantCheckInServiceFactory,
      mapDiscoveryServiceFactory: widget.mapDiscoveryServiceFactory,
      lotDetailsServiceFactory: widget.lotDetailsServiceFactory,
      parkingHistoryServiceFactory: widget.parkingHistoryServiceFactory,
      mapLocationPermissionService: widget.mapLocationPermissionService,
      attendantScannerBuilder: widget.attendantScannerBuilder,
    );
  }

  @override
  void dispose() {
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ParkingApp',
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}

class _AuthRouteSync extends StatefulWidget {
  const _AuthRouteSync({required this.session, required this.onAuthenticated});

  final AuthSession session;
  final void Function(AuthSession session) onAuthenticated;

  @override
  State<_AuthRouteSync> createState() => _AuthRouteSyncState();
}

class _AuthRouteSyncState extends State<_AuthRouteSync> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _AuthRouteSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _sync();
    }
  }

  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onAuthenticated(widget.session);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _GuardedAuthService implements AuthService {
  const _GuardedAuthService({
    required this.delegate,
    required this.suppressRestore,
  });

  final AuthService delegate;
  final bool suppressRestore;

  @override
  Future<AuthSession?> restoreSession() {
    if (suppressRestore) {
      return Future<AuthSession?>.value(null);
    }
    return delegate.restoreSession();
  }

  @override
  Future<AuthSession?> refreshSession() => delegate.refreshSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    bool rememberSession = false,
  }) => delegate.register(
    email: email,
    password: password,
    rememberSession: rememberSession,
  );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberSession = false,
  }) => delegate.login(
    email: email,
    password: password,
    rememberSession: rememberSession,
  );

  @override
  Future<void> signOut() => delegate.signOut();
}

class AuthenticatedHome extends StatelessWidget {
  const AuthenticatedHome({
    super.key,
    this.workspacePath,
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
    this.ownerRevenueDashboardServiceFactory =
        defaultOwnerRevenueDashboardServiceFactory,
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

  final String? workspacePath;
  final AuthSession session;
  final AuthService authService;
  final Future<void> Function() onSignOut;
  final void Function(AuthSession session) onSessionUpdated;
  final VehicleServiceFactory vehicleServiceFactory;
  final LotOwnerApplicationServiceFactory applicationServiceFactory;
  final OperatorApplicationServiceFactory operatorApplicationServiceFactory;
  final AdminApprovalsServiceFactory adminApprovalsServiceFactory;
  final ParkingLotServiceFactory parkingLotServiceFactory;
  final OwnerRevenueDashboardServiceFactory ownerRevenueDashboardServiceFactory;
  final OperatorLotManagementServiceFactory operatorLotManagementServiceFactory;
  final DriverCheckInServiceFactory driverCheckInServiceFactory;
  final DriverBookingServiceFactory driverBookingServiceFactory;
  final AttendantCheckInServiceFactory attendantCheckInServiceFactory;
  final MapDiscoveryServiceFactory mapDiscoveryServiceFactory;
  final LotDetailsServiceFactory lotDetailsServiceFactory;
  final ParkingHistoryServiceFactory parkingHistoryServiceFactory;
  final MapLocationPermissionService mapLocationPermissionService;
  final AttendantScannerBuilder attendantScannerBuilder;

  String get _effectiveWorkspacePath =>
      workspacePath ?? AppRouter.locationForSession(session);

  bool get _isOperatorWorkspace =>
      _effectiveWorkspacePath == AppRouter.operatorPath;
  bool get _isLotOwnerWorkspace =>
      _effectiveWorkspacePath == AppRouter.lotOwnerPath;
  bool get _isDriverWorkspace =>
      _effectiveWorkspacePath == AppRouter.driverPath;

  @override
  Widget build(BuildContext context) {
    final hasLotOwnerCapability = session.capabilities['lot_owner'] ?? false;
    final hasOperatorCapability = session.capabilities['operator'] ?? false;

    if (session.isAdmin) {
      return Theme(
        data: AppTheme.light(),
        child: AdminApprovalsScreen(
          approvalsService: adminApprovalsServiceFactory(session.accessToken),
          onSignOut: onSignOut,
        ),
      );
    }

    if (session.isAttendant) {
      return AttendantWorkspaceShell(
        attendantCheckInService: attendantCheckInServiceFactory(
          session.accessToken,
        ),
        scannerBuilder: attendantScannerBuilder,
        onSignOut: onSignOut,
      );
    }

    if (_isOperatorWorkspace) {
      return OperatorWorkspaceShell(
        lotsTab: OperatorLotManagementScreen(
          lotManagementService: operatorLotManagementServiceFactory(
            session.accessToken,
          ),
          onSignOut: onSignOut,
        ),
        onOpenLotOwnerWorkspace: hasLotOwnerCapability
            ? () => GoRouter.of(context).go(AppRouter.lotOwnerPath)
            : null,
        onSignOut: onSignOut,
      );
    }

    if (_isLotOwnerWorkspace) {
      return LotOwnerWorkspaceShell(
        lotsTab: ParkingLotRegistrationScreen(
          parkingLotService: parkingLotServiceFactory(session.accessToken),
          ownerRevenueDashboardService: ownerRevenueDashboardServiceFactory(
            session.accessToken,
          ),
          onSignOut: onSignOut,
        ),
        onOpenOperatorWorkspace: hasOperatorCapability
            ? () => GoRouter.of(context).go(AppRouter.operatorPath)
            : null,
        onSignOut: onSignOut,
      );
    }

    final mapboxToken =
        dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];
    final mapCanvasBuilder = mapboxToken == null || mapboxToken.isEmpty
        ? defaultDriverMapFallbackCanvasBuilder
        : defaultDriverMapCanvasBuilder;

    if (_isDriverWorkspace) {
      return Theme(
        data: AppTheme.light(),
        child: DriverWorkspaceShell(
          mapTab: MapDiscoveryScreen(
            mapDiscoveryService: mapDiscoveryServiceFactory(
              session.accessToken,
            ),
            lotDetailsService: lotDetailsServiceFactory(session.accessToken),
            driverBookingService: driverBookingServiceFactory(
              session.accessToken,
            ),
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
            onOpenLotOwnerApplication: hasLotOwnerCapability
                ? null
                : () => openLotOwnerApplication(
                    context,
                    session,
                    authService: authService,
                    onSessionUpdated: onSessionUpdated,
                    applicationServiceFactory: applicationServiceFactory,
                  ),
            onOpenOperatorApplication: hasOperatorCapability
                ? null
                : () => openOperatorApplication(
                    context,
                    session,
                    authService: authService,
                    onSessionUpdated: onSessionUpdated,
                    applicationServiceFactory:
                        operatorApplicationServiceFactory,
                  ),
            onSignOut: onSignOut,
            showParkingHistoryAction: false,
            showDriverCheckInAction: false,
            showVehicleAction: false,
            showLotOwnerApplicationAction: false,
            showOperatorApplicationAction: false,
            showSignOutAction: false,
          ),
          historyTab: ParkingHistoryScreen(
            parkingHistoryService: parkingHistoryServiceFactory(
              session.accessToken,
            ),
          ),
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
          onOpenLotOwnerWorkspace: hasLotOwnerCapability
              ? () => GoRouter.of(context).go(AppRouter.lotOwnerPath)
              : null,
          onOpenOperatorWorkspace: hasOperatorCapability
              ? () => GoRouter.of(context).go(AppRouter.operatorPath)
              : null,
          onOpenLotOwnerApplication: hasLotOwnerCapability
              ? null
              : () => openLotOwnerApplication(
                  context,
                  session,
                  authService: authService,
                  onSessionUpdated: onSessionUpdated,
                  applicationServiceFactory: applicationServiceFactory,
                ),
          onOpenOperatorApplication: hasOperatorCapability
              ? null
              : () => openOperatorApplication(
                  context,
                  session,
                  authService: authService,
                  onSessionUpdated: onSessionUpdated,
                  applicationServiceFactory: operatorApplicationServiceFactory,
                ),
          onSignOut: onSignOut,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
