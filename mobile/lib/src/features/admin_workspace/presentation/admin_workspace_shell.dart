import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class AdminWorkspaceShell extends StatefulWidget {
  const AdminWorkspaceShell({
    super.key,
    required this.approvalsTab,
    required this.onSignOut,
  });

  final Widget approvalsTab;
  final Future<void> Function() onSignOut;

  @override
  State<AdminWorkspaceShell> createState() => _AdminWorkspaceShellState();
}

class _AdminWorkspaceShellState extends State<AdminWorkspaceShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      widget.approvalsTab,
      _AdminPlaceholderScreen(
        title: 'Người dùng',
        headline: 'Quản lý người dùng sẽ được gom về workspace riêng',
        message:
            'Các thao tác khóa và mở lại tài khoản hiện vẫn nằm trong bề mặt duyệt hồ sơ hiện có. Tab này giữ chỗ cho không gian quản trị người dùng chuyên biệt khi nó được tách khỏi approvals flow.',
        onSignOut: widget.onSignOut,
      ),
      _AdminPlaceholderScreen(
        title: 'Bãi xe',
        headline: 'Điều phối bãi xe đang bám vào dashboard approvals',
        message:
            'Các thao tác tạm dừng và mở lại bãi xe vẫn chạy từ màn duyệt hiện tại để giữ nguyên business flow. Tab này là điểm neo trung thực cho không gian quản trị bãi xe riêng ở các story sau.',
        onSignOut: widget.onSignOut,
      ),
    ];

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: tabs),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              activeIcon: Icon(Icons.fact_check),
              label: 'Duyệt hồ sơ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Người dùng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_parking_outlined),
              activeIcon: Icon(Icons.local_parking),
              label: 'Bãi xe',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPlaceholderScreen extends StatelessWidget {
  const _AdminPlaceholderScreen({
    required this.title,
    required this.headline,
    required this.message,
    required this.onSignOut,
  });

  final String title;
  final String headline;
  final String message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: onSignOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                headline,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
