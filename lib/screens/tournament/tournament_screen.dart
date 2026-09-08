import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
      if (mounted) showToast(context, 'Could not register. $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(body: AppLoader());
    }

    if (_tournament == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const AppEmptyState(
          icon: CupertinoIcons.rosette,
          title: 'Tournament not found',
          message: 'It may have finished or been cancelled.',
        ),
      );
    }

    final name = (_tournament!['name'] ?? 'Tournament').toString();
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
                        registrationOpen ? 'Registration open' : status,
                        tone: registrationOpen
                            ? StatusTone.accent
                            : StatusTone.neutral,
                      ),
                      if (isRegistered) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const StatusPill('You are in',
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
                    AppButton('Register',
                        loading: _isRegistering, onPressed: _register),
                  ] else if (registrationOpen && isRegistered) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Seats are drawn when registration closes. We will '
                      'notify you when your board is ready.',
                      style: t.bodySmall?.copyWith(color: c.labelTertiary),
                    ),
                  ],
                ],
              ),
            ),
            if (games.isEmpty)
              const AppEmptyState(
                icon: CupertinoIcons.square_grid_2x2,
                title: 'No boards yet',
                message: 'Games appear here once the draw is made.',
              )
            else
              InsetSection(
                header: 'Boards',
                children: [
                  for (final game in games)
                    InsetRow(
                      title:
                          (game['name'] ?? 'Game ${game['id']}').toString(),
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
