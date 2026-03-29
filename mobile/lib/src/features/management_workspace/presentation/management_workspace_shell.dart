import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../shared/presentation/state_views.dart';

class OperatorWorkspaceShell extends StatefulWidget {
  const OperatorWorkspaceShell({
    super.key,
    required this.lotsTab,
    required this.onSignOut,
    this.onOpenLotOwnerWorkspace,
  });

  final Widget lotsTab;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenLotOwnerWorkspace;

  @override
  State<OperatorWorkspaceShell> createState() => _OperatorWorkspaceShellState();
}

class _OperatorWorkspaceShellState extends State<OperatorWorkspaceShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      widget.lotsTab,
      _ManagementPlaceholderScreen(
        title: 'Nhân viên',
        headline: 'Nhân viên trực đang gắn với từng bãi xe',
        message:
            'Các luồng tạo và gỡ Attendant hiện vẫn mở trực tiếp từ từng bãi trong tab Bãi xe. Shell này giữ chỗ cho không gian nhân sự riêng khi feature đó được tách thành màn hình độc lập.',
        onOpenAlternateWorkspace: widget.onOpenLotOwnerWorkspace,
        alternateWorkspaceLabel: 'Mở không gian chủ bãi xe',
        onSignOut: widget.onSignOut,
      ),
      _ManagementPlaceholderScreen(
        title: 'Doanh thu',
        headline: 'Doanh thu vận hành hiện mở theo từng bãi xe',
        message:
            'Dashboard doanh thu vẫn sống trong từng thẻ bãi xe để bám đúng dữ liệu lease và vận hành hiện có. Tab này là điểm neo lâu dài cho màn doanh thu tổng hợp sau này.',
        onOpenAlternateWorkspace: widget.onOpenLotOwnerWorkspace,
        alternateWorkspaceLabel: 'Mở không gian chủ bãi xe',
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
              icon: Icon(Icons.local_parking_outlined),
              activeIcon: Icon(Icons.local_parking),
              label: 'Bãi xe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_2_outlined),
              activeIcon: Icon(Icons.groups_2),
              label: 'Nhân viên',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.query_stats_outlined),
              activeIcon: Icon(Icons.query_stats),
              label: 'Doanh thu',
            ),
          ],
        ),
      ),
    );
  }
}

class LotOwnerWorkspaceShell extends StatefulWidget {
  const LotOwnerWorkspaceShell({
    super.key,
    required this.lotsTab,
    required this.onSignOut,
    this.onOpenOperatorWorkspace,
  });

  final Widget lotsTab;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenOperatorWorkspace;

  @override
  State<LotOwnerWorkspaceShell> createState() => _LotOwnerWorkspaceShellState();
}

class _LotOwnerWorkspaceShellState extends State<LotOwnerWorkspaceShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      widget.lotsTab,
      _ManagementPlaceholderScreen(
        title: 'Hợp đồng',
        headline: 'Hợp đồng vẫn được khởi tạo từ từng bãi đã duyệt',
        message:
            'Luồng tạo lease đang bám vào từng bãi trong tab Bãi của tôi để dùng đúng dữ liệu vận hành khả dụng. Tab này giữ chỗ cho màn hợp đồng tổng hợp khi feature đó sẵn sàng.',
        onOpenAlternateWorkspace: widget.onOpenOperatorWorkspace,
        alternateWorkspaceLabel: 'Mở không gian vận hành',
        onSignOut: widget.onSignOut,
      ),
      _ManagementPlaceholderScreen(
        title: 'Cá nhân',
        headline: 'Không gian cá nhân chủ bãi đang được hoàn thiện',
        message:
            'Trong giai đoạn này bạn vẫn quản lý bãi, tạo lease và xem doanh thu từ tab Bãi của tôi. Tab Cá nhân giữ chỗ cho thiết lập hồ sơ và điều hướng capability sau này.',
        onOpenAlternateWorkspace: widget.onOpenOperatorWorkspace,
        alternateWorkspaceLabel: 'Mở không gian vận hành',
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
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'Bãi của tôi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Hợp đồng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementPlaceholderScreen extends StatelessWidget {
  const _ManagementPlaceholderScreen({
    required this.title,
    required this.headline,
    required this.message,
    required this.onSignOut,
    this.onOpenAlternateWorkspace,
    this.alternateWorkspaceLabel,
  });

  final String title;
  final String headline;
  final String message;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenAlternateWorkspace;
  final String? alternateWorkspaceLabel;

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
        child: EmptyView(
          icon: Icons.inventory_2_outlined,
          title: headline,
          message: message,
          actionLabel: alternateWorkspaceLabel,
          onAction: onOpenAlternateWorkspace,
        ),
      ),
    );
  }
}
