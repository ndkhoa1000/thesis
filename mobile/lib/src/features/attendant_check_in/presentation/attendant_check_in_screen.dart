import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../shared/presentation/state_views.dart';
import '../data/attendant_check_in_service.dart';

typedef AttendantScannerBuilder =
    Widget Function(
      BuildContext context,
      Future<void> Function(String token) onDetect,
      bool isBusy,
    );

typedef AttendantImageCapture = Future<String?> Function();

enum _AttendantGateMode { scanner, walkIn }

enum _AttendantScannerFlow { checkIn, checkOut }

class AttendantCheckInScreen extends StatefulWidget {
  const AttendantCheckInScreen({
    super.key,
    required this.attendantCheckInService,
    this.scannerBuilder = defaultAttendantScannerBuilder,
    this.captureOverviewImage = defaultCaptureOverviewImage,
    this.capturePlateImage = defaultCapturePlateImage,
    this.onSignOut,
    this.startInWalkInMode = false,
    this.embeddedInShell = false,
    this.onParkingLotNameChanged,
  });

  final AttendantCheckInService attendantCheckInService;
  final AttendantScannerBuilder scannerBuilder;
  final AttendantImageCapture captureOverviewImage;
  final AttendantImageCapture capturePlateImage;
  final Future<void> Function()? onSignOut;
  final bool startInWalkInMode;
  final bool embeddedInShell;
  final ValueChanged<String?>? onParkingLotNameChanged;

  @override
  State<AttendantCheckInScreen> createState() => _AttendantCheckInScreenState();
}

