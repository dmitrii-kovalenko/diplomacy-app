import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../auth/login_screen.dart';

/// Linking a second device.
///
/// A sliding segmented control replaces the tab bar — this is one screen with
/// two modes, not two destinations. The generated code is the hero: display
/// size, tabular figures, tracked out, with the countdown directly beneath it.
class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();

  int _mode = 0; // 0 = show a code, 1 = enter one
bool _isGenerating = false;
  bool _isMerging = false;
  final E2EEService _e2eeService = E2EEService();
  


  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isGenerating = true;
    });
    try {
      final res = await _authService.dio.post('/api/auth/link/generate/');
      final data = res.data;
      
      await _e2eeService.init();
      final keyStr = await _e2eeService.exportKey();
      String fullCode = data['code'];
      if (keyStr != null) {
        fullCode += '-' + base64Encode(utf8.encode(keyStr));
      }
      
      await Clipboard.setData(ClipboardData(text: fullCode));
      
      if (!mounted) return;
      showToast(context, 'Code generated and copied to clipboard');
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not generate a code.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _mergeAccount() async {
    final input = _codeController.text.trim();
    final parts = input.split('-');
    final code = parts[0].toUpperCase();
    if (code.length != 6) return;

    setState(() => _isMerging = true);
    try {
      final res = await _authService.dio
          .post('/api/auth/link/merge/', data: {'code': code});
      await _authService.saveTokens(res.data);
      
      if (parts.length > 1) {
        try {
          final jwkStr = utf8.decode(base64Decode(parts[1]));
          await _e2eeService.importKey(jwkStr);
        } catch (_) {}
      }
      
      if (!mounted) return;
      showToast(context, 'Accounts linked. Sign in once more to finish.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Linking failed.';
      if (mounted) showToast(context, msg.toString(), isError: true);
    } catch (e) {
      if (mounted) showToast(context, 'Linking failed. $e', isError: true);
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Linked devices')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _mode,
              backgroundColor: c.fill,
              thumbColor: c.bgRaised,
              padding: const EdgeInsets.all(3),
              onValueChanged: (v) => setState(() => _mode = v ?? 0),
              children: {
                0: _segment(context, 'Show a code', _mode == 0),
                1: _segment(context, 'Enter a code', _mode == 1),
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.standard,
            child: _mode == 0 ? _generatePane() : _enterPane(),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, bool selected) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? c.labelPrimary : c.labelSecondary,
            ),
      ),
    );
  }

  Widget _generatePane() {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('generate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Generate a code here, then paste it on your other device.',
          style: t.bodyMedium?.copyWith(color: c.labelSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          'Generate & Copy Code',
          style: AppButtonStyle.filled,
          loading: _isGenerating,
          onPressed: _generateCode,
        ),
      ],
    );
  }

  Widget _enterPane() {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final ready = _codeController.text.trim().split('-')[0].length == 6;

    return Column(
      key: const ValueKey('enter'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the six-character code shown on your other device.',
          style: t.bodyMedium?.copyWith(color: c.labelSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: AppRadius.brLg,
            border: Border.all(color: c.separator, width: AppMetrics.hairline),
          ),
          child: TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            cursorColor: c.accent,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-\=\_\+]')),
              TextInputFormatter.withFunction(
                  (_, next) => next.copyWith(text: next.text.toUpperCase())),
            ],
            style: t.displayMedium?.copyWith(
              letterSpacing: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: t.displayMedium
                  ?.copyWith(color: c.labelQuaternary, letterSpacing: 10),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          'Link this device',
          loading: _isMerging,
          onPressed: ready ? _mergeAccount : null,
        ),

      ],
    );
  }
}
