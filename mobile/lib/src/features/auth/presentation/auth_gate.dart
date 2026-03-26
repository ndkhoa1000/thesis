import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.authenticatedBuilder,
  });

  final AuthService authService;
  final Widget Function(BuildContext context, AuthSession session)
  authenticatedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _showLogin = true;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await widget.authService.restoreSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
      _loading = false;
    });
  }

  void _handleAuthenticated(AuthSession session) {
    setState(() {
      _session = session;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session != null) {
      return widget.authenticatedBuilder(context, session);
    }

    if (_showLogin) {
      return LoginScreen(
        authService: widget.authService,
        onAuthenticated: _handleAuthenticated,
        onSwitchToRegister: () {
          setState(() {
            _showLogin = false;
          });
        },
      );
    }

    return RegisterScreen(
      authService: widget.authService,
      onAuthenticated: _handleAuthenticated,
      onSwitchToLogin: () {
        setState(() {
          _showLogin = true;
        });
      },
    );
  }
}
