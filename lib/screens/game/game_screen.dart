import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
        showToast(context, AppLocalizations.of(context)!.gameLoadErrorToast,
            isError: true);
      }
    }
  }

  void _toggleReady() async {
    setState(() => _isReady = !_isReady);
    await _gameService.toggleReady(widget.gameId, _isReady, false);
    _loadGame();
  }

  void _surrender() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await confirm(
      context,
      title: loc.gameSurrenderTitle,
      message: loc.gameSurrenderMessage,
      confirmLabel: loc.gameSurrenderConfirm,
      destructive: true,
    );
    if (!ok) return;
    await _gameService.surrender(widget.gameId);
    _loadGame();
  }

  void _proposeDraw() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await confirm(
      context,
      title: loc.gameProposeDrawTitle,
      message: loc.gameProposeDrawMessage,
      confirmLabel: loc.gameProposeDrawConfirm,
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
        showToast(context, AppLocalizations.of(context)!.gameNoResolvedTurnsYet);
        return;
      }
      setState(() {
        _historyPhase = phase;
        _isHistoryLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load history: $e');
      if (!mounted) return;
      setState(() => _isHistoryLoading = false);
      showToast(context, AppLocalizations.of(context)!.gameHistoryLoadErrorToast,
          isError: true);
    }
  }

  void _exitHistory() {
    setState(() {
      _historyPhase = null;
    });
    _loadGame();
  }

  // Confirmation before a disband — it is destructive (the unit leaves the
  // board immediately) and, before T17, fired on a single tap with no
  // confirmation at all. Shared by the retreat-phase and adjustment-phase
  // Disband chips.
  Future<void> _confirmDisband(BuildContext context, OrderBloc bloc) async {
    final loc = AppLocalizations.of(context)!;
    final ok = await confirm(
      context,
      title: loc.gameDisbandUnitTitle,
      message: loc.gameDisbandUnitMessage,
      confirmLabel: loc.orderDisband,
      destructive: true,
    );
    if (!ok) return;
    bloc.setAction(ActionType.disband);
  }

  // The coast-prompt hook OrderBloc calls when a fleet move or build targets
  // a split-coast province — mirrors orders_ui.js's promptCoast. Options
  // come from `bloc.coastOptionsFor`, which sources them the same way
  // Reachability does (DB coast_adjacency -> SVG data-adj-<coast> -> the
  // generic NC/SC pair for a legacy map with neither) rather than this
  // screen re-deriving them straight from `coast_adjacency` and skipping
  // that middle SVG rung. `fromCode` narrows a move to the coasts the unit
  // can actually enter from there — a fleet at BAR moving to STP must never
  // be offered STP/SC — and is null for a build, which orders_ui.js's own
  // submitBuild call leaves unfiltered too. A move that narrows to exactly
  // one coast resolves without ever showing the sheet, matching
  // promptCoast's own auto-resolve; a build always asks, even with one
  // option, since orders_ui.js's promptCoast(code) — no fromCode — never
  // takes that shortcut.
  Future<String?> _promptCoast(String targetCode, String? fromCode, OrderBloc bloc) async {
    if (!mounted) return null;
    final options = bloc.coastOptionsFor(targetCode, from: fromCode);
    if (fromCode != null && options.length == 1) return options.first;

    String? chosen;
    await showAppSheet<void>(
      context,
      builder: (ctx) => AppSheet(
        title: AppLocalizations.of(ctx)!.gameWhichCoast(targetCode),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: InsetSection(
            children: [
              for (final coast in options)
                InsetRow(
                  title: coast,
                  showChevron: false,
                  onTap: () {
                    chosen = coast;
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
    return chosen;
  }

  // season_name/kind_name arrive pre-translated from the server (see the
  // comment below) — this method only needs a localizations object for its
  // own fallback, so it takes one instead of a BuildContext.
  String _turnLabel(AppLocalizations loc) {
    final phase = _gameState?['phase'];
    if (phase == null) return loc.tournamentGameFallbackName(widget.gameId);
    final year = phase['year'];
    // The API's field names are season_name / kind_name (game/api/
    // serializers.py:_serialize_game_state) — not *_display. Getting this
    // wrong silently falls through to the raw numeric codes instead of
    // erroring, which is exactly what shipped: "1902 · 1 · 1" instead of
    // "1902 · Spring · Movement". They are already server-translated into
    // the player's language once T09 sends it — this screen never
    // retranslates them client-side.
    final season = phase['season_name'] ?? phase['season'];
    final kind = phase['kind_name'] ?? phase['kind'];
    final parts = [year, season, kind]
        .where((p) => p != null && p.toString().isNotEmpty)
        .map((p) => p.toString())
        .toList();
    return parts.isEmpty
        ? loc.tournamentGameFallbackName(widget.gameId)
        : parts.join(' · ');
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
    final loc = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(body: AppLoader(label: loc.gameLoadingBoard));
    }

    final drawProposal = _gameState?['draw_proposal'];
    bool hasVotedDraw = false;
    if (drawProposal != null) {
      final myVotePending = drawProposal['my_vote_pending'] as bool? ?? true;
      hasVotedDraw = !myVotePending;
    }

    return ChangeNotifierProvider(
      create: (_) {
        // `late` so the closure below can hand the bloc back to
        // `_promptCoast`, which needs it for `coastOptionsFor` — the bloc
        // has no BuildContext of its own to reach the picker UI with, and
        // the picker needs the bloc to reach Reachability's coast data.
        late final OrderBloc bloc;
        bloc = OrderBloc(
          widget.gameId,
          onOrderSubmitted: _loadGame,
          onOrderError: (kind, {detail}) {
            if (!mounted) return;
            final loc = AppLocalizations.of(context)!;
            // The server's reason (game/api/orders.py, validation.py) is an
            // English literal — on a crash, a raw exception class name — so it
            // belongs in the log, and the player gets a message in their own
            // language instead.
            if (kind == OrderErrorKind.submitFailed) {
              debugPrint('submitOrder failed: $detail');
            }
            final message = switch (kind) {
              OrderErrorKind.cancelFailed => loc.gameCancelOrderFailedToast,
              OrderErrorKind.coastPickerUnavailable =>
                loc.gameCoastPickerUnavailableToast,
              OrderErrorKind.submitFailed => loc.gameSubmitOrderFailedToast,
            };
            showToast(context, message, isError: true);
          },
          onCoastPrompt: (target, from) => _promptCoast(target, from, bloc),
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
              Text(_isHistoryMode ? loc.gameHistoryTitle : _turnLabel(loc),
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
                    tooltip: loc.gameEarlierTurn,
                    onPressed: _historyPhase?['has_prev'] == true
                        ? () => _fetchHistory(
                            (_historyPhase!['offset'] as num).toInt() + 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_right),
                    tooltip: loc.gameLaterTurn,
                    onPressed: _historyPhase?['has_next'] == true
                        ? () => _fetchHistory(
                            (_historyPhase!['offset'] as num).toInt() - 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    tooltip: loc.gameBackToLiveBoard,
                    onPressed: _exitHistory,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ]
              : [
                  IconButton(
                    icon: const Icon(CupertinoIcons.bubble_left_bubble_right),
                    tooltip: loc.chatMessagesTitle,
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
                      tooltip: loc.gameMyOrdersTooltip,
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(CupertinoIcons.ellipsis_circle),
                    tooltip: loc.gameMoreTooltip,
                    onSelected: (val) {
                      if (val == 'draw') _proposeDraw();
                      if (val == 'surrender') _surrender();
                      if (val == 'history') _fetchHistory(0);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'history', child: Text(loc.gameViewHistory)),
                      PopupMenuItem(
                          value: 'draw',
                          child: Text(loc.gameProposeDrawMenuItem)),
                      PopupMenuItem(
                        value: 'surrender',
                        child: Text(loc.gameSurrenderConfirm,
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
                      // OrderBloc's `create` callback only runs once per
                      // screen lifetime (Provider keeps the same instance
                      // across rebuilds), so without this the bloc would
                      // keep reasoning about the game state as it stood at
                      // the very first build — stale quota, stale
                      // my_orders, stale units — the moment the player
                      // submits a single order. Cheap and idempotent, so
                      // it's safe to call on every build.
                      bloc.setGameState(_gameState!);

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
                          bloc.selectProvince(province);
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
                          child: Center(
                            child: AppLoader(label: loc.gameLoadingHistory),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!_isHistoryMode)
              Consumer<OrderBloc>(
                builder: (context, bloc, child) {
                  // Idempotent — see the identical call in the map's own
                  // Consumer above. Repeated here rather than relied on
                  // solely from build order, since this bar reads
                  // bloc.phaseKind/quota/canSupport/canConvoy directly.
                  bloc.setGameState(_gameState!);
                  return _CommandBar(
                    bloc: bloc,
                    isReady: _isReady,
                    orderCount:
                        (_gameState?['my_orders'] as List?)?.length ?? 0,
                    onToggleReady: _toggleReady,
                    onConfirmDisband: () => _confirmDisband(context, bloc),
                  );
                },
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
            final loc = AppLocalizations.of(context)!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                      AppSpacing.xl, AppSpacing.gutter, AppSpacing.md),
                  child: Row(
                    children: [
                      Text(loc.gameOrdersDrawerTitle, style: t.displaySmall),
                      const SizedBox(width: AppSpacing.sm),
                      Text('${myOrders.length}',
                          style: t.displaySmall
                              ?.copyWith(color: c.labelTertiary)),
                    ],
                  ),
                ),
                Expanded(
                  child: myOrders.isEmpty
                      ? AppEmptyState(
                          icon: CupertinoIcons.list_bullet,
                          title: loc.gameNoOrdersYetTitle,
                          message: loc.gameNoOrdersYetMessage,
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
                                        debugPrint(
                                            'Failed to cancel order: $e');
                                        if (context.mounted) {
                                          showToast(
                                              context,
                                              loc.gameCancelOrderFailedToast,
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
            label: AppLocalizations.of(context)!.gameCancelOrder,
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
    final loc = AppLocalizations.of(context)!;

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
                Text(loc.gameDrawBannerTitle, style: t.titleSmall),
                Text(
                  hasVoted
                      ? loc.gameDrawWaitingOnOthers
                      : loc.gameDrawEveryoneMustAccept,
                  style: t.bodySmall?.copyWith(color: c.labelSecondary),
                ),
              ],
            ),
          ),
          if (!hasVoted) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton(loc.gameDrawAccept,
                onPressed: onAccept, compact: true, expand: false),
            const SizedBox(width: AppSpacing.sm),
            AppButton(loc.gameDrawReject,
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
    required this.onConfirmDisband,
  });

  final OrderBloc bloc;
  final bool isReady;
  final int orderCount;
  final VoidCallback onToggleReady;

  /// Wraps the destructive-action confirmation around `bloc.setAction
  /// (ActionType.disband)` — Disband appears in both the retreat and the
  /// adjustment chip sets below, so both go through the same confirmation.
  final VoidCallback onConfirmDisband;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    Widget content;
    switch (bloc.currentState) {
      case OrderState.unitSelected:
        content = _actionsRow(context);

      case OrderState.buildChoice:
        content = _buildChoiceRow(context);

      case OrderState.pendingCancel:
        content = _pendingCancelRow(context, c, t);

      case OrderState.moveTarget:
      case OrderState.retreatTarget:
      case OrderState.supportAux:
      case OrderState.supportTarget:
      case OrderState.convoyAux:
      case OrderState.convoyTarget:
        content = _targetPromptRow(context, c, t);

      case OrderState.idle:
        content = _readyRow(context, c, t);
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

  // Movement → Hold/Move/Support/Convoy; retreat → Retreat/Disband;
  // adjustment (negative quota, a unit was tapped) → Disband. Never all
  // five in one bar — mirrors orders_ui.js's onProvinceClick, which builds
  // a different button set per phase kind rather than one fixed row.
  Widget _actionsRow(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final actions = <Widget>[];
    switch (bloc.phaseKind) {
      case kPhaseRetreat:
        actions.add(_Action(loc.orderRetreat, CupertinoIcons.arrow_uturn_left,
            () => bloc.setAction(ActionType.retreat)));
        actions.add(_Action(
            loc.orderDisband, CupertinoIcons.xmark_circle, onConfirmDisband));
      case kPhaseAdjustment:
        // Only reached when quota < 0 tapped an own unit — build candidates
        // go through OrderState.buildChoice instead.
        actions.add(_Action(
            loc.orderDisband, CupertinoIcons.xmark_circle, onConfirmDisband));
      default:
        actions.add(_Action(loc.orderHold, CupertinoIcons.shield,
            () => bloc.setAction(ActionType.hold)));
        actions.add(_Action(loc.orderMove, CupertinoIcons.arrow_right,
            () => bloc.setAction(ActionType.move)));
        // Hide Support/Convoy outright when there is nothing they could
        // legally do — orders_ui.js drops the button rather than opening a
        // menu that can only ever be backed out of.
        if (bloc.canSupport) {
          actions.add(_Action(loc.orderSupport, CupertinoIcons.arrow_branch,
              () => bloc.setAction(ActionType.support)));
        }
        if (bloc.canConvoy) {
          actions.add(_Action(loc.orderConvoy, CupertinoIcons.location_north_fill,
              () => bloc.setAction(ActionType.convoy)));
        }
    }

    return Row(
      key: const ValueKey('actions'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: actions),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CancelButton(onTap: bloc.reset),
      ],
    );
  }

  // Adjustment build menu: Army always, Fleet only at a port — mirrors
  // orders_ui.js's showBuildButtons(code, isPort).
  Widget _buildChoiceRow(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final actions = <Widget>[
      _Action(loc.unitArmy, CupertinoIcons.person_fill,
          () => bloc.setAction(ActionType.buildArmy)),
    ];
    if (bloc.selectedScIsPort) {
      actions.add(_Action(loc.unitFleet, CupertinoIcons.location_north_fill,
          () => bloc.setAction(ActionType.buildFleet)));
    }
    return Row(
      key: const ValueKey('build'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: actions),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CancelButton(onTap: bloc.reset),
      ],
    );
  }

  // Re-tapping a province that already carries a submitted build, disband
  // or retreat order — offers a cancel instead of reopening the order
  // dialog on top of it (orders_ui.js's existingBuild/existingDisband/
  // existingOrder checks in onProvinceClick).
  Widget _pendingCancelRow(BuildContext context, AppColors c, TextTheme t) {
    final loc = AppLocalizations.of(context)!;
    final order = bloc.pendingOrder;
    final type = (order?['order_type'] as num?)?.toInt();
    String label = loc.gameCancelOrder;
    if (type == kOrderBuild) label = loc.gameCancelBuild;
    if (type == kOrderDisband) label = loc.gameCancelDisband;
    if (type == kOrderRetreat) label = loc.gameCancelRetreat;

    return Row(
      key: const ValueKey('pending-cancel'),
      children: [
        Expanded(
          child: Text(
            loc.gamePendingOrderStatus(
                (order?['order_type_name'] as String?) ?? label,
                bloc.selectedProvince ?? ''),
            style: t.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton(
          label,
          onPressed: bloc.cancelPendingOrder,
          style: AppButtonStyle.tinted,
          compact: true,
          expand: false,
        ),
        const SizedBox(width: AppSpacing.sm),
        _CancelButton(onTap: bloc.reset),
      ],
    );
  }

  // The map is waiting for a tap: a move/retreat destination, a support/
  // convoy aux unit, or a support/convoy destination. The explicit "Support
  // hold" button only appears once an aux is chosen and the supporter can
  // actually reach that aux's own province — mirrors orders_ui.js's
  // canHoldSupport button, which exists because a tap on the aux province
  // itself is deliberately ignored (see OrderBloc._onSupportTargetTap).
  Widget _targetPromptRow(BuildContext context, AppColors c, TextTheme t) {
    final loc = AppLocalizations.of(context)!;
    String hint;
    switch (bloc.currentState) {
      case OrderState.retreatTarget:
        hint = loc.gameTargetPromptRetreat;
      case OrderState.supportAux:
        hint = loc.gameTargetPromptSupportAux;
      case OrderState.supportTarget:
        hint = loc.gameTargetPromptSupportTarget;
      case OrderState.convoyAux:
        hint = loc.gameTargetPromptConvoyAux;
      case OrderState.convoyTarget:
        hint = loc.gameTargetPromptConvoyTarget;
      default:
        hint = loc.gameTargetPromptDefault;
    }

    return Row(
      key: ValueKey('target-${bloc.currentState}'),
      children: [
        Icon(CupertinoIcons.hand_point_right_fill, size: 18, color: c.accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(hint, style: t.bodyLarge)),
        if (bloc.currentState == OrderState.supportTarget && bloc.canSupportHold) ...[
          AppButton(
            loc.gameSupportHold,
            onPressed: bloc.supportHold,
            style: AppButtonStyle.tinted,
            compact: true,
            expand: false,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        _CancelButton(onTap: bloc.reset),
      ],
    );
  }

  Widget _readyRow(BuildContext context, AppColors c, TextTheme t) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      key: const ValueKey('ready'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isReady ? loc.gameReadyLabel : loc.gameYourMoveLabel,
                style: t.titleSmall
                    ?.copyWith(color: isReady ? c.green : c.labelPrimary),
              ),
              Text(
                orderCount == 0
                    ? loc.gameOrderCountEmpty
                    : loc.gameOrdersSubmitted(orderCount),
                style: t.bodySmall?.copyWith(color: c.labelSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppButton(
          isReady ? loc.gameNotReadyLabel : loc.gameReadyLabel,
          icon: isReady ? null : CupertinoIcons.check_mark,
          style: isReady ? AppButtonStyle.tinted : AppButtonStyle.filled,
          onPressed: onToggleReady,
          expand: false,
          compact: true,
        ),
      ],
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
      label: AppLocalizations.of(context)!.commonCancel,
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
