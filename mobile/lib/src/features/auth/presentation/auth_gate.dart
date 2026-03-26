import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'register_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.authenticatedBuilder,
  });

  final AuthService authService;
  final WidgetBuilder authenticatedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final hasSession = await widget.authService.hasSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _authenticated = hasSession;
      _loading = false;
    });
  }

  void _handleRegistered() {
    setState(() {
      _authenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_authenticated) {
      return widget.authenticatedBuilder(context);
    }

    return RegisterScreen(
      authService: widget.authService,
      onRegistered: _handleRegistered,
    );
  }
}
