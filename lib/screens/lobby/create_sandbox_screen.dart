import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
      showToast(context, 'Could not load maps.', isError: true);
    }
  }

  String get _selectedMapName {
    final match = _maps.firstWhere(
      (m) => m['id']?.toString() == _selectedMap,
      orElse: () => null,
    );
    if (match == null) return _mapsLoading ? 'Loading…' : 'None available';
    return match['name']?.toString() ?? '—';
  }

  Future<void> _pickMap() async {
    if (_maps.isEmpty) return;
    final picked = await showChoiceSheet<String>(
      context,
      title: 'Map',
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
      if (mounted) {
        showToast(context, 'Could not start the sandbox. $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sandbox')),
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
                Text('Play every power', style: t.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A private board with no opponents and no deadlines. Move '
                  'any unit, resolve the turn whenever you like — the fastest '
                  'way to learn how adjudication actually works.',
                  style: t.bodyMedium?.copyWith(color: c.labelSecondary),
                ),
              ],
            ),
          ),
          InsetSection(
            header: 'Board',
            children: [
              InsetRow(
                title: 'Map',
                icon: CupertinoIcons.map,
                value: _selectedMapName,
                onTap: _maps.isEmpty ? null : _pickMap,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          'Start sandbox',
          loading: _isLoading,
          onPressed: _selectedMap == null ? null : _createSandbox,
        ),
      ),
    );
  }
}
