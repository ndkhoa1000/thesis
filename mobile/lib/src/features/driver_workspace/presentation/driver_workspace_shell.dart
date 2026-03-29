import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class DriverWorkspaceShell extends StatefulWidget {
  const DriverWorkspaceShell({
    super.key,
    required this.mapTab,
    required this.historyTab,
    required this.onOpenDriverCheckIn,
    required this.onOpenVehicles,
    required this.onSignOut,
    this.onOpenLotOwnerWorkspace,
    this.onOpenOperatorWorkspace,
    this.onOpenLotOwnerApplication,
    this.onOpenOperatorApplication,
  });

  final Widget mapTab;
  final Widget historyTab;
  final Future<void> Function() onOpenDriverCheckIn;
  final Future<void> Function() onOpenVehicles;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenLotOwnerWorkspace;
  final VoidCallback? onOpenOperatorWorkspace;
  final VoidCallback? onOpenLotOwnerApplication;
  final VoidCallback? onOpenOperatorApplication;

  @override
  State<DriverWorkspaceShell> createState() => _DriverWorkspaceShellState();
}

class _DriverWorkspaceShellState extends State<DriverWorkspaceShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      widget.mapTab,
      widget.historyTab,
      _DriverProfileTab(
        onOpenDriverCheckIn: widget.onOpenDriverCheckIn,
        onOpenVehicles: widget.onOpenVehicles,
        onOpenLotOwnerWorkspace: widget.onOpenLotOwnerWorkspace,
        onOpenOperatorWorkspace: widget.onOpenOperatorWorkspace,
        onOpenLotOwnerApplication: widget.onOpenLotOwnerApplication,
        onOpenOperatorApplication: widget.onOpenOperatorApplication,
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
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Bản đồ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Lịch sử',
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

class _DriverProfileTab extends StatelessWidget {
  const _DriverProfileTab({
    required this.onOpenDriverCheckIn,
    required this.onOpenVehicles,
    required this.onSignOut,
    this.onOpenLotOwnerWorkspace,
    this.onOpenOperatorWorkspace,
    this.onOpenLotOwnerApplication,
    this.onOpenOperatorApplication,
  });

  final Future<void> Function() onOpenDriverCheckIn;
  final Future<void> Function() onOpenVehicles;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenLotOwnerWorkspace;
  final VoidCallback? onOpenOperatorWorkspace;
  final VoidCallback? onOpenLotOwnerApplication;
  final VoidCallback? onOpenOperatorApplication;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quản lý nhanh các tác vụ cá nhân và hồ sơ capability từ một nơi cố định.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Các hành động chính được neo xuống cuối màn hình để dễ thao tác bằng một tay.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onOpenDriverCheckIn,
                icon: const Icon(Icons.qr_code_2_outlined),
                label: const Text('Mã check-in'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpenVehicles,
                icon: const Icon(Icons.directions_car_outlined),
                label: const Text('Xe của tôi'),
              ),
              if (onOpenLotOwnerWorkspace != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onOpenLotOwnerWorkspace,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Không gian Chủ bãi'),
                ),
              ],
              if (onOpenOperatorWorkspace != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onOpenOperatorWorkspace,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: const Text('Không gian Operator'),
                ),
              ],
              if (onOpenLotOwnerApplication != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onOpenLotOwnerApplication,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Nộp hồ sơ Chủ bãi'),
                ),
              ],
              if (onOpenOperatorApplication != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onOpenOperatorApplication,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  label: const Text('Nộp hồ sơ Operator'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
