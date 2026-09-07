import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../blocs/game/order_bloc.dart';
import '../../services/game_service.dart';
import '../../widgets/map_viewer.dart';
import '../../widgets/order_arrows.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  bool _isLoading = true;
  bool _isReady = false;
  int _historyOffset = 0;
  bool _isHistoryMode = false;

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
      // The SVG URL is relative to the backend. In dev, we prepend the backend URL.
      // But for this environment, let's assume AuthService's dio base options handles it, 
      // or we just fetch it. Wait, `map_svg_url` might be like `/static/game/maps/classic.svg?v=123`.
      final svgStr = await _gameService.fetchSvg(svgUrl);

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
      }
    }
  }

  void _toggleReady() async {
    setState(() => _isReady = !_isReady);
    await _gameService.toggleReady(widget.gameId, _isReady, false);
    _loadGame(); // Reload state
  }

  void _surrender() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Surrender?'),
        content: const Text('Are you sure you want to surrender?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirm == true) {
      await _gameService.surrender(widget.gameId);
      _loadGame();
    }
  }

  void _proposeDraw() async {
    await _gameService.proposeDraw(widget.gameId);
    _loadGame();
  }

  void _voteDraw(bool accept) async {
    await _gameService.drawVote(widget.gameId, accept);
    _loadGame();
  }

  void _fetchHistory(int offset) async {
    try {
      if (offset == 0) {
        await _loadGame();
        setState(() {
          _historyOffset = 0;
          _isHistoryMode = false;
        });
        return;
      }
      final data = await _gameService.fetchHistory(widget.gameId, offset);
      setState(() {
        _gameState = data;
        _historyOffset = offset;
        _isHistoryMode = offset < 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('History error: $e')));
      }
    }
  }

  void _showBuildModal(BuildContext context, OrderBloc bloc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Build Army'),
            onTap: () {
              bloc.setAction(ActionType.buildArmy);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_boat),
            title: const Text('Build Fleet'),
            onTap: () {
              bloc.setAction(ActionType.buildFleet);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final drawProposal = _gameState?['draw_proposal'];
    bool hasVotedDraw = false;
    if (drawProposal != null) {
      final myVotePending = drawProposal['my_vote_pending'] as bool? ?? true;
      hasVotedDraw = !myVotePending;
    }

    return ChangeNotifierProvider(
      create: (context) {
        final bloc = OrderBloc(widget.gameId, onOrderSubmitted: _loadGame);
        bloc.setGameState(_gameState!);
        return bloc;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isHistoryMode ? 'History (Offset: $_historyOffset)' : 'Game ${widget.gameId}'),
          actions: [
            if (_isHistoryMode) ...[
              IconButton(icon: const Icon(Icons.arrow_left), onPressed: () => _fetchHistory(_historyOffset - 1)),
              IconButton(icon: const Icon(Icons.arrow_right), onPressed: () => _fetchHistory(_historyOffset + 1)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => _fetchHistory(0)), // Exit history
            ],
            if (!_isHistoryMode) ...[
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.list_alt),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
              IconButton(icon: Icon(_isReady ? Icons.check_circle : Icons.check_circle_outline), onPressed: _toggleReady),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'draw') _proposeDraw();
                  if (val == 'surrender') _surrender();
                  if (val == 'history') _fetchHistory(-1);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'history', child: Text('View History')),
                  PopupMenuItem(value: 'draw', child: Text('Propose Draw')),
                  PopupMenuItem(value: 'surrender', child: Text('Surrender')),
                ],
              ),
            ],
          ],
        ),
        endDrawer: _buildOrdersDrawer(),
        body: Column(
          children: [
            if (drawProposal != null)
              Container(
                color: Colors.orange[100],
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Expanded(child: Text('A draw has been proposed.')),
                    if (!hasVotedDraw) ...[
                      TextButton(onPressed: () => _voteDraw(true), child: const Text('Accept')),
                      TextButton(onPressed: () => _voteDraw(false), child: const Text('Reject')),
                    ] else
                      const Text('Waiting on others...'),
                  ],
                ),
              ),
            Expanded(
              child: Consumer<OrderBloc>(
                builder: (context, bloc, child) {
                  // Build mock orders for the map visualization
                  final List<Order> renderedOrders = [];
                  if (_gameState != null && _gameState!['my_orders'] != null) {
                    // Mapping requires SVG offsets which we don't have easily outside MapViewer.
                  }

                  return MapViewer(
                    svgString: _svgString ?? '<svg></svg>',
                    onSvgParsed: (mapData) {
                      bloc.setMapData(mapData);
                    },
                    onProvinceTapped: (province) {
                      if (_isHistoryMode) return;
                      // Determine if it has a unit
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
                          if (sc['province_code'] == province && sc['empire_code'] == myCode) {
                            isOwnedSc = true;
                            break;
                          }
                        }
                      }

                      final phaseKind = _gameState?['phase']?['kind'] ?? 'diplomacy';

                      bloc.selectProvince(province, hasUnit, isOwned, phaseKind, isOwnedSc);
                    },
                    activeOrderUnitProvince: bloc.selectedProvince,
                    validTargetProvinces: bloc.validTargetProvinces,
                    orders: renderedOrders,
                  );
                },
              ),
            ),
            Consumer<OrderBloc>(
              builder: (context, bloc, child) {
                if (_isHistoryMode) return const SizedBox.shrink();

                if (bloc.currentState == OrderState.unitSelected) {
                  return Container(
                    color: Colors.grey[200],
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: () => bloc.setAction(ActionType.hold), child: const Text('Hold')),
                        ElevatedButton(onPressed: () => bloc.setAction(ActionType.move), child: const Text('Move')),
                        ElevatedButton(onPressed: () => bloc.setAction(ActionType.support), child: const Text('Support')),
                        ElevatedButton(onPressed: () => bloc.setAction(ActionType.convoy), child: const Text('Convoy')),
                        ElevatedButton(onPressed: () => _showBuildModal(context, bloc), child: const Text('Build...')),
                        IconButton(icon: const Icon(Icons.cancel), onPressed: () => bloc.reset()),
                      ],
                    ),
                  );
                } else if (bloc.currentState == OrderState.targetSelection) {
                  return Container(
                    color: Colors.blue[100],
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Tap destination province on map...')),
                        IconButton(icon: const Icon(Icons.cancel), onPressed: () => bloc.reset()),
                      ],
                    ),
                  );
                } else if (bloc.currentState == OrderState.auxTargetSelection) {
                  return Container(
                    color: Colors.purple[100],
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Tap destination of supported/convoyed unit...')),
                        IconButton(icon: const Icon(Icons.cancel), onPressed: () => bloc.reset()),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
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
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(),
            if (myOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No orders submitted.'),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: myOrders.length,
                itemBuilder: (context, index) {
                  final order = myOrders[index];
                  String text = '${order['unit_type']} ${order['source_code']} - ${order['order_type_name']}';
                  if (order['target_code'] != null) text += ' ${order['target_code']}';
                  if (order['aux_code'] != null) text += ' ${order['aux_code']}';

                  return ListTile(
                    title: Text(text),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        try {
                          await _gameService.cancelOrder(order['id'].toString());
                          _loadGame();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
