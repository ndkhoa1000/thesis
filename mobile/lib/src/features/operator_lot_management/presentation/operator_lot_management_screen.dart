import 'package:flutter/material.dart';

import '../data/operator_lot_management_service.dart';

String _formatAnnouncementDateTime(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

DateTime? _parseAnnouncementDateTime(String value) {
  final trimmed = value.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$',
  ).firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  final hour = int.tryParse(match.group(4)!);
  final minute = int.tryParse(match.group(5)!);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null) {
    return null;
  }
  final parsed = DateTime(year, month, day, hour, minute);
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute) {
    return null;
  }
  return parsed;
}

String _announcementTypeLabel(String type) => switch (type) {
  'EVENT' => 'Sự kiện',
  'TRAFFIC_ALERT' => 'Giao thông',
  'PEAK_HOURS' => 'Giờ cao điểm',
  'CLOSURE' => 'Đóng tạm thời',
  _ => 'Thông báo chung',
};

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

  Future<void> _openAnnouncementManagement(
    OperatorManagedParkingLot lot,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperatorAnnouncementManagementSheet(
        parkingLot: lot,
        lotManagementService: widget.lotManagementService,
      ),
    );
  }

  Future<void> _openShiftAlerts() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperatorShiftAlertSheet(
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
            key: const ValueKey('operator-shift-alerts-button'),
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Canh bao giao ca',
            onPressed: _openShiftAlerts,
          ),
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
                onManageAnnouncements: () => _openAnnouncementManagement(lot),
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
    required this.onManageAnnouncements,
  });

  final OperatorManagedParkingLot parkingLot;
  final VoidCallback onConfigure;
  final VoidCallback onManageAttendants;
  final VoidCallback onManageAnnouncements;

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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onManageAttendants,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Nhân viên trực'),
                ),
                OutlinedButton.icon(
                  onPressed: onManageAnnouncements,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Thông báo'),
                ),
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

class _OperatorShiftAlertSheet extends StatefulWidget {
  const _OperatorShiftAlertSheet({required this.lotManagementService});

  final OperatorLotManagementService lotManagementService;

  @override
  State<_OperatorShiftAlertSheet> createState() =>
      _OperatorShiftAlertSheetState();
}

class _OperatorShiftAlertSheetState extends State<_OperatorShiftAlertSheet> {
  late Future<List<OperatorShiftAlert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _alertsFuture = widget.lotManagementService.getShiftHandoverAlerts();
    });
  }

  String _formatAlertDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month ${hour}:$minute';
  }

  Future<void> _openFinalShiftCloseOut(int closeOutId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OperatorFinalShiftCloseOutSheet(
        closeOutId: closeOutId,
        lotManagementService: widget.lotManagementService,
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canh bao giao ca va dong ca',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Operator nhan canh bao chenh lech giao ca va yeu cau dong ca cuoi ngay tai day.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Lam moi canh bao'),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<OperatorShiftAlert>>(
                  future: _alertsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _reload,
                              child: const Text('Thu lai'),
                            ),
                          ],
                        ),
                      );
                    }

                    final alerts =
                        snapshot.data ?? const <OperatorShiftAlert>[];
                    if (alerts.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chua co canh bao giao ca hoac dong ca nao.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        final isFinalCloseOut =
                            alert.referenceType == 'SHIFT_CLOSE_OUT' &&
                            alert.referenceId != null;
                        return Card(
                          color: isFinalCloseOut
                              ? const Color(0xFFE3F2FD)
                              : const Color(0xFFFFF3E0),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        alert.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Text(_formatAlertDateTime(alert.createdAt)),
                                  ],
                                ),
                                if ((alert.message ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(alert.message!),
                                ],
                                if (isFinalCloseOut) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.tonalIcon(
                                      key: ValueKey(
                                        'final-shift-close-out-alert-action-${alert.id}',
                                      ),
                                      onPressed: () => _openFinalShiftCloseOut(
                                        alert.referenceId!,
                                      ),
                                      icon: const Icon(Icons.task_alt_outlined),
                                      label: const Text(
                                        'Xem va hoan tat dong ca',
                                      ),
                                    ),
                                  ),
                                ],
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

class _OperatorFinalShiftCloseOutSheet extends StatefulWidget {
  const _OperatorFinalShiftCloseOutSheet({
    required this.closeOutId,
    required this.lotManagementService,
  });

  final int closeOutId;
  final OperatorLotManagementService lotManagementService;

  @override
  State<_OperatorFinalShiftCloseOutSheet> createState() =>
      _OperatorFinalShiftCloseOutSheetState();
}

