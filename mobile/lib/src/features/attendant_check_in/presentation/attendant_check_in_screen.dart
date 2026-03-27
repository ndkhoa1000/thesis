import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/attendant_check_in_service.dart';

typedef AttendantScannerBuilder =
    Widget Function(
      BuildContext context,
      Future<void> Function(String token) onDetect,
      bool isBusy,
    );

class AttendantCheckInScreen extends StatefulWidget {
  const AttendantCheckInScreen({
    super.key,
    required this.attendantCheckInService,
    this.scannerBuilder = defaultAttendantScannerBuilder,
    this.onSignOut,
  });

  final AttendantCheckInService attendantCheckInService;
  final AttendantScannerBuilder scannerBuilder;
  final Future<void> Function()? onSignOut;

  @override
  State<AttendantCheckInScreen> createState() => _AttendantCheckInScreenState();
}

class _AttendantCheckInScreenState extends State<AttendantCheckInScreen> {
  bool _isBusy = false;
  String? _errorMessage;
  AttendantCheckInResult? _lastResult;

  Future<void> _handleScan(String token) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.attendantCheckInService.checkInDriver(
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _isBusy = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastResult = null;
        _errorMessage = error.message;
        _isBusy = false;
      });
    }
  }

  String get _statusLabel {
    if (_isBusy) {
      return 'Đang xác nhận mã check-in...';
    }
    return 'Sẵn sàng quét xe vào bãi';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: const Color(0xFF00E676),
    );

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF050505),
        useMaterial3: true,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quét mã check-in'),
          actions: widget.onSignOut == null
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Đăng xuất',
                    onPressed: widget.onSignOut,
                  ),
                ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _errorMessage == null
                            ? colorScheme.primary
                            : colorScheme.error,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: widget.scannerBuilder(
                        context,
                        _handleScan,
                        _isBusy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  _FeedbackCard(
                    title: 'Quét thất bại',
                    message: _errorMessage!,
                    color: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                if (_lastResult != null)
                  _FeedbackCard(
                    title: 'Check-in thành công',
                    message:
                        '${_lastResult!.licensePlate}\n${_vehicleTypeLabel(_lastResult!.vehicleType)}\nCòn ${_lastResult!.currentAvailable} chỗ trong bãi',
                    color: const Color(0xFF003B1F),
                    foregroundColor: const Color(0xFFB9F6CA),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _vehicleTypeLabel(String vehicleType) {
    return vehicleType.toUpperCase() == 'CAR' ? 'Ô tô' : 'Xe máy';
  }
}

Widget defaultAttendantScannerBuilder(
  BuildContext context,
  Future<void> Function(String token) onDetect,
  bool isBusy,
) {
  return Stack(
    fit: StackFit.expand,
    children: [
      MobileScanner(
        controller: MobileScannerController(
          formats: const [BarcodeFormat.qrCode],
        ),
        onDetect: (capture) {
          if (isBusy) {
            return;
          }
          for (final barcode in capture.barcodes) {
            final rawValue = barcode.rawValue;
            if (rawValue == null || rawValue.isEmpty) {
              continue;
            }
            onDetect(rawValue);
            break;
          }
        },
      ),
      Align(
        alignment: Alignment.center,
        child: IgnorePointer(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white70, width: 3),
            ),
          ),
        ),
      ),
      if (isBusy)
        const ColoredBox(
          color: Color(0x99000000),
          child: Center(child: CircularProgressIndicator()),
        ),
    ],
  );
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.message,
    required this.color,
    required this.foregroundColor,
  });

  final String title;
  final String message;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: foregroundColor),
            ),
          ],
        ),
      ),
    );
  }
}
