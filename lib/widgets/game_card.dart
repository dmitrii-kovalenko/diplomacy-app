import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/game_model.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// One game in the lobby.
///
/// The whole card is the primary tap target — entering a game is what people
/// come here to do, so it never hides behind a button. Secondary actions
/// (join, leave, mute) appear as a footer only when they apply, which keeps
/// the common card down to two lines of type.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    this.onJoin,
    this.onLeave,
    this.onEnter,
    this.onMuteToggle,
    this.isMuted = false,
    this.margin = const EdgeInsets.fromLTRB(
        AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.md),
  });

  final GameModel game;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final VoidCallback? onEnter;
  final VoidCallback? onMuteToggle;
  final bool isMuted;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final hasFooter = onJoin != null || onLeave != null || onMuteToggle != null;

    return AppCard(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onEnter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  game.name.isEmpty ? loc.gameCardUntitled : game.name,
                  style: t.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (game.isPrivate)
                _Glyph(CupertinoIcons.lock_fill, loc.gameCardPrivateTag,
                    c.labelTertiary),
              if (game.isSandbox)
                _Glyph(CupertinoIcons.wand_stars, loc.sandboxLabel,
                    c.labelTertiary),
              if (isMuted)
                _Glyph(CupertinoIcons.bell_slash_fill, loc.gameCardMutedTag,
                    c.labelTertiary),
              if (onEnter != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(CupertinoIcons.chevron_right,
                    size: 15, color: c.labelTertiary),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusPill(_statusLabel(loc),
                  tone: _statusTone, icon: _statusIcon),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  _metaLine(loc),
                  style: t.bodySmall?.copyWith(color: c.labelSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (game.deadline != null && game.deadline!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(CupertinoIcons.clock, size: 13, color: c.labelTertiary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    game.deadline!,
                    style: t.bodySmall?.copyWith(color: c.labelTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (hasFooter) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (onJoin != null)
                  Expanded(
                    child: AppButton(loc.gameCardJoinButton,
                        onPressed: onJoin,
                        style: AppButtonStyle.filled,
                        compact: true),
                  ),
                if (onJoin != null && onLeave != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onLeave != null)
                  Expanded(
                    child: AppButton(loc.gameCardLeaveButton,
                        onPressed: onLeave,
                        style: AppButtonStyle.tinted,
                        compact: true),
                  ),
                if (onMuteToggle != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _IconAction(
                    icon: isMuted
                        ? CupertinoIcons.bell_slash
                        : CupertinoIcons.bell,
                    semanticLabel: isMuted
                        ? loc.gameCardUnmuteAction
                        : loc.gameCardMuteAction,
                    onTap: onMuteToggle!,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _metaLine(AppLocalizations loc) {
    final parts = <String>[
      game.mapName?.trim().isNotEmpty == true
          ? game.mapName!
          : loc.gameCardStandardMap,
      if (game.phase != null && game.phase!.isNotEmpty) game.phase!,
      if (game.shareId != null && game.shareId!.isNotEmpty) '#${game.shareId}',
    ];
    return parts.join(' · ');
  }

  String _statusLabel(AppLocalizations loc) => switch (game.status) {
        0 => loc.gameCardStatusOpen,
        2 => loc.gameCardStatusFinished,
        _ => loc.gameCardStatusInPlay,
      };

  StatusTone get _statusTone => switch (game.status) {
        0 => StatusTone.accent,
        2 => StatusTone.neutral,
        _ => StatusTone.positive,
      };

  IconData get _statusIcon => switch (game.status) {
        0 => CupertinoIcons.person_badge_plus_fill,
        2 => CupertinoIcons.flag_fill,
        _ => CupertinoIcons.circle_fill,
      };
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, top: 3),
      child: Tooltip(
        message: label,
        child: Icon(icon, size: 13, color: color, semanticLabel: label),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 38,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.fill,
            borderRadius: AppRadius.brCapsule,
          ),
          child: Icon(icon, size: 17, color: c.labelSecondary),
        ),
      ),
    );
  }
}
