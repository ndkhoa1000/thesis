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
              description,
              coverImage,
            }) async {
              await widget.lotManagementService.updateManagedParkingLot(
                parkingLotId: lot.id,
                name: name,
                address: address,
                totalCapacity: totalCapacity,
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
  const _ManagedLotCard({required this.parkingLot, required this.onConfigure});

  final OperatorManagedParkingLot parkingLot;
  final VoidCallback onConfigure;

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
              label: 'Chỗ còn nhận thêm',
              value: '${parkingLot.currentAvailable} xe',
            ),
            if ((parkingLot.description ?? '').isNotEmpty)
              _InfoRow(label: 'Mô tả', value: parkingLot.description!),
            if ((parkingLot.coverImage ?? '').isNotEmpty)
              _InfoRow(label: 'Ảnh đại diện', value: parkingLot.coverImage!),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onConfigure,
                icon: const Icon(Icons.settings_outlined),
                label: Text(
                  parkingLot.isConfigured
                      ? 'Cập nhật cấu hình'
                      : 'Thiết lập sức chứa',
                ),
              ),
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
  late final TextEditingController _descriptionController;
  late final TextEditingController _coverImageController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parkingLot.name);
    _addressController = TextEditingController(text: widget.parkingLot.address);
    _capacityController = TextEditingController(
      text: widget.parkingLot.totalCapacity?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.parkingLot.description ?? '',
    );
    _coverImageController = TextEditingController(
      text: widget.parkingLot.coverImage ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
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
