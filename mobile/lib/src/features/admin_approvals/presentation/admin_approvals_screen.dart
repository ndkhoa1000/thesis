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

  Future<void> _approve(AdminApprovalItem item) async {
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
  }

  Future<void> _reject(AdminApprovalItem item) async {
    final rejectionReason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectionReasonDialog(),
    );
    if (rejectionReason == null || rejectionReason.trim().isEmpty) {
      return;
    }

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
        SnackBar(content: Text('Đã từ chối ${item.typeLabel.toLowerCase()}.')),
      );
      _reload();
    } on AdminApprovalsException catch (error) {
      _showError(error.message);
    }
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Phê duyệt hệ thống'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chủ bãi'),
              Tab(text: 'Operator'),
              Tab(text: 'Bãi xe'),
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
                  emptyTitle: 'Không có hồ sơ Chủ bãi chờ duyệt',
                  emptyMessage:
                      'Danh sách này sẽ hiển thị các hồ sơ công khai đang chờ Admin xét duyệt.',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _ApprovalsList(
                  items: dashboard.operatorApplications,
                  emptyTitle: 'Không có hồ sơ Operator chờ duyệt',
                  emptyMessage:
                      'Danh sách này sẽ hiển thị các hồ sơ Operator đang chờ Admin xét duyệt.',
                  onApprove: _approve,
                  onReject: _reject,
                ),
                _ApprovalsList(
                  items: dashboard.parkingLotApplications,
                  emptyTitle: 'Không có đăng ký bãi xe chờ duyệt',
                  emptyMessage:
                      'Các bãi xe do Lot Owner khai báo sẽ xuất hiện tại đây để Admin xét duyệt.',
                  onApprove: _approve,
                  onReject: _reject,
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
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onApprove,
    required this.onReject,
  });

  final List<AdminApprovalItem> items;
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
                        onPressed: () => onReject(item),
                        icon: const Icon(Icons.close),
                        label: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onApprove(item),
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
