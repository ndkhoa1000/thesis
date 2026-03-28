import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../driver_booking/data/driver_booking_service.dart';
import '../../vehicles/data/vehicle_service.dart';
import '../data/lot_details_service.dart';

String _announcementWindowLabel(DriverLotAnnouncement announcement) {
  final start = announcement.visibleFrom.toLocal();
  final startDate =
      '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  if (announcement.visibleUntil == null) {
    return 'Hiển thị từ $startDate';
  }
  final end = announcement.visibleUntil!.toLocal();
  final endDate =
      '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  return '$startDate - $endDate';
}

String _announcementTypeLabel(String type) => switch (type) {
  'EVENT' => 'Sự kiện',
  'TRAFFIC_ALERT' => 'Giao thông',
  'PEAK_HOURS' => 'Giờ cao điểm',
  'CLOSURE' => 'Đóng tạm thời',
  _ => 'Thông báo',
};

class LotDetailsSheet extends StatefulWidget {
  const LotDetailsSheet({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.lotDetailsService,
    required this.driverBookingService,
    required this.vehicleService,
    required this.onManageVehicles,
  });

  final int lotId;
  final String lotName;
  final LotDetailsService lotDetailsService;
  final DriverBookingService driverBookingService;
  final VehicleService vehicleService;
  final Future<void> Function() onManageVehicles;

  @override
  State<LotDetailsSheet> createState() => _LotDetailsSheetState();
}

