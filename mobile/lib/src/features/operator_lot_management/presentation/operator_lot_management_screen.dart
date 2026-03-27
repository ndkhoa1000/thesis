import 'package:flutter/material.dart';

import '../data/operator_lot_management_service.dart';

class OperatorLotManagementScreen extends StatefulWidget {
  const OperatorLotManagementScreen({
    super.key,
    required this.lotManagementService,
    required this.onSignOut,
  });

  final OperatorLotManagementService lotManagementService;
  final Future<void> Function() onSignOut;

  @override
  State<OperatorLotManagementScreen> createState() =>
      _OperatorLotManagementScreenState();
}

class _OperatorLotManagementScreenState
    extends State<OperatorLotManagementScreen> {
  late Future<List<OperatorManagedParkingLot>> _managedLotsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _managedLotsFuture = widget.lotManagementService.getManagedParkingLots();
    });
  }

  Future<void> _openForm(OperatorManagedParkingLot lot) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperatorLotConfigurationForm(
        parkingLot: lot,
        onSubmit:
            ({
              required name,
              required address,
              required totalCapacity,
              required openingTime,
              required closingTime,
              required pricingMode,
              required priceAmount,
              description,
              coverImage,
            }) async {
              await widget.lotManagementService.updateManagedParkingLot(
                parkingLotId: lot.id,
                name: name,
                address: address,
                totalCapacity: totalCapacity,
                openingTime: openingTime,
                closingTime: closingTime,
                pricingMode: pricingMode,
                priceAmount: priceAmount,
                description: description,
                coverImage: coverImage,
              );
            },
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật cấu hình cho ${lot.name}.')),
      );
      _reload();
    }
  }

  Future<void> _openAttendantManagement(OperatorManagedParkingLot lot) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperatorAttendantManagementSheet(
        parkingLot: lot,
        lotManagementService: widget.lotManagementService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều hành bãi xe'),
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
      body: FutureBuilder<List<OperatorManagedParkingLot>>(
        future: _managedLotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _OperatorLotErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final lots = snapshot.data ?? const <OperatorManagedParkingLot>[];
          if (lots.isEmpty) {
            return const _OperatorLotEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final lot = lots[index];
              return _ManagedLotCard(
                parkingLot: lot,
                onConfigure: () => _openForm(lot),
                onManageAttendants: () => _openAttendantManagement(lot),
              );
            },
          );
        },
      ),
    );
  }
}

class _OperatorLotEmptyState extends StatelessWidget {
  const _OperatorLotEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_parking_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có bãi xe đang vận hành',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Operator chỉ có thể cấu hình các bãi xe đang có lease ACTIVE. Khi có bãi xe được bàn giao, danh sách sẽ xuất hiện ở đây.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagedLotCard extends StatelessWidget {
  const _ManagedLotCard({
    required this.parkingLot,
    required this.onConfigure,
    required this.onManageAttendants,
  });

  final OperatorManagedParkingLot parkingLot;
  final VoidCallback onConfigure;
  final VoidCallback onManageAttendants;

  @override
  Widget build(BuildContext context) {
    final totalCapacity = parkingLot.totalCapacity;
    final occupancyText = totalCapacity == null
        ? 'Chưa cấu hình sức chứa'
        : '${parkingLot.occupiedCount}/${parkingLot.totalCapacity} xe đang trong bãi';

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
                    parkingLot.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(parkingLot.statusLabel)),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Địa chỉ', value: parkingLot.address),
            _InfoRow(label: 'Công suất', value: occupancyText),
            _InfoRow(
              label: 'Giờ hoạt động',
              value: parkingLot.operatingHoursLabel,
            ),
            _InfoRow(label: 'Giá hiện hành', value: parkingLot.pricingLabel),
            _InfoRow(
              label: 'Chỗ còn nhận thêm',
              value: '${parkingLot.currentAvailable} xe',
            ),
            if ((parkingLot.description ?? '').isNotEmpty)
              _InfoRow(label: 'Mô tả', value: parkingLot.description!),
            if ((parkingLot.coverImage ?? '').isNotEmpty)
              _InfoRow(label: 'Ảnh đại diện', value: parkingLot.coverImage!),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onManageAttendants,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Nhân viên trực'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(
                    parkingLot.isConfigured
                        ? 'Cập nhật cấu hình'
                        : 'Thiết lập sức chứa',
                  ),
                ),
              ],
            ),
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

