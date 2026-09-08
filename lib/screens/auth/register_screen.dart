import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Account creation.
///
/// Validation is inline and lives under the field it belongs to — an alert
/// for a mistyped password would be a blocking interruption for something the
/// person can see and fix in place.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _submitted = false;

  String? get _emailError {
    final v = _emailController.text.trim();
    if (v.isEmpty) return _submitted ? 'Enter your email address.' : null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'That does not look like an email address.';
    }
    return null;
  }

  String? get _passwordError {
    final v = _passwordController.text;
    if (v.isEmpty) return _submitted ? 'Choose a password.' : null;
    if (v.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  String? get _confirmError {
    if (_confirmPasswordController.text.isEmpty) return null;
    if (_confirmPasswordController.text != _passwordController.text) {
      return 'The two passwords do not match.';
    }
    return null;
  }

  bool get _isValid =>
      _emailError == null &&
      _passwordError == null &&
      _confirmError == null &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  Future<void> _register() async {
    setState(() => _submitted = true);
    if (!_isValid) return;

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        showToast(context, 'Account created — sign in to continue.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Registration failed. $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      _emailController,
      _passwordController,
      _confirmPasswordController
    ]) {
      ctrl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(loc.signUp)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Create your account', style: t.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'One account carries your games, your chats and your encryption '
            'keys across every device.',
            style: t.bodyMedium?.copyWith(color: c.labelSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _Field(
            controller: _emailController,
            label: loc.email,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            error: _emailError,
          ),
          _Field(
            controller: _passwordController,
            label: loc.password,
            hint: 'At least 8 characters',
            obscure: true,
            error: _passwordError,
          ),
          _Field(
            controller: _confirmPasswordController,
            label: loc.confirmPassword,
            obscure: true,
            error: _confirmError,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(loc.signUp, loading: _isLoading, onPressed: _register),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.error,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.xs),
            child: Text(label,
                style: t.labelMedium?.copyWith(color: c.labelSecondary)),
          ),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            autocorrect: false,
            enableSuggestions: !obscure,
            cursorColor: c.accent,
            decoration: InputDecoration(hintText: hint, errorText: error),
          ),
        ],
      ),
    );
  }
}