class _LotDetailsSheetState extends State<LotDetailsSheet> {
  DriverLotDetail? _detail;
  DriverBooking? _activeBooking;
  List<Vehicle> _vehicles = const [];
  bool _isLoading = true;
  bool _isBookingBusy = false;
  String? _errorMessage;
  String? _bookingErrorMessage;
  int? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _bookingErrorMessage = null;
    });

    try {
      final detail = await widget.lotDetailsService.fetchLotDetail(
        lotId: widget.lotId,
      );
      final vehicles = await widget.vehicleService.listVehicles();
      final activeBooking = await widget.driverBookingService.getActiveBooking(
        parkingLotId: widget.lotId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _vehicles = vehicles;
        _activeBooking = activeBooking;
        _selectedVehicleId =
            activeBooking?.vehicle.id ??
            (vehicles.isEmpty ? null : vehicles.first.id);
        _isLoading = false;
      });
    } on LotDetailsException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on DriverBookingException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on VehicleException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openVehicleManagement() async {
    await widget.onManageVehicles();
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _createBooking() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) {
      setState(() {
        _bookingErrorMessage = 'Bạn cần chọn xe trước khi đặt chỗ.';
      });
      return;
    }

    setState(() {
      _isBookingBusy = true;
      _bookingErrorMessage = null;
    });

    try {
      await widget.driverBookingService.createBooking(
        parkingLotId: widget.lotId,
        vehicleId: vehicleId,
      );
      if (!mounted) {
        return;
      }
      await _load();
    } on DriverBookingException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bookingErrorMessage = error.message;
        _isBookingBusy = false;
      });
    }
  }

  Future<void> _cancelBooking() async {
    final activeBooking = _activeBooking;
    if (activeBooking == null) {
      return;
    }

    setState(() {
      _isBookingBusy = true;
      _bookingErrorMessage = null;
    });

    try {
      await widget.driverBookingService.cancelBooking(
        bookingId: activeBooking.bookingId,
      );
      if (!mounted) {
        return;
      }
      await _load();
    } on DriverBookingException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bookingErrorMessage = error.message;
        _isBookingBusy = false;
      });
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa có';
    }
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
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

  String _vehicleTypeLabel(String vehicleType) {
    return switch (vehicleType) {
      'CAR' => 'Ô tô',
      _ => 'Xe máy',
    };
  }

  Widget _buildBookingSection(ThemeData theme) {
    final detail = _detail!;
    final booking = _activeBooking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đặt chỗ trước', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Giữ chỗ trong 30 phút với xác nhận do backend phát hành để attendant quét khi bạn đến bãi.',
          style: theme.textTheme.bodyMedium,
        ),
        if (_bookingErrorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _bookingErrorMessage!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (booking != null && booking.status != 'EXPIRED')
          _ActiveBookingCard(
            booking: booking,
            isBusy: _isBookingBusy,
            onCancel: _cancelBooking,
            formatDateTime: _formatDateTime,
            formatMoney: _formatMoney,
            vehicleTypeLabel: _vehicleTypeLabel,
          )
        else if (booking != null && booking.status == 'EXPIRED')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpiredBookingCard(
                booking: booking,
                formatDateTime: _formatDateTime,
                formatMoney: _formatMoney,
                vehicleTypeLabel: _vehicleTypeLabel,
              ),
              const SizedBox(height: 12),
              if (_vehicles.isEmpty)
                _NoVehicleBookingCard(onManageVehicles: _openVehicleManagement)
              else
                _CreateBookingCard(
                  detail: detail,
                  vehicles: _vehicles,
                  selectedVehicleId: _selectedVehicleId,
                  onVehicleChanged: (value) {
                    setState(() {
                      _selectedVehicleId = value;
                    });
                  },
                  onCreateBooking: _createBooking,
                  isBusy: _isBookingBusy,
                  vehicleTypeLabel: _vehicleTypeLabel,
                ),
            ],
          )
        else if (_vehicles.isEmpty)
          _NoVehicleBookingCard(onManageVehicles: _openVehicleManagement)
        else
          _CreateBookingCard(
            detail: detail,
            vehicles: _vehicles,
            selectedVehicleId: _selectedVehicleId,
            onVehicleChanged: (value) {
              setState(() {
                _selectedVehicleId = value;
              });
            },
            onCreateBooking: _createBooking,
            isBusy: _isBookingBusy,
            vehicleTypeLabel: _vehicleTypeLabel,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _isLoading
            ? const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              )
            : _errorMessage != null
            ? SizedBox(
                height: 320,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _detail!.name,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _detail!.address,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Làm mới',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _FactCard(
                          label: 'Khả dụng',
                          value: _detail!.capacityLabel,
                          icon: Icons.local_parking_outlined,
                        ),
                        _FactCard(
                          label: 'Giá hiện tại',
                          value: _detail!.pricingLabel,
                          icon: Icons.payments_outlined,
                        ),
                        _FactCard(
                          label: 'Giờ hoạt động',
                          value: _detail!.operatingHoursLabel,
                          icon: Icons.schedule_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildBookingSection(theme),
                    if ((_detail!.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Mô tả', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_detail!.description!),
                    ],
                    if (_detail!.tagLabels.isNotEmpty ||
                        _detail!.featureLabels.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Tiện ích', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._detail!.tagLabels.map(
                            (tag) => Chip(label: Text(tag)),
                          ),
                          ..._detail!.featureLabels.map(
                            (feature) => Chip(label: Text(feature)),
                          ),
                        ],
                      ),
                    ],
                    if (_detail!.announcements.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Thông báo', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Column(
                        children: _detail!.announcements
                            .map(
                              (announcement) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AnnouncementCard(
                                  announcement: announcement,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Peak hours ${_detail!.peakHours.lookbackDays} ngày gần nhất',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dựa trên ${_detail!.peakHours.totalSessions} lượt check-in lịch sử.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _detail!.peakHours.hasData
                        ? _PeakHoursChart(points: _detail!.peakHours.points)
                        : const _TrendEmptyState(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CreateBookingCard extends StatelessWidget {
  const _CreateBookingCard({
    required this.detail,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.onVehicleChanged,
    required this.onCreateBooking,
    required this.isBusy,
    required this.vehicleTypeLabel,
  });

  final DriverLotDetail detail;
  final List<Vehicle> vehicles;
  final int? selectedVehicleId;
  final ValueChanged<int?> onVehicleChanged;
  final Future<void> Function() onCreateBooking;
  final bool isBusy;
  final String Function(String vehicleType) vehicleTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey('bookingVehicle:${detail.id}'),
            initialValue: selectedVehicleId,
            decoration: const InputDecoration(labelText: 'Chọn xe để giữ chỗ'),
            items: vehicles
                .map(
                  (vehicle) => DropdownMenuItem<int>(
                    value: vehicle.id,
                    child: Text(
                      '${vehicle.licensePlate} • ${vehicleTypeLabel(vehicle.vehicleType)}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: isBusy ? null : onVehicleChanged,
          ),
          const SizedBox(height: 12),
          Text(
            detail.isFull
                ? 'Bãi đang đầy nên chưa thể tạo booking mới.'
                : 'Sau khi xác nhận, hệ thống sẽ giữ 1 chỗ trong 30 phút và phát hành mã xác nhận để attendant quét khi bạn đến.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: ValueKey('bookLot:${detail.id}'),
            onPressed: detail.isFull || isBusy ? null : onCreateBooking,
            icon: const Icon(Icons.event_available_outlined),
            label: Text(isBusy ? 'Đang xử lý...' : 'Đặt chỗ 30 phút'),
          ),
        ],
      ),
    );
  }
}

class _NoVehicleBookingCard extends StatelessWidget {
  const _NoVehicleBookingCard({required this.onManageVehicles});

  final Future<void> Function() onManageVehicles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bạn cần đăng ký ít nhất một xe trước khi đặt chỗ cho bãi này.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onManageVehicles,
            icon: const Icon(Icons.directions_car_outlined),
            label: const Text('Quản lý xe của tôi'),
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({
    required this.booking,
    required this.isBusy,
    required this.onCancel,
    required this.formatDateTime,
    required this.formatMoney,
    required this.vehicleTypeLabel,
  });

  final DriverBooking booking;
  final bool isBusy;
  final Future<void> Function() onCancel;
  final String Function(DateTime? value) formatDateTime;
  final String Function(double amount) formatMoney;
  final String Function(String vehicleType) vehicleTypeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Booking đang hoạt động',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Chip(label: Text('Còn ${booking.currentAvailable} chỗ')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.vehicle.licensePlate,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(vehicleTypeLabel(booking.vehicle.vehicleType)),
          const SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: booking.token,
              version: QrVersions.auto,
              size: 220,
            ),
          ),
          const SizedBox(height: 12),
          Text('Đến trước: ${formatDateTime(booking.expirationTime)}'),
          const SizedBox(height: 4),
          Text(
            'Phí giữ chỗ: ${formatMoney(booking.payment.finalAmount)} VNĐ • ${booking.payment.paymentMethod}',
          ),
          const SizedBox(height: 4),
          Text(
            'Mã này do backend phát hành và attendant sẽ quét khi bạn đến bãi.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: ValueKey('cancelBooking:${booking.bookingId}'),
            onPressed: isBusy ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(isBusy ? 'Đang hủy...' : 'Hủy booking'),
          ),
        ],
      ),
    );
  }
}

