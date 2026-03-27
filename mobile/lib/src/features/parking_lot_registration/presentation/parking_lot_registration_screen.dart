import 'package:flutter/material.dart';

import '../data/parking_lot_service.dart';

class ParkingLotRegistrationScreen extends StatefulWidget {
  const ParkingLotRegistrationScreen({
    super.key,
    required this.parkingLotService,
    required this.onSignOut,
  });

  final ParkingLotService parkingLotService;
  final Future<void> Function() onSignOut;

  @override
  State<ParkingLotRegistrationScreen> createState() =>
      _ParkingLotRegistrationScreenState();
}

class _ParkingLotRegistrationScreenState
    extends State<ParkingLotRegistrationScreen> {
  late Future<List<ParkingLotRegistration>> _parkingLotsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _parkingLotsFuture = widget.parkingLotService.getMyParkingLots();
    });
  }

  Future<void> _openForm() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ParkingLotRegistrationForm(
        onSubmit:
            ({
              required name,
              required address,
              required latitude,
              required longitude,
              description,
              coverImage,
            }) async {
              await widget.parkingLotService.createParkingLot(
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude,
                description: description,
                coverImage: coverImage,
              );
            },
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi đăng ký bãi xe thành công.')),
      );
      _reload();
    }
  }

  Future<void> _openLeaseBootstrap(ParkingLotRegistration parkingLot) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LeaseBootstrapSheet(
        parkingLotService: widget.parkingLotService,
        parkingLot: parkingLot,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã kích hoạt quyền điều hành cho operator.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bãi xe của tôi'),
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
      body: FutureBuilder<List<ParkingLotRegistration>>(
        future: _parkingLotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ParkingLotErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final parkingLots = snapshot.data ?? const <ParkingLotRegistration>[];
          if (parkingLots.isEmpty) {
            return _ParkingLotEmptyState(onCreate: _openForm);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final parkingLot = parkingLots[index];
              return _ParkingLotCard(
                parkingLot: parkingLot,
                onBootstrapLease: parkingLot.isApproved
                    ? () => _openLeaseBootstrap(parkingLot)
                    : null,
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: parkingLots.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Đăng ký bãi xe'),
      ),
    );
  }
}

class _ParkingLotEmptyState extends StatelessWidget {
  const _ParkingLotEmptyState({required this.onCreate});

  final VoidCallback onCreate;

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
              'Chưa có bãi xe nào được khai báo',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Khai báo bãi xe mới để gửi lên hệ thống và chờ Admin xét duyệt.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Tạo hồ sơ bãi xe'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingLotCard extends StatelessWidget {
  const _ParkingLotCard({required this.parkingLot, this.onBootstrapLease});

