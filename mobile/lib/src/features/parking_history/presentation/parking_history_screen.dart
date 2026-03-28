import 'package:flutter/material.dart';

import '../data/parking_history_service.dart';

class ParkingHistoryScreen extends StatefulWidget {
  const ParkingHistoryScreen({super.key, required this.parkingHistoryService});

  final ParkingHistoryService parkingHistoryService;

  @override
  State<ParkingHistoryScreen> createState() => _ParkingHistoryScreenState();
}

class _ParkingHistoryScreenState extends State<ParkingHistoryScreen> {
  late Future<List<DriverParkingHistoryEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _historyFuture = widget.parkingHistoryService.fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử gửi xe'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Làm mới lịch sử',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<DriverParkingHistoryEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ParkingHistoryErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final history = snapshot.data ?? const <DriverParkingHistoryEntry>[];
          if (history.isEmpty) {
            return const _ParkingHistoryEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _ParkingHistoryCard(entry: history[index]);
            },
          );
        },
      ),
    );
  }
}

class _ParkingHistoryCard extends StatelessWidget {
  const _ParkingHistoryCard({required this.entry});

  final DriverParkingHistoryEntry entry;

  String _formatDateTime(DateTime value) {
    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    final year = localValue.year.toString();
    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
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
                    entry.parkingLotName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(entry.paymentMethodLabel)),
              ],
            ),
            const SizedBox(height: 12),
            _HistoryInfoRow(label: 'Biển số', value: entry.licensePlate),
            _HistoryInfoRow(label: 'Loại xe', value: entry.vehicleType),
            _HistoryInfoRow(
              label: 'Vào bãi',
              value: _formatDateTime(entry.checkedInAt),
            ),
            _HistoryInfoRow(
              label: 'Rời bãi',
              value: _formatDateTime(entry.checkedOutAt),
            ),
            _HistoryInfoRow(label: 'Thời lượng', value: entry.durationLabel),
            _HistoryInfoRow(label: 'Đã thanh toán', value: entry.amountLabel),
          ],
        ),
      ),
    );
  }
}

class _HistoryInfoRow extends StatelessWidget {
  const _HistoryInfoRow({required this.label, required this.value});

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

class _ParkingHistoryEmptyState extends StatelessWidget {
  const _ParkingHistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có lượt gửi xe đã hoàn tất',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Khi bạn hoàn tất một phiên gửi xe, hóa đơn và thời lượng sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParkingHistoryErrorState extends StatelessWidget {
  const _ParkingHistoryErrorState({
    required this.message,
    required this.onRetry,
  });

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
