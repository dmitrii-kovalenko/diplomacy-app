import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import '../lobby/lobby_screen.dart';
import 'nickname_screen.dart';

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

  void _login() async {
    setState(() => _isLoading = true);
    try {
      await _authService.login(
        _emailController.text,
        _passwordController.text,
      );
      await _checkNicknameAndProceed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.loginWithGoogle();
      await _checkNicknameAndProceed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      await _authService.loginWithApple();
      await _checkNicknameAndProceed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      // Error fetching me, might be token issue.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user info: $e')),
        );
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
    return Scaffold(
      appBar: AppBar(title: Text(loc.login)),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading) 
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ElevatedButton(
                      onPressed: _loginWithApple,
                      child: Text(loc.signInWithApple),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loginWithGoogle,
                      child: Text(loc.signInWithGoogle),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'OR',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: loc.email),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: loc.password),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _login,
                      child: Text(loc.login),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: Text(loc.createAnAccount),
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
