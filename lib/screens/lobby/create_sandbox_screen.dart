import 'package:flutter/material.dart';
import '../../services/lobby_service.dart';

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

  void _createSandbox() async {
    setState(() => _isLoading = true);
    try {
      await _lobbyService.createSandbox({'map_id': _selectedMap});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating sandbox: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Sandbox')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedMap,
                    decoration: const InputDecoration(labelText: 'Map'),
                    items: _maps.map((m) => DropdownMenuItem<String>(
                      value: m['id'].toString(),
                      child: Text(m['name']),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedMap = val),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _createSandbox,
                    child: const Text('Start Sandbox'),
                  ),
                ],
              ),
            ),
    );
  }
}
