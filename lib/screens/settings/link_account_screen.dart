import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'package:dio/dio.dart';

class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isGenerating = false;
  String? _generatedCode;
  DateTime? _expiresAt;
  Timer? _timer;
  String _timeLeft = '';
  
  bool _isMerging = false;

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _generateCode() async {
    setState(() {
      _isGenerating = true;
      _generatedCode = null;
    });
    
    try {
      final res = await _authService.dio.post('/api/auth/link/generate/');
      final data = res.data;
      setState(() {
        _generatedCode = data['code'];
        _expiresAt = DateTime.parse(data['expires_at']).toLocal();
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate code')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
  
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiresAt == null) return;
      final diff = _expiresAt!.difference(DateTime.now());
      if (diff.isNegative) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _timeLeft = 'Expired';
            _generatedCode = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _timeLeft = '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
          });
        }
      }
    });
  }

  void _mergeAccount() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 6-character code')));
      return;
    }
    
    setState(() {
      _isMerging = true;
    });
    
    try {
      final res = await _authService.dio.post('/api/auth/link/merge/', data: {'code': code});
      final data = res.data;
      
      await _authService.saveTokens(data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accounts merged successfully')));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Merge failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merge failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Link Accounts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Generate Code'),
              Tab(text: 'Enter Code'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Generate Code
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Generate a code here and enter it on your other device to link them together.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_generatedCode != null) ...[
                    Text(
                      _generatedCode!,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        letterSpacing: 8.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Expires in: $_timeLeft', style: const TextStyle(color: Colors.red)),
                  ] else ...[
                    ElevatedButton(
                      onPressed: _isGenerating ? null : _generateCode,
                      child: _isGenerating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Generate Code'),
                    ),
                  ],
                ],
              ),
            ),
            
            // Tab 2: Enter Code
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Enter the 6-character code generated on your other device.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 8.0, fontSize: 24),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isMerging ? null : _mergeAccount,
                    child: _isMerging
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Merge Account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
