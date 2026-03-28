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
  });

  final AttendantCheckInService attendantCheckInService;
  final AttendantScannerBuilder scannerBuilder;
  final AttendantImageCapture captureOverviewImage;
  final AttendantImageCapture capturePlateImage;
  final Future<void> Function()? onSignOut;
  final bool startInWalkInMode;

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
        return 'Dang tao phien walk-in...';
      }
      if (_scannerFlow == _AttendantScannerFlow.checkOut &&
          _lastCheckOutFinalize != null) {
        return 'Dang hoan tac giao dich...';
      }
      if (_scannerFlow == _AttendantScannerFlow.checkOut &&
          _lastCheckOutPreview != null) {
        return 'Dang chot thanh toan...';
      }
      return _scannerFlow == _AttendantScannerFlow.checkOut
          ? 'Dang tinh phi check-out...'
          : 'Dang xac nhan ma check-in...';
    }
    if (_mode == _AttendantGateMode.walkIn) {
      return 'San sang tao phien walk-in';
    }
    if (_scannerFlow == _AttendantScannerFlow.checkOut &&
        _lastCheckOutPreview != null) {
      return 'Vuot trai hoac phai de chot thanh toan';
    }
    return _scannerFlow == _AttendantScannerFlow.checkOut
        ? 'San sang quet xe ra bai'
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
                : _scannerFlow == _AttendantScannerFlow.checkOut
                ? 'Quet ma check-out'
                : 'Quét mã check-in',
          ),
          actions: [
            IconButton(
              key: const ValueKey('active-session-management-button'),
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'Phien ton',
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
              final operationPanelHeight = (constraints.maxHeight * 0.34).clamp(
                180.0,
                280.0,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _statusLabel,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _OccupancySummaryPanel(
                      isLoading: _isLoadingOccupancy,
                      summary: _occupancySummary,
                      errorMessage: _occupancyErrorMessage,
                      onRefresh: _reloadOccupancySummary,
                      vehicleTypeLabel: _vehicleTypeLabel,
                    ),
                    const SizedBox(height: 16),
                    if (_mode == _AttendantGateMode.scanner) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _ScannerModeButton(
                              key: const ValueKey('attendant-check-in-mode'),
                              label: 'Xe vao',
                              isSelected:
                                  _scannerFlow == _AttendantScannerFlow.checkIn,
                              onPressed: () => _selectScannerFlow(
                                _AttendantScannerFlow.checkIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScannerModeButton(
                              key: const ValueKey('attendant-check-out-mode'),
                              label: 'Xe ra',
                              isSelected:
                                  _scannerFlow ==
                                  _AttendantScannerFlow.checkOut,
                              onPressed: () => _selectScannerFlow(
                                _AttendantScannerFlow.checkOut,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      height: operationPanelHeight,
                      child: _mode == _AttendantGateMode.scanner
                          ? _scannerFlow == _AttendantScannerFlow.checkOut &&
                                    _lastCheckOutPreview != null
                                ? _CheckOutSettlementZone(
                                    key: const ValueKey(
                                      'attendant-check-out-settlement-zone',
                                    ),
                                    preview: _lastCheckOutPreview!,
                                    isBusy: _isBusy,
                                    dragOffset: _settlementDragOffset,
                                    onDragStart: _handleSettlementDragStart,
                                    onDragUpdate: _handleSettlementDragUpdate,
                                    onDragEnd: _handleSettlementDragEnd,
                                    vehicleTypeLabel: _vehicleTypeLabel,
                                    formatCurrency: _formatCurrency,
                                  )
                                : DecoratedBox(
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
                    if (_mode == _AttendantGateMode.scanner &&
                        _scannerFlow == _AttendantScannerFlow.checkIn)
                      FilledButton.icon(
                        key: const ValueKey('walk-in-entry-button'),
                        onPressed: _isBusy ? null : _openWalkInMode,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Xe vang lai'),
                      ),
                    if (_mode == _AttendantGateMode.scanner &&
                        _scannerFlow == _AttendantScannerFlow.checkIn)
                      const SizedBox(height: 16),
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
                ),
              );
            },
          ),
        ),
      ),
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
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (summary == null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorMessage ?? 'Khong the tai thong ke bai xe.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => onRefresh(),
                child: const Text('Thu lai thong ke'),
              ),
            ],
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
                  tooltip: 'Lam moi thong ke',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!summary!.hasActiveCapacityConfig) ...[
              Text(
                'Chua cau hinh suc chua dang hoat dong',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Thong ke chi hien so xe dang gui theo loai cho den khi suc chua duoc cau hinh.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _OccupancyFact(
                    label: 'Da gui',
                    value:
                        '${summary!.occupiedCount}/${summary!.totalCapacity}',
                  ),
                  _OccupancyFact(
                    label: 'Con cho',
                    value: '${summary!.freeCount}',
                  ),
                  _OccupancyFact(
                    label: 'Tong suc chua',
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
                'Phien dang gui',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Khu vuc xu ly phien ton va timeout thu cong cho bai xe hien tai.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Lam moi danh sach'),
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
