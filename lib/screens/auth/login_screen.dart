import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'register_screen.dart';
import '../lobby/lobby_screen.dart';
import 'nickname_screen.dart';

/// Sign-in.
///
/// The identity leads, the platform buttons come first (they are what most
/// people will use), and the email form sits below a quiet rule — present,
/// but not the default path. Nothing here has a border heavier than a
/// hairline and there is exactly one filled capsule on the screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _run(Future<void> Function() action, String failureLabel) async {
    setState(() => _isLoading = true);
    try {
      await action();
      await _checkNicknameAndProceed();
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return;
      showToast(context, failureLabel, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _login() {
    final loc = AppLocalizations.of(context)!;
    _run(
        () => _authService.login(
            _emailController.text, _passwordController.text),
        loc.authSignInFailed);
  }

  void _loginWithGoogle() => _run(
      _authService.loginWithGoogle, AppLocalizations.of(context)!.authGoogleSignInFailed);

  void _loginWithApple() => _run(
      _authService.loginWithApple, AppLocalizations.of(context)!.authAppleSignInFailed);

  Future<void> _checkNicknameAndProceed() async {
    try {
      final me = await _authService.fetchMe();
      if (!mounted) return;
      if (me['nickname'] == null || me['nickname'].toString().isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NicknameScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.authProfileLoadError,
            isError: true);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter, vertical: AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const _Wordmark(),
                  const SizedBox(height: AppSpacing.huge),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
                      child: AppLoader(label: loc.authSigningIn),
                    )
                  else ...[
                    SignInWithAppleButton(
                      onPressed: _loginWithApple,
                      text: loc.signInWithApple,
                      style: SignInWithAppleButtonStyle.white,
                      borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.capsule)),
                      height: AppMetrics.buttonHeight,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProviderButton(
                      label: loc.signInWithGoogle,
                      onPressed: _loginWithGoogle,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: c.separator,
                                thickness: AppMetrics.hairline)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          child: Text(loc.authOrDivider,
                              style: t.bodySmall
                                  ?.copyWith(color: c.labelTertiary)),
                        ),
                        Expanded(
                            child: Divider(
                                color: c.separator,
                                thickness: AppMetrics.hairline)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    InsetSection(
                      padding: EdgeInsets.zero,
                      children: [
                        _AuthField(
                          controller: _emailController,
                          label: loc.email,
                          hint: loc.authEmailHint,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        _AuthField(
                          controller: _passwordController,
                          label: loc.password,
                          hint: '••••••••',
                          obscure: true,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _login(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(loc.login, onPressed: _login),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      loc.createAnAccount,
                      style: AppButtonStyle.plain,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accentMuted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.accent.withOpacity(0.35), width: 1),
          ),
          child: Icon(Icons.handshake_outlined, size: 32, color: c.accent),
        ),
        const SizedBox(height: AppSpacing.xl),
        // 'Hegemony' is the brand name and stays untranslated in every locale.
        Text('Hegemony', style: t.displayLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          loc.authTagline,
          style: t.bodyLarge?.copyWith(color: c.labelSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Third-party sign-in button, matched to the Apple button's metrics so the
/// two stack as one block.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: AppMetrics.buttonHeight,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.brCapsule,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GoogleGlyph(),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF1F1F1F),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google's four-quadrant mark, drawn rather than shipped as an asset so it
/// stays crisp at any scale.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final centre = Offset(r, r);
    final stroke = size.width * 0.24;
    final rect = Rect.fromCircle(center: centre, radius: r - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    void arc(double startDeg, double sweepDeg, Color color) {
      paint.color = color;
      canvas.drawArc(rect, startDeg * 3.1415926 / 180,
          sweepDeg * 3.1415926 / 180, false, paint);
    }

    arc(-20, -70, const Color(0xFFEA4335)); // red
    arc(-90, -100, const Color(0xFF4285F4)); // blue
    arc(170, 80, const Color(0xFFFBBC05)); // yellow
    arc(90, 80, const Color(0xFF34A853)); // green

    // The blue crossbar of the "G".
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(r, r - stroke / 2, r - stroke * 0.1, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Field styled as a grouped-list row.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: t.bodyLarge?.copyWith(color: c.labelSecondary)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              autocorrect: false,
              enableSuggestions: !obscure,
              cursorColor: c.accent,
              style: t.bodyLarge,
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
