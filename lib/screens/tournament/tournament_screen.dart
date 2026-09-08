import 'package:flutter/material.dart';
import '../../services/game_service.dart';

class TournamentScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentScreen({super.key, required this.tournamentId});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final GameService _gameService = GameService();
  Map<String, dynamic>? _tournament;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  Future<void> _loadTournament() async {
    try {
      final data = await _gameService.getTournament(widget.tournamentId);
      setState(() {
        _tournament = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load tournament: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    try {
      await _gameService.registerForTournament(widget.tournamentId);
      _loadTournament();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_tournament == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(child: Text('Tournament not found.')),
      );
    }

    final String name = _tournament!['name'] ?? 'Tournament';
    final String description = _tournament!['description'] ?? '';
    final String status = _tournament!['status'] ?? 'UNKNOWN';
    final bool isRegistered = _tournament!['is_registered'] ?? false;
    final List games = _tournament!['games'] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Status: $status', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                Text(description, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                if (status == 'REGISTRATION' || status == 'Registration Open') ...[
                  if (isRegistered)
                    Chip(
                      label: Text('Registered. Waiting for shuffle.', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    )
                  else
                    ElevatedButton(
                      onPressed: _register,
                      child: const Text('Register'),
                    ),
                ] else if (isRegistered) ...[
                  Chip(
                    label: Text('Registered', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Tournament Games', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(game['name'] ?? 'Game ${game['id']}'),
                    subtitle: Text('Status: ${game['status']}'),
                    onTap: () {
                      // Navigate to game or preview
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(gameId: game['id'].toString())));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
