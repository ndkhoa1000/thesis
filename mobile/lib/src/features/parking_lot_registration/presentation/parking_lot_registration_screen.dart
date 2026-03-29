import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../owner_revenue_dashboard/data/owner_revenue_dashboard_service.dart';
import '../../owner_revenue_dashboard/presentation/owner_revenue_dashboard_sheet.dart';
import '../data/parking_lot_service.dart';

class ParkingLotRegistrationScreen extends StatefulWidget {
  const ParkingLotRegistrationScreen({
    super.key,
    required this.parkingLotService,
    required this.ownerRevenueDashboardService,
    required this.onSignOut,
  });

  final ParkingLotService parkingLotService;
  final OwnerRevenueDashboardService ownerRevenueDashboardService;
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
      builder: (context) => _LeaseContractSheet(
        parkingLotService: widget.parkingLotService,
        parkingLot: parkingLot,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo hợp đồng thuê và gửi cho operator.'),
        ),
      );
      _reload();
    }
  }

  Future<void> _openRevenueDashboard(ParkingLotRegistration parkingLot) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => OwnerRevenueDashboardSheet(
        parkingLot: parkingLot,
        ownerRevenueDashboardService: widget.ownerRevenueDashboardService,
      ),
    );
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
                onViewRevenue: parkingLot.isApproved
                    ? () => _openRevenueDashboard(parkingLot)
                    : null,
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
  const _ParkingLotCard({
    required this.parkingLot,
    this.onBootstrapLease,
    this.onViewRevenue,
  });

  final ParkingLotRegistration parkingLot;
  final VoidCallback? onBootstrapLease;
  final VoidCallback? onViewRevenue;

  @override
  Widget build(BuildContext context) {
    final canCreateLeaseContract =
        parkingLot.isApproved &&
        (parkingLot.activeLeaseStatus == null ||
            !{'PENDING', 'ACTIVE'}.contains(parkingLot.activeLeaseStatus));

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
            if (canCreateLeaseContract || onViewRevenue != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canCreateLeaseContract)
                    FilledButton(
                      onPressed: onBootstrapLease,
                      child: const Text('Tạo hợp đồng thuê'),
                    ),
                  if (onViewRevenue != null)
                    OutlinedButton.icon(
                      onPressed: onViewRevenue,
                      icon: const Icon(Icons.query_stats_outlined),
                      label: const Text('Xem doanh thu'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaseContractSheet extends StatefulWidget {
  const _LeaseContractSheet({
    required this.parkingLotService,
    required this.parkingLot,
  });

  final ParkingLotService parkingLotService;
  final ParkingLotRegistration parkingLot;

  @override
  State<_LeaseContractSheet> createState() => _LeaseContractSheetState();
}

class _LeaseContractSheetState extends State<_LeaseContractSheet> {
  late Future<List<AvailableOperatorOption>> _operatorsFuture;
  AvailableOperatorOption? _selectedOperator;
  final _monthlyFeeController = TextEditingController(text: '15000000');
  final _revenueShareController = TextEditingController(text: '35');
  final _termMonthsController = TextEditingController(text: '6');
  final _additionalTermsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _operatorsFuture = widget.parkingLotService.getAvailableOperators();
  }

  @override
  void dispose() {
    _monthlyFeeController.dispose();
    _revenueShareController.dispose();
    _termMonthsController.dispose();
    _additionalTermsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final operator = _selectedOperator;
    if (operator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn operator.')));
      return;
    }

    final monthlyFee = double.tryParse(_monthlyFeeController.text.trim());
    final revenueShare = double.tryParse(_revenueShareController.text.trim());
    final termMonths = int.tryParse(_termMonthsController.text.trim());
    if (monthlyFee == null || monthlyFee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phí thuê hàng tháng không hợp lệ.')),
      );
      return;
    }
    if (revenueShare == null || revenueShare <= 0 || revenueShare > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tỷ lệ chia doanh thu phải từ 0 đến 100.'),
        ),
      );
      return;
    }
    if (termMonths == null || termMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời hạn hợp đồng phải lớn hơn 0 tháng.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.parkingLotService.createLeaseContract(
        parkingLotId: widget.parkingLot.id,
        managerUserId: operator.userId,
        monthlyFee: monthlyFee,
        revenueSharePercentage: revenueShare,
        termMonths: termMonths,
        additionalTerms: _emptyToNull(_additionalTermsController.text),
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

            final operators =
                snapshot.data ?? const <AvailableOperatorOption>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tạo hợp đồng thuê cho ${widget.parkingLot.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (operators.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Chưa có operator đã được duyệt để gán thử nghiệm.',
                    ),
                  )
                else
                  Column(
                    children: [
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
                      TextField(
                        controller: _monthlyFeeController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Phí thuê hàng tháng (VND)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _revenueShareController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tỷ lệ doanh thu cho chủ bãi (%)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _termMonthsController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thời hạn hợp đồng (tháng)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _additionalTermsController,
                        enabled: !_isSubmitting,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Điều khoản bổ sung (tuỳ chọn)',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting || operators.isEmpty
                        ? null
                        : _submit,
                    child: Text(
                      _isSubmitting
                          ? 'Đang tạo hợp đồng...'
                          : 'Gửi hợp đồng cho operator',
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

class _PickedLotLocation {
  const _PickedLotLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
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
  final _descriptionController = TextEditingController();
  final _coverImageController = TextEditingController();

  _PickedLotLocation? _selectedLocation;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    final selected = await showModalBottomSheet<_PickedLotLocation>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ParkingLotLocationPicker(initialLocation: _selectedLocation),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedLocation = selected;
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final location = _selectedLocation;
    if (location == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
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
                const SizedBox(height: 16),
                Text(
                  'Vị trí bãi xe',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLocation == null
                            ? 'Chưa chọn vị trí. Hãy ghim bãi xe trên bản đồ để hệ thống tự lấy kinh độ và vĩ độ.'
                            : 'Đã chọn tọa độ: ${_selectedLocation!.label}',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const ValueKey('openLocationPickerButton'),
                        onPressed: _isSubmitting ? null : _openLocationPicker,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          _selectedLocation == null
                              ? 'Chọn vị trí trên bản đồ'
                              : 'Chọn lại vị trí trên bản đồ',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedLocation == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Bạn cần chọn vị trí trước khi gửi đăng ký.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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

class _ParkingLotLocationPicker extends StatefulWidget {
  const _ParkingLotLocationPicker({this.initialLocation});

  final _PickedLotLocation? initialLocation;

  @override
  State<_ParkingLotLocationPicker> createState() =>
      _ParkingLotLocationPickerState();
}

class _ParkingLotLocationPickerState extends State<_ParkingLotLocationPicker> {
  static const _defaultLatitude = 10.7730;
  static const _defaultLongitude = 106.7030;
  _PickedLotLocation? _selectedLocation;

  bool get _hasMapboxToken {
    final token =
        dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['ACCESS_TOKEN'];
    return token != null && token.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  void _setSelectedLocation(double latitude, double longitude) {
    setState(() {
      _selectedLocation = _PickedLotLocation(
        latitude: latitude,
        longitude: longitude,
      );
    });
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
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn vị trí bãi xe',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _hasMapboxToken
                    ? 'Chạm vào bản đồ để ghim vị trí bãi xe.'
                    : 'Workspace chưa có MAPBOX_ACCESS_TOKEN. Bạn vẫn có thể chọn vị trí gần đúng bằng bản đồ đơn giản bên dưới.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _hasMapboxToken
                    ? _LotLocationMapboxCanvas(
                        initialLocation: _selectedLocation,
                        onLocationSelected: _setSelectedLocation,
                      )
                    : _LotLocationFallbackCanvas(
                        initialLocation: _selectedLocation,
                        onLocationSelected: _setSelectedLocation,
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedLocation == null
                    ? 'Chưa có tọa độ nào được chọn.'
                    : 'Tọa độ đã ghim: ${_selectedLocation!.label}',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('confirmLocationPickerButton'),
                  onPressed: _selectedLocation == null
                      ? null
                      : () => Navigator.of(context).pop(_selectedLocation),
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Xác nhận vị trí'),
                ),
              ),
              if (_selectedLocation == null)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => _setSelectedLocation(
                      widget.initialLocation?.latitude ?? _defaultLatitude,
                      widget.initialLocation?.longitude ?? _defaultLongitude,
                    ),
                    child: const Text('Dùng vị trí trung tâm mặc định'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotLocationFallbackCanvas extends StatelessWidget {
  const _LotLocationFallbackCanvas({
    required this.initialLocation,
    required this.onLocationSelected,
  });

  final _PickedLotLocation? initialLocation;
  final void Function(double latitude, double longitude) onLocationSelected;

  static const _minLatitude = 10.745;
  static const _maxLatitude = 10.800;
  static const _minLongitude = 106.675;
  static const _maxLongitude = 106.725;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          key: const ValueKey('fallbackLocationPickerCanvas'),
          onTapUp: (details) {
            final width = constraints.maxWidth <= 0
                ? 1.0
                : constraints.maxWidth;
            final height = constraints.maxHeight <= 0
                ? 1.0
                : constraints.maxHeight;
            final dx = details.localPosition.dx.clamp(0.0, width);
            final dy = details.localPosition.dy.clamp(0.0, height);
            final longitude =
                _minLongitude + (dx / width) * (_maxLongitude - _minLongitude);
            final latitude =
                _maxLatitude - (dy / height) * (_maxLatitude - _minLatitude);
            onLocationSelected(latitude, longitude);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFD7F0FF), Color(0xFFF6F7F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FallbackGridPainter(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_city,
                        size: 44,
                        color: Color(0xFF1565C0),
                      ),
                      SizedBox(height: 8),
                      Text('Khu vực trung tâm TP.HCM'),
                      SizedBox(height: 4),
                      Text('Chạm để ghim vị trí gần đúng'),
                    ],
                  ),
                ),
                if (initialLocation != null)
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.place,
                      color: Color(0xFFC62828),
                      size: 32,
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

class _LotLocationMapboxCanvas extends StatefulWidget {
  const _LotLocationMapboxCanvas({
    required this.initialLocation,
    required this.onLocationSelected,
  });

  final _PickedLotLocation? initialLocation;
  final void Function(double latitude, double longitude) onLocationSelected;

  @override
  State<_LotLocationMapboxCanvas> createState() =>
      _LotLocationMapboxCanvasState();
}

class _LotLocationMapboxCanvasState extends State<_LotLocationMapboxCanvas> {
  MapboxMap? _mapboxMap;

  @override
  void dispose() {
    _mapboxMap?.setOnMapTapListener(null);
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    final latitude = widget.initialLocation?.latitude ?? 10.7730;
    final longitude = widget.initialLocation?.longitude ?? 106.7030;
    mapboxMap.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 14.5,
      ),
    );
    mapboxMap.setOnMapTapListener((context) {
      final coordinates = context.point.coordinates;
      widget.onLocationSelected(
        coordinates.lat.toDouble(),
        coordinates.lng.toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: MapWidget(onMapCreated: _onMapCreated),
    );
  }
}

class _FallbackGridPainter extends CustomPainter {
  const _FallbackGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    const divisions = 6;
    for (var index = 1; index < divisions; index += 1) {
      final dx = size.width * index / divisions;
      final dy = size.height * index / divisions;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FallbackGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