class _OperatorFinalShiftCloseOutSheetState
    extends State<_OperatorFinalShiftCloseOutSheet> {
  late Future<OperatorFinalShiftCloseOutDetail> _detailFuture;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _detailFuture = widget.lotManagementService.getFinalShiftCloseOutDetail(
        closeOutId: widget.closeOutId,
      );
    });
  }

  String _formatMoney(double amount) {
    final normalized = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    final buffer = StringBuffer();
    for (var index = 0; index < normalized.length; index += 1) {
      final remaining = normalized.length - index;
      buffer.write(normalized[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return '${buffer.toString()} VND';
  }

  Future<void> _complete() async {
    setState(() {
      _isCompleting = true;
    });
    try {
      final result = await widget.lotManagementService
          .completeFinalShiftCloseOut(closeOutId: widget.closeOutId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Da hoan tat dong ca cuoi ngay cho ${result.parkingLotName}.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on OperatorLotManagementException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
      setState(() {
        _isCompleting = false;
      });
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
          height: MediaQuery.of(context).size.height * 0.75,
          child: FutureBuilder<OperatorFinalShiftCloseOutDetail>(
            future: _detailFuture,
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

              final detail = snapshot.data!;
              final isCompleted = detail.status == 'COMPLETED';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dong ca cuoi ngay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Bai xe', value: detail.parkingLotName),
                  _InfoRow(label: 'Nhan vien', value: detail.attendantName),
                  _InfoRow(
                    label: 'Tien mat doi chieu',
                    value: _formatMoney(detail.expectedCash),
                  ),
                  _InfoRow(
                    label: 'Cho trong snapshot',
                    value: '${detail.currentAvailable} cho',
                  ),
                  _InfoRow(
                    label: 'Active sessions',
                    value: '${detail.activeSessionCount}',
                  ),
                  _InfoRow(label: 'Trang thai', value: detail.status),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey(
                        'complete-final-shift-close-out-button',
                      ),
                      onPressed: isCompleted || _isCompleting
                          ? null
                          : _complete,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(
                        isCompleted
                            ? 'Da hoan tat dong ca'
                            : _isCompleting
                            ? 'Dang hoan tat...'
                            : 'Operator xac nhan dong ca',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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

class _OperatorAnnouncementManagementSheet extends StatefulWidget {
  const _OperatorAnnouncementManagementSheet({
    required this.parkingLot,
    required this.lotManagementService,
  });

  final OperatorManagedParkingLot parkingLot;
  final OperatorLotManagementService lotManagementService;

  @override
  State<_OperatorAnnouncementManagementSheet> createState() =>
      _OperatorAnnouncementManagementSheetState();
}

class _OperatorAnnouncementManagementSheetState
    extends State<_OperatorAnnouncementManagementSheet> {
  late Future<List<OperatorLotAnnouncement>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _reloadAnnouncements();
  }

  void _reloadAnnouncements() {
    setState(() {
      _announcementsFuture = widget.lotManagementService.getLotAnnouncements(
        parkingLotId: widget.parkingLot.id,
      );
    });
  }

  Future<void> _openAnnouncementForm({
    OperatorLotAnnouncement? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AnnouncementFormSheet(
        existing: existing,
        onSubmit:
            ({
              required title,
              content,
              required announcementType,
              required visibleFrom,
              visibleUntil,
            }) async {
              try {
                if (existing == null) {
                  await widget.lotManagementService.createLotAnnouncement(
                    parkingLotId: widget.parkingLot.id,
                    title: title,
                    content: content,
                    announcementType: announcementType,
                    visibleFrom: visibleFrom,
                    visibleUntil: visibleUntil,
                  );
                } else {
                  await widget.lotManagementService.updateLotAnnouncement(
                    parkingLotId: widget.parkingLot.id,
                    announcementId: existing.id,
                    title: title,
                    content: content,
                    announcementType: announcementType,
                    visibleFrom: visibleFrom,
                    visibleUntil: visibleUntil,
                  );
                }
                if (!mounted || !sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      existing == null
                          ? 'Đã tạo thông báo cho ${widget.parkingLot.name}.'
                          : 'Đã cập nhật thông báo cho ${widget.parkingLot.name}.',
                    ),
                  ),
                );
                _reloadAnnouncements();
              } on OperatorLotManagementException catch (error) {
                if (!sheetContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(error.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
      ),
    );
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
                'Thông báo bãi xe',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(widget.parkingLot.name),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openAnnouncementForm(),
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Tạo thông báo'),
              ),
              Expanded(
                child: FutureBuilder<List<OperatorLotAnnouncement>>(
                  future: _announcementsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _OperatorLotErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _reloadAnnouncements,
                      );
                    }

                    final announcements =
                        snapshot.data ?? const <OperatorLotAnnouncement>[];
                    if (announcements.isEmpty) {
                      return const Center(
                        child: Text(
                          'Chưa có thông báo nào cho bãi xe này.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 16),
                      itemCount: announcements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final announcement = announcements[index];
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
                                        announcement.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        _announcementTypeLabel(
                                          announcement.announcementType,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((announcement.content ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(announcement.content!),
                                ],
                                const SizedBox(height: 12),
                                _InfoRow(
                                  label: 'Bắt đầu hiển thị',
                                  value: _formatAnnouncementDateTime(
                                    announcement.visibleFrom,
                                  ),
                                ),
                                _InfoRow(
                                  label: 'Kết thúc hiển thị',
                                  value: announcement.visibleUntil == null
                                      ? 'Không giới hạn'
                                      : _formatAnnouncementDateTime(
                                          announcement.visibleUntil!,
                                        ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openAnnouncementForm(
                                      existing: announcement,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Cập nhật thông báo'),
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

class _AnnouncementFormSheet extends StatefulWidget {
  const _AnnouncementFormSheet({required this.onSubmit, this.existing});

  final OperatorLotAnnouncement? existing;
  final Future<void> Function({
    required String title,
    String? content,
    required String announcementType,
    required DateTime visibleFrom,
    DateTime? visibleUntil,
  })
  onSubmit;

  @override
  State<_AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends State<_AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _visibleFromController;
  late final TextEditingController _visibleUntilController;
  late String _announcementType;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );
    _visibleFromController = TextEditingController(
      text: widget.existing == null
          ? _formatAnnouncementDateTime(DateTime.now())
          : _formatAnnouncementDateTime(widget.existing!.visibleFrom),
    );
    _visibleUntilController = TextEditingController(
      text: widget.existing?.visibleUntil == null
          ? ''
          : _formatAnnouncementDateTime(widget.existing!.visibleUntil!),
    );
    _announcementType = widget.existing?.announcementType ?? 'GENERAL';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _visibleFromController.dispose();
    _visibleUntilController.dispose();
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
        title: _titleController.text.trim(),
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        announcementType: _announcementType,
        visibleFrom: _parseAnnouncementDateTime(
          _visibleFromController.text.trim(),
        )!,
        visibleUntil: _visibleUntilController.text.trim().isEmpty
            ? null
            : _parseAnnouncementDateTime(_visibleUntilController.text.trim()),
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null
                      ? 'Tạo thông báo'
                      : 'Cập nhật thông báo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Tiêu đề là bắt buộc';
                    }
                    if (trimmed.length < 2) {
                      return 'Tiêu đề phải có ít nhất 2 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung (tuỳ chọn)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _announcementType,
                  decoration: const InputDecoration(
                    labelText: 'Loại thông báo',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'GENERAL',
                      child: Text('Thông báo chung'),
                    ),
                    DropdownMenuItem(value: 'EVENT', child: Text('Sự kiện')),
                    DropdownMenuItem(
                      value: 'TRAFFIC_ALERT',
                      child: Text('Giao thông'),
                    ),
                    DropdownMenuItem(
                      value: 'PEAK_HOURS',
                      child: Text('Giờ cao điểm'),
                    ),
                    DropdownMenuItem(
                      value: 'CLOSURE',
                      child: Text('Đóng tạm thời'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _announcementType = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _visibleFromController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Bắt đầu hiển thị (YYYY-MM-DD HH:mm)',
                  ),
                  validator: (value) {
                    if (_parseAnnouncementDateTime((value ?? '').trim()) ==
                        null) {
                      return 'Nhập theo định dạng YYYY-MM-DD HH:mm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _visibleUntilController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Kết thúc hiển thị (tuỳ chọn)',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return null;
                    }
                    final visibleUntil = _parseAnnouncementDateTime(trimmed);
                    if (visibleUntil == null) {
                      return 'Nhập theo định dạng YYYY-MM-DD HH:mm';
                    }
                    final visibleFrom = _parseAnnouncementDateTime(
                      _visibleFromController.text.trim(),
                    );
                    if (visibleFrom != null &&
                        visibleUntil.isBefore(visibleFrom)) {
                      return 'Thời gian kết thúc phải sau thời gian bắt đầu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _isSubmitting ? 'Đang lưu...' : 'Lưu thông báo',
                    ),
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
      final openingTime = _parseTime(_openingTimeController.text.trim());
      final closingTime = _parseTime(_closingTimeController.text.trim());
      await widget.onSubmit(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        totalCapacity: int.parse(_capacityController.text.trim()),
        openingTime: _formatTime(openingTime!),
        closingTime: _formatTime(closingTime!),
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

  TimeOfDay? _parseTime(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(controller.text) ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      controller.text = _formatTime(selected);
    });
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
                  decoration: InputDecoration(
                    labelText: 'Giờ mở cửa (HH:mm)',
                    suffixIcon: IconButton(
                      tooltip: 'Chọn giờ mở cửa',
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickTime(_openingTimeController),
                      icon: const Icon(Icons.schedule_outlined),
                    ),
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Giờ mở cửa là bắt buộc';
                    }
                    if (_parseTime(trimmed) == null) {
                      return 'Nhập giờ theo định dạng HH:mm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _closingTimeController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Giờ đóng cửa (HH:mm)',
                    suffixIcon: IconButton(
                      tooltip: 'Chọn giờ đóng cửa',
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickTime(_closingTimeController),
                      icon: const Icon(Icons.schedule_outlined),
                    ),
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Giờ đóng cửa là bắt buộc';
                    }
                    final parsed = _parseTime(trimmed);
                    if (parsed == null) {
                      return 'Nhập giờ theo định dạng HH:mm';
                    }
                    final openingTime = _parseTime(
                      _openingTimeController.text.trim(),
                    );
                    if (openingTime != null &&
                        _formatTime(parsed) == _formatTime(openingTime)) {
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
