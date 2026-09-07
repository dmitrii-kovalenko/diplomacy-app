import 'package:flutter/material.dart';
import '../models/game_model.dart';

class GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onEnter;
  final VoidCallback? onMuteToggle;

  const GameCard({
    super.key,
    required this.game,
    this.onJoin,
    this.onLeave,
    this.onEnter,
    this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    game.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (game.isPrivate) const Icon(Icons.lock, size: 16),
                if (game.isSandbox) const Icon(Icons.science, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text('Map: ${game.mapName ?? "Standard"}'),
            if (game.phase != null) Text('Phase: ${game.phase}'),
            if (game.deadline != null) Text('Deadline: ${game.deadline}'),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Wrap(
              spacing: 8,
              children: [
                if (onEnter != null)
                  ElevatedButton(
                    onPressed: onEnter,
                    child: const Text('Enter'),
                  ),
                if (onJoin != null)
                  ElevatedButton(
                    onPressed: onJoin,
                    child: const Text('Join'),
                  ),
                if (onLeave != null)
                  OutlinedButton(
                    onPressed: onLeave,
                    child: const Text('Leave'),
                  ),
                if (onMuteToggle != null)
                  IconButton(
                    icon: const Icon(Icons.notifications_off),
                    onPressed: onMuteToggle,
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
