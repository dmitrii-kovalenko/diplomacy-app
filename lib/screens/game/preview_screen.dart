import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final state = await _gameService.getGamePreview(widget.gameId);
      final svgUrl = state['map_svg_url'];
      if (svgUrl != null) {
        final svgStr = await _gameService.fetchSvg(svgUrl);
        if (mounted) {
          setState(() {
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

  @override
  Widget build(BuildContext context) {
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
                  isReadOnly: true,
                  onProvinceTapped: (province) {},
                ),
    );
  }
}
