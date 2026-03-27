import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../data/operator_application_service.dart';

class OperatorApplicationScreen extends StatefulWidget {
  const OperatorApplicationScreen({
    super.key,
    required this.session,
    required this.authService,
    required this.applicationService,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final AuthService authService;
  final OperatorApplicationService applicationService;
  final void Function(AuthSession session) onSessionUpdated;

  @override
  State<OperatorApplicationScreen> createState() =>
      _OperatorApplicationScreenState();
}

class _OperatorApplicationScreenState extends State<OperatorApplicationScreen> {
  late Future<OperatorApplication?> _applicationFuture;

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

  Future<OperatorApplication?> _loadApplication() async {
    final application = await widget.applicationService.getMyApplication();
    if (application != null && application.isApproved) {
      final refreshedSession = await widget.authService.refreshSession();
      if (refreshedSession != null && mounted) {
        widget.onSessionUpdated(refreshedSession);
      }
    }
    return application;
  }

  Future<void> _openForm([OperatorApplication? existing]) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperatorApplicationForm(
        existing: existing,
        onSubmit:
            ({
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
        const SnackBar(content: Text('Đã gửi hồ sơ operator thành công.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Operator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới trạng thái',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<OperatorApplication?>(
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
            onResubmit: application.isRejected
                ? () => _openForm(application)
                : null,
          );
        },
      ),
      floatingActionButton: FutureBuilder<OperatorApplication?>(
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

  final Future<void> Function([OperatorApplication? existing]) onApply;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_suggest_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nâng cấp tài khoản thành Operator',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gửi thông tin doanh nghiệp để được duyệt capability Operator trên chính tài khoản hiện tại của bạn.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Nộp hồ sơ Operator'),
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
  final OperatorApplication application;
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, message) = switch (application.status) {
      'APPROVED' => (
        Colors.green,
        Icons.verified_outlined,
        'Đã được duyệt',
        'Tài khoản của bạn đã được cấp capability Operator.',
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
                if (application.isApproved &&
                    !session.capabilities['operator']!) ...[
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
                Text(
                  'Thông tin hồ sơ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Họ tên', value: application.fullName),
                _InfoRow(
                  label: 'Số điện thoại',
                  value: application.phoneNumber,
                ),
                _InfoRow(
                  label: 'Giấy phép kinh doanh',
                  value: application.businessLicense,
                ),
                _InfoRow(
                  label: 'Tài liệu xác minh',
                  value: application.documentReference,
                ),
                if (application.notes != null)
                  _InfoRow(label: 'Ghi chú', value: application.notes!),
              ],
            ),
          ),
        ),
        if (onResubmit != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onResubmit,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật và gửi lại hồ sơ'),
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
      padding: const EdgeInsets.only(bottom: 12),
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

class _OperatorApplicationForm extends StatefulWidget {
  const _OperatorApplicationForm({required this.onSubmit, this.existing});

  final OperatorApplication? existing;
  final Future<void> Function({
    required String fullName,
    required String phoneNumber,
    required String businessLicense,
    required String documentReference,
    String? notes,
  })
  onSubmit;

  @override
  State<_OperatorApplicationForm> createState() =>
      _OperatorApplicationFormState();
}

class _OperatorApplicationFormState extends State<_OperatorApplicationForm> {
  static const int _minFullNameLength = 2;
  static const int _minPhoneLength = 8;
  static const int _minBusinessLicenseLength = 4;
  static const int _minDocumentReferenceLength = 4;

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
    _fullNameController = TextEditingController(
      text: widget.existing?.fullName ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.existing?.phoneNumber ?? '',
    );
    _licenseController = TextEditingController(
      text: widget.existing?.businessLicense ?? '',
    );
    _documentController = TextEditingController(
      text: widget.existing?.documentReference ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
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
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
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
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'Nộp hồ sơ Operator'
                    : 'Cập nhật hồ sơ Operator',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (value) => _minLengthValidator(
                  value,
                  minLength: _minFullNameLength,
                  emptyMessage: 'Trường này là bắt buộc',
                  shortMessage: 'Họ và tên phải có ít nhất 2 ký tự',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (value) => _minLengthValidator(
                  value,
                  minLength: _minPhoneLength,
                  emptyMessage: 'Trường này là bắt buộc',
                  shortMessage: 'Số điện thoại phải có ít nhất 8 ký tự',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Giấy phép kinh doanh / mã số thuế',
                ),
                validator: (value) => _minLengthValidator(
                  value,
                  minLength: _minBusinessLicenseLength,
                  emptyMessage: 'Trường này là bắt buộc',
                  shortMessage: 'Giấy phép kinh doanh phải có ít nhất 4 ký tự',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _documentController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Link tài liệu xác minh',
                ),
                validator: (value) => _minLengthValidator(
                  value,
                  minLength: _minDocumentReferenceLength,
                  emptyMessage: 'Trường này là bắt buộc',
                  shortMessage: 'Link tài liệu phải có ít nhất 4 ký tự',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                ),
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
                    : Text(
                        widget.existing == null ? 'Gửi hồ sơ' : 'Gửi lại hồ sơ',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _minLengthValidator(
    String? value, {
    required int minLength,
    required String emptyMessage,
    required String shortMessage,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return emptyMessage;
    }
    if (normalized.length < minLength) {
      return shortMessage;
    }
    return null;
  }
}
