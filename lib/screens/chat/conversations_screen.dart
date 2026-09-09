import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'messages_screen.dart';

/// Labels a conversation the same way the Mini App's `chatConvLabel` does:
/// by the *other* members' countries, joined. `Conversation.title` is an
/// optional field the create endpoint accepts and almost nobody sets, and an
/// empty string is not null, so it must be checked explicitly rather than
/// relying on `??`.
String conversationLabel(Map<String, dynamic> conv, String? myEmpireCode) {
  final title = (conv['title'] ?? '').toString().trim();
  if (title.isNotEmpty) return title;
  final members = List<Map<String, dynamic>>.from(conv['members'] as List? ?? []);
  final others = members
      .where((m) => m['empire_code'] != null && m['empire_code'] != myEmpireCode)
      .toList();
  final list = others.isNotEmpty ? others : members;
  final names = list
      .map((m) => (m['empire_name'] ?? m['empire_code'])?.toString())
      .whereType<String>()
      .where((n) => n.isNotEmpty)
      .toList();
  return names.isNotEmpty ? names.join(', ') : 'Conversation';
}

/// The other members of a conversation, for colour dots and chip lists —
/// everyone except the viewer's own empire.
List<Map<String, dynamic>> otherMembers(
    Map<String, dynamic> conv, String? myEmpireCode) {
  final members = List<Map<String, dynamic>>.from(conv['members'] as List? ?? []);
  return members
      .where((m) => m['empire_code'] != null && m['empire_code'] != myEmpireCode)
      .toList();
}

/// Parses the server's `#RRGGBB` empire colour, same convention the map
/// inlines twice for unit and supply-centre colouring
/// (`lib/models/board_state.dart:37, 98`) — a per-country identity, not a
/// design-system token, so it is read straight off the payload rather than
/// substituted with an app colour.
Color? empireColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final value = int.tryParse('0xFF${hex.substring(1)}');
  return value == null ? null : Color(value);
}

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
    // A prior fetch that already failed leaves the bloc idle on bad data
    // forever otherwise — kick off one more attempt each time the sheet is
    // reopened. A fetch still in flight (e.g. from ChatBloc._init) needs no
    // help; the AnimatedBuilder below picks it up when it resolves.
    if (!bloc.participantsLoading && !bloc.participantsLoaded) {
      bloc.retryParticipants();
    }
    final selected = <String>{};

    showAppSheet(
      context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        final t = Theme.of(ctx).textTheme;
        // Listens to the bloc directly rather than snapshotting
        // `bloc.participants` once: this builder runs a single time when the
        // sheet opens, so a snapshot never sees a fetch that was still in
        // flight (or was retried) resolve — the sheet would sit on "No other
        // countries in this game." forever, T20 defect 3's exact symptom
        // with participants instead of the hardcoded empire list.
        return AnimatedBuilder(
          animation: bloc,
          builder: (ctx, _) {
            final seats = bloc.participants
                .where((p) =>
                    p['empire_code'] != null &&
                    p['empire_code'] != bloc.myEmpireCode)
                .toList();
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
                        'Pick who is at the table. Everyone selected sees '
                        'every message in this thread.',
                        style: t.bodyMedium?.copyWith(color: c.labelSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (bloc.participantsLoading)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: AppLoader()),
                        )
                      else if (!bloc.participantsLoaded)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg),
                          child: Column(
                            children: [
                              Text(
                                'Could not load the other powers.',
                                style: t.bodyMedium
                                    ?.copyWith(color: c.labelSecondary),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppButton(
                                'Retry',
                                style: AppButtonStyle.tinted,
                                onPressed: () => bloc.retryParticipants(),
                              ),
                            ],
                          ),
                        )
                      else if (seats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg),
                          child: Text(
                            'No other countries in this game.',
                            style: t.bodyMedium
                                ?.copyWith(color: c.labelSecondary),
                          ),
                        )
                      else
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final seat in seats)
                              _EmpireChip(
                                label: (seat['empire_name'] ??
                                        seat['empire_code'])
                                    .toString(),
                                color: empireColor(
                                    seat['empire_color'] as String?),
                                selected: selected
                                    .contains(seat['empire_code'].toString()),
                                onTap: () => setState(() {
                                  final code =
                                      seat['empire_code'].toString();
                                  if (!selected.remove(code)) {
                                    selected.add(code);
                                  }
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
                            : () async {
                                final ok = await bloc
                                    .createConversation(selected.toList());
                                if (!ctx.mounted) return;
                                if (ok) {
                                  Navigator.pop(ctx);
                                } else {
                                  showToast(
                                    ctx,
                                    'Could not start that conversation. '
                                    'Try again.',
                                    isError: true,
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
                              myEmpireCode: bloc.myEmpireCode,
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
  const _ConversationRow({
    required this.conversation,
    required this.myEmpireCode,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final String? myEmpireCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final unread = (conversation['unread'] as num?)?.toInt() ?? 0;
    final title = conversationLabel(conversation, myEmpireCode);
    final others = otherMembers(conversation, myEmpireCode);
    final last = conversation['last_message'];
    final isE2ee = conversation['encryption'] == 'e2ee';
    final isMuted = conversation['is_muted'] == true;
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
                      if (isMuted) ...[
                        const SizedBox(width: 5),
                        Icon(CupertinoIcons.bell_slash_fill,
                            size: 11, color: c.labelTertiary),
                      ],
                      if (others.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        for (final m in others.take(4))
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: empireColor(
                                        m['empire_color'] as String?) ??
                                    c.labelQuaternary,
                              ),
                            ),
                          ),
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
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final Color? color;
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
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
            ],
            if (selected) ...[
              Icon(CupertinoIcons.check_mark, size: 13, color: c.accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? c.accent : c.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
