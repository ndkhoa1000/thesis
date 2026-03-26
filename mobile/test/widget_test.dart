import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';
import 'package:parking_app/src/features/auth/data/auth_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.hasSessionValue = false});

  final bool hasSessionValue;

  @override
  Future<bool> hasSession() async => hasSessionValue;

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('ParkingApp shows registration screen without session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: FakeAuthService()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ParkingApp'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsOneWidget);
  });
}
