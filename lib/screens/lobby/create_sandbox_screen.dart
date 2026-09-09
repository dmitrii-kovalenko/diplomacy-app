import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/lobby_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// A sandbox is one decision wide, so the screen is too: explain what it is,
/// pick a map, start.
class CreateSandboxScreen extends StatefulWidget {
  const CreateSandboxScreen({super.key});

  @override
  State<CreateSandboxScreen> createState() => _CreateSandboxScreenState();
}

class _CreateSandboxScreenState extends State<CreateSandboxScreen> {
  final _lobbyService = LobbyService();
  List<dynamic> _maps = [];
  String? _selectedMap;
  bool _isLoading = false;
  bool _mapsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMaps();
  }

  Future<void> _fetchMaps() async {
    try {
      final maps = await _lobbyService.fetchMaps();
      if (!mounted) return;
      setState(() {
        _maps = maps;
        _mapsLoading = false;
        if (maps.isNotEmpty) _selectedMap = maps.first['id']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mapsLoading = false);
      showToast(context, AppLocalizations.of(context)!.sandboxLoadMapsError,
          isError: true);
    }
  }

  String _selectedMapName(AppLocalizations loc) {
    final match = _maps.firstWhere(
      (m) => m['id']?.toString() == _selectedMap,
      orElse: () => null,
    );
    if (match == null) {
      return _mapsLoading ? loc.loadingEllipsis : loc.mapNoneAvailable;
    }
    return match['name']?.toString() ?? '—';
  }

  Future<void> _pickMap(AppLocalizations loc) async {
    if (_maps.isEmpty) return;
    final picked = await showChoiceSheet<String>(
      context,
      title: loc.map,
      selected: _selectedMap,
      options: [
        for (final m in _maps)
          (
            value: m['id'].toString(),
            label: m['name']?.toString() ?? '—',
            detail: null,
          ),
      ],
    );
    if (picked != null) setState(() => _selectedMap = picked);
  }

  Future<void> _createSandbox() async {
    setState(() => _isLoading = true);
    try {
      await _lobbyService.createSandbox({'game_map_id': _selectedMap});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Could not start the sandbox: $e');
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.sandboxCreateError,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(loc.sandboxLabel)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm,
                AppSpacing.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentMuted,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(CupertinoIcons.wand_stars,
                      size: 26, color: c.accent),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(loc.sandboxHeadline, style: t.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  loc.sandboxDescription,
                  style: t.bodyMedium?.copyWith(color: c.labelSecondary),
                ),
              ],
            ),
          ),
          InsetSection(
            header: loc.sandboxBoardSection,
            children: [
              InsetRow(
                title: loc.map,
                icon: CupertinoIcons.map,
                value: _selectedMapName(loc),
                onTap: _maps.isEmpty ? null : () => _pickMap(loc),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          loc.sandboxStartButton,
          loading: _isLoading,
          onPressed: _selectedMap == null ? null : _createSandbox,
        ),
      ),
    );
  }
}