class _OperatorLotErrorState extends StatelessWidget {
  const _OperatorLotErrorState({required this.message, required this.onRetry});

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

class _OperatorAttendantManagementSheet extends StatefulWidget {
  const _OperatorAttendantManagementSheet({
    required this.parkingLot,
    required this.lotManagementService,
  });

  final OperatorManagedParkingLot parkingLot;
  final OperatorLotManagementService lotManagementService;

  @override
  State<_OperatorAttendantManagementSheet> createState() =>
      _OperatorAttendantManagementSheetState();
}

class _OperatorAttendantManagementSheetState
    extends State<_OperatorAttendantManagementSheet> {
  late Future<List<OperatorManagedAttendant>> _attendantsFuture;
  final Set<int> _pendingRemovals = <int>{};

  @override
  void initState() {
    super.initState();
    _reloadAttendants();
  }

  void _reloadAttendants() {
    setState(() {
      _attendantsFuture = widget.lotManagementService.getLotAttendants(
        parkingLotId: widget.parkingLot.id,
      );
    });
  }

  Future<bool> _createAttendant({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final attendant = await widget.lotManagementService.createLotAttendant(
        parkingLotId: widget.parkingLot.id,
        name: name,
        username: username,
        email: email,
        password: password,
        phone: phone,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo tài khoản attendant cho ${attendant.name}.'),
        ),
      );
      _reloadAttendants();
      return true;
    } on OperatorLotManagementException catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  Future<void> _openCreateAttendantForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AttendantAccountFormSheet(
        onSubmit:
            ({
              required name,
              required username,
              required email,
              required password,
              phone,
            }) async {
              final created = await _createAttendant(
                name: name,
                username: username,
                email: email,
                password: password,
                phone: phone,
              );
              if (created && sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
      ),
    );
  }

  Future<void> _removeAttendant(OperatorManagedAttendant attendant) async {
    setState(() {
      _pendingRemovals.add(attendant.id);
    });

    try {
      await widget.lotManagementService.removeLotAttendant(
        parkingLotId: widget.parkingLot.id,
        attendantId: attendant.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thu hồi tài khoản ${attendant.username}.')),
      );
      _reloadAttendants();
    } on OperatorLotManagementException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingRemovals.remove(attendant.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.95,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhân viên trực',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(widget.parkingLot.name),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openCreateAttendantForm,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tạo tài khoản Attendant'),
              ),
              Expanded(
                child: FutureBuilder<List<OperatorManagedAttendant>>(
                  future: _attendantsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _OperatorLotErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _reloadAttendants,
                      );
                    }

                    final attendants =
                        snapshot.data ?? const <OperatorManagedAttendant>[];
                    if (attendants.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có attendant nào cho bãi xe này.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 16),
                      itemCount: attendants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final attendant = attendants[index];
                        final isRemoving = _pendingRemovals.contains(
                          attendant.id,
                        );
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  attendant.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                _InfoRow(
                                  label: 'Tên đăng nhập',
                                  value: attendant.username,
                                ),
                                _InfoRow(
                                  label: 'Email',
                                  value: attendant.email,
                                ),
                                if ((attendant.phone ?? '').isNotEmpty)
                                  _InfoRow(
                                    label: 'Số điện thoại',
                                    value: attendant.phone!,
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: isRemoving
                                        ? null
                                        : () => _removeAttendant(attendant),
                                    icon: const Icon(
                                      Icons.person_remove_outlined,
                                    ),
                                    label: const Text('Thu hồi tài khoản'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendantAccountForm extends StatefulWidget {
  const _AttendantAccountForm({required this.onSubmit});

  final Future<void> Function({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  })
  onSubmit;

  @override
  State<_AttendantAccountForm> createState() => _AttendantAccountFormState();
}

class _AttendantAccountFormState extends State<_AttendantAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Họ và tên là bắt buộc';
              }
              if (trimmed.length < 2) {
                return 'Họ và tên phải có ít nhất 2 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Tên đăng nhập là bắt buộc';
              }
              if (!RegExp(r'^[a-z0-9]+$').hasMatch(trimmed)) {
                return 'Tên đăng nhập chỉ gồm chữ thường và số';
              }
              if (trimmed.length < 2) {
                return 'Tên đăng nhập phải có ít nhất 2 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Email là bắt buộc';
              }
              if (!trimmed.contains('@')) {
                return 'Email không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu tạm thời'),
            validator: (value) {
              final raw = value ?? '';
              if (raw.isEmpty) {
                return 'Mật khẩu là bắt buộc';
              }
              if (!_isStrongPassword(raw)) {
                return 'Mật khẩu cần chữ hoa, chữ thường, số và ký tự đặc biệt';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại (tuỳ chọn)',
            ),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return null;
              }
              if (trimmed.length < 8) {
                return 'Số điện thoại phải có ít nhất 8 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tạo tài khoản'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendantAccountFormSheet extends StatelessWidget {
  const _AttendantAccountFormSheet({required this.onSubmit});

  final Future<void> Function({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  })
  onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tạo tài khoản Attendant',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _AttendantAccountForm(onSubmit: onSubmit),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperatorLotConfigurationForm extends StatefulWidget {
  const _OperatorLotConfigurationForm({
    required this.parkingLot,
    required this.onSubmit,
  });

  final OperatorManagedParkingLot parkingLot;
  final Future<void> Function({
    required String name,
    required String address,
    required int totalCapacity,
    required String openingTime,
    required String closingTime,
    required String pricingMode,
    required double priceAmount,
    String? description,
    String? coverImage,
  })
  onSubmit;

  @override
  State<_OperatorLotConfigurationForm> createState() =>
      _OperatorLotConfigurationFormState();
}

class _OperatorLotConfigurationFormState
    extends State<_OperatorLotConfigurationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _capacityController;
  late final TextEditingController _openingTimeController;
  late final TextEditingController _closingTimeController;
  late final TextEditingController _priceAmountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverImageController;
  late String _pricingMode;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parkingLot.name);
    _addressController = TextEditingController(text: widget.parkingLot.address);
    _capacityController = TextEditingController(
      text: widget.parkingLot.totalCapacity?.toString() ?? '',
    );
    _openingTimeController = TextEditingController(
      text: widget.parkingLot.openingTime ?? '',
    );
    _closingTimeController = TextEditingController(
      text: widget.parkingLot.closingTime ?? '',
    );
    _priceAmountController = TextEditingController(
      text: widget.parkingLot.priceAmount?.toStringAsFixed(0) ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.parkingLot.description ?? '',
    );
    _coverImageController = TextEditingController(
      text: widget.parkingLot.coverImage ?? '',
    );
    _pricingMode = widget.parkingLot.pricingMode ?? 'HOURLY';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _priceAmountController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        totalCapacity: int.parse(_capacityController.text.trim()),
        openingTime: _openingTimeController.text.trim(),
        closingTime: _closingTimeController.text.trim(),
        pricingMode: _pricingMode,
        priceAmount: double.parse(_priceAmountController.text.trim()),
        description: _emptyToNull(_descriptionController.text),
        coverImage: _emptyToNull(_coverImageController.text),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on OperatorLotManagementException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isValidTime(String value) {
    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    return timePattern.hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cấu hình bãi xe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên bãi xe'),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Tên bãi xe là bắt buộc';
                    }
                    if (trimmed.length < 2) {
                      return 'Tên bãi xe phải có ít nhất 2 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Địa chỉ là bắt buộc';
                    }
                    if (trimmed.length < 5) {
                      return 'Địa chỉ phải có ít nhất 5 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tổng sức chứa tối đa',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Sức chứa là bắt buộc';
                    }
                    final parsed = int.tryParse(trimmed);
                    if (parsed == null || parsed <= 0) {
                      return 'Sức chứa phải là số nguyên dương';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _openingTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Giờ mở cửa (HH:mm)',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Giờ mở cửa là bắt buộc';
                    }
                    if (!_isValidTime(trimmed)) {
                      return 'Nhập giờ theo định dạng HH:mm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _closingTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Giờ đóng cửa (HH:mm)',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Giờ đóng cửa là bắt buộc';
                    }
                    if (!_isValidTime(trimmed)) {
                      return 'Nhập giờ theo định dạng HH:mm';
                    }
                    if (trimmed == _openingTimeController.text.trim()) {
                      return 'Giờ đóng cửa phải khác giờ mở cửa';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _pricingMode,
                  decoration: const InputDecoration(labelText: 'Kiểu tính giá'),
                  items: const [
                    DropdownMenuItem(value: 'HOURLY', child: Text('Theo giờ')),
                    DropdownMenuItem(
                      value: 'SESSION',
                      child: Text('Theo lượt'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _pricingMode = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Mức giá hiện hành (VND)',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Mức giá là bắt buộc';
                    }
                    final parsed = double.tryParse(trimmed);
                    if (parsed == null || parsed <= 0) {
                      return 'Mức giá phải là số dương';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coverImageController,
                  decoration: const InputDecoration(
                    labelText: 'Link ảnh đại diện',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSubmitting ? 'Đang lưu...' : 'Lưu cấu hình'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
