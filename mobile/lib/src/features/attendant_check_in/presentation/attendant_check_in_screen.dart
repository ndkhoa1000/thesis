import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/attendant_check_in_service.dart';

typedef AttendantScannerBuilder =
    Widget Function(
      BuildContext context,
      Future<void> Function(String token) onDetect,
      bool isBusy,
    );

typedef AttendantImageCapture = Future<String?> Function();

enum _AttendantGateMode { scanner, walkIn }

class AttendantCheckInScreen extends StatefulWidget {
  const AttendantCheckInScreen({
    super.key,
    required this.attendantCheckInService,
    this.scannerBuilder = defaultAttendantScannerBuilder,
    this.captureOverviewImage = defaultCaptureOverviewImage,
    this.capturePlateImage = defaultCapturePlateImage,
    this.onSignOut,
  });

  final AttendantCheckInService attendantCheckInService;
  final AttendantScannerBuilder scannerBuilder;
  final AttendantImageCapture captureOverviewImage;
  final AttendantImageCapture capturePlateImage;
  final Future<void> Function()? onSignOut;

  @override
  State<AttendantCheckInScreen> createState() => _AttendantCheckInScreenState();
}

class _AttendantCheckInScreenState extends State<AttendantCheckInScreen> {
  _AttendantGateMode _mode = _AttendantGateMode.scanner;
  bool _isBusy = false;
  String? _errorMessage;
  AttendantCheckInResult? _lastResult;
  String _walkInVehicleType = 'MOTORBIKE';
  String? _overviewImagePath;
  String? _plateImagePath;

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

  Future<void> _captureOverviewImage() async {
    final path = await widget.captureOverviewImage();
    if (!mounted || path == null) return;
    setState(() {
      _overviewImagePath = path;
      _errorMessage = null;
    });
  }

  Future<void> _capturePlateImage() async {
    final path = await widget.capturePlateImage();
    if (!mounted || path == null) return;
    setState(() {
      _plateImagePath = path;
      _errorMessage = null;
    });
  }

  Future<void> _submitWalkIn() async {
    if (_isBusy) return;
    if (_plateImagePath == null) {
      setState(() {
        _lastResult = null;
        _errorMessage = 'Can chup anh bien so truoc khi tao phien walk-in.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.attendantCheckInService.checkInWalkIn(
        vehicleType: _walkInVehicleType,
        plateImagePath: _plateImagePath!,
        overviewImagePath: _overviewImagePath,
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _isBusy = false;
        _mode = _AttendantGateMode.scanner;
        _overviewImagePath = null;
        _plateImagePath = null;
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

  void _openWalkInMode() {
    if (_isBusy) return;
    setState(() {
      _mode = _AttendantGateMode.walkIn;
      _lastResult = null;
      _errorMessage = null;
    });
  }

  void _returnToScannerMode() {
    if (_isBusy) return;
    setState(() {
      _mode = _AttendantGateMode.scanner;
      _overviewImagePath = null;
      _plateImagePath = null;
      _errorMessage = null;
    });
  }

  String get _statusLabel {
    if (_isBusy) {
      return _mode == _AttendantGateMode.walkIn
          ? 'Dang tao phien walk-in...'
          : 'Dang xac nhan ma check-in...';
    }
    return _mode == _AttendantGateMode.walkIn
        ? 'San sang tao phien walk-in'
        : 'Sẵn sàng quét xe vào bãi';
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
          title: Text(
            _mode == _AttendantGateMode.walkIn
                ? 'Walk-in check-in'
                : 'Quét mã check-in',
          ),
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
                  child: _mode == _AttendantGateMode.scanner
                      ? DecoratedBox(
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
                        )
                      : _WalkInPanel(
                          isBusy: _isBusy,
                          vehicleType: _walkInVehicleType,
                          overviewImagePath: _overviewImagePath,
                          plateImagePath: _plateImagePath,
                          onVehicleTypeChanged: (value) {
                            setState(() {
                              _walkInVehicleType = value;
                            });
                          },
                          onCaptureOverviewImage: _captureOverviewImage,
                          onCapturePlateImage: _capturePlateImage,
                          onSubmit: _submitWalkIn,
                          onBack: _returnToScannerMode,
                        ),
                ),
                const SizedBox(height: 16),
                if (_mode == _AttendantGateMode.scanner)
                  FilledButton.icon(
                    key: const ValueKey('walk-in-entry-button'),
                    onPressed: _isBusy ? null : _openWalkInMode,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Xe vang lai'),
                  ),
                if (_mode == _AttendantGateMode.scanner)
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

Future<String?> defaultCaptureOverviewImage() => _captureImageFromCamera();

Future<String?> defaultCapturePlateImage() => _captureImageFromCamera();

Future<String?> _captureImageFromCamera() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
  );
  return image?.path;
}

class _WalkInPanel extends StatelessWidget {
  const _WalkInPanel({
    required this.isBusy,
    required this.vehicleType,
    required this.overviewImagePath,
    required this.plateImagePath,
    required this.onVehicleTypeChanged,
    required this.onCaptureOverviewImage,
    required this.onCapturePlateImage,
    required this.onSubmit,
    required this.onBack,
  });

  final bool isBusy;
  final String vehicleType;
  final String? overviewImagePath;
  final String? plateImagePath;
  final ValueChanged<String> onVehicleTypeChanged;
  final Future<void> Function() onCaptureOverviewImage;
  final Future<void> Function() onCapturePlateImage;
  final Future<void> Function() onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Walk-in check-in',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'MOTORBIKE', label: Text('Xe may')),
              ButtonSegment(value: 'CAR', label: Text('O to')),
            ],
            selected: {vehicleType},
            onSelectionChanged: isBusy
                ? null
                : (selection) => onVehicleTypeChanged(selection.first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: isBusy ? null : onCaptureOverviewImage,
            child: Text(
              overviewImagePath == null
                  ? 'Chup anh toan canh'
                  : 'Da chup anh toan canh',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isBusy ? null : onCapturePlateImage,
            child: Text(
              plateImagePath == null
                  ? 'Chup anh bien so'
                  : 'Da chup anh bien so',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isBusy ? null : onSubmit,
            child: const Text('Tao phien walk-in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isBusy ? null : onBack,
            child: const Text('Quay lai quet QR'),
          ),
        ],
      ),
    );
  }
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
