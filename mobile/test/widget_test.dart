import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';
import 'package:parking_app/src/features/auth/data/auth_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.session});

  final AuthSession? session;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async =>
      session ??
      const AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        role: 'DRIVER',
        capabilities: {
          'driver': true,
          'lot_owner': false,
          'operator': false,
          'attendant': false,
          'admin': false,
          'public_account': true,
        },
      );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async =>
      session ??
      const AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        role: 'DRIVER',
        capabilities: {
          'driver': true,
          'lot_owner': false,
          'operator': false,
          'attendant': false,
          'admin': false,
          'public_account': true,
        },
      );

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('ParkingApp shows login screen without session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ParkingApp'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets('ParkingApp routes attendant session to dedicated workspace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        authService: FakeAuthService(
          session: const AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            role: 'ATTENDANT',
            capabilities: {
              'driver': false,
              'lot_owner': false,
              'operator': false,
              'attendant': true,
              'admin': false,
              'public_account': false,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendant Workspace'), findsOneWidget);
  });
}