class _ExpiredBookingCard extends StatelessWidget {
  const _ExpiredBookingCard({
    required this.booking,
    required this.formatDateTime,
    required this.formatMoney,
    required this.vehicleTypeLabel,
  });

  final DriverBooking booking;
  final String Function(DateTime? value) formatDateTime;
  final String Function(double amount) formatMoney;
  final String Function(String vehicleType) vehicleTypeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking đã hết hạn', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Giữ chỗ cho ${booking.vehicle.licensePlate} (${vehicleTypeLabel(booking.vehicle.vehicleType)}) đã được trả lại cho bãi.',
          ),
          const SizedBox(height: 8),
          Text('Hết hạn lúc: ${formatDateTime(booking.expirationTime)}'),
          const SizedBox(height: 4),
          Text(
            'Phí giữ chỗ trước đó: ${formatMoney(booking.payment.finalAmount)} VNĐ • ${booking.payment.paymentMethod}',
          ),
          const SizedBox(height: 4),
          const Text('Bạn có thể tạo booking mới ngay nếu bãi vẫn còn chỗ.'),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final DriverLotAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Chip(
                label: Text(
                  _announcementTypeLabel(announcement.announcementType),
                ),
              ),
            ],
          ),
          if ((announcement.content ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(announcement.content!),
          ],
          const SizedBox(height: 8),
          Text(
            _announcementWindowLabel(announcement),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  const _PeakHoursChart({required this.points});

  final List<LotPeakHourPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(0, (maxCount, point) {
      return math.max(maxCount, point.sessionCount);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: points
              .map((point) {
                final ratio = maxValue == 0
                    ? 0.0
                    : point.sessionCount / maxValue;
                final barHeight = 36 + (ratio * 92);
                return SizedBox(
                  width: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${point.sessionCount}'),
                        const SizedBox(height: 8),
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(point.label),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _TrendEmptyState extends StatelessWidget {
  const _TrendEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Chưa đủ dữ liệu lịch sử để hiển thị peak hours cho bãi này.',
      ),
    );
  }
}
