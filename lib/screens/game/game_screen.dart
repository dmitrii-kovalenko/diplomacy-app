import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocs/game/order_bloc.dart';
import '../../services/game_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/map_viewer.dart';
import '../../widgets/order_arrows.dart';
import '../../widgets/ui_kit.dart';
import '../chat/conversations_screen.dart';

/// The board.
///
/// Only the chrome around the map is designed here — the [MapViewer] itself
/// renders exactly as it always has, same placement, same sizing, same
/// gestures. What changed is everything that frames it:
///
///  • the nav bar states the turn instead of the row id;
///  • the draw banner is a surface step, not a pale Material tint;
///  • the order flow lives in one bottom bar that swaps content by state, so
///    the map never has to share the screen with three different coloured
///    strips;
///  • Ready is a real primary action at the bottom, not an ambiguous icon in
///    the top-right corner.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  bool _isLoading = true;
  bool _isReady = false;
  int _historyOffset = 0;
  bool _isHistoryMode = false;

  Map<String, dynamic>? _gameState;
  String? _svgString;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    try {
      final state = await _gameService.fetchGameState(widget.gameId);
      final svgUrl = state['game']['map_svg_url'];
      final svgStr = await _gameService.fetchSvg(svgUrl);

      if (!mounted) return;
      setState(() {
        _gameState = state;
        _svgString = svgStr;
        _isReady = state['me']['is_ready'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load game: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleReady() async {
    setState(() => _isReady = !_isReady);
    await _gameService.toggleReady(widget.gameId, _isReady, false);
    _loadGame();
  }

  void _surrender() async {
    final ok = await confirm(
      context,
      title: 'Surrender?',
      message:
          'Your units stay on the board and hold. You cannot rejoin this game.',
      confirmLabel: 'Surrender',
      destructive: true,
    );
    if (!ok) return;
    await _gameService.surrender(widget.gameId);
    _loadGame();
  }

  void _proposeDraw() async {
    final ok = await confirm(
      context,
      title: 'Propose a draw?',
      message:
          'Everyone still playing votes. The game ends in a shared draw only '
          'if they all accept.',
      confirmLabel: 'Propose draw',
    );
    if (!ok) return;
    await _gameService.proposeDraw(widget.gameId);
    _loadGame();
  }

  void _voteDraw(bool accept) async {
    await _gameService.drawVote(widget.gameId, accept);
    _loadGame();
  }

  void _fetchHistory(int offset) async {
    try {
      if (offset == 0) {
        await _loadGame();
        if (!mounted) return;
        setState(() {
          _historyOffset = 0;
          _isHistoryMode = false;
        });
        return;
      }
      final data = await _gameService.fetchHistory(widget.gameId, offset);
      if (!mounted) return;
      setState(() {
        _gameState = data;
        _historyOffset = offset;
        _isHistoryMode = offset < 0;
      });
    } catch (e) {
      if (mounted) showToast(context, 'History error: $e', isError: true);
    }
  }

  void _showBuildSheet(BuildContext context, OrderBloc bloc) {
    showAppSheet(
      context,
      builder: (ctx) => AppSheet(
        title: 'Build a unit',
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InsetSection(
            children: [
              InsetRow(
                title: 'Army',
                subtitle: 'Moves overland; can be convoyed',
                icon: CupertinoIcons.person_fill,
                showChevron: false,
                onTap: () {
                  bloc.setAction(ActionType.buildArmy);
                  Navigator.pop(ctx);
                },
              ),
              InsetRow(
                title: 'Fleet',
                subtitle: 'Moves at sea and along the coast; convoys armies',
                icon: CupertinoIcons.location_north_fill,
                showChevron: false,
                onTap: () {
                  bloc.setAction(ActionType.buildFleet);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _turnLabel {
    final phase = _gameState?['phase'];
    if (phase == null) return 'Game ${widget.gameId}';
    final year = phase['year'];
    final season = phase['season_display'] ?? phase['season'];
    final kind = phase['kind_display'] ?? phase['kind'];
    final parts = [year, season, kind]
        .where((p) => p != null && p.toString().isNotEmpty)
        .map((p) => p.toString())
        .toList();
    return parts.isEmpty ? 'Game ${widget.gameId}' : parts.join(' · ');
  }

  Map<String, Color> _computeProvinceColors() {
    if (_gameState == null) return {};
    final scs = _gameState!['sc_ownership'] as List<dynamic>? ?? [];
    final empires = _gameState!['empires'] as List<dynamic>? ?? [];
    
    final Map<String, Color> empireColors = {};
    for (final e in empires) {
      final code = e['code'] as String?;
      final colorStr = e['color'] as String?;
      if (code != null && colorStr != null) {
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          final hex = colorStr.substring(1);
          empireColors[code] = Color(int.parse('0xFF$hex')).withOpacity(0.55);
        }
      }
    }

    final Map<String, Color> colors = {};
    for (final sc in scs) {
      final prov = sc['province_code'] as String?;
      final emp = sc['empire_code'] as String?;
      if (prov != null && emp != null && empireColors.containsKey(emp)) {
        colors[prov] = empireColors[emp]!;
      }
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(body: AppLoader(label: 'Loading the board…'));
    }

    final drawProposal = _gameState?['draw_proposal'];
    bool hasVotedDraw = false;
    if (drawProposal != null) {
      final myVotePending = drawProposal['my_vote_pending'] as bool? ?? true;
      hasVotedDraw = !myVotePending;
    }

    return ChangeNotifierProvider(
      create: (context) {
        final bloc = OrderBloc(widget.gameId, onOrderSubmitted: _loadGame);
        bloc.setGameState(_gameState!);
        return bloc;
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isHistoryMode ? 'History' : _turnLabel,
                  style: t.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (_isHistoryMode)
                Text('$_historyOffset turns back',
                    style: t.labelSmall?.copyWith(color: c.labelSecondary)),
            ],
          ),
          actions: _isHistoryMode
              ? [
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_left),
                    tooltip: 'Earlier turn',
                    onPressed: () => _fetchHistory(_historyOffset - 1),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_right),
                    tooltip: 'Later turn',
                    onPressed: () => _fetchHistory(_historyOffset + 1),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    tooltip: 'Back to the live board',
                    onPressed: () => _fetchHistory(0),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ]
              : [
                  IconButton(
                    icon: const Icon(CupertinoIcons.bubble_left_bubble_right),
                    tooltip: 'Messages',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ConversationsScreen(gameId: widget.gameId),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(CupertinoIcons.list_bullet),
                      tooltip: 'My orders',
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(CupertinoIcons.ellipsis_circle),
                    tooltip: 'More',
                    onSelected: (val) {
                      if (val == 'draw') _proposeDraw();
                      if (val == 'surrender') _surrender();
                      if (val == 'history') _fetchHistory(-1);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'history', child: Text('View history')),
                      const PopupMenuItem(
                          value: 'draw', child: Text('Propose a draw')),
                      PopupMenuItem(
                        value: 'surrender',
                        child: Text('Surrender',
                            style: TextStyle(color: c.red)),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
        ),
        endDrawer: _buildOrdersDrawer(),
        body: Column(
          children: [
            if (drawProposal != null)
              _DrawBanner(
                hasVoted: hasVotedDraw,
                onAccept: () => _voteDraw(true),
                onReject: () => _voteDraw(false),
              ),
            Expanded(
              child: Consumer<OrderBloc>(
                builder: (context, bloc, child) {
                  // Order arrows are drawn from map-space coordinates the
                  // viewer owns, so nothing is passed in from here yet.
                  final List<Order> renderedOrders = [];

                  return MapViewer(
                    svgString: _svgString ?? '<svg></svg>',
                    provinceColors: _computeProvinceColors(),
                    onSvgParsed: (mapData) {
                      bloc.setMapData(mapData);
                    },
                    onProvinceTapped: (province) {
                      if (_isHistoryMode) return;
                      bool hasUnit = false;
                      bool isOwned = false;
                      bool isOwnedSc = false;

                      final myCode = _gameState?['me']['empire_code'];

                      if (_gameState?['units'] != null) {
                        for (var u in _gameState!['units']) {
                          if (u['province_code'] == province) {
                            hasUnit = true;
                            if (u['empire_code'] == myCode) isOwned = true;
                            break;
                          }
                        }
                      }

                      if (_gameState?['sc_ownership'] != null) {
                        for (var sc in _gameState!['sc_ownership']) {
                          if (sc['province_code'] == province &&
                              sc['empire_code'] == myCode) {
                            isOwnedSc = true;
                            break;
                          }
                        }
                      }

                      final phaseKind =
                          _gameState?['phase']?['kind'] ?? 'diplomacy';

                      bloc.selectProvince(
                          province, hasUnit, isOwned, phaseKind, isOwnedSc);
                    },
                    activeOrderUnitProvince: bloc.selectedProvince,
                    validTargetProvinces: bloc.validTargetProvinces,
                    orders: renderedOrders,
                  );
                },
              ),
            ),
            if (!_isHistoryMode)
              Consumer<OrderBloc>(
                builder: (context, bloc, child) => _CommandBar(
                  bloc: bloc,
                  isReady: _isReady,
                  orderCount:
                      (_gameState?['my_orders'] as List?)?.length ?? 0,
                  onToggleReady: _toggleReady,
                  onBuild: () => _showBuildSheet(context, bloc),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersDrawer() {
    final myOrders = _gameState?['my_orders'] as List? ?? [];
    return Drawer(
      width: 340,
      child: SafeArea(
        child: Builder(
          builder: (context) {
            final c = AppColors.of(context);
            final t = Theme.of(context).textTheme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                      AppSpacing.xl, AppSpacing.gutter, AppSpacing.md),
                  child: Row(
                    children: [
                      Text('Orders', style: t.displaySmall),
                      const SizedBox(width: AppSpacing.sm),
                      Text('${myOrders.length}',
                          style: t.displaySmall
                              ?.copyWith(color: c.labelTertiary)),
                    ],
                  ),
                ),
                Expanded(
                  child: myOrders.isEmpty
                      ? const AppEmptyState(
                          icon: CupertinoIcons.list_bullet,
                          title: 'No orders yet',
                          message:
                              'Tap one of your units on the map to give it '
                              'an order.',
                        )
                      : ListView(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.xxl),
                          children: [
                            InsetSection(
                              children: [
                                for (final order in myOrders)
                                  _OrderRow(
                                    order: order,
                                    onDelete: () async {
                                      try {
                                        await _gameService.cancelOrder(
                                            order['id'].toString());
                                        _loadGame();
                                      } catch (e) {
                                        if (context.mounted) {
                                          showToast(context,
                                              'Could not cancel that order.',
                                              isError: true);
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One submitted order, written the way players say it out loud:
/// `A PAR — Move → BUR`.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onDelete});

  final dynamic order;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final unit = (order['unit_type'] ?? '').toString();
    final source = (order['source_code'] ?? '').toString();
    final type = (order['order_type_name'] ?? '').toString();
    final target = order['target_code']?.toString();
    final aux = order['aux_code']?.toString();

    final detail = [
      type,
      if (aux != null && aux.isNotEmpty) aux,
      if (target != null && target.isNotEmpty) '→ $target',
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: c.accentMuted, borderRadius: AppRadius.brSm),
            child: Text(unit.isEmpty ? '?' : unit.substring(0, 1).toUpperCase(),
                style: t.labelMedium?.copyWith(color: c.accent)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source, style: t.titleMedium),
                Text(detail,
                    style: t.bodySmall?.copyWith(color: c.labelSecondary)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Cancel order',
            child: PressableScale(
              onTap: onDelete,
              child: SizedBox(
                height: AppMetrics.minTap,
                width: AppMetrics.minTap,
                child: Icon(CupertinoIcons.minus_circle_fill,
                    size: 20, color: c.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The draw proposal. A surface step with an accent rule, not a pale tint —
/// tinted Material banners read as broken on a dark ground.
class _DrawBanner extends StatelessWidget {
  const _DrawBanner({
    required this.hasVoted,
    required this.onAccept,
    required this.onReject,
  });

  final bool hasVoted;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        border: Border(
          left: BorderSide(color: c.orange, width: 3),
          bottom:
              BorderSide(color: c.separator, width: AppMetrics.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A draw has been proposed', style: t.titleSmall),
                Text(
                  hasVoted
                      ? 'Waiting on the other powers…'
                      : 'Every remaining power must accept.',
                  style: t.bodySmall?.copyWith(color: c.labelSecondary),
                ),
              ],
            ),
          ),
          if (!hasVoted) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton('Accept',
                onPressed: onAccept, compact: true, expand: false),
            const SizedBox(width: AppSpacing.sm),
            AppButton('Reject',
                onPressed: onReject,
                style: AppButtonStyle.tinted,
                compact: true,
                expand: false),
          ],
        ],
      ),
    );
  }
}

/// One bar at the bottom of the board that swaps content with the order state:
/// idle shows Ready, a selected unit shows the orders it can be given, and a
/// pending target shows what the map is waiting for.
class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.bloc,
    required this.isReady,
    required this.orderCount,
    required this.onToggleReady,
    required this.onBuild,
  });

  final OrderBloc bloc;
  final bool isReady;
  final int orderCount;
  final VoidCallback onToggleReady;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    Widget content;
    switch (bloc.currentState) {
      case OrderState.unitSelected:
        content = Row(
          key: const ValueKey('actions'),
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _Action('Hold', CupertinoIcons.shield,
                      () => bloc.setAction(ActionType.hold)),
                  _Action('Move', CupertinoIcons.arrow_right,
                      () => bloc.setAction(ActionType.move)),
                  _Action('Support', CupertinoIcons.arrow_branch,
                      () => bloc.setAction(ActionType.support)),
                  _Action('Convoy', CupertinoIcons.location_north_fill,
                      () => bloc.setAction(ActionType.convoy)),
                  _Action('Build', CupertinoIcons.plus_app, onBuild),
                ]),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _CancelButton(onTap: bloc.reset),
          ],
        );

      case OrderState.targetSelection:
      case OrderState.auxTargetSelection:
        final isAux = bloc.currentState == OrderState.auxTargetSelection;
        content = Row(
          key: const ValueKey('target'),
          children: [
            Icon(CupertinoIcons.hand_point_right_fill,
                size: 18, color: c.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                isAux
                    ? 'Tap where the supported unit is going'
                    : 'Tap the destination province',
                style: t.bodyLarge,
              ),
            ),
            _CancelButton(onTap: bloc.reset),
          ],
        );

      default:
        content = Row(
          key: const ValueKey('ready'),
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isReady ? 'Ready' : 'Your move',
                    style: t.titleSmall
                        ?.copyWith(color: isReady ? c.green : c.labelPrimary),
                  ),
                  Text(
                    orderCount == 0
                        ? 'Tap one of your units to give it an order'
                        : '$orderCount order${orderCount == 1 ? '' : 's'} submitted',
                    style: t.bodySmall?.copyWith(color: c.labelSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              isReady ? 'Not ready' : 'Ready',
              icon: isReady ? null : CupertinoIcons.check_mark,
              style:
                  isReady ? AppButtonStyle.tinted : AppButtonStyle.filled,
              onPressed: onToggleReady,
              expand: false,
              compact: true,
            ),
          ],
        );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.bgBase,
        border: Border(
            top: BorderSide(color: c.separator, width: AppMetrics.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
              AppSpacing.lg, AppSpacing.md),
          child: AnimatedSize(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.fill, borderRadius: AppRadius.brCapsule),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: c.accent),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: c.labelPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: 'Cancel',
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 40,
          width: 40,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: c.fill, shape: BoxShape.circle),
          child: Icon(CupertinoIcons.xmark, size: 16, color: c.labelSecondary),
        ),
      ),
    );
  }
}
