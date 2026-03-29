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
}
