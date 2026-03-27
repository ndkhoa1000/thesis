import 'package:flutter/material.dart';

import '../data/admin_approvals_service.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({
    super.key,
    required this.approvalsService,
    required this.onSignOut,
  });

  final AdminApprovalsService approvalsService;
  final Future<void> Function() onSignOut;

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  late Future<AdminApprovalsDashboard> _dashboardFuture;
  final Set<String> _pendingActions = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _dashboardFuture = widget.approvalsService.loadDashboard();
    });
  }

  Future<void> _runPendingAction(
    String actionKey,
    Future<void> Function() action,
  ) async {
    if (_pendingActions.contains(actionKey)) {
      return;
    }

    setState(() {
      _pendingActions.add(actionKey);
    });

    try {
      await action();
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingActions.remove(actionKey);
      });
    }
  }

  String _approvalActionKey(AdminApprovalItem item) =>
      'approval:${item.type.name}:${item.id}';

  String _userActionKey(AdminManagedUser user) => 'user:${user.id}';

  String _parkingLotActionKey(AdminManagedParkingLot lot) => 'lot:${lot.id}';

  Future<void> _approve(AdminApprovalItem item) async {
    await _runPendingAction(_approvalActionKey(item), () async {
      try {
        await widget.approvalsService.approve(
          type: item.type,
          applicationId: item.id,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã duyệt ${item.typeLabel.toLowerCase()}.')),
        );
        _reload();
      } on AdminApprovalsException catch (error) {
        _showError(error.message);
      }
    });
  }

  Future<void> _reject(AdminApprovalItem item) async {
    final rejectionReason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectionReasonDialog(),
    );
    if (rejectionReason == null || rejectionReason.trim().isEmpty) {
      return;
    }

    await _runPendingAction(_approvalActionKey(item), () async {
      try {
        await widget.approvalsService.reject(
          type: item.type,
          applicationId: item.id,
          rejectionReason: rejectionReason.trim(),
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã từ chối ${item.typeLabel.toLowerCase()}.'),
          ),
        );
        _reload();
      } on AdminApprovalsException catch (error) {
        _showError(error.message);
      }
    });
  }

  Future<void> _toggleUserActivation(AdminManagedUser user) async {
    final nextIsActive = !user.isActive;
    await _runPendingAction(_userActionKey(user), () async {
      try {
        await widget.approvalsService.updateUserActivation(
          userId: user.id,
          isActive: nextIsActive,
        );
        if (!mounted) {
          return;
        }
        final message = nextIsActive
            ? 'Đã kích hoạt tài khoản ${user.name}.'
            : 'Đã vô hiệu hóa tài khoản ${user.name}.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _reload();
      } on AdminApprovalsException catch (error) {
        _showError(error.message);
      }
    });
  }

  Future<void> _toggleParkingLotStatus(AdminManagedParkingLot lot) async {
    final nextStatus = lot.canSuspend ? 'CLOSED' : 'APPROVED';
    await _runPendingAction(_parkingLotActionKey(lot), () async {
      try {
        await widget.approvalsService.updateParkingLotStatus(
          parkingLotId: lot.id,
          status: nextStatus,
        );
        if (!mounted) {
          return;
        }
        final message = nextStatus == 'CLOSED'
            ? 'Đã tạm dừng bãi xe ${lot.name}.'
            : 'Đã mở lại bãi xe ${lot.name}.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _reload();
      } on AdminApprovalsException catch (error) {
        _showError(error.message);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Điều phối hệ thống'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Chủ bãi'),
              Tab(text: 'Operator'),
              Tab(text: 'Bãi xe'),
              Tab(text: 'Người dùng'),
              Tab(text: 'Vận hành bãi'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới danh sách',
              onPressed: _reload,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
              onPressed: widget.onSignOut,
            ),
          ],
        ),
        body: FutureBuilder<AdminApprovalsDashboard>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }

            final dashboard = snapshot.data;
            if (dashboard == null) {
              return _ErrorState(
                message: 'Không tải được danh sách phê duyệt.',
                onRetry: _reload,
              );
            }

            return TabBarView(
              children: [
                _ApprovalsList(
                  items: dashboard.lotOwnerApplications,
                  pendingActionKeys: _pendingActions,
                  emptyTitle: 'Không có hồ sơ Chủ bãi chờ duyệt',
                  emptyMessage:
                      'Danh sách này sẽ hiển thị các hồ sơ công khai đang chờ Admin xét duyệt.',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _ApprovalsList(
                  items: dashboard.operatorApplications,
                  pendingActionKeys: _pendingActions,
                  emptyTitle: 'Không có hồ sơ Operator chờ duyệt',
                  emptyMessage:
                      'Danh sách này sẽ hiển thị các hồ sơ Operator đang chờ Admin xét duyệt.',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _ApprovalsList(
                  items: dashboard.parkingLotApplications,
                  pendingActionKeys: _pendingActions,
                  emptyTitle: 'Không có đăng ký bãi xe chờ duyệt',
                  emptyMessage:
                      'Các bãi xe do Lot Owner khai báo sẽ xuất hiện tại đây để Admin xét duyệt.',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _ManagedUsersList(
                  users: dashboard.managedUsers,
                  pendingActionKeys: _pendingActions,
                  onToggleActivation: _toggleUserActivation,
                ),
                _ManagedParkingLotsList(
                  lots: dashboard.managedParkingLots,
                  pendingActionKeys: _pendingActions,
                  onToggleStatus: _toggleParkingLotStatus,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalsList extends StatelessWidget {
  const _ApprovalsList({
    required this.items,
    required this.pendingActionKeys,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onApprove,
    required this.onReject,
  });

  final List<AdminApprovalItem> items;
  final Set<String> pendingActionKeys;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function(AdminApprovalItem item) onApprove;
  final Future<void> Function(AdminApprovalItem item) onReject;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(title: emptyTitle, message: emptyMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = items[index];
        final isPending = pendingActionKeys.contains(
          'approval:${item.type.name}:${item.id}',
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(item.typeLabel)),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Người nộp', value: item.applicantName),
                _InfoRow(label: 'Số điện thoại', value: item.phoneNumber),
                if (item.type == ApprovalSubjectType.parkingLot) ...[
                  _InfoRow(
                    label: 'Tên bãi xe',
                    value: item.parkingLotName ?? 'Chưa có',
                  ),
                  _InfoRow(
                    label: 'Địa chỉ',
                    value: item.parkingLotAddress ?? item.documentReference,
                  ),
                  _InfoRow(
                    label: 'Giấy phép chủ bãi',
                    value: item.businessLicense,
                  ),
                  if (item.coverImage != null && item.coverImage!.isNotEmpty)
                    _InfoRow(label: 'Ảnh đại diện', value: item.coverImage!),
                ] else ...[
                  _InfoRow(
                    label: 'Giấy phép / mã số',
                    value: item.businessLicense,
                  ),
                  _InfoRow(
                    label: 'Tài liệu xác minh',
                    value: item.documentReference,
                  ),
                ],
                if (item.notes != null && item.notes!.isNotEmpty)
                  _InfoRow(
                    label: item.type == ApprovalSubjectType.parkingLot
                        ? 'Mô tả'
                        : 'Ghi chú',
                    value: item.notes!,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isPending ? null : () => onReject(item),
                        icon: const Icon(Icons.close),
                        label: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isPending ? null : () => onApprove(item),
                        icon: const Icon(Icons.check),
                        label: const Text('Duyệt'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}

class _ManagedUsersList extends StatelessWidget {
  const _ManagedUsersList({
    required this.users,
    required this.pendingActionKeys,
    required this.onToggleActivation,
  });

  final List<AdminManagedUser> users;
  final Set<String> pendingActionKeys;
  final Future<void> Function(AdminManagedUser user) onToggleActivation;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _EmptyState(
        title: 'Không có tài khoản để quản lý',
        message:
            'Danh sách tài khoản hệ thống sẽ xuất hiện tại đây để Admin kích hoạt hoặc vô hiệu hóa.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final isPending = pendingActionKeys.contains('user:${user.id}');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      label: Text(user.isActive ? 'Đang hoạt động' : 'Đã khóa'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Username', value: user.username),
                _InfoRow(label: 'Email', value: user.email),
                if ((user.phone ?? '').isNotEmpty)
                  _InfoRow(label: 'Số điện thoại', value: user.phone!),
                _InfoRow(label: 'Vai trò', value: user.roleLabel),
                _InfoRow(
                  label: 'Phân quyền hệ thống',
                  value: user.isSuperuser ? 'Superuser' : 'Tài khoản chuẩn',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: isPending
                        ? null
                        : () => onToggleActivation(user),
                    icon: Icon(
                      user.isActive ? Icons.block : Icons.check_circle,
                    ),
                    label: Text(
                      user.isActive ? 'Vô hiệu hóa' : 'Kích hoạt lại',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManagedParkingLotsList extends StatelessWidget {
  const _ManagedParkingLotsList({
    required this.lots,
    required this.pendingActionKeys,
    required this.onToggleStatus,
  });

  final List<AdminManagedParkingLot> lots;
  final Set<String> pendingActionKeys;
  final Future<void> Function(AdminManagedParkingLot lot) onToggleStatus;

  @override
  Widget build(BuildContext context) {
    if (lots.isEmpty) {
      return const _EmptyState(
        title: 'Không có bãi xe để quản lý',
        message:
            'Các bãi xe đã duyệt hoặc đang tạm dừng sẽ xuất hiện tại đây để Admin điều phối vận hành.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lot = lots[index];
        final canToggle =
            (lot.canSuspend || lot.canReopen) &&
            !pendingActionKeys.contains('lot:${lot.id}');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lot.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(lot.statusLabel)),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Địa chỉ', value: lot.address),
                if ((lot.ownerName ?? '').isNotEmpty)
                  _InfoRow(label: 'Chủ bãi', value: lot.ownerName!),
                if ((lot.ownerPhone ?? '').isNotEmpty)
                  _InfoRow(label: 'Liên hệ', value: lot.ownerPhone!),
                _InfoRow(
                  label: 'Chỗ trống hiện tại',
                  value: lot.currentAvailable.toString(),
                ),
                if ((lot.description ?? '').isNotEmpty)
                  _InfoRow(label: 'Mô tả', value: lot.description!),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: canToggle ? () => onToggleStatus(lot) : null,
                    icon: Icon(
                      lot.canSuspend ? Icons.pause_circle : Icons.play_circle,
                    ),
                    label: Text(
                      lot.canSuspend
                          ? 'Tạm dừng bãi xe'
                          : lot.canReopen
                          ? 'Mở lại bãi xe'
                          : 'Không khả dụng',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lý do từ chối'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Nhập lý do từ chối'),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Lý do từ chối là bắt buộc';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Xác nhận')),
      ],
    );
  }
}
