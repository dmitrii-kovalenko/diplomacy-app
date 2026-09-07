import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/lobby_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchMaps();
  }

  Future<void> _fetchMaps() async {
    try {
      final maps = await _lobbyService.fetchMaps();
      setState(() {
        _maps = maps;
        if (maps.isNotEmpty) {
          _selectedMap = maps.first['id']?.toString();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching maps: $e')),
        );
      }
    }
  }

  void _createGame() async {
    setState(() => _isLoading = true);
    try {
      await _lobbyService.createGame({
        'name': _nameController.text,
        'map_id': _selectedMap,
        'turn_length': _turnLength,
        'random_assignment': _randomAssignment,
        'is_anonymous': _isAnonymous,
        'is_private': _isPrivate,
        'host_as_master': _hostAsMaster,
        'house_rules': _rulesController.text,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating game: $e')),
        );
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
    return Scaffold(
      appBar: AppBar(title: Text(loc.createLobby)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: loc.gameName),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedMap,
                  decoration: InputDecoration(labelText: loc.map),
                  items: _maps.map((m) => DropdownMenuItem<String>(
                    value: m['id'].toString(),
                    child: Text(m['name']),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedMap = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _turnLength,
                  decoration: InputDecoration(labelText: loc.turnLength),
                  items: [
                    DropdownMenuItem(value: '12h', child: Text(loc.hours12)),
                    DropdownMenuItem(value: '24h', child: Text(loc.hours24)),
                    DropdownMenuItem(value: '48h', child: Text(loc.hours48)),
                  ],
                  onChanged: (val) => setState(() => _turnLength = val!),
                ),
                SwitchListTile(
                  title: Text(loc.randomAssignment),
                  value: _randomAssignment,
                  onChanged: (val) => setState(() => _randomAssignment = val),
                ),
                SwitchListTile(
                  title: Text(loc.anonymous),
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                ),
                SwitchListTile(
                  title: Text(loc.privateRoom),
                  value: _isPrivate,
                  onChanged: (val) => setState(() => _isPrivate = val),
                ),
                SwitchListTile(
                  title: Text(loc.hostAsMaster),
                  value: _hostAsMaster,
                  onChanged: (val) => setState(() => _hostAsMaster = val),
                ),
                TextField(
                  controller: _rulesController,
                  decoration: InputDecoration(labelText: loc.houseRules),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _createGame,
                  child: Text(loc.create),
                ),
              ],
            ),
    );
  }
}