  final ParkingLotRegistration parkingLot;
  final VoidCallback? onBootstrapLease;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, message) = switch (parkingLot.status) {
      'APPROVED' => (
        Colors.green,
        Icons.verified_outlined,
        'Đã được duyệt',
        'Bãi xe đã sẵn sàng cho các bước cấu hình và vận hành tiếp theo.',
      ),
      'REJECTED' => (
        Colors.red,
        Icons.cancel_outlined,
        'Đã bị từ chối',
        'Bạn có thể tạo hồ sơ mới sau khi rà soát lại thông tin bãi xe.',
      ),
      _ => (
        Colors.orange,
        Icons.hourglass_top,
        'Đang chờ duyệt',
        'Hồ sơ bãi xe đã được gửi và đang chờ Admin xem xét.',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    parkingLot.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(title)),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            _ParkingLotInfoRow(label: 'Địa chỉ', value: parkingLot.address),
            _ParkingLotInfoRow(
              label: 'Tọa độ',
              value:
                  '${parkingLot.latitude.toStringAsFixed(6)}, ${parkingLot.longitude.toStringAsFixed(6)}',
            ),
            if (parkingLot.description != null &&
                parkingLot.description!.isNotEmpty)
              _ParkingLotInfoRow(
                label: 'Mô tả',
                value: parkingLot.description!,
              ),
            if (parkingLot.coverImage != null &&
                parkingLot.coverImage!.isNotEmpty)
              _ParkingLotInfoRow(
                label: 'Ảnh đại diện',
                value: parkingLot.coverImage!,
              ),
            if (parkingLot.activeOperatorName != null)
              _ParkingLotInfoRow(
                label: 'Operator đang phụ trách',
                value: parkingLot.activeOperatorName!,
              ),
            if (parkingLot.activeLeaseStatus != null)
              _ParkingLotInfoRow(
                label: 'Lease',
                value: parkingLot.activeLeaseStatus!,
              ),
            if (parkingLot.isApproved && parkingLot.activeLeaseId == null) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onBootstrapLease,
                child: const Text('Gán operator thử nghiệm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaseBootstrapSheet extends StatefulWidget {
  const _LeaseBootstrapSheet({
    required this.parkingLotService,
    required this.parkingLot,
  });

  final ParkingLotService parkingLotService;
  final ParkingLotRegistration parkingLot;

  @override
  State<_LeaseBootstrapSheet> createState() => _LeaseBootstrapSheetState();
}

class _LeaseBootstrapSheetState extends State<_LeaseBootstrapSheet> {
  late Future<List<AvailableOperatorOption>> _operatorsFuture;
  AvailableOperatorOption? _selectedOperator;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _operatorsFuture = widget.parkingLotService.getAvailableOperators();
  }

  Future<void> _submit() async {
    final operator = _selectedOperator;
    if (operator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn operator.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.parkingLotService.bootstrapLease(
        parkingLotId: widget.parkingLot.id,
        managerUserId: operator.userId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ParkingLotException catch (error) {
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
        child: FutureBuilder<List<AvailableOperatorOption>>(
          future: _operatorsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 220,
                child: Center(child: Text(snapshot.error.toString())),
              );
            }

            final operators = snapshot.data ?? const <AvailableOperatorOption>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kích hoạt operator cho ${widget.parkingLot.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (operators.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Chưa có operator đã được duyệt để gán thử nghiệm.'),
                  )
                else
                  ...operators.map(
                    (operator) => RadioListTile<int>(
                      value: operator.userId,
                      groupValue: _selectedOperator?.userId,
                      title: Text(operator.name),
                      subtitle: Text(operator.email),
                      onChanged: _isSubmitting
                          ? null
                          : (_) {
                              setState(() {
                                _selectedOperator = operator;
                              });
                            },
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting || operators.isEmpty ? null : _submit,
                    child: Text(
                      _isSubmitting ? 'Đang kích hoạt...' : 'Kích hoạt điều hành',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ParkingLotInfoRow extends StatelessWidget {
  const _ParkingLotInfoRow({required this.label, required this.value});

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

class _ParkingLotErrorState extends StatelessWidget {
  const _ParkingLotErrorState({required this.message, required this.onRetry});

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

class _ParkingLotRegistrationForm extends StatefulWidget {
  const _ParkingLotRegistrationForm({required this.onSubmit});

  final Future<void> Function({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    String? coverImage,
  })
  onSubmit;

  @override
  State<_ParkingLotRegistrationForm> createState() =>
      _ParkingLotRegistrationFormState();
}

class _ParkingLotRegistrationFormState
    extends State<_ParkingLotRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverImageController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        description: _emptyToNull(_descriptionController.text),
        coverImage: _emptyToNull(_coverImageController.text),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ParkingLotException catch (error) {
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

  String? _validateLatitude(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Vĩ độ là bắt buộc';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < -90 || parsed > 90) {
      return 'Vĩ độ phải nằm trong khoảng -90 đến 90';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Kinh độ là bắt buộc';
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < -180 || parsed > 180) {
      return 'Kinh độ phải nằm trong khoảng -180 đến 180';
    }
    return null;
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
                  'Đăng ký bãi xe mới',
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
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Vĩ độ'),
                  validator: _validateLatitude,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Kinh độ'),
                  validator: _validateLongitude,
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
                        : const Icon(Icons.send_outlined),
                    label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi đăng ký'),
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
