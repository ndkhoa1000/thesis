import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/driver_check_in_service.dart';
import '../../vehicles/data/vehicle_service.dart';

class DriverCheckInScreen extends StatefulWidget {
  const DriverCheckInScreen({
    super.key,
    required this.vehicleService,
    required this.driverCheckInService,
    required this.onManageVehicles,
  });

  final VehicleService vehicleService;
  final DriverCheckInService driverCheckInService;
  final Future<void> Function() onManageVehicles;

  @override
  State<DriverCheckInScreen> createState() => _DriverCheckInScreenState();
}

class _DriverCheckInScreenState extends State<DriverCheckInScreen> {
  bool _isLoadingVehicles = true;
  bool _isGeneratingQr = false;
  bool _isGeneratingCheckOutQr = false;
  String? _loadError;
  String? _qrError;
  List<Vehicle> _vehicles = const [];
  int? _selectedVehicleId;
  DriverCheckInQr? _currentQr;
  DriverActiveSession? _activeSession;
  DriverCheckOutQr? _currentCheckOutQr;

  @override
  void initState() {
    super.initState();
    _loadDriverParkingState();
  }

  Future<void> _loadDriverParkingState() async {
    setState(() {
      _isLoadingVehicles = true;
      _loadError = null;
      _qrError = null;
      _currentQr = null;
      _activeSession = null;
      _currentCheckOutQr = null;
    });

    try {
      final activeSession = await widget.driverCheckInService
          .getActiveSession();
      if (!mounted) return;

      if (activeSession != null) {
        setState(() {
          _activeSession = activeSession;
          _vehicles = const [];
          _selectedVehicleId = null;
          _isLoadingVehicles = false;
        });
        return;
      }

      final vehicles = await widget.vehicleService.listVehicles();
      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = vehicles.isEmpty ? null : vehicles.first.id;
        _isLoadingVehicles = false;
      });

      if (vehicles.isNotEmpty) {
        await _generateQr(vehicles.first.id);
      }
    } on DriverCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingVehicles = false;
        _loadError = error.message;
      });
    } on VehicleException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingVehicles = false;
        _loadError = error.message;
      });
    }
  }

  Future<void> _generateQr(int vehicleId) async {
    setState(() {
      _isGeneratingQr = true;
      _qrError = null;
    });

    try {
      final qr = await widget.driverCheckInService.createCheckInQr(
        vehicleId: vehicleId,
      );
      if (!mounted) return;
      setState(() {
        _currentQr = qr;
        _isGeneratingQr = false;
      });
    } on DriverCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _currentQr = null;
        _qrError = error.message;
        _isGeneratingQr = false;
      });
    }
  }

  Future<void> _openVehicleManagement() async {
    await widget.onManageVehicles();
    if (!mounted) return;
    await _loadDriverParkingState();
  }

  Future<void> _generateCheckOutQr() async {
    setState(() {
      _isGeneratingCheckOutQr = true;
      _qrError = null;
    });

    try {
      final qr = await widget.driverCheckInService.createCheckOutQr();
      if (!mounted) return;
      setState(() {
        _currentCheckOutQr = qr;
        _isGeneratingCheckOutQr = false;
      });
    } on DriverCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _currentCheckOutQr = null;
        _qrError = error.message;
        _isGeneratingCheckOutQr = false;
      });
    }
  }

  String _formatExpiry(DateTime expiresAt) {
    final local = expiresAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatMoney(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final reversedIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activeSession == null ? 'Mã check-in' : 'Phiên gửi xe'),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoadingVehicles) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadDriverParkingState,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeSession != null) {
      return RefreshIndicator(
        onRefresh: _loadDriverParkingState,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phiên gửi xe đang hoạt động',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _activeSession!.parkingLotName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeSession!.licensePlate,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Loại xe: ${_activeSession!.vehicleType == 'CAR' ? 'Ô tô' : 'Xe máy'}',
                    ),
                    const SizedBox(height: 4),
                    Text('Đã gửi ${_activeSession!.elapsedMinutes} phút'),
                    const SizedBox(height: 12),
                    Text(
                      'Tạm tính ${_formatMoney(_activeSession!.estimatedCost)} VNĐ',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_activeSession!.pricingMode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _activeSession!.pricingMode == 'SESSION'
                            ? 'Giá theo lượt'
                            : 'Giá theo giờ',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isGeneratingCheckOutQr ? null : _generateCheckOutQr,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: Text(
                _isGeneratingCheckOutQr
                    ? 'Đang tạo mã...'
                    : 'Hiện mã check-out',
              ),
            ),
            const SizedBox(height: 16),
            if (_qrError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _qrError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            if (_currentCheckOutQr != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _currentCheckOutQr!.licensePlate,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      QrImageView(
                        data: _currentCheckOutQr!.token,
                        version: QrVersions.auto,
                        size: 240,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mã có hiệu lực đến ${_formatExpiry(_currentCheckOutQr!.expiresAt)}.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đưa mã này cho attendant quét khi bạn rời bãi.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.no_crash_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bạn cần đăng ký ít nhất một xe trước khi tạo mã check-in.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openVehicleManagement,
                  icon: const Icon(Icons.directions_car_outlined),
                  label: const Text('Quản lý xe của tôi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDriverParkingState,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            key: const ValueKey('driver-check-in-vehicle-dropdown'),
            initialValue: _selectedVehicleId,
            decoration: const InputDecoration(
              labelText: 'Chọn xe',
              border: OutlineInputBorder(),
            ),
            items: _vehicles
                .map(
                  (vehicle) => DropdownMenuItem<int>(
                    value: vehicle.id,
                    child: Text(vehicle.licensePlate),
                  ),
                )
                .toList(growable: false),
            onChanged: _isGeneratingQr
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedVehicleId = value;
                    });
                    _generateQr(value);
                  },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isGeneratingQr || _selectedVehicleId == null
                ? null
                : () => _generateQr(_selectedVehicleId!),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(_isGeneratingQr ? 'Đang tạo mã...' : 'Tạo lại mã QR'),
          ),
          const SizedBox(height: 16),
          if (_qrError != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _qrError!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_currentQr != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _currentQr!.vehicle.licensePlate,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentQr!.vehicle.vehicleType == 'CAR'
                          ? 'Ô tô'
                          : 'Xe máy',
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: _currentQr!.token,
                      version: QrVersions.auto,
                      size: 240,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mã có hiệu lực đến ${_formatExpiry(_currentQr!.expiresAt)}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đưa mã này cho attendant quét khi bạn đến bãi.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
