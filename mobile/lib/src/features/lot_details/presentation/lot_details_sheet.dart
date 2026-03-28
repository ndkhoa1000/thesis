import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  });

  final int lotId;
  final String lotName;
  final LotDetailsService lotDetailsService;

  @override
  State<LotDetailsSheet> createState() => _LotDetailsSheetState();
}

class _LotDetailsSheetState extends State<LotDetailsSheet> {
  DriverLotDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await widget.lotDetailsService.fetchLotDetail(
        lotId: widget.lotId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
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
    }
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
