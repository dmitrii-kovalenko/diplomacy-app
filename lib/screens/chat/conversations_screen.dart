import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'messages_screen.dart';

/// The negotiation table.
///
/// Rows carry a power monogram, the last thing said, and an unread count on
/// the trailing edge — the standard messaging row, so nothing has to be
/// learned. Starting a conversation is a sheet of selectable powers rather
/// than a dialog, because it is a task, not an alert.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key, required this.gameId});

  final String gameId;

  void _showNewConversationSheet(BuildContext context, ChatBloc bloc) {
    // Ideally fetched from game state; the classic seven until then.
    const empires = ['FRA', 'ENG', 'GER', 'ITA', 'RUS', 'TUR', 'AUS'];
    final selected = <String>{};

    showAppSheet(
      context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        final t = Theme.of(ctx).textTheme;
        return StatefulBuilder(
          builder: (ctx, setState) => AppSheet(
            title: 'New conversation',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0,
                  AppSpacing.gutter, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pick who is at the table. Everyone selected sees every '
                    'message in this thread.',
                    style: t.bodyMedium?.copyWith(color: c.labelSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final emp in empires)
                        _EmpireChip(
                          code: emp,
                          selected: selected.contains(emp),
                          onTap: () => setState(() {
                            if (!selected.remove(emp)) selected.add(emp);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    selected.isEmpty
                        ? 'Select at least one power'
                        : 'Start chat with ${selected.length}',
                    onPressed: selected.isEmpty
                        ? null
                        : () {
                            bloc.createConversation(selected.toList());
                            Navigator.pop(ctx);
                          },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ChangeNotifierProvider(
      create: (_) => ChatBloc(gameId),
      child: Builder(
        builder: (context) => Scaffold(
          body: Consumer<ChatBloc>(
            builder: (context, bloc, child) => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                SliverAppBar.large(
                  pinned: true,
                  backgroundColor: c.bgBase,
                  title: const Text('Messages'),
                  actions: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.square_pencil),
                      tooltip: 'New conversation',
                      onPressed: () =>
                          _showNewConversationSheet(context, bloc),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
                if (bloc.isLoading)
                  const SliverFillRemaining(
                      hasScrollBody: false, child: AppLoader())
                else if (bloc.conversations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: CupertinoIcons.bubble_left_bubble_right,
                      title: 'No conversations yet',
                      message:
                          'Diplomacy is won in private. Open a channel with '
                          'one power — or several.',
                      actionLabel: 'New conversation',
                      onAction: () =>
                          _showNewConversationSheet(context, bloc),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: InsetSection(
                        children: [
                          for (final conv in bloc.conversations)
                            _ConversationRow(
                              conversation: conv,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MessagesScreen(
                                    bloc: bloc,
                                    conversationId: conv['id'],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.huge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final unread = (conversation['unread_count'] ?? 0) as int;
    final title = (conversation['title'] ?? 'Conversation').toString();
    final last = conversation['last_message'];
    final isE2ee = conversation['encryption'] == 'e2ee';
    final preview = last == null
        ? 'No messages yet'
        : (last['text']?.toString().trim().isNotEmpty == true
            ? last['text'].toString()
            : 'Encrypted message');

    return RowHighlight(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            _Monogram(title),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: unread > 0
                              ? t.titleMedium
                              : t.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isE2ee) ...[
                        const SizedBox(width: 5),
                        Icon(CupertinoIcons.lock_fill,
                            size: 11, color: c.green),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: t.bodyMedium?.copyWith(
                        color: unread > 0 ? c.labelPrimary : c.labelSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (unread > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                    color: c.accent, borderRadius: AppRadius.brCapsule),
                child: Text('$unread',
                    style: t.labelSmall?.copyWith(color: c.onAccent)),
              )
            else
              Icon(CupertinoIcons.chevron_right,
                  size: 15, color: c.labelTertiary),
          ],
        ),
      ),
    );
  }
}

/// Two-letter monogram standing in for a power's crest.
class _Monogram extends StatelessWidget {
  const _Monogram(this.source);

  final String source;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final letters = source
        .split(RegExp(r'[\s,·]+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      height: 40,
      width: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: AppRadius.brCapsule,
      ),
      child: Text(
        letters.isEmpty ? '#' : letters,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: c.labelSecondary),
      ),
    );
  }
}

class _EmpireChip extends StatelessWidget {
  const _EmpireChip({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: AppMetrics.minTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accentMuted : c.fill,
          borderRadius: AppRadius.brCapsule,
          border: Border.all(
            color: selected ? c.accent : Colors.transparent,
            width: selected ? 2 : 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(CupertinoIcons.check_mark, size: 13, color: c.accent),
              const SizedBox(width: 5),
            ],
            Text(
              code,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? c.accent : c.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
