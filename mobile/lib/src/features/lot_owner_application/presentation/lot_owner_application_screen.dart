import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../data/lot_owner_application_service.dart';

class LotOwnerApplicationScreen extends StatefulWidget {
  const LotOwnerApplicationScreen({
    super.key,
    required this.session,
    required this.authService,
    required this.applicationService,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final AuthService authService;
  final LotOwnerApplicationService applicationService;
  final void Function(AuthSession session) onSessionUpdated;

  @override
  State<LotOwnerApplicationScreen> createState() =>
      _LotOwnerApplicationScreenState();
}

class _LotOwnerApplicationScreenState extends State<LotOwnerApplicationScreen> {
  late Future<LotOwnerApplication?> _applicationFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _applicationFuture = _loadApplication();
    });
  }

  Future<LotOwnerApplication?> _loadApplication() async {
    final application = await widget.applicationService.getMyApplication();
    if (application != null && application.isApproved) {
      final refreshedSession = await widget.authService.refreshSession();
      if (refreshedSession != null && mounted) {
        widget.onSessionUpdated(refreshedSession);
      }
    }
    return application;
  }

  Future<void> _openForm([LotOwnerApplication? existing]) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LotOwnerApplicationForm(
        existing: existing,
        onSubmit: ({
          required fullName,
          required phoneNumber,
          required businessLicense,
          required documentReference,
          notes,
        }) async {
          await widget.applicationService.submitApplication(
            fullName: fullName,
            phoneNumber: phoneNumber,
            businessLicense: businessLicense,
            documentReference: documentReference,
            notes: notes,
          );
        },
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi hồ sơ chủ bãi thành công.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Chủ bãi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới trạng thái',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<LotOwnerApplication?>(
        future: _applicationFuture,
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

          final application = snapshot.data;
          if (application == null) {
            return _EmptyState(onApply: _openForm);
          }

          return _ApplicationStatusView(
            session: widget.session,
            application: application,
            onResubmit: application.isRejected ? () => _openForm(application) : null,
          );
        },
      ),
      floatingActionButton: FutureBuilder<LotOwnerApplication?>(
        future: _applicationFuture,
        builder: (context, snapshot) {
          final application = snapshot.data;
          if (application == null || application.isRejected) {
            return FloatingActionButton.extended(
              onPressed: () => _openForm(application),
              icon: const Icon(Icons.assignment_outlined),
              label: Text(application == null ? 'Nộp hồ sơ' : 'Gửi lại hồ sơ'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onApply});

  final Future<void> Function([LotOwnerApplication? existing]) onApply;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nâng cấp tài khoản thành Chủ bãi',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gửi thông tin xác minh để được duyệt capability Chủ bãi trên chính tài khoản hiện tại của bạn.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Nộp hồ sơ Chủ bãi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationStatusView extends StatelessWidget {
  const _ApplicationStatusView({
    required this.session,
    required this.application,
    this.onResubmit,
  });

  final AuthSession session;
  final LotOwnerApplication application;
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, message) = switch (application.status) {
      'APPROVED' => (
        Colors.green,
        Icons.verified_outlined,
        'Đã được duyệt',
        'Tài khoản của bạn đã được cấp capability Chủ bãi.',
      ),
      'REJECTED' => (
        Colors.red,
        Icons.cancel_outlined,
        'Hồ sơ bị từ chối',
        'Bạn có thể chỉnh sửa và gửi lại hồ sơ với thông tin đầy đủ hơn.',
      ),
      _ => (
        Colors.orange,
        Icons.hourglass_top,
        'Đang chờ duyệt',
        'Hồ sơ của bạn đã được gửi và đang chờ Admin xem xét.',
      ),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(message),
                if (application.isApproved && !session.capabilities['lot_owner']!) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Ứng dụng sẽ làm mới phiên để cập nhật quyền khi trạng thái duyệt thay đổi.',
                  ),
                ],
                if (application.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Lý do từ chối: ${application.rejectionReason}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông tin hồ sơ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _InfoRow(label: 'Họ tên', value: application.fullName),
                _InfoRow(label: 'Số điện thoại', value: application.phoneNumber),
                _InfoRow(label: 'Giấy phép/sở hữu', value: application.businessLicense),
                _InfoRow(label: 'Tài liệu xác minh', value: application.documentReference),
                if (application.notes != null) _InfoRow(label: 'Ghi chú', value: application.notes!),
              ],
            ),
          ),
        ),
        if (onResubmit != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onResubmit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Chỉnh sửa và gửi lại'),
          ),
        ],
      ],
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
          const SizedBox(height: 2),
          Text(value),
        ],
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LotOwnerApplicationForm extends StatefulWidget {
  const _LotOwnerApplicationForm({
    required this.onSubmit,
    this.existing,
  });

  final LotOwnerApplication? existing;
  final Future<void> Function({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  }) onSubmit;

  @override
  State<_LotOwnerApplicationForm> createState() => _LotOwnerApplicationFormState();
}

class _LotOwnerApplicationFormState extends State<_LotOwnerApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  late final TextEditingController _documentController;
  late final TextEditingController _notesController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.existing?.fullName ?? '');
    _phoneController = TextEditingController(text: widget.existing?.phoneNumber ?? '');
    _licenseController = TextEditingController(text: widget.existing?.businessLicense ?? '');
    _documentController = TextEditingController(text: widget.existing?.documentReference ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _documentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onSubmit(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        businessLicense: _licenseController.text.trim(),
        documentReference: _documentController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on LotOwnerApplicationException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Nộp hồ sơ Chủ bãi' : 'Cập nhật hồ sơ Chủ bãi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: 'Giấy phép kinh doanh / sở hữu',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _documentController,
                decoration: const InputDecoration(
                  labelText: 'Link tài liệu xác minh',
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.existing == null ? 'Gửi hồ sơ' : 'Gửi lại hồ sơ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Trường này là bắt buộc';
    }
    return null;
  }
}