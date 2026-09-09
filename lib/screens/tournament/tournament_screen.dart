import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/game_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../game/game_screen.dart';

/// A tournament: what it is, where you stand, and the games it has produced.
/// Registration state is a pill, not a paragraph, and the call to action only
/// appears while it can actually be taken.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final GameService _gameService = GameService();
  Map<String, dynamic>? _tournament;
  bool _isLoading = true;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  Future<void> _loadTournament() async {
    try {
      final data = await _gameService.getTournament(widget.tournamentId);
      if (!mounted) return;
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
    setState(() => _isRegistering = true);
    try {
      await _gameService.registerForTournament(widget.tournamentId);
      await _loadTournament();
    } catch (e) {
      debugPrint('Could not register for tournament: $e');
      if (mounted) {
        showToast(
            context, AppLocalizations.of(context)!.tournamentRegisterError,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(body: AppLoader());
    }

    if (_tournament == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.tournamentTitle)),
        body: AppEmptyState(
          icon: CupertinoIcons.rosette,
          title: loc.tournamentNotFoundTitle,
          message: loc.tournamentNotFoundMessage,
        ),
      );
    }

    final name = (_tournament!['name'] ?? loc.tournamentTitle).toString();
    final description = (_tournament!['description'] ?? '').toString();
    final status = (_tournament!['status'] ?? 'UNKNOWN').toString();
    final isRegistered = _tournament!['is_registered'] == true;
    final games = (_tournament!['games'] ?? []) as List;
    final registrationOpen =
        status == 'REGISTRATION' || status == 'Registration Open';

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: c.bgBase,
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SliverList.list(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusPill(
                        registrationOpen
                            ? loc.tournamentRegistrationOpen
                            : status,
                        tone: registrationOpen
                            ? StatusTone.accent
                            : StatusTone.neutral,
                      ),
                      if (isRegistered) ...[
                        const SizedBox(width: AppSpacing.sm),
                        StatusPill(loc.tournamentYouAreIn,
                            tone: StatusTone.positive,
                            icon: CupertinoIcons.check_mark),
                      ],
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(description,
                        style:
                            t.bodyLarge?.copyWith(color: c.labelSecondary)),
                  ],
                  if (registrationOpen && !isRegistered) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(loc.tournamentRegisterButton,
                        loading: _isRegistering, onPressed: _register),
                  ] else if (registrationOpen && isRegistered) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      loc.tournamentRegisteredNotice,
                      style: t.bodySmall?.copyWith(color: c.labelTertiary),
                    ),
                  ],
                ],
              ),
            ),
            if (games.isEmpty)
              AppEmptyState(
                icon: CupertinoIcons.square_grid_2x2,
                title: loc.tournamentNoBoardsTitle,
                message: loc.tournamentNoBoardsMessage,
              )
            else
              InsetSection(
                header: loc.tournamentBoardsSection,
                children: [
                  for (final game in games)
                    InsetRow(
                      title: (game['name'] ??
                              loc.tournamentGameFallbackName(
                                  game['id'].toString()))
                          .toString(),
                      subtitle: game['status']?.toString(),
                      icon: CupertinoIcons.map,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GameScreen(gameId: game['id'].toString()),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.huge),
          ]),
        ],
      ),
    );
  }
}
