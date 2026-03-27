import 'package:flutter/material.dart';

import '../data/vehicle_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key, required this.vehicleService});

  final VehicleService vehicleService;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  late Future<List<Vehicle>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _vehiclesFuture = widget.vehicleService.listVehicles();
    });
  }

  Future<void> _addVehicle() async {
    final result = await showDialog<_AddVehicleResult>(
      context: context,
      builder: (_) => const _AddVehicleDialog(),
    );
    if (result == null) return;

    try {
      await widget.vehicleService.createVehicle(
        licensePlate: result.licensePlate,
        vehicleType: result.vehicleType,
      );
      _refresh();
    } on VehicleException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Xoá xe'),
            content: Text(
              'Bạn có chắc muốn xoá biển số "${vehicle.licensePlate}" không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Xoá'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await widget.vehicleService.deleteVehicle(vehicle.id);
      _refresh();
    } on VehicleException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý biển số xe'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Vehicle>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa có xe nào được đăng ký.\nNhấn + để thêm biển số xe.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final v = vehicles[index];
              final isCar = v.vehicleType.toUpperCase() == 'CAR';
              return Card(
                child: ListTile(
                  leading: Icon(
                    isCar ? Icons.directions_car : Icons.two_wheeler,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  title: Text(
                    v.licensePlate,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  subtitle: Text(isCar ? 'Ô tô' : 'Xe máy'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Xoá biển số',
                    onPressed: () => _deleteVehicle(v),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVehicle,
        tooltip: 'Thêm biển số',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Add-vehicle dialog ───────────────────────────────────────────────────────

class _AddVehicleResult {
  const _AddVehicleResult({
    required this.licensePlate,
    required this.vehicleType,
  });
  final String licensePlate;
  final String vehicleType;
}

class _AddVehicleDialog extends StatefulWidget {
  const _AddVehicleDialog();

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  String _vehicleType = 'MOTORBIKE';

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _AddVehicleResult(
        licensePlate: _plateController.text.trim(),
        vehicleType: _vehicleType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm biển số xe'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'Biển số xe',
                hintText: '59A-12345',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Vui lòng nhập biển số xe';
                if (val.length > 15) return 'Biển số tối đa 15 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Loại xe', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'MOTORBIKE',
                  label: Text('Xe máy'),
                  icon: Icon(Icons.two_wheeler),
                ),
                ButtonSegment(
                  value: 'CAR',
                  label: Text('Ô tô'),
                  icon: Icon(Icons.directions_car),
                ),
              ],
              selected: {_vehicleType},
              onSelectionChanged: (s) => setState(() => _vehicleType = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Thêm')),
      ],
    );
  }
}
