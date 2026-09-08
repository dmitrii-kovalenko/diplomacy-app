import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../blocs/chat/chat_bloc.dart';
import 'messages_screen.dart';

class ConversationsScreen extends StatelessWidget {
  final String gameId;
  const ConversationsScreen({super.key, required this.gameId});

  void _showNewConversationModal(BuildContext context, ChatBloc bloc) {
    // Ideally fetch empires from game state, mock for now
    final mockEmpires = ['FRA', 'ENG', 'GER', 'ITA', 'RUS', 'TUR', 'AUS'];
    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('New Conversation', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: mockEmpires.map((emp) {
                      final isSelected = selected.contains(emp);
                      return ChoiceChip(
                        label: Text(emp),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selected.add(emp);
                            } else {
                              selected.remove(emp);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: selected.isEmpty ? null : () {
                      bloc.createConversation(selected.toList());
                      Navigator.pop(ctx);
                    },
                    child: const Text('Start Chat'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatBloc(gameId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Conversations')),
        body: Consumer<ChatBloc>(
          builder: (context, bloc, child) {
            if (bloc.isLoading) return const Center(child: CircularProgressIndicator());
            if (bloc.conversations.isEmpty) return const Center(child: Text('No conversations.'));

            return ListView.builder(
              itemCount: bloc.conversations.length,
              itemBuilder: (context, index) {
                final conv = bloc.conversations[index];
                final unread = conv['unread_count'] ?? 0;
                final lastMsg = conv['last_message'];
                String preview = 'No messages';
                if (lastMsg != null) {
                  preview = lastMsg['text'] ?? '';
                }
                final title = conv['title'] ?? 'Conversation';
                return ListTile(
                  title: Text(
                    title, 
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: unread > 0 
                    ? CircleAvatar(
                        radius: 12, 
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '$unread', 
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ) 
                    : null,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesScreen(bloc: bloc, conversationId: conv['id'])));
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () => _showNewConversationModal(context, context.read<ChatBloc>()),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
