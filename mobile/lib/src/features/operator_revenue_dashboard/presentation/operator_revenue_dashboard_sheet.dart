import 'package:flutter/material.dart';

import '../../operator_lot_management/data/operator_lot_management_service.dart';

class OperatorRevenueDashboardSheet extends StatefulWidget {
  const OperatorRevenueDashboardSheet({
    super.key,
    required this.parkingLot,
    required this.lotManagementService,
  });

  final OperatorManagedParkingLot parkingLot;
  final OperatorLotManagementService lotManagementService;

  @override
  State<OperatorRevenueDashboardSheet> createState() =>
      _OperatorRevenueDashboardSheetState();
}

class _OperatorRevenueDashboardSheetState
    extends State<OperatorRevenueDashboardSheet> {
  OperatorRevenuePeriod _selectedPeriod = OperatorRevenuePeriod.day;
  late Future<OperatorRevenueSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary([OperatorRevenuePeriod? period]) {
    final nextPeriod = period ?? _selectedPeriod;
    setState(() {
      _selectedPeriod = nextPeriod;
      _summaryFuture = widget.lotManagementService.getRevenueSummary(
        parkingLotId: widget.parkingLot.id,
        period: nextPeriod,
      );
    });
  }

  String _formatCurrency(double value) => '${value.toStringAsFixed(0)} VND';

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, OperatorRevenueSummary summary) {
    final infoRows = <Widget>[
      _InfoRow(
        label: 'Khoảng báo cáo',
        value:
            '${_formatDate(summary.rangeStart)} - ${_formatDate(summary.rangeEnd)}',
      ),
      if (summary.leaseStatus != null)
        _InfoRow(label: 'Lease', value: summary.leaseStatus!),
      if (summary.ownerName != null)
        _InfoRow(label: 'Chủ bãi', value: summary.ownerName!),
      if (summary.revenueSharePercentage != null)
        _InfoRow(
          label: 'Tỷ lệ chủ bãi',
          value: '${summary.revenueSharePercentage!.toStringAsFixed(0)}%',
        ),
      if (summary.totalCapacity != null)
        _InfoRow(label: 'Sức chứa', value: '${summary.totalCapacity} chỗ'),
      if (summary.occupancyRatePercentage != null)
        _InfoRow(
          label: 'Tỷ lệ lấp đầy',
          value: '${summary.occupancyRatePercentage!.toStringAsFixed(1)}%',
        ),
    ];

    if (!summary.hasData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...infoRows,
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có dữ liệu vận hành',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  summary.emptyMessage ??
                      'Chưa có phiên hoàn tất phù hợp trong khoảng đã chọn.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...infoRows,
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricTile(
              context: context,
              label: 'Tổng doanh thu',
              value: _formatCurrency(summary.grossRevenue ?? 0),
            ),
            _buildMetricTile(
              context: context,
              label: 'Phần vận hành',
              value: _formatCurrency(summary.operatorShare ?? 0),
            ),
            _buildMetricTile(
              context: context,
              label: 'Phần chủ bãi',
              value: _formatCurrency(summary.ownerShare ?? 0),
            ),
            _buildMetricTile(
              context: context,
              label: 'Phiên hoàn tất',
              value: '${summary.completedSessionCount}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Cơ cấu loại xe', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...summary.vehicleTypeBreakdown.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _InfoRow(
              label: item.vehicleType,
              value: '${item.sessionCount} phiên',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SafeArea(
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
                          'Bảng doanh thu vận hành',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(widget.parkingLot.name),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: OperatorRevenuePeriod.values
                    .map(
                      (period) => ChoiceChip(
                        label: Text(period.label),
                        selected: _selectedPeriod == period,
                        onSelected: (_) => _loadSummary(period),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<OperatorRevenueSummary>(
                  future: _summaryFuture,
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
                              onPressed: _loadSummary,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      );
                    }

                    final summary = snapshot.data;
                    if (summary == null) {
                      return const SizedBox.shrink();
                    }

                    return SingleChildScrollView(
                      child: _buildSummary(context, summary),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
