import 'package:flutter/material.dart';
import '../../services/game_service.dart';
import '../../widgets/map_viewer.dart';

class GamePreviewScreen extends StatefulWidget {
  final String gameId;
  const GamePreviewScreen({super.key, required this.gameId});

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
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Failed to load preview: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Preview (ID: ${widget.gameId})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _svgString == null
              ? const Center(child: Text('Failed to load map preview.'))
              : MapViewer(
                  svgString: _svgString!,
                  isReadOnly: true,
                  onProvinceTapped: (province) {
                    // Read-only, do nothing
                  },
                ),
    );
  }
}
