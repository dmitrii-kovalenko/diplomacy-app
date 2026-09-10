import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';

import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
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
        fullCode += '-${base64Encode(utf8.encode(keyStr))}';
      }

      await Clipboard.setData(ClipboardData(text: fullCode));

      if (!mounted) return;
      showToast(context, AppLocalizations.of(context)!.linkCodeGeneratedToast);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.linkGenerateError,
            isError: true);
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
      
      var keyImported = parts.length <= 1; // nothing to import isn't a failure
      if (parts.length > 1) {
        try {
          final jwkStr = utf8.decode(base64Decode(parts[1]));
          await _e2eeService.importKey(jwkStr);
          keyImported = true;
        } catch (_) {
          keyImported = false;
        }
      }

      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      showToast(
        context,
        keyImported
            ? loc.linkAccountsLinkedToast
            : loc.linkAccountsLinkedKeyUnreadableToast,
        isError: !keyImported,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      // `??` only short-circuits when the server actually sent an `error`
      // field; a timeout or a 502 HTML body falls through to the lookup, and
      // this screen navigates away on success — so guard before touching the
      // element tree, not just before the toast.
      if (!mounted) return;
      final msg = e.response?.data?['error'] ??
          AppLocalizations.of(context)!.linkFailedGeneric;
      showToast(context, msg.toString(), isError: true);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.linkFailedGeneric,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsLinkedDevicesTitle)),
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
                0: _segment(context, loc.linkShowCodeSegment, _mode == 0),
                1: _segment(context, loc.linkEnterCodeSegment, _mode == 1),
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
    final loc = AppLocalizations.of(context)!;

    return Column(
      key: const ValueKey('generate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.linkGenerateInstructions,
          style: t.bodyMedium?.copyWith(color: c.labelSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          loc.linkGenerateButton,
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
    final loc = AppLocalizations.of(context)!;
    final ready = _codeController.text.trim().split('-')[0].length == 6;

    return Column(
      key: const ValueKey('enter'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.linkEnterInstructions,
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
            autocorrect: false,
            cursorColor: c.accent,
            // The 6-char code is uppercase-only (and normalised with
            // .toUpperCase() before it's sent — see _mergeAccount), but the
            // E2EE key appended after it is case-sensitive base64: an
            // earlier version of this field force-uppercased everything
            // typed or natively pasted here, silently corrupting that key
            // on every merge that carried one. `/` was also missing from
            // the allowed character set, which corrupted it a second way.
            // Never transform case, and allow the full base64 alphabet.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-=_+/]')),
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
          loc.linkPasteButton,
          onPressed: () async {
            final data = await Clipboard.getData('text/plain');
            if (data != null && data.text != null) {
              _codeController.text = data.text!;
              _mergeAccount();
            }
          },
          style: AppButtonStyle.tinted,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          loc.linkThisDeviceButton,
          loading: _isMerging,
          onPressed: ready ? _mergeAccount : null,
        ),

      ],
    );
  }
}
