import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/game_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../game/game_screen.dart';

// Numeric codes mirroring DjangoProject/game/models.py's
// TOURNAMENT_STATUS_CHOICES — the tournament API sends this integer as
// `status`, never the display name, so match against these rather than a
// string. Keep this block in sync with models.py by hand; there is no
// generated bridge between the two languages.
const int kTournamentStatusRegistration = 0;
const int kTournamentStatusActive = 1;
const int kTournamentStatusFinished = 2;
const int kTournamentStatusCancelled = 3;

// Numeric codes mirroring DjangoProject/game/choices.py's
// GAME_STATUS_CHOICES — the per-board `status` in a tournament's games list
// is this same raw integer, with no display-name counterpart in the API.
const int kGameStatusLobby = 0;
const int kGameStatusActive = 1;
const int kGameStatusFinished = 2;

/// Parses a status value the API may send as an int or (defensively) as a
/// numeric string, returning null for anything unrecognized.
int? _parseStatus(dynamic raw) =>
    raw is int ? raw : int.tryParse(raw?.toString() ?? '');

/// The tournament status pill's label.
///
/// Plain English on purpose, not an [AppLocalizations] lookup: the ARB
/// files are owned by a concurrent localization pass at the time of this
/// fix, so these words are left for that sweep to convert into proper
/// translation keys rather than added here as a fourth language file edit.
String _tournamentStatusLabel(dynamic raw) {
  switch (_parseStatus(raw)) {
    case kTournamentStatusRegistration:
      return 'Registration Open';
    case kTournamentStatusActive:
      return 'Active';
    case kTournamentStatusFinished:
      return 'Finished';
    case kTournamentStatusCancelled:
      return 'Cancelled';
    default:
      return 'Unknown';
  }
}

/// The per-board status shown in a tournament's games list. Same
/// not-yet-localized caveat as [_tournamentStatusLabel].
String _gameStatusLabel(dynamic raw) {
  switch (_parseStatus(raw)) {
    case kGameStatusLobby:
      return 'Lobby';
    case kGameStatusActive:
      return 'Active';
    case kGameStatusFinished:
      return 'Finished';
    default:
      return 'Unknown';
  }
}

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
    final status = _tournament!['status'];
    final isRegistered = _tournament!['is_registered'] == true;
    final games = (_tournament!['games'] ?? []) as List;
    final registrationOpen =
        _parseStatus(status) == kTournamentStatusRegistration;

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
                            : _tournamentStatusLabel(status),
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
                      subtitle: _gameStatusLabel(game['status']),
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
