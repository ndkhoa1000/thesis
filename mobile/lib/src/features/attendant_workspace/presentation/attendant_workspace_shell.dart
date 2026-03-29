import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';
import '../../attendant_check_in/data/attendant_check_in_service.dart';
import '../../attendant_check_in/presentation/attendant_check_in_screen.dart';

class AttendantWorkspaceShell extends StatefulWidget {
  const AttendantWorkspaceShell({
    super.key,
    required this.attendantCheckInService,
    required this.scannerBuilder,
    this.onSignOut,
  });

  final AttendantCheckInService attendantCheckInService;
  final AttendantScannerBuilder scannerBuilder;
  final Future<void> Function()? onSignOut;

  @override
  State<AttendantWorkspaceShell> createState() =>
      _AttendantWorkspaceShellState();
}

class _AttendantWorkspaceShellState extends State<AttendantWorkspaceShell> {
  String? _parkingLotName;

  void _handleParkingLotNameChanged(String? parkingLotName) {
    final normalized = parkingLotName?.trim();
    if (_parkingLotName == normalized) {
      return;
    }

    setState(() {
      _parkingLotName = normalized == null || normalized.isEmpty
          ? null
          : normalized;
    });
  }

  String get _headerLabel {
    final parkingLotName = _parkingLotName;
    if (parkingLotName == null || parkingLotName.isEmpty) {
      return 'BÃI XE — CHƯA GÁN';
    }
    return 'BÃI XE — $parkingLotName';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Color(0xFF121212),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Builder(
          builder: (context) {
            final topInset = MediaQuery.paddingOf(context).top;

            return Scaffold(
              backgroundColor: const Color(0xFF121212),
              body: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      key: const ValueKey('attendant-shell-header'),
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFF121212),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                      ),
                      child: Text(
                        _headerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AttendantCheckInScreen(
                        attendantCheckInService: widget.attendantCheckInService,
                        scannerBuilder: widget.scannerBuilder,
                        onSignOut: widget.onSignOut,
                        embeddedInShell: true,
                        onParkingLotNameChanged: _handleParkingLotNameChanged,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
