import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_app/src/shared/presentation/state_views.dart';

Widget _buildSubject({required Widget child, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('LoadingView renders adaptive light content', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        child: const LoadingView(
          title: 'Đang tải dữ liệu',
          message: 'Vui lòng chờ trong giây lát.',
        ),
      ),
    );

    expect(find.text('Đang tải dữ liệu'), findsOneWidget);
    expect(find.text('Vui lòng chờ trong giây lát.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final title = tester.widget<Text>(find.text('Đang tải dữ liệu'));
    expect(title.style?.color, ThemeData.light().colorScheme.onSurface);
  });

  testWidgets('ErrorView renders retry action and handles tap', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      _buildSubject(
        child: ErrorView(
          title: 'Không tải được dữ liệu',
          message: 'Hãy thử lại sau.',
          onRetry: () async {
            retried = true;
          },
        ),
      ),
    );

    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Hãy thử lại sau.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Thử lại'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Thử lại'));
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('EmptyView supports dark tone and action callback', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      _buildSubject(
        theme: ThemeData.light(useMaterial3: true),
        child: EmptyView(
          title: 'Chưa có dữ liệu',
          message: 'Hãy tạo mục đầu tiên để tiếp tục.',
          actionLabel: 'Tạo mới',
          onAction: () {
            tapped = true;
          },
          tone: StateViewTone.dark,
        ),
      ),
    );

    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Hãy tạo mục đầu tiên để tiếp tục.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tạo mới'), findsOneWidget);

    final title = tester.widget<Text>(find.text('Chưa có dữ liệu'));
    expect(title.style?.color, Colors.white);

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo mới'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
