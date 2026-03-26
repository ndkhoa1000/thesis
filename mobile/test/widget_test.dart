import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/main.dart';

void main() {
  testWidgets('ParkingApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ParkingApp'), findsOneWidget);
  });
}
