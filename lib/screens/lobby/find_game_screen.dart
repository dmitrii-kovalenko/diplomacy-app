import 'package:flutter/material.dart';
import '../../services/lobby_service.dart';
import '../../models/game_model.dart';
import '../../widgets/game_card.dart';

class FindGameScreen extends StatefulWidget {
  const FindGameScreen({super.key});

  @override
  State<FindGameScreen> createState() => _FindGameScreenState();
}

class _FindGameScreenState extends State<FindGameScreen> {
  final _shareIdController = TextEditingController();
  final _lobbyService = LobbyService();
  bool _isLoading = false;
  GameModel? _foundGame;

  void _search() async {
    final shareId = _shareIdController.text.trim();
    if (shareId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundGame = null;
    });

    try {
      final data = await _lobbyService.findGame(shareId);
      setState(() {
        _foundGame = GameModel.fromJson(data['game']);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Game not found or error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shareIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Game')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shareIdController,
                    decoration: const InputDecoration(labelText: 'Share ID (e.g. 123456)'),
                    maxLength: 6,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _search,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_foundGame != null)
              GameCard(
                game: _foundGame!,
                onJoin: _foundGame!.phase == 'lobby' ? () {} : null,
                onEnter: _foundGame!.phase != 'lobby' ? () {} : null,
              ),
          ],
        ),
      ),
    );
  }
}
