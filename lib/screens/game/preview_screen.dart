import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/board_state.dart';
import '../../services/game_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/map_viewer.dart';
import '../../widgets/ui_kit.dart';

/// Read-only board. Chrome only — the map itself renders exactly as it always
/// has.
class GamePreviewScreen extends StatefulWidget {
  const GamePreviewScreen({super.key, required this.gameId});

  final String gameId;

  @override
  State<GamePreviewScreen> createState() => _GamePreviewScreenState();
}

class _GamePreviewScreenState extends State<GamePreviewScreen> {
  final GameService _gameService = GameService();
  bool _isLoading = true;
  String? _svgString;

  // The whole preview payload, kept around (not just the SVG URL) so the
  // board can be painted with starting units and supply-centre ownership —
  // game/api/serializers.py's _serialize_preview_state sends the same
  // units/sc_ownership/empires/label_positions shape the live game state
  // does, it was just never read here.
  Map<String, dynamic>? _previewState;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final state = await _gameService.getGamePreview(widget.gameId);
      // Nested under `game`, exactly like the live game state
      // (serializers.py _serialize_preview_state / _serialize_game_state) —
      // it was never at the top level, which is why the board never loaded.
      final svgUrl = state['game']?['map_svg_url'] as String?;
      if (svgUrl != null) {
        final svgStr = await _gameService.fetchSvg(svgUrl);
        if (mounted) {
          setState(() {
            _previewState = state;
            _svgString = svgStr;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Failed to load preview: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Starting supply-centre / default-owner paint. There is no history mode
  // here, so this always reads straight off `sc_ownership` rather than
  // choosing between it and a history payload the way GameScreen does. See
  // lib/models/board_state.dart for the shared conversion and for why it
  // reads off the payload rather than the SVG.
  Map<String, Color> _computeProvinceColors() {
    final state = _previewState;
    if (state == null) return {};
    return BoardState.provinceColors(
      scOwnership: state['sc_ownership'] as List<dynamic>? ?? [],
      empires: state['empires'] as List<dynamic>? ?? [],
    );
  }

  // Province-code label anchors. Labels are static per map, so this payload
  // carries the same `label_positions` shape the live state does.
  Map<String, Offset> _computeLabelPositions() {
    return BoardState.labelPositions(
      _previewState?['label_positions'] as Map<String, dynamic>?,
    );
  }

  // Starting unit placement and colour. `_serialize_preview_state` emits one
  // `units` row per `EmpireStartingUnit`, with the same
  // unit_x/unit_y/color fields the live payload's Unit rows carry.
  (Map<String, Offset>, Map<String, Color>) _computeUnitPositionsAndColors() {
    final units = _previewState?['units'] as List<dynamic>? ?? [];
    return BoardState.unitPositionsAndColors(units);
  }

  // Supply-centre dots, same shape as the live game state — the preview
  // payload's `sc_ownership` rows carry `is_supply_center`/`sc_x`/`sc_y`
  // too, one row per province rather than per phase, since a lobby preview
  // has no history to disagree with.
  Map<String, Offset> _computeScPositions() {
    return BoardState.scPositions(
      _previewState?['sc_ownership'] as List<dynamic>? ?? [],
    );
  }

  // Real army/fleet starting tokens, in place of the flat
  // `unitPositions`/`unitColors` maps above. `_serialize_preview_state`
  // ships the same `coast_positions`/`army_coasts` shape the live state
  // does.
  List<MapUnit> _computeUnits() {
    final units = _previewState?['units'] as List<dynamic>? ?? [];
    return BoardState.units(
      units: units,
      coastPositions:
          _previewState?['coast_positions'] as Map<String, dynamic>?,
      armyCoasts: _previewState?['army_coasts'] as Map<String, dynamic>?,
    );
  }

  // The untranslated SVG basename — `_serialize_preview_state`'s own
  // `map_name` is translated (`str(_(game.game_map.name))`), so this must
  // read the SVG URL instead, same as `GameScreen`.
  String? _computeMapSlug() {
    return BoardState.mapSlugFromSvgUrl(
      _previewState?['game']?['map_svg_url'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (unitPositions, unitColors) = _computeUnitPositionsAndColors();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: StatusPill('#${widget.gameId}'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoader()
          : _svgString == null
              ? AppEmptyState(
                  icon: CupertinoIcons.map,
                  title: 'Board unavailable',
                  message: 'The map for this game could not be loaded.',
                  actionLabel: 'Try again',
                  onAction: () {
                    setState(() => _isLoading = true);
                    _loadPreview();
                  },
                )
              : MapViewer(
                  svgString: _svgString!,
                  provinceColors: _computeProvinceColors(),
                  labelPositions: _computeLabelPositions(),
                  scPositions: _computeScPositions(),
                  unitPositions: unitPositions,
                  unitColors: unitColors,
                  units: _computeUnits(),
                  mapSlug: _computeMapSlug(),
                  isReadOnly: true,
                  onProvinceTapped: (province) {},
                ),
    );
  }
}
