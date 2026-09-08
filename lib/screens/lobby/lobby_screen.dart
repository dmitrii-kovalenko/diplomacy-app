import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../blocs/lobby/lobby_bloc.dart';
import '../../widgets/game_card.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'create_game_screen.dart';
import 'find_game_screen.dart';
import 'create_sandbox_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  void _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LobbyBloc(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lobby'),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindGameScreen()),
                  );
                },
              ),
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _logout(context),
              ),
            ),
          ],
        ),
        body: Consumer<LobbyBloc>(
          builder: (context, bloc, child) {
            if (bloc.isLoading && bloc.yourTurn.isEmpty && bloc.openLobbies.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (bloc.error != null) {
              return RefreshIndicator(
                onRefresh: () => bloc.refreshLobby(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Center(child: Text('Error: ${bloc.error}')),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => bloc.refreshLobby(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildSection(context, 'Your Turn', bloc.yourTurn),
                  _buildSection(context, 'Waiting', bloc.waiting),
                  _buildSection(context, 'Open Lobbies', bloc.openLobbies),
                  _buildSection(context, 'Surrendered', bloc.surrendered),
                  _buildSection(context, 'Observed', bloc.observed),
                  _buildSection(context, 'Completed', bloc.completed),
                ],
              ),
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'sandbox',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateSandboxScreen()),
                  );
                  if (context.mounted) {
                    context.read<LobbyBloc>().refreshLobby();
                  }
                },
                child: const Icon(Icons.science),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'create',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateGameScreen()),
                  );
                  if (context.mounted) {
                    context.read<LobbyBloc>().refreshLobby();
                  }
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List games) {
    if (games.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ),
        ...games.map((game) => GameCard(
          game: game,
          onEnter: () {
            // Navigate to game view
          },
          onJoin: game['status'] == 'lobby' ? () {} : null,
        )),
      ],
    );
  }
}
