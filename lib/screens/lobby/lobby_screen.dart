import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocs/lobby/lobby_bloc.dart';
import '../../models/game_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_card.dart';
import '../../widgets/ui_kit.dart';
import '../game/game_screen.dart';
import '../game/preview_screen.dart';
import '../settings/settings_screen.dart';
import 'create_game_screen.dart';
import 'create_sandbox_screen.dart';
import 'find_game_screen.dart';

/// The home screen.
///
/// A large title that collapses on scroll, grouped sections of game cards, and
/// exactly two nav-bar controls: Settings on the leading edge and a single "+"
/// that opens the three ways to start playing. The old stack of floating
/// buttons is gone — a FAB tower covers content and has no Apple equivalent.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  Future<void> _openAndRefresh(BuildContext context, Widget screen) async {
    final bloc = context.read<LobbyBloc>();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    bloc.refreshLobby();
  }

  void _showNewGameSheet(BuildContext context) {
    showAppSheet(
      context,
      builder: (ctx) => AppSheet(
        title: 'Start playing',
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InsetSection(
            children: [
              InsetRow(
                title: 'New game',
                subtitle: 'Open a room and invite other powers',
                icon: CupertinoIcons.plus_circle_fill,
                onTap: () {
                  Navigator.pop(ctx);
                  _openAndRefresh(context, const CreateGameScreen());
                },
              ),
              InsetRow(
                title: 'Sandbox',
                subtitle: 'Play every power yourself, no deadlines',
                icon: CupertinoIcons.wand_stars,
                onTap: () {
                  Navigator.pop(ctx);
                  _openAndRefresh(context, const CreateSandboxScreen());
                },
              ),
              InsetRow(
                title: 'Join by code',
                subtitle: 'Enter the six-character room code',
                icon: CupertinoIcons.number,
                onTap: () {
                  Navigator.pop(ctx);
                  _openAndRefresh(context, const FindGameScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ChangeNotifierProvider(
      create: (_) => LobbyBloc(),
      child: Builder(
        builder: (context) => Scaffold(
          body: Consumer<LobbyBloc>(
            builder: (context, bloc, child) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverAppBar.large(
                    pinned: true,
                    backgroundColor: c.bgBase,
                    title: const Text('Games'),
                    leading: IconButton(
                      icon: const Icon(CupertinoIcons.gear_alt),
                      tooltip: 'Settings',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.add),
                        tooltip: 'Start playing',
                        onPressed: () => _showNewGameSheet(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ),
                  CupertinoSliverRefreshControl(
                    onRefresh: () => bloc.refreshLobby(),
                  ),
                  ..._body(context, bloc),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.huge)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, LobbyBloc bloc) {
    final isEmpty = bloc.yourTurn.isEmpty &&
        bloc.waiting.isEmpty &&
        bloc.openLobbies.isEmpty &&
        bloc.surrendered.isEmpty &&
        bloc.observed.isEmpty &&
        bloc.completed.isEmpty;

    if (bloc.isLoading && isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: AppLoader()),
      ];
    }

    if (bloc.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: CupertinoIcons.wifi_slash,
            title: "Couldn't load your games",
            message: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => bloc.refreshLobby(),
          ),
        ),
      ];
    }

    if (isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: CupertinoIcons.map,
            title: 'No games yet',
            message:
                'Open a room, spin up a sandbox, or join a friend with their '
                'room code.',
            actionLabel: 'Start playing',
            onAction: () => _showNewGameSheet(context),
          ),
        ),
      ];
    }

    return [
      ..._section(context, 'Your turn', bloc.yourTurn),
      ..._section(context, 'Waiting', bloc.waiting),
      ..._section(context, 'Open lobbies', bloc.openLobbies),
      ..._section(context, 'Observing', bloc.observed),
      ..._section(context, 'Surrendered', bloc.surrendered),
      ..._section(context, 'Finished', bloc.completed),
    ];
  }

  List<Widget> _section(
      BuildContext context, String title, List<GameModel> games) {
    if (games.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: SectionHeader(title, count: games.length)),
      SliverList.builder(
        itemCount: games.length,
        itemBuilder: (context, i) {
          final game = games[i];
          return GameCard(
            game: game,
            // An open lobby has no board to command yet — show the map so
            // people can judge the room before committing.
            onEnter: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => game.status == 0
                    ? GamePreviewScreen(gameId: game.id)
                    : GameScreen(gameId: game.id),
              ),
            ),
          );
        },
      ),
    ];
  }
}
