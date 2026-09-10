import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocs/game/order_bloc.dart';
import '../../models/board_state.dart';
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

  // Offset convention matches the server's (game/api/games.py
  // phase_history): 0 = most recent resolved phase, larger = further back.
  // History mode is derived from whether a phase is loaded, not tracked as
  // a separate flag that can drift from it. Stepping reads the offset the
  // server actually served back from `_historyPhase['offset']` rather than
  // a locally tracked counter, so a double-tap landing two responses out of
  // order can't leave the client and server disagreeing about where it is.
  Map<String, dynamic>? _historyPhase;
  bool _isHistoryLoading = false;
  bool get _isHistoryMode => _historyPhase != null;

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
      if (mounted) {
        setState(() => _isLoading = false);
        showToast(context, 'MAP/GAME ERROR: $e', isError: true);
      }
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

  // Loads the resolved phase at `offset` (0 = most recent) into
  // `_historyPhase`, leaving `_gameState` — the live board — untouched.
  // `_ensure_phase_snapshot` on the server can reconstruct a snapshot by
  // replaying the game the first time an old phase is requested, so this
  // shows the loader rather than leaving the board looking frozen.
  void _fetchHistory(int offset) async {
    setState(() => _isHistoryLoading = true);
    try {
      final phase = await _gameService.fetchHistory(widget.gameId, offset);
      if (!mounted) return;
      if (phase == null) {
        // games.py returns {"phase": null} once offset runs past the last
        // resolved phase — most commonly there simply isn't one yet. Leaving
        // `_historyPhase` alone (rather than assigning null over a phase
        // already on screen) would make "View history" look like it did
        // nothing at all, so say so explicitly.
        setState(() => _isHistoryLoading = false);
        showToast(context, 'No resolved turns yet.');
        return;
      }
      setState(() {
        _historyPhase = phase;
        _isHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isHistoryLoading = false);
      showToast(context, 'History error: $e', isError: true);
    }
  }

  void _exitHistory() {
    setState(() {
      _historyPhase = null;
    });
    _loadGame();
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
    // The API's field names are season_name / kind_name (game/api/
    // serializers.py:_serialize_game_state) — not *_display. Getting this
    // wrong silently falls through to the raw numeric codes instead of
    // erroring, which is exactly what shipped: "1902 · 1 · 1" instead of
    // "1902 · Spring · Movement".
    final season = phase['season_name'] ?? phase['season'];
    final kind = phase['kind_name'] ?? phase['kind'];
    final parts = [year, season, kind]
        .where((p) => p != null && p.toString().isNotEmpty)
        .map((p) => p.toString())
        .toList();
    return parts.isEmpty ? 'Game ${widget.gameId}' : parts.join(' · ');
  }

  // Mirrors the Mini App's renderHistoryBar label (assets/game/orders_ui.js:
  // `${p.year} ${p.season_name} · ${p.kind_name}`) instead of a raw offset
  // count, which used to render as the nonsensical "-1 turns back".
  String get _historySubtitle {
    final p = _historyPhase;
    if (p == null) return '';
    return '${p['year']} ${p['season_name']} · ${p['kind_name']}';
  }

  // History rows carry only province_code/empire_code (no sc_x/sc_y, no
  // is_supply_center) — empire colours still come from the live state's
  // `empires` list, since the history payload doesn't repeat them either.
  // See lib/models/board_state.dart for why this reads off the payload
  // rather than the SVG, and for the copy GamePreviewScreen shares.
  Map<String, Color> _computeProvinceColors() {
    if (_gameState == null) return {};
    return BoardState.provinceColors(
      scOwnership:
          (_historyPhase ?? _gameState)!['sc_ownership'] as List<dynamic>? ??
              [],
      empires: _gameState!['empires'] as List<dynamic>? ?? [],
    );
  }

  // Always read from `_gameState`, live or in history mode: labels are
  // static per map and the history payload carries none of its own.
  Map<String, Offset> _computeLabelPositions() {
    return BoardState.labelPositions(
      _gameState?['label_positions'] as Map<String, dynamic>?,
    );
  }

  // TODO(T04 follow-up): the Mini App also overlays ownerless "Known World"
  // garrisons in history mode (assets/game/map.js liveNeutralOverlay) — this
  // client doesn't reconstruct that overlay yet.
  (Map<String, Offset>, Map<String, Color>) _computeUnitPositionsAndColors() {
    final units =
        (_historyPhase ?? _gameState)?['units'] as List<dynamic>? ?? [];
    return BoardState.unitPositionsAndColors(units);
  }

  // Supply-centre dots always read the live state, live or in history mode:
  // a history phase's `sc_ownership` rows carry only `province_code`/
  // `empire_code` (`_last_phase_payload` in serializers.py), not the
  // `is_supply_center`/`sc_x`/`sc_y` this needs — same reasoning as
  // `_computeLabelPositions` reading `_gameState` unconditionally.
  Map<String, Offset> _computeScPositions() {
    return BoardState.scPositions(
      _gameState?['sc_ownership'] as List<dynamic>? ?? [],
    );
  }

  // Real army/fleet tokens for the map, in place of the flat
  // `unitPositions`/`unitColors` maps above. `coast_positions`/`army_coasts`
  // are static per map, so — like labels and supply centres — these always
  // come off the live state even in history mode; only the units themselves
  // switch to the history snapshot.
  List<MapUnit> _computeUnits() {
    final units =
        (_historyPhase ?? _gameState)?['units'] as List<dynamic>? ?? [];
    return BoardState.units(
      units: units,
      coastPositions:
          _gameState?['coast_positions'] as Map<String, dynamic>?,
      armyCoasts: _gameState?['army_coasts'] as Map<String, dynamic>?,
    );
  }

  // The untranslated SVG basename, so `MapViewer` picks the right per-map
  // unit icon set and size (see `mapSlugFromSvgUrl`'s doc for why this reads
  // the SVG URL rather than `map_name`).
  String? _computeMapSlug() {
    return BoardState.mapSlugFromSvgUrl(
      _gameState?['game']?['map_svg_url'] as String?,
    );
  }

  // `#RRGGBB` -> Color, or null for anything else (including the server's
  // own null, sent for an observer or an empire with no colour assigned).
  // `Empire.color` is a plain CharField with no validator, so a seven-character
  // value is not necessarily seven hex digits; tryParse keeps a hand-edited
  // colour from throwing out of build().
  Color? _parseHexColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    final rgb = int.tryParse(hex.substring(1), radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  // Builds the live order-arrow overlay from `my_orders`, mirroring
  // `arrows_overlay.js` `renderArrowsForOrders`/`renderOrder`: resolve every
  // province code to a point, aggregate which routes already have a move
  // order and which fleets convoy which route, then turn each raw order into
  // an [Order] the painter can draw without knowing anything about codes.
  // History-mode arrows are a separate ticket (T16), so this stays empty
  // there rather than reaching into `_historyPhase`.
  List<Order> _buildOrderArrows(
    BuildContext context,
    Map<String, Offset> unitPositions,
    Map<String, ProvinceData>? mapData,
  ) {
    if (_isHistoryMode) return const [];
    final rawOrders = _gameState?['my_orders'] as List? ?? [];
    if (rawOrders.isEmpty) return const [];

    final units = _gameState?['units'] as List<dynamic>? ?? [];
    final labelPositions = _computeLabelPositions();
    final meColor = _parseHexColor(_gameState?['me']?['color'] as String?);
    final neutral = AppColors.of(context).labelTertiary;

    // Same precedence as `arrows_overlay.js` `pt()`: unit centre (units move
    // every turn, so this is the only source that can't go stale) → the
    // admin-tunable label anchor + 16 (roughly the middle of the province,
    // for a target with no unit on it) → the province's own bounds — the
    // last-resort fallback for a sea province with neither.
    Offset? pt(String? code) {
      if (code == null) return null;
      final unit = unitPositions[code];
      if (unit != null) return unit;
      final label = labelPositions[code];
      if (label != null) return label.translate(0, 16);
      final bounds = mapData?[code]?.path.getBounds();
      if (bounds != null && !bounds.isEmpty) return bounds.center;
      return null;
    }

    bool isMyUnit(String? code) {
      if (code == null) return false;
      for (final u in units) {
        if (u['province_code'] == code) return u['is_mine'] == true;
      }
      return false;
    }

    Color colorFor(dynamic o) {
      return _parseHexColor(o['color'] as String?) ?? meColor ?? neutral;
    }

    // Which routes already have a MOVE order (so a matching CONVOY order
    // doesn't draw a second arrow on top of it), and which fleets convoy
    // which route (so both the MOVE and a SUPPORT of that move can draw the
    // arc through them instead of a straight line over the sea).
    final hasMoveFor = <String>{};
    final convoyFleetsByRoute = <String, List<String>>{};
    for (final o in rawOrders) {
      final type = (o['order_type'] as num?)?.toInt();
      final auxCode = o['aux_code'] as String?;
      final targetCode = o['target_code'] as String?;
      final sourceCode = o['source_code'] as String?;
      if (type == kOrderConvoy && auxCode != null && targetCode != null) {
        (convoyFleetsByRoute['$auxCode->$targetCode'] ??= [])
            .add(sourceCode ?? '');
      } else if (type == kOrderMove && targetCode != null) {
        hasMoveFor.add('$sourceCode->$targetCode');
      }
    }

    List<Offset> fleetsFor(String? from, String? to) {
      if (from == null || to == null) return const [];
      final codes = convoyFleetsByRoute['$from->$to'];
      if (codes == null) return const [];
      return codes.map(pt).whereType<Offset>().toList();
    }

    final result = <Order>[];
    for (final o in rawOrders) {
      // One bad order must never blank the whole overlay.
      try {
        final rawType = (o['order_type'] as num?)?.toInt();
        if (rawType != kOrderHold &&
            rawType != kOrderMove &&
            rawType != kOrderSupport &&
            rawType != kOrderConvoy) {
          continue; // Retreat/build/disband arrows aren't modelled yet.
        }
        final type = rawType!;
        final source = pt(o['source_code'] as String?);
        if (source == null) continue;
        final color = colorFor(o);

        if (type == kOrderConvoy) {
          final auxCode = o['aux_code'] as String?;
          final targetCode = o['target_code'] as String?;
          if (auxCode == null || targetCode == null) continue;
          // The convoyed army's own MOVE order already draws the
          // through-ships arc; only draw this convoy order's own arc when
          // that move isn't in this set (e.g. the fleet owner's own view,
          // who can't see a foreign army's order).
          if (hasMoveFor.contains('$auxCode->$targetCode')) continue;
          final aux = pt(auxCode);
          final target = pt(targetCode);
          if (aux == null || target == null) continue;
          result.add(Order(
              orderType: type,
              source: source,
              target: target,
              aux: aux,
              color: color));
          continue;
        }

        if (type == kOrderHold) {
          result.add(Order(orderType: type, source: source, color: color));
          continue;
        }

        if (type == kOrderMove) {
          final targetCode = o['target_code'] as String?;
          final target = pt(targetCode);
          if (target == null) continue;
          final fleets = fleetsFor(o['source_code'] as String?, targetCode);
          result.add(Order(
              orderType: type,
              source: source,
              target: target,
              convoyFleets: fleets,
              color: color));
          continue;
        }

        // Support.
        final auxCode = o['aux_code'] as String?;
        final aux = pt(auxCode);
        if (aux == null) continue;
        final targetCode = o['target_code'] as String?;
        if (targetCode == null || targetCode == auxCode) {
          result.add(
              Order(orderType: type, source: source, aux: aux, color: color));
          continue;
        }
        final target = pt(targetCode);
        if (target == null) continue;
        final fleets = fleetsFor(auxCode, targetCode);
        // "The move is missing" is only provable when every order of the
        // supported unit is visible — for a live board that's my own units
        // only, since a foreign unit's orders are secret until resolution.
        final orphaned = !hasMoveFor.contains('$auxCode->$targetCode') &&
            isMyUnit(auxCode);
        result.add(Order(
          orderType: type,
          source: source,
          target: target,
          aux: aux,
          convoyFleets: fleets,
          color: color,
          orphanedSupport: orphaned,
        ));
      } catch (e) {
        debugPrint('order arrow build failed for $o: $e');
      }
    }
    return result;
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
      create: (_) {
        final bloc = OrderBloc(
          widget.gameId,
          onOrderSubmitted: _loadGame,
          onOrderError: (message) {
            if (mounted) showToast(context, message, isError: true);
          },
        );
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
                Text(_historySubtitle,
                    style: t.labelSmall?.copyWith(color: c.labelSecondary)),
            ],
          ),
          actions: _isHistoryMode
              ? [
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_left),
                    tooltip: 'Earlier turn',
                    onPressed: _historyPhase?['has_prev'] == true
                        ? () => _fetchHistory(
                            (_historyPhase!['offset'] as num).toInt() + 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_right),
                    tooltip: 'Later turn',
                    onPressed: _historyPhase?['has_next'] == true
                        ? () => _fetchHistory(
                            (_historyPhase!['offset'] as num).toInt() - 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    tooltip: 'Back to the live board',
                    onPressed: _exitHistory,
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
                      if (val == 'history') _fetchHistory(0);
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
              // MapViewer owns a TransformationController that must survive a
              // history step, so the loader is overlaid in a Stack instead of
              // replacing this subtree — swapping it in via a ternary would
              // unmount MapViewer, disposing that controller and re-running
              // _parseSvg on the way back, which throws away the player's
              // zoom/pan on every "earlier turn" / "later turn" tap.
              child: Stack(
                children: [
                  Consumer<OrderBloc>(
                    builder: (context, bloc, child) {
                      final (unitPositions, unitColors) =
                          _computeUnitPositionsAndColors();
                      // Order arrows are drawn from the same map-space
                      // coordinates the viewer owns — resolved here, from
                      // `my_orders` plus whatever the viewer has already
                      // parsed from the SVG (`bloc.mapData`), rather than in
                      // MapViewer itself, which has no notion of a "unit
                      // centre" or "province code" at all.
                      final renderedOrders = _buildOrderArrows(
                          context, unitPositions, bloc.mapData);

                      return MapViewer(
                        svgString: _svgString ?? '<svg></svg>',
                        provinceColors: _computeProvinceColors(),
                        labelPositions: _computeLabelPositions(),
                        scPositions: _computeScPositions(),
                        unitPositions: unitPositions,
                        unitColors: unitColors,
                        units: _computeUnits(),
                        mapSlug: _computeMapSlug(),
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
                              (_gameState?['phase']?['kind'] as num?)
                                      ?.toInt() ??
                                  kPhaseMovement;

                          bloc.selectProvince(province, hasUnit, isOwned,
                              phaseKind, isOwnedSc);
                        },
                        activeOrderUnitProvince: bloc.selectedProvince,
                        validTargetProvinces: bloc.validTargetProvinces,
                        orders: renderedOrders,
                      );
                    },
                  ),
                  if (_isHistoryLoading)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: c.scrim,
                          child: const Center(
                            child: AppLoader(label: 'Loading history…'),
                          ),
                        ),
                      ),
                    ),
                ],
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
