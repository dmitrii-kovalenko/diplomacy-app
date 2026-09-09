import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../services/e2ee_fingerprint.dart' as fp;
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'conversations_screen.dart';

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
  bool _sending = false;

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

  Future<void> _send(ChatBloc bloc) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    // The text stays in the composer until the send resolves — a failed
    // request must never look like it deleted what the player typed.
    setState(() => _sending = true);
    final ok = await bloc.sendMessage(widget.conversationId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
    } else {
      showToast(context, 'Could not send that message. Try again.',
          isError: true);
    }
  }

  Future<void> _showFingerprintSheet(
      BuildContext context, String peerPub) async {
    final hex = await fp.fingerprint(peerPub);
    final grouped = fp.formatFingerprint(hex);
    if (!context.mounted) return;
    await showAppSheet(
      context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        final t = Theme.of(ctx).textTheme;
        return AppSheet(
          title: 'Verify encryption',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Compare this code with the other side, out loud or on '
                  'another channel. A match means no one is between you.',
                  style: t.bodyMedium?.copyWith(color: c.labelSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Text(
                    grouped,
                    textAlign: TextAlign.center,
                    style: t.titleMedium?.copyWith(
                      color: c.labelPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  'Copy',
                  style: AppButtonStyle.tinted,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: grouped));
                    if (ctx.mounted) {
                      showToast(ctx, 'Fingerprint copied to clipboard');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return ChangeNotifierProvider.value(
      value: widget.bloc,
      child: Consumer<ChatBloc>(
        builder: (context, bloc, child) {
          Map<String, dynamic>? found;
          for (final entry in bloc.conversations) {
            if (entry['id'] == widget.conversationId) {
              found = entry;
              break;
            }
          }
          final conv = found ?? <String, dynamic>{};
          final title = conversationLabel(conv, bloc.myEmpireCode);
          final isE2ee = conv['encryption'] == 'e2ee';
          Map<String, dynamic>? peer;
          for (final m in otherMembers(conv, bloc.myEmpireCode)) {
            if (m['public_key'] != null) {
              peer = m;
              break;
            }
          }
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
                    GestureDetector(
                      onTap: () {
                        final peerKey = peer?['public_key'] as String?;
                        if (peerKey != null) {
                          _showFingerprintSheet(context, peerKey);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.lock_fill,
                              size: 10, color: c.green),
                          const SizedBox(width: 4),
                          Text('End-to-end encrypted (tap to verify)',
                              style: t.labelSmall?.copyWith(color: c.green)),
                        ],
                      ),
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
                  enabled: !_sending,
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
    final scheme = message['scheme']?.toString();
    final isLocked = message['_locked'] == true;
    // Three states, not two: a message we know we can never read (no key
    // resolved it, or decryption failed) shows a lock, distinct from one
    // that is merely still on its way through decryption. Gate pending on
    // the e2ee scheme specifically — every e2ee message is awaited through
    // ChatBloc._decryptOne before it ever reaches this widget, so this is
    // never actually the live path, but it is the *correct* condition. What
    // used to trip this branch was a fernet/plain message whose `text` is
    // `""`, which `crypto.decrypt_at_rest` returns on InvalidToken (a
    // rotated CHAT_ENCRYPTION_KEY, a corrupt row) — that must render empty
    // or locked, like the Mini App, never a permanent "Decrypting…".
    final isPending = !isLocked && text == null && scheme == 'e2ee';

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
              child: isLocked
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.lock_fill,
                            size: 12, color: c.labelTertiary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "Encrypted — can't read with this key",
                            style: t.bodyMedium
                                ?.copyWith(color: c.labelTertiary),
                          ),
                        ),
                      ],
                    )
                  : isPending
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
                          text!,
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
  const _Composer({
    required this.controller,
    required this.onSend,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canSend = enabled && controller.text.trim().isNotEmpty;

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
                    enabled: enabled,
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