class _AttendantCheckInScreenState extends State<AttendantCheckInScreen> {
  _AttendantGateMode _mode = _AttendantGateMode.scanner;
  _AttendantScannerFlow _scannerFlow = _AttendantScannerFlow.checkIn;
  bool _isBusy = false;
  bool _isLoadingOccupancy = true;
  String? _errorMessage;
  String? _occupancyErrorMessage;
  AttendantOccupancySummary? _occupancySummary;
  AttendantCheckInResult? _lastCheckInResult;
  AttendantCheckOutPreviewResult? _lastCheckOutPreview;
  AttendantCheckOutFinalizeResult? _lastCheckOutFinalize;
  AttendantCheckOutPreviewResult? _undoPreviewSnapshot;
  double _settlementDragOffset = 0;
  String _walkInVehicleType = 'MOTORBIKE';
  String? _overviewImagePath;
  String? _plateImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.startInWalkInMode) {
      _mode = _AttendantGateMode.walkIn;
    }
    _reloadOccupancySummary();
  }

  Future<void> _reloadOccupancySummary({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingOccupancy = true;
        _occupancyErrorMessage = null;
      });
    }

    try {
      final summary = await widget.attendantCheckInService
          .getOccupancySummary();
      if (!mounted) {
        return;
      }
      widget.onParkingLotNameChanged?.call(summary.parkingLotName);
      setState(() {
        _occupancySummary = summary;
        _occupancyErrorMessage = null;
        _isLoadingOccupancy = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _occupancyErrorMessage = error.message;
        _isLoadingOccupancy = false;
      });
    }
  }

  Future<void> _handleScan(String token) async {
    if (_scannerFlow == _AttendantScannerFlow.checkOut) {
      await _handleCheckOutScan(token);
      return;
    }

    await _handleCheckInScan(token);
  }

  Future<void> _handleCheckInScan(String token) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _lastCheckOutPreview = null;
      _lastCheckOutFinalize = null;
    });

    try {
      final result = await widget.attendantCheckInService.checkInDriver(
        token: token,
      );
      await _reloadOccupancySummary(showLoading: false);
      if (!mounted) return;
      setState(() {
        _lastCheckInResult = result;
        _isBusy = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastCheckInResult = null;
        _errorMessage = error.message;
        _isBusy = false;
      });
    }
  }

  Future<void> _handleCheckOutScan(String token) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _lastCheckInResult = null;
      _lastCheckOutFinalize = null;
    });

    try {
      final result = await widget.attendantCheckInService.checkOutPreview(
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _lastCheckOutPreview = result;
        _isBusy = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastCheckOutPreview = null;
        _errorMessage = error.message;
        _isBusy = false;
      });
    }
  }

  Future<void> _finalizeCheckOut(String paymentMethod) async {
    if (_isBusy || _lastCheckOutPreview == null) return;

    final preview = _lastCheckOutPreview!;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _lastCheckInResult = null;
      _settlementDragOffset = 0;
    });

    try {
      final result = await widget.attendantCheckInService.finalizeCheckOut(
        sessionId: preview.sessionId,
        paymentMethod: paymentMethod,
        quotedFinalFee: preview.finalFee,
      );
      await _reloadOccupancySummary(showLoading: false);
      if (!mounted) return;
      setState(() {
        _lastCheckOutFinalize = result;
        _undoPreviewSnapshot = preview;
        _lastCheckOutPreview = null;
        _isBusy = false;
      });
      _showUndoSnackBar(result);
    } on AttendantCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isBusy = false;
      });
    }
  }

  Future<void> _undoCheckOut() async {
    if (_isBusy ||
        _lastCheckOutFinalize == null ||
        _undoPreviewSnapshot == null) {
      return;
    }

    final finalized = _lastCheckOutFinalize!;
    final preview = _undoPreviewSnapshot!;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _settlementDragOffset = 0;
    });

    try {
      await widget.attendantCheckInService.undoCheckOut(
        sessionId: finalized.sessionId,
      );
      await _reloadOccupancySummary(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() {
        _lastCheckOutPreview = preview;
        _lastCheckOutFinalize = null;
        _undoPreviewSnapshot = null;
        _isBusy = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isBusy = false;
      });
    }
  }

  void _showUndoSnackBar(AttendantCheckOutFinalizeResult result) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          result.paymentMethod == 'CASH'
              ? 'Da ghi nhan tien mat cho ${result.licensePlate}'
              : 'Da xac nhan thanh toan online cho ${result.licensePlate}',
        ),
        action: SnackBarAction(
          label: 'Hoan tac',
          onPressed: () {
            _undoCheckOut();
          },
        ),
      ),
    );
  }

  void _handleSettlementDragStart(DragStartDetails details) {
    if (_isBusy) return;
    setState(() {
      _settlementDragOffset = 0;
    });
  }

  void _handleSettlementDragUpdate(DragUpdateDetails details) {
    if (_isBusy) return;
    setState(() {
      _settlementDragOffset += details.primaryDelta ?? 0;
    });
  }

  void _handleSettlementDragEnd(DragEndDetails details) {
    if (_isBusy) return;
    final dragOffset = _settlementDragOffset;
    setState(() {
      _settlementDragOffset = 0;
    });

    final velocity = details.primaryVelocity ?? 0;
    if (dragOffset <= -140 || velocity <= -600) {
      _finalizeCheckOut('CASH');
      return;
    }
    if (dragOffset >= 140 || velocity >= 600) {
      _finalizeCheckOut('ONLINE');
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
        _lastCheckInResult = null;
        _lastCheckOutPreview = null;
        _errorMessage = 'Cần chụp ảnh biển số trước khi tạo phiên vãng lai.';
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
      await _reloadOccupancySummary(showLoading: false);
      if (!mounted) return;
      setState(() {
        _lastCheckInResult = result;
        _lastCheckOutPreview = null;
        _isBusy = false;
        _mode = _AttendantGateMode.scanner;
        _scannerFlow = _AttendantScannerFlow.checkIn;
        _overviewImagePath = null;
        _plateImagePath = null;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastCheckInResult = null;
        _errorMessage = error.message;
        _isBusy = false;
      });
    }
  }

  void _openWalkInMode() {
    if (_isBusy) return;
    setState(() {
      _mode = _AttendantGateMode.walkIn;
      _scannerFlow = _AttendantScannerFlow.checkIn;
      _lastCheckInResult = null;
      _lastCheckOutPreview = null;
      _lastCheckOutFinalize = null;
      _undoPreviewSnapshot = null;
      _errorMessage = null;
    });
  }

  void _returnToScannerMode() {
    if (_isBusy) return;
    setState(() {
      _mode = _AttendantGateMode.scanner;
      _scannerFlow = _AttendantScannerFlow.checkIn;
      _overviewImagePath = null;
      _plateImagePath = null;
      _lastCheckOutFinalize = null;
      _undoPreviewSnapshot = null;
      _errorMessage = null;
    });
  }

  Future<void> _openActiveSessionManagement() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ActiveSessionManagementSheet(
        attendantCheckInService: widget.attendantCheckInService,
        vehicleTypeLabel: _vehicleTypeLabel,
        onTimeoutCompleted: () async {
          await _reloadOccupancySummary(showLoading: false);
        },
      ),
    );
  }

  Future<void> _openShiftHandover() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ShiftHandoverSheet(
        attendantCheckInService: widget.attendantCheckInService,
        scannerBuilder: widget.scannerBuilder,
        formatCurrency: _formatCurrency,
      ),
    );
  }

  void _selectScannerFlow(_AttendantScannerFlow flow) {
    if (_isBusy) return;
    setState(() {
      _mode = _AttendantGateMode.scanner;
      _scannerFlow = flow;
      _overviewImagePath = null;
      _plateImagePath = null;
      _errorMessage = null;
      _lastCheckInResult = null;
      _lastCheckOutPreview = null;
      _lastCheckOutFinalize = null;
      _undoPreviewSnapshot = null;
    });
  }

  String get _statusLabel {
    if (_isBusy) {
      if (_mode == _AttendantGateMode.walkIn) {
        return 'Đang tạo phiên vãng lai...';
      }
      if (_scannerFlow == _AttendantScannerFlow.checkOut &&
          _lastCheckOutFinalize != null) {
        return 'Đang hoàn tác giao dịch...';
      }
      if (_scannerFlow == _AttendantScannerFlow.checkOut &&
          _lastCheckOutPreview != null) {
        return 'Đang chốt thanh toán...';
      }
      return _scannerFlow == _AttendantScannerFlow.checkOut
          ? 'Đang tính phí xe ra...'
          : 'Đang xác nhận mã xe vào...';
    }
    if (_mode == _AttendantGateMode.walkIn) {
      return 'Sẵn sàng tạo phiên vãng lai';
    }
    if (_scannerFlow == _AttendantScannerFlow.checkOut &&
        _lastCheckOutPreview != null) {
      return 'Vuốt trái hoặc phải để chốt thanh toán';
    }
    return _scannerFlow == _AttendantScannerFlow.checkOut
        ? 'Sẵn sàng quét xe ra bãi'
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      child: Builder(
        builder: (context) {
          if (widget.embeddedInShell) {
            return _buildEmbeddedShellBody(context, colorScheme);
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                _mode == _AttendantGateMode.walkIn
                    ? 'Check-in vãng lai'
                    : _scannerFlow == _AttendantScannerFlow.checkOut
                    ? 'Quét mã xe ra'
                    : 'Quét mã xe vào',
              ),
              actions: [
                IconButton(
                  key: const ValueKey('shift-handover-button'),
                  icon: const Icon(Icons.qr_code_2_outlined),
                  tooltip: 'Bàn giao ca',
                  onPressed: _openShiftHandover,
                ),
                IconButton(
                  key: const ValueKey('active-session-management-button'),
                  icon: const Icon(Icons.fact_check_outlined),
                  tooltip: 'Phiên tồn',
                  onPressed: _openActiveSessionManagement,
                ),
                if (widget.onSignOut != null)
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Đăng xuất',
                    onPressed: widget.onSignOut,
                  ),
              ],
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final operationPanelHeight = (constraints.maxHeight * 0.26)
                      .clamp(150.0, 220.0);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusAndSummaryPanel(
                          context,
                          colorScheme,
                          includeQuickActions: false,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: operationPanelHeight,
                          child: _buildOperationSurface(context, colorScheme),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmbeddedShellBody(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                key: const ValueKey('attendant-shell-top-zone'),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                padding: const EdgeInsets.all(12),
                child: _buildOperationSurface(context, colorScheme),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                key: const ValueKey('attendant-shell-bottom-zone'),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: _buildStatusAndSummaryPanel(
                    context,
                    colorScheme,
                    includeQuickActions: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAndSummaryPanel(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool includeQuickActions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _statusLabel,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          textAlign: includeQuickActions ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (includeQuickActions) ...[
          _buildQuickActions(context),
          const SizedBox(height: 12),
        ],
        _OccupancySummaryPanel(
          isLoading: _isLoadingOccupancy,
          summary: _occupancySummary,
          errorMessage: _occupancyErrorMessage,
          onRefresh: _reloadOccupancySummary,
          vehicleTypeLabel: _vehicleTypeLabel,
        ),
        const SizedBox(height: 12),
        if (_mode == _AttendantGateMode.scanner) ...[
          Row(
            children: [
              Expanded(
                child: _ScannerModeButton(
                  key: const ValueKey('attendant-check-in-mode'),
                  label: 'Xe vào',
                  isSelected: _scannerFlow == _AttendantScannerFlow.checkIn,
                  onPressed: () =>
                      _selectScannerFlow(_AttendantScannerFlow.checkIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScannerModeButton(
                  key: const ValueKey('attendant-check-out-mode'),
                  label: 'Xe ra',
                  isSelected: _scannerFlow == _AttendantScannerFlow.checkOut,
                  onPressed: () =>
                      _selectScannerFlow(_AttendantScannerFlow.checkOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_mode == _AttendantGateMode.scanner &&
            _scannerFlow == _AttendantScannerFlow.checkIn) ...[
          FilledButton.icon(
            key: const ValueKey('walk-in-entry-button'),
            onPressed: _isBusy ? null : _openWalkInMode,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Xe vãng lai'),
          ),
          const SizedBox(height: 12),
        ],
        if (_errorMessage != null)
          _FeedbackCard(
            title: 'Quét thất bại',
            message: _errorMessage!,
            color: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
        if (_lastCheckInResult != null)
          _FeedbackCard(
            title: 'Check-in thành công',
            message:
                '${_lastCheckInResult!.licensePlate}\n${_vehicleTypeLabel(_lastCheckInResult!.vehicleType)}\nCòn ${_lastCheckInResult!.currentAvailable} chỗ trong bãi',
            color: const Color(0xFF003B1F),
            foregroundColor: const Color(0xFFB9F6CA),
          ),
        if (_lastCheckOutPreview != null &&
            !(_mode == _AttendantGateMode.scanner &&
                _scannerFlow == _AttendantScannerFlow.checkOut))
          _CheckOutPreviewCard(
            preview: _lastCheckOutPreview!,
            vehicleTypeLabel: _vehicleTypeLabel,
            formatCurrency: _formatCurrency,
          ),
        if (_lastCheckOutFinalize != null)
          _FeedbackCard(
            title: 'Hoan tat xe ra',
            message:
                '${_lastCheckOutFinalize!.licensePlate}\n${_paymentMethodLabel(_lastCheckOutFinalize!.paymentMethod)}\nCon ${_lastCheckOutFinalize!.currentAvailable} cho trong bai',
            color: const Color(0xFF003B1F),
            foregroundColor: const Color(0xFFB9F6CA),
          ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('shift-handover-button'),
          onPressed: _openShiftHandover,
          icon: const Icon(Icons.qr_code_2_outlined),
          label: const Text('Bàn giao ca'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('active-session-management-button'),
          onPressed: _openActiveSessionManagement,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Phiên tồn'),
        ),
        if (widget.onSignOut != null)
          OutlinedButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
      ],
    );
  }

  Widget _buildOperationSurface(BuildContext context, ColorScheme colorScheme) {
    if (_mode == _AttendantGateMode.scanner) {
      if (_scannerFlow == _AttendantScannerFlow.checkOut &&
          _lastCheckOutPreview != null) {
        return _CheckOutSettlementZone(
          key: const ValueKey('attendant-check-out-settlement-zone'),
          preview: _lastCheckOutPreview!,
          isBusy: _isBusy,
          dragOffset: _settlementDragOffset,
          onDragStart: _handleSettlementDragStart,
          onDragUpdate: _handleSettlementDragUpdate,
          onDragEnd: _handleSettlementDragEnd,
          vehicleTypeLabel: _vehicleTypeLabel,
          formatCurrency: _formatCurrency,
        );
      }

      return DecoratedBox(
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
          child: widget.scannerBuilder(context, _handleScan, _isBusy),
        ),
      );
    }

    return _WalkInPanel(
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
    );
  }

  String _vehicleTypeLabel(String vehicleType) {
    return vehicleType.toUpperCase() == 'CAR' ? 'Ô tô' : 'Xe máy';
  }

  String _formatCurrency(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index += 1) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()} VND';
  }

  String _paymentMethodLabel(String paymentMethod) {
    return paymentMethod == 'CASH'
        ? 'Da thu tien mat'
        : 'Da xac nhan thanh toan online';
  }
}

class _ScannerModeButton extends StatelessWidget {
  const _ScannerModeButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    if (isSelected) {
      return FilledButton(onPressed: onPressed, child: child);
    }

    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _OccupancySummaryPanel extends StatelessWidget {
  const _OccupancySummaryPanel({
    required this.isLoading,
    required this.summary,
    required this.errorMessage,
    required this.onRefresh,
    required this.vehicleTypeLabel,
  });

  final bool isLoading;
  final AttendantOccupancySummary? summary;
  final String? errorMessage;
  final Future<void> Function({bool showLoading}) onRefresh;
  final String Function(String vehicleType) vehicleTypeLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LoadingView(
            title: 'Đang tải thống kê bãi xe',
            message: 'Sức chứa hiện tại sẽ được cập nhật sau ít giây.',
            tone: StateViewTone.dark,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }

    if (summary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorView(
            title: 'Không tải được thống kê bãi xe',
            message: errorMessage ?? 'Không thể tải thống kê bãi xe.',
            onRetry: onRefresh,
            tone: StateViewTone.dark,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }

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
                    summary!.parkingLotName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onRefresh(showLoading: false),
                  tooltip: 'Làm mới thống kê',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!summary!.hasActiveCapacityConfig) ...[
              Text(
                'Chưa cấu hình sức chứa đang hoạt động',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Thống kê hiện chỉ hiển thị số xe đang gửi theo loại cho đến khi sức chứa được cấu hình.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _OccupancyFact(
                    label: 'Đã gửi',
                    value:
                        '${summary!.occupiedCount}/${summary!.totalCapacity}',
                  ),
                  _OccupancyFact(
                    label: 'Còn chỗ',
                    value: '${summary!.freeCount}',
                  ),
                  _OccupancyFact(
                    label: 'Tổng sức chứa',
                    value: '${summary!.totalCapacity}',
                  ),
                ],
              ),
            ],
            if (summary!.vehicleTypeBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary!.vehicleTypeBreakdown
                    .map(
                      (item) => Chip(
                        label: Text(
                          '${vehicleTypeLabel(item.vehicleType)}: ${item.occupiedCount}',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OccupancyFact extends StatelessWidget {
  const _OccupancyFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            key: ValueKey('occupancy-fact-$label'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionManagementSheet extends StatefulWidget {
  const _ActiveSessionManagementSheet({
    required this.attendantCheckInService,
    required this.vehicleTypeLabel,
    required this.onTimeoutCompleted,
  });

  final AttendantCheckInService attendantCheckInService;
  final String Function(String vehicleType) vehicleTypeLabel;
  final Future<void> Function() onTimeoutCompleted;

  @override
  State<_ActiveSessionManagementSheet> createState() =>
      _ActiveSessionManagementSheetState();
}

class _ActiveSessionManagementSheetState
    extends State<_ActiveSessionManagementSheet> {
  late Future<List<AttendantActiveSession>> _activeSessionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _activeSessionsFuture = widget.attendantCheckInService
          .getActiveSessions();
    });
  }

  String _elapsedLabel(int elapsedMinutes) {
    if (elapsedMinutes < 60) {
      return '$elapsedMinutes phut';
    }
    final hours = elapsedMinutes ~/ 60;
    final minutes = elapsedMinutes % 60;
    if (minutes == 0) {
      return '$hours gio';
    }
    return '$hours gio $minutes phut';
  }

  Future<void> _openForceCloseForm(AttendantActiveSession session) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ForceCloseTimeoutFormSheet(
        licensePlate: session.licensePlate,
        onSubmit: (reason) async {
          try {
            final result = await widget.attendantCheckInService
                .forceCloseTimeout(
                  sessionId: session.sessionId,
                  reason: reason,
                );
            if (!mounted || !sheetContext.mounted) {
              return;
            }
            Navigator.of(sheetContext).pop();
            await widget.onTimeoutCompleted();
            _reload();
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Da timeout phien ${result.licensePlate}. Con ${result.currentAvailable} cho trong bai.',
                ),
              ),
            );
          } on AttendantCheckInException catch (error) {
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
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phiên đang gửi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Khu vực xử lý phiên tồn và timeout thủ công cho bãi xe hiện tại.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới danh sách'),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<AttendantActiveSession>>(
                  future: _activeSessionsFuture,
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

                    final sessions =
                        snapshot.data ?? const <AttendantActiveSession>[];
                    if (sessions.isEmpty) {
                      return const Center(
                        child: Text(
                          'Khong con phien dang gui nao can xu ly.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.licensePlate,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.vehicleTypeLabel(session.vehicleType),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dang gui: ${_elapsedLabel(session.elapsedMinutes)}',
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _openForceCloseForm(session),
                                    icon: const Icon(Icons.gpp_bad_outlined),
                                    label: const Text('Timeout phien'),
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

class _ForceCloseTimeoutFormSheet extends StatefulWidget {
  const _ForceCloseTimeoutFormSheet({
    required this.licensePlate,
    required this.onSubmit,
  });

  final String licensePlate;
  final Future<void> Function(String reason) onSubmit;

  @override
  State<_ForceCloseTimeoutFormSheet> createState() =>
      _ForceCloseTimeoutFormSheetState();
}

class _ForceCloseTimeoutFormSheetState
    extends State<_ForceCloseTimeoutFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
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
      await widget.onSubmit(_reasonController.text.trim());
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
                  'Timeout phien ${widget.licensePlate}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nhap ly do bat buoc truoc khi giai phong suc chua cho phien bi ket.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Ly do timeout bat buoc',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Ly do timeout la bat buoc';
                    }
                    if (trimmed.length < 5) {
                      return 'Ly do timeout phai co it nhat 5 ky tu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.warning_amber_outlined),
                    label: Text(
                      _isSubmitting ? 'Dang xu ly...' : 'Xac nhan timeout',
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

class _ShiftHandoverSheet extends StatefulWidget {
  const _ShiftHandoverSheet({
    required this.attendantCheckInService,
    required this.scannerBuilder,
    required this.formatCurrency,
  });

  final AttendantCheckInService attendantCheckInService;
  final AttendantScannerBuilder scannerBuilder;
  final String Function(double amount) formatCurrency;

  @override
  State<_ShiftHandoverSheet> createState() => _ShiftHandoverSheetState();
}

class _ShiftHandoverSheetState extends State<_ShiftHandoverSheet> {
  final _actualCashController = TextEditingController();
  bool _isPreparing = false;
  bool _isCloseOutSubmitting = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _detectedToken;
  AttendantFinalShiftCloseOutResult? _closeOutResult;
  AttendantShiftHandoverStartResult? _startResult;
  AttendantShiftHandoverFinalizeResult? _finalizeResult;

  @override
  void dispose() {
    _actualCashController.dispose();
    super.dispose();
  }

  double? _parseActualCash() {
    final digitsOnly = _actualCashController.text.replaceAll(
      RegExp(r'[^0-9.]'),
      '',
    );
    if (digitsOnly.isEmpty) {
      return null;
    }
    return double.tryParse(digitsOnly);
  }

  Future<void> _prepareHandover() async {
    if (_isPreparing) {
      return;
    }
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.attendantCheckInService
          .prepareShiftHandover();
      if (!mounted) {
        return;
      }
      setState(() {
        _startResult = result;
        _isPreparing = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isPreparing = false;
      });
    }
  }

  Future<void> _requestFinalShiftCloseOut() async {
    if (_isCloseOutSubmitting) {
      return;
    }
    setState(() {
      _isCloseOutSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.attendantCheckInService
          .requestFinalShiftCloseOut();
      if (!mounted) {
        return;
      }
      setState(() {
        _closeOutResult = result;
        _isCloseOutSubmitting = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isCloseOutSubmitting = false;
      });
    }
  }

  Future<void> _handleTokenDetected(String token) async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _detectedToken = token;
      _errorMessage = null;
    });
  }

  Future<void> _submitHandover({String? discrepancyReason}) async {
    final token = _detectedToken;
    final actualCash = _parseActualCash();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'Can quet Shift QR truoc khi nhan ca.';
      });
      return;
    }
    if (actualCash == null) {
      setState(() {
        _errorMessage = 'Can nhap so tien mat da kiem dem.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.attendantCheckInService.finalizeShiftHandover(
        token: token,
        actualCash: actualCash,
        discrepancyReason: discrepancyReason,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _finalizeResult = result;
        _isSubmitting = false;
      });
    } on AttendantCheckInException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.message.contains('Discrepancy reason is required')) {
        final rationale = await showGeneralDialog<String>(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'Bao cao chenh lech giao ca',
          pageBuilder: (context, _, _) => _ShiftDiscrepancyDialog(
            actualCash: actualCash,
            onSubmit: (value) => Navigator.of(context).pop(value),
          ),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _isSubmitting = false;
        });
        if (rationale != null && rationale.trim().isNotEmpty) {
          await _submitHandover(discrepancyReason: rationale.trim());
        }
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelTheme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bàn giao ca', style: panelTheme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Khu vực quản trị ca trực tách riêng giao ca QR và đóng ca cuối ngày.',
                  style: panelTheme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đóng ca cuối ngày',
                          style: panelTheme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chỉ dùng cho ca cuối cùng trong ngày. Hệ thống sẽ khóa ca, đối chiếu tiền mặt và gửi đơn vị vận hành xác nhận kết thúc ngày vận hành.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey(
                            'request-final-shift-close-out-button',
                          ),
                          onPressed: _isCloseOutSubmitting
                              ? null
                              : _requestFinalShiftCloseOut,
                          icon: const Icon(Icons.nightlight_round),
                          label: Text(
                            _isCloseOutSubmitting
                                ? 'Đang gửi đóng ca...'
                                : 'Gửi đóng ca cuối ngày',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_closeOutResult != null) ...[
                  const SizedBox(height: 16),
                  _FeedbackCard(
                    title: 'Đã gửi đóng ca cuối ngày',
                    message:
                        'Tiền mặt đối chiếu ${widget.formatCurrency(_closeOutResult!.expectedCash)}\nĐang chờ đơn vị vận hành xác nhận kết thúc ngày vận hành.',
                    color: const Color(0xFF102A43),
                    foregroundColor: const Color(0xFFDCEEFB),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendant ban giao',
                          style: panelTheme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ket thuc ca hien tai, khoa tong tien mat ky vong va tao QR de nhan vien tiep ca quet.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey(
                            'generate-shift-handover-qr-button',
                          ),
                          onPressed: _isPreparing ? null : _prepareHandover,
                          icon: const Icon(Icons.qr_code_2),
                          label: Text(
                            _isPreparing ? 'Dang tao QR...' : 'Tao QR giao ca',
                          ),
                        ),
                        if (_startResult != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Tien mat ky vong: ${widget.formatCurrency(_startResult!.expectedCash)}',
                            style: panelTheme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: QrImageView(
                              key: const ValueKey('shift-handover-qr'),
                              data: _startResult!.token,
                              version: QrVersions.auto,
                              size: 210,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendant nhan ca',
                          style: panelTheme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Quet Shift QR, kiem dem tien mat thuc te va hoan tat nhan ca. Neu lech, he thong buoc phai bao cao ly do.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: panelTheme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: widget.scannerBuilder(
                                context,
                                _handleTokenDetected,
                                _isSubmitting,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_detectedToken != null)
                          const Chip(label: Text('Da quet Shift QR')),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey(
                            'shift-handover-actual-cash-field',
                          ),
                          controller: _actualCashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tien mat thuc te (VND)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('finalize-shift-handover-button'),
                          onPressed: _isSubmitting ? null : _submitHandover,
                          icon: const Icon(Icons.lock_clock_outlined),
                          label: Text(
                            _isSubmitting
                                ? 'Dang khoa ca...'
                                : 'Hoan tat giao ca',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _FeedbackCard(
                    title: 'Bàn giao ca thất bại',
                    message: _errorMessage!,
                    color: panelTheme.colorScheme.errorContainer,
                    foregroundColor: panelTheme.colorScheme.onErrorContainer,
                  ),
                ],
                if (_finalizeResult != null) ...[
                  const SizedBox(height: 16),
                  _FeedbackCard(
                    title: _finalizeResult!.discrepancyFlagged
                        ? 'Đã khóa ca và báo cáo chênh lệch'
                        : 'Bàn giao ca thành công',
                    message:
                        'Expected ${widget.formatCurrency(_finalizeResult!.expectedCash)}\nActual ${widget.formatCurrency(_finalizeResult!.actualCash)}',
                    color: _finalizeResult!.discrepancyFlagged
                        ? const Color(0xFF4A1A00)
                        : const Color(0xFF003B1F),
                    foregroundColor: _finalizeResult!.discrepancyFlagged
                        ? const Color(0xFFFFD180)
                        : const Color(0xFFB9F6CA),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShiftDiscrepancyDialog extends StatefulWidget {
  const _ShiftDiscrepancyDialog({
    required this.actualCash,
    required this.onSubmit,
  });

  final double actualCash;
  final ValueChanged<String> onSubmit;

  @override
  State<_ShiftDiscrepancyDialog> createState() =>
      _ShiftDiscrepancyDialogState();
}

class _ShiftDiscrepancyDialogState extends State<_ShiftDiscrepancyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF220909),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFB300),
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bao cao chenh lech giao ca',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'He thong phat hien chenh lech tien mat. Ban khong the dong man hinh nay neu chua nhap ly do va gui bao cao.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'So tien kiem dem: ${widget.actualCash.toStringAsFixed(0)} VND',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFFD180),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('shift-discrepancy-reason-field'),
                    controller: _reasonController,
                    minLines: 4,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Ly do chenh lech bat buoc',
                    ),
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return 'Ly do chenh lech la bat buoc';
                      }
                      if (trimmed.length < 5) {
                        return 'Ly do chenh lech phai co it nhat 5 ky tu';
                      }
                      return null;
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('submit-shift-discrepancy-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD84315),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_formKey.currentState?.validate() != true) {
                          return;
                        }
                        widget.onSubmit(_reasonController.text.trim());
                      },
                      child: const Text('Gui bao cao va khoa ca'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
            'Check-in vãng lai',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'MOTORBIKE', label: Text('Xe máy')),
              ButtonSegment(value: 'CAR', label: Text('Ô tô')),
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
                  ? 'Chụp ảnh toàn cảnh'
                  : 'Đã chụp ảnh toàn cảnh',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isBusy ? null : onCapturePlateImage,
            child: Text(
              plateImagePath == null
                  ? 'Chụp ảnh biển số'
                  : 'Đã chụp ảnh biển số',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isBusy ? null : onSubmit,
            child: const Text('Tạo phiên vãng lai'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isBusy ? null : onBack,
            child: const Text('Quay lại quét QR'),
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

class _CheckOutPreviewCard extends StatelessWidget {
  const _CheckOutPreviewCard({
    required this.preview,
    required this.vehicleTypeLabel,
    required this.formatCurrency,
  });

  final AttendantCheckOutPreviewResult preview;
  final String Function(String vehicleType) vehicleTypeLabel;
  final String Function(double amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101F16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview.licensePlate,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              preview.parkingLotName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${vehicleTypeLabel(preview.vehicleType)} • ${preview.elapsedMinutes} phut',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              formatCurrency(preview.finalFee),
              key: const ValueKey('attendant-check-out-amount'),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: const Color(0xFFB9F6CA),
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tinh theo ${preview.pricingMode}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckOutSettlementZone extends StatelessWidget {
  const _CheckOutSettlementZone({
    super.key,
    required this.preview,
    required this.isBusy,
    required this.dragOffset,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.vehicleTypeLabel,
    required this.formatCurrency,
  });

  final AttendantCheckOutPreviewResult preview;
  final bool isBusy;
  final double dragOffset;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final String Function(String vehicleType) vehicleTypeLabel;
  final String Function(double amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final hint = dragOffset <= -40
        ? 'Tha tay de thu tien mat'
        : dragOffset >= 40
        ? 'Tha tay de xac nhan online'
        : 'Vuot trai: Tien mat • Vuot phai: Online';

    return Semantics(
      label: 'Swipe to Pay Cash or Online',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: isBusy ? null : onDragStart,
        onHorizontalDragUpdate: isBusy ? null : onDragUpdate,
        onHorizontalDragEnd: isBusy ? null : onDragEnd,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF07140E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF00E676), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CheckOutPreviewCard(
                    preview: preview,
                    vehicleTypeLabel: vehicleTypeLabel,
                    formatCurrency: formatCurrency,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Khong can ban phim. Quet xong, vuot de chot.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
