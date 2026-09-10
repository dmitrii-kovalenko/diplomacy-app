import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../lobby/lobby_screen.dart';

/// One question, asked once. Onboarding stays a single step: no carousel, no
/// permission requests up front, and the primary action is disabled rather
/// than erroring when the field is empty.
class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _nicknameController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(() => setState(() {}));
  }

  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _authService.setNickname(nickname);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.nicknameSaveError,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;
    final canContinue = _nicknameController.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.huge),
              Text(loc.nicknamePromptTitle, style: t.displayMedium),
              const SizedBox(height: AppSpacing.md),
              Text(
                loc.nicknamePromptSubtitle,
                style: t.bodyLarge?.copyWith(color: c.labelSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              TextField(
                controller: _nicknameController,
                autofocus: true,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _saveNickname(),
                cursorColor: c.accent,
                maxLength: 24,
                style: t.headlineSmall,
                decoration: const InputDecoration(
                  // A fixed historical name, kept as the placeholder in every
                  // locale rather than translated — see T13's decision.
                  hintText: 'Talleyrand',
                  counterText: '',
                ),
              ),
              const Spacer(),
              AppButton(loc.nicknameContinueButton,
                  loading: _isLoading,
                  onPressed: canContinue ? _saveNickname : null),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
