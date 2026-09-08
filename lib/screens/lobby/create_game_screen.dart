import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/lobby_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// Creating a room, as a grouped form.
///
/// Pickers are sheets rather than dropdowns (dropdowns have no Apple
/// equivalent), switches carry a one-line explanation of what they change, and
/// the single primary action sits in a pinned bar so it stays reachable no
/// matter how far the form scrolls.
class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final _nameController = TextEditingController();
  final _rulesController = TextEditingController();
  final _lobbyService = LobbyService();

  List<dynamic> _maps = [];
  String? _selectedMap;
  String _turnLength = '24h';

  bool _randomAssignment = true;
  bool _isAnonymous = false;
  bool _isPrivate = false;
  bool _hostAsMaster = false;
  bool _isLoading = false;
  bool _mapsLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
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
      showToast(context, 'Could not load maps. Pull back and try again.',
          isError: true);
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

  String _turnLabel(AppLocalizations loc) => switch (_turnLength) {
        '12h' => loc.hours12,
        '48h' => loc.hours48,
        _ => loc.hours24,
      };

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

  Future<void> _pickTurnLength(AppLocalizations loc) async {
    final picked = await showChoiceSheet<String>(
      context,
      title: loc.turnLength,
      selected: _turnLength,
      options: [
        (value: '12h', label: loc.hours12, detail: 'Fast, for focused groups'),
        (value: '24h', label: loc.hours24, detail: 'The classic pace'),
        (value: '48h', label: loc.hours48, detail: 'Relaxed, for long games'),
      ],
    );
    if (picked != null) setState(() => _turnLength = picked);
  }

  Future<void> _createGame() async {
    setState(() => _isLoading = true);
    try {
      await _lobbyService.createGame({
        'name': _nameController.text.trim(),
        'game_map_id': _selectedMap,
        'turn_length': _turnLength,
        'random_assignment': _randomAssignment,
        'is_anonymous': _isAnonymous,
        'is_private': _isPrivate,
        'host_as_master': _hostAsMaster,
        'house_rules': _rulesController.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not create the game. $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final canCreate =
        _nameController.text.trim().isNotEmpty && _selectedMap != null;

    return Scaffold(
      appBar: AppBar(title: Text(loc.createLobby)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          InsetSection(
            header: 'Room',
            children: [
              _FieldRow(
                controller: _nameController,
                label: loc.gameName,
                hint: 'Congress of Vienna',
                textInputAction: TextInputAction.next,
              ),
              InsetRow(
                title: loc.map,
                icon: CupertinoIcons.map,
                value: _selectedMapName,
                onTap: _maps.isEmpty ? null : () => _pickMap(loc),
              ),
              InsetRow(
                title: loc.turnLength,
                icon: CupertinoIcons.clock,
                value: _turnLabel(loc),
                onTap: () => _pickTurnLength(loc),
              ),
            ],
          ),
          InsetSection(
            header: 'Rules',
            footer: 'These cannot be changed once the first turn resolves.',
            children: [
              InsetSwitchRow(
                title: loc.randomAssignment,
                subtitle: 'Deal the powers at random when the room fills.',
                value: _randomAssignment,
                onChanged: (v) => setState(() => _randomAssignment = v),
              ),
              InsetSwitchRow(
                title: loc.anonymous,
                subtitle: 'Hide who plays which power until the game ends.',
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v),
              ),
              InsetSwitchRow(
                title: loc.privateRoom,
                subtitle: 'Only players with the room code can join.',
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
              InsetSwitchRow(
                title: loc.hostAsMaster,
                subtitle: 'You referee instead of taking a power.',
                value: _hostAsMaster,
                onChanged: (v) => setState(() => _hostAsMaster = v),
              ),
            ],
          ),
          InsetSection(
            header: loc.houseRules,
            footer: 'Shown to everyone in the room before they commit.',
            children: [
              _FieldRow(
                controller: _rulesController,
                label: null,
                hint: 'No stabs before 1902…',
                maxLines: 4,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!canCreate)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Text(
                'Give the room a name to continue.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.labelTertiary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          loc.create,
          loading: _isLoading,
          onPressed: canCreate ? _createGame : null,
        ),
      ),
    );
  }
}

/// A text field shaped like a grouped-list row: label on the leading edge,
/// the field itself filling the rest, no box around it.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: t.bodyLarge,
      cursorColor: c.accent,
      decoration: InputDecoration(
        hintText: hint,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMetrics.minTap - 24),
        child: label == null
            ? field
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(label!,
                        style: t.bodyLarge?.copyWith(color: c.labelSecondary)),
                  ),
                  Expanded(child: field),
                ],
              ),
      ),
    );
  }
}
