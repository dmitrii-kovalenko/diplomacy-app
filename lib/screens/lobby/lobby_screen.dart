import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final loc = AppLocalizations.of(context)!;
    showAppSheet(
      context,
      builder: (ctx) => AppSheet(
        title: loc.startPlaying,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InsetSection(
            children: [
              InsetRow(
                title: loc.lobbyNewGameTitle,
                subtitle: loc.lobbyNewGameSubtitle,
                icon: CupertinoIcons.plus_circle_fill,
                onTap: () {
                  Navigator.pop(ctx);
                  _openAndRefresh(context, const CreateGameScreen());
                },
              ),
              InsetRow(
                title: loc.sandboxLabel,
                subtitle: loc.lobbySandboxSubtitle,
                icon: CupertinoIcons.wand_stars,
                onTap: () {
                  Navigator.pop(ctx);
                  _openAndRefresh(context, const CreateSandboxScreen());
                },
              ),
              InsetRow(
                title: loc.findRoomTitle,
                subtitle: loc.lobbyJoinByCodeSubtitle,
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
    final loc = AppLocalizations.of(context)!;

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
                    title: Text(loc.lobbyGamesTitle),
                    leading: IconButton(
                      icon: const Icon(CupertinoIcons.gear_alt),
                      tooltip: loc.settings,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.add),
                        tooltip: loc.startPlaying,
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
    final loc = AppLocalizations.of(context)!;
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
            title: loc.lobbyLoadErrorTitle,
            message: loc.lobbyLoadErrorMessage,
            actionLabel: loc.tryAgain,
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
            title: loc.lobbyEmptyTitle,
            message: loc.lobbyEmptyMessage,
            actionLabel: loc.startPlaying,
            onAction: () => _showNewGameSheet(context),
          ),
        ),
      ];
    }

    return [
      ..._section(context, loc.lobbySectionYourTurn, bloc.yourTurn),
      ..._section(context, loc.lobbySectionWaiting, bloc.waiting),
      ..._section(context, loc.lobbySectionOpenLobbies, bloc.openLobbies),
      ..._section(context, loc.lobbySectionObserving, bloc.observed),
      ..._section(context, loc.lobbySectionSurrendered, bloc.surrendered),
      ..._section(context, loc.lobbySectionFinished, bloc.completed),
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
