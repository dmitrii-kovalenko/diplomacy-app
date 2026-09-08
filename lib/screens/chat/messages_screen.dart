import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// A single negotiation thread.
///
/// Bubbles are the familiar messaging shape: mine on the trailing edge in the
/// accent, theirs on the leading edge on an elevated surface. The composer is
/// a capsule field with a circular send button that only lights up when there
/// is something to send, and it clears the home indicator on its own.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.bloc,
    required this.conversationId,
  });

  final ChatBloc bloc;
  final int conversationId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    widget.bloc.fetchMessages(widget.conversationId);
    widget.bloc.markAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(ChatBloc bloc) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    bloc.sendMessage(widget.conversationId, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return ChangeNotifierProvider.value(
      value: widget.bloc,
      child: Consumer<ChatBloc>(
        builder: (context, bloc, child) {
          final conv = bloc.conversations.firstWhere(
            (c) => c['id'] == widget.conversationId,
            orElse: () => <String, dynamic>{'title': 'Chat'},
          );
          final title = (conv['title'] ?? 'Chat').toString();
          final isE2ee = conv['encryption'] == 'e2ee';
          final msgs = bloc.messages[widget.conversationId] ?? [];

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (isE2ee)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.lock_fill,
                            size: 10, color: c.green),
                        const SizedBox(width: 4),
                        Text('End-to-end encrypted',
                            style: t.labelSmall?.copyWith(color: c.green)),
                      ],
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: msgs.isEmpty
                      ? const AppEmptyState(
                          icon: CupertinoIcons.bubble_left,
                          title: 'Nothing said yet',
                          message: 'Open with an offer. Or a lie.',
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                              AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
                          itemCount: msgs.length,
                          itemBuilder: (context, index) => _Bubble(
                            message: msgs[index],
                            previousSender: index == 0
                                ? null
                                : msgs[index - 1]['sender_empire_name']
                                    ?.toString(),
                          ),
                        ),
                ),
                _Composer(
                  controller: _controller,
                  onSend: () => _send(bloc),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.previousSender});

  final Map<String, dynamic> message;
  final String? previousSender;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final isMine = message['is_mine'] == true;
    final sender = message['sender_empire_name']?.toString();
    final text = message['text']?.toString();
    final pending = text == null || text.isEmpty;

    // Only label the first bubble in a run from the same power — repeating the
    // name on every line is noise once the speaker is established.
    final showSender = !isMine && sender != null && sender != previousSender;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.md, bottom: 3),
              child: Text(sender,
                  style: t.labelSmall?.copyWith(color: c.labelSecondary)),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: isMine ? c.accent : c.bgElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isMine ? AppRadius.lg : 6),
                  bottomRight: Radius.circular(isMine ? 6 : AppRadius.lg),
                ),
                border: isMine
                    ? null
                    : Border.all(
                        color: c.separator, width: AppMetrics.hairline),
              ),
              child: pending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.lock_fill,
                            size: 12, color: c.labelTertiary),
                        const SizedBox(width: 6),
                        Text('Decrypting…',
                            style: t.bodyMedium
                                ?.copyWith(color: c.labelTertiary)),
                      ],
                    )
                  : Text(
                      text,
                      style: t.bodyLarge?.copyWith(
                          color: isMine ? c.onAccent : c.labelPrimary),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canSend = controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.bgBase,
        border: Border(
            top: BorderSide(color: c.separator, width: AppMetrics.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: AppRadius.brCapsule,
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: c.accent,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: c.labelTertiary),
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                button: true,
                label: 'Send message',
                child: PressableScale(
                  onTap: canSend ? onSend : null,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    height: AppMetrics.minTap,
                    width: AppMetrics.minTap,
                    decoration: BoxDecoration(
                      color: canSend ? c.accent : c.fill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.arrow_up,
                      size: 19,
                      color: canSend ? c.onAccent : c.labelTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
