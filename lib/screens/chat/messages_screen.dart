import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../blocs/chat/chat_bloc.dart';

class MessagesScreen extends StatefulWidget {
  final ChatBloc bloc;
  final int conversationId;

  const MessagesScreen({super.key, required this.bloc, required this.conversationId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.bloc.fetchMessages(widget.conversationId);
    widget.bloc.markAsRead(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.bloc,
      child: Consumer<ChatBloc>(
        builder: (context, bloc, child) {
          final conv = bloc.conversations.firstWhere((c) => c['id'] == widget.conversationId);
          final title = conv['title'] ?? 'Chat';
          final isE2ee = conv['encryption'] == 'e2ee';
          final msgs = bloc.messages[widget.conversationId] ?? [];

          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Text(title),
                  if (isE2ee) Padding(
                    padding: const EdgeInsets.only(left: 8), 
                    child: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary, size: 16),
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final msg = msgs[index];
                      final isMine = msg['is_mine'] == true;
                      
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMine) Text(
                                msg['sender_empire_name'] ?? '', 
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                msg['text'] ?? '[decryption pending]',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(hintText: 'Type message...'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          if (_controller.text.trim().isNotEmpty) {
                            bloc.sendMessage(widget.conversationId, _controller.text.trim());
                            _controller.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
