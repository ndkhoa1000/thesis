import 'package:flutter/material.dart';

import '../../parking_lot_registration/data/parking_lot_service.dart';
import '../data/owner_revenue_dashboard_service.dart';

class OwnerRevenueDashboardSheet extends StatefulWidget {
  const OwnerRevenueDashboardSheet({
    super.key,
    required this.parkingLot,
    required this.ownerRevenueDashboardService,
  });

  final ParkingLotRegistration parkingLot;
  final OwnerRevenueDashboardService ownerRevenueDashboardService;

  @override
  State<OwnerRevenueDashboardSheet> createState() =>
      _OwnerRevenueDashboardSheetState();
}

class _OwnerRevenueDashboardSheetState
    extends State<OwnerRevenueDashboardSheet> {
  OwnerRevenuePeriod _selectedPeriod = OwnerRevenuePeriod.day;
  late Future<OwnerRevenueSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary([OwnerRevenuePeriod? period]) {
    final nextPeriod = period ?? _selectedPeriod;
    setState(() {
      _selectedPeriod = nextPeriod;
      _summaryFuture = widget.ownerRevenueDashboardService
          .getOwnerRevenueSummary(
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

  Widget _buildSummaryBody(BuildContext context, OwnerRevenueSummary summary) {
    final infoRows = <Widget>[
      _InfoRow(
        label: 'Khoảng báo cáo',
        value:
            '${_formatDate(summary.rangeStart)} - ${_formatDate(summary.rangeEnd)}',
      ),
      if (summary.leaseStatus != null)
        _InfoRow(label: 'Lease', value: summary.leaseStatus!),
      if (summary.operatorName != null)
        _InfoRow(label: 'Operator', value: summary.operatorName!),
      if (summary.revenueSharePercentage != null)
        _InfoRow(
          label: 'Tỷ lệ chủ bãi',
          value: '${summary.revenueSharePercentage!.toStringAsFixed(0)}%',
        ),
      if (summary.leaseStartDate != null)
        _InfoRow(
          label: 'Bắt đầu lease',
          value: _formatDate(summary.leaseStartDate!),
        ),
      if (summary.leaseEndDate != null)
        _InfoRow(
          label: 'Kết thúc lease',
          value: _formatDate(summary.leaseEndDate!),
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
                  Icons.query_stats_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có dữ liệu doanh thu',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  summary.emptyMessage ??
                      'Chưa có dữ liệu phù hợp để hiển thị trong khoảng đã chọn.',
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
          childAspectRatio: 1.35,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricTile(
              context: context,
              label: 'Tổng doanh thu',
              value: _formatCurrency(summary.grossRevenue ?? 0),
            ),
            _buildMetricTile(
              context: context,
              label: 'Phần chủ bãi',
              value: _formatCurrency(summary.ownerShare ?? 0),
            ),
            _buildMetricTile(
              context: context,
              label: 'Phần operator',
              value: _formatCurrency(summary.operatorShare ?? 0),
            ),
            _buildMetricTile(
              context: context,
              label: 'Phiên đã thanh toán',
              value: '${summary.completedPaymentCount}',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
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
                          'Dashboard doanh thu',
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
                children: OwnerRevenuePeriod.values
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
                child: FutureBuilder<OwnerRevenueSummary>(
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
                      child: _buildSummaryBody(context, summary),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
