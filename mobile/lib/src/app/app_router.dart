import '../features/auth/data/auth_service.dart';

final class AppRouter {
  static const String authName = 'auth';
  static const String authPath = '/auth';
  static const String driverName = 'driver';
  static const String driverPath = '/driver';
  static const String operatorName = 'operator';
  static const String operatorPath = '/operator';
  static const String lotOwnerName = 'lot-owner';
  static const String lotOwnerPath = '/lot-owner';
  static const String attendantName = 'attendant';
  static const String attendantPath = '/attendant';
  static const String adminName = 'admin';
  static const String adminPath = '/admin';

  static String locationForSession(AuthSession session) {
    if (session.isAdmin) {
      return adminPath;
    }
    if (session.isAttendant) {
      return attendantPath;
    }
    switch (session.role) {
      case 'MANAGER':
        return operatorPath;
      case 'LOT_OWNER':
        return lotOwnerPath;
      default:
        return driverPath;
    }
  }

  static bool canAccessLocation(AuthSession session, String location) {
    if (_matches(location, adminPath)) {
      return session.isAdmin;
    }
    if (_matches(location, attendantPath)) {
      return session.isAttendant;
    }
    if (_matches(location, driverPath)) {
      return session.capabilities['driver'] ?? session.role == 'DRIVER';
    }
    if (_matches(location, operatorPath)) {
      return session.role == 'MANAGER' || session.capabilities['operator'] == true;
    }
    if (_matches(location, lotOwnerPath)) {
      return session.role == 'LOT_OWNER' || session.capabilities['lot_owner'] == true;
    }
    return false;
  }

  static bool _matches(String location, String path) {
    return location == path || location.startsWith('$path/');
  }
}
