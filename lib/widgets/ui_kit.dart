// ─────────────────────────────────────────────────────────────────────────────
// The shared UI kit.
//
// Every screen is assembled from these parts, so the whole app moves together
// when a token changes. Nothing here paints a shadow, invents a radius, or
// reaches for a second accent — see lib/theme/app_theme.dart for the rules.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../theme/app_theme.dart';

// ── Press feedback ───────────────────────────────────────────────────────────

/// Wraps a tappable surface with the system press response: a quiet scale-down,
/// no ripple. Used by every custom card and button in the app.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1,
        duration: AppMotion.instant,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

// ── Buttons ──────────────────────────────────────────────────────────────────

enum AppButtonStyle {
  /// Solid accent capsule. One per screen — the single most important action.
  filled,

  /// Accent label on a 14% accent wash. Secondary actions that still matter.
  tinted,

  /// Label only. Tertiary actions and links.
  plain,

  /// Solid red capsule. Irreversible actions, always behind a confirmation.
  destructive,
}

/// The one button in the app. Capsule, 50pt tall, 44pt minimum tap target,
/// with an inline spinner that keeps the button's width while loading.
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.style = AppButtonStyle.filled,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool loading;

  /// Stretch to the available width. Off for buttons that sit in a row.
  final bool expand;

  /// 38pt pill for dense contexts (card footers, inline actions).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null && !loading;

    late final Color bg;
    late final Color fg;
    switch (style) {
      case AppButtonStyle.filled:
        bg = c.accent;
        fg = c.onAccent;
      case AppButtonStyle.tinted:
        bg = c.accentMuted;
        fg = c.accent;
      case AppButtonStyle.plain:
        bg = Colors.transparent;
        fg = c.accent;
      case AppButtonStyle.destructive:
        bg = c.red;
        fg = Colors.white;
    }

    final height = compact ? 38.0 : AppMetrics.buttonHeight;
    final textStyle = (compact
            ? Theme.of(context).textTheme.titleSmall
            : Theme.of(context).textTheme.labelLarge)
        ?.copyWith(color: enabled ? fg : c.labelTertiary);

    Widget content = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CupertinoActivityIndicator(color: fg, radius: 9),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: compact ? 16 : 19,
                    color: enabled ? fg : c.labelTertiary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: PressableScale(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: height,
          constraints: BoxConstraints(
            minWidth: expand ? 0 : AppMetrics.minTap,
            minHeight: AppMetrics.minTap - 6,
          ),
          padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.lg : AppSpacing.xxl),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? bg
                : (style == AppButtonStyle.plain ? Colors.transparent : c.fill),
            borderRadius: AppRadius.brCapsule,
          ),
          child: content,
        ),
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

// ── Grouped sections ─────────────────────────────────────────────────────────

/// An Apple grouped-list section: an optional caption header, one elevated
/// surface with `lg` corners, and hairlines inset past the leading content.
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.padding =
        const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs, AppSpacing.xxl, AppSpacing.xs, AppSpacing.sm),
              child: Text(
                header!.toUpperCase(),
                style: t.labelSmall?.copyWith(
                  color: c.labelSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: AppRadius.brLg,
              border: Border.all(
                  color: c.separator, width: AppMetrics.hairline),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.brLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _withSeparators(context, children),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, 0),
              child: Text(footer!,
                  style: t.bodySmall?.copyWith(color: c.labelSecondary)),
            ),
        ],
      ),
    );
  }

  List<Widget> _withSeparators(BuildContext context, List<Widget> rows) {
    final c = AppColors.of(context);
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i != rows.length - 1) {
        out.add(Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          child: Divider(
              height: AppMetrics.hairline,
              thickness: AppMetrics.hairline,
              color: c.separator),
        ));
      }
    }
    return out;
  }
}

/// A row inside an [InsetSection]: optional tinted icon tile, title, optional
/// subtitle, an inline value on the trailing edge, and a chevron when it
/// navigates.
class InsetRow extends StatelessWidget {
  const InsetRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.iconColor,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final tint = destructive ? c.red : (iconColor ?? c.accent);
    final titleColor = destructive ? c.red : c.labelPrimary;

    return RowHighlight(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppMetrics.minTap - 24),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  height: 30,
                  width: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.14),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(icon, size: 17, color: tint),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: t.bodyLarge?.copyWith(color: titleColor)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          style:
                              t.bodySmall?.copyWith(color: c.labelSecondary)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    value!,
                    style: t.bodyLarge?.copyWith(color: c.labelSecondary),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
              if (onTap != null && showChevron && trailing == null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(CupertinoIcons.chevron_right,
                    size: 15, color: c.labelTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch row. The control carries the state, so the row itself never shows
/// a chevron and the whole row toggles.
class InsetSwitchRow extends StatelessWidget {
  const InsetSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InsetRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showChevron: false,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: IgnorePointer(
        child: Transform.scale(
          scale: 0.86,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

/// Momentary background wash on press — the grouped-list equivalent of the
/// scale used by cards.
class RowHighlight extends StatefulWidget {
  const RowHighlight({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<RowHighlight> createState() => _RowHighlightState();
}

class _RowHighlightState extends State<RowHighlight> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: AppMotion.instant,
        color: _down ? c.fill : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

// ── Small parts ──────────────────────────────────────────────────────────────

/// Section heading used outside grouped lists (e.g. above a list of cards).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.count});

  final String title;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.xxl,
          AppSpacing.gutter, AppSpacing.md),
      child: Row(
        children: [
          Text(title, style: t.titleLarge),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text('$count', style: t.titleLarge?.copyWith(color: c.labelTertiary)),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Capsule state badge. Tinted, never solid — a badge is information, not an
/// action, and must not compete with the accent.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = StatusTone.neutral, this.icon});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Color fg = switch (tone) {
      StatusTone.neutral => c.labelSecondary,
      StatusTone.accent => c.accent,
      StatusTone.positive => c.green,
      StatusTone.warning => c.orange,
      StatusTone.negative => c.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: 3),
      decoration: BoxDecoration(
        color: tone == StatusTone.neutral ? c.fill : fg.withOpacity(0.15),
        borderRadius: AppRadius.brCapsule,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { neutral, accent, positive, warning, negative }

/// Elevated tappable surface with the standard press response.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: margin,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: AppRadius.brLg,
            border:
                Border.all(color: c.separator, width: AppMetrics.hairline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Helpful empty state: a quiet glyph, what will appear here, and one action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl, vertical: AppSpacing.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: c.labelQuaternary),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message!,
                style: t.bodyMedium?.copyWith(color: c.labelSecondary),
                textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppButton(actionLabel!,
                onPressed: onAction,
                style: AppButtonStyle.tinted,
                expand: false),
          ],
        ],
      ),
    );
  }
}

/// The one loading indicator in the app.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 12, color: c.labelSecondary),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(label!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.labelSecondary)),
          ],
        ],
      ),
    );
  }
}

/// The 36×5 grabber that tells people a sheet can be dragged.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Center(
        child: Container(
          height: 5,
          width: 36,
          decoration: BoxDecoration(
              color: c.labelQuaternary, borderRadius: AppRadius.brCapsule),
        ),
      ),
    );
  }
}

/// Sheet scaffold: grabber, title, and a body that never runs under the home
/// indicator.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child, this.title, this.trailing});

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetGrabber(),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.md, AppSpacing.gutter, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: Text(title!, style: t.titleLarge)),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Flexible(child: child),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Presents [builder] as a HIG-shaped modal sheet.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).bgElevated,
    barrierColor: AppColors.of(context).scrim,
    builder: builder,
  );
}

/// Single-choice picker sheet — the Apple answer to a dropdown.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, String? detail})> options,
  T? selected,
}) {
  return showAppSheet<T>(
    context,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      return AppSheet(
        title: title,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InsetSection(
              children: [
                for (final o in options)
                  InsetRow(
                    title: o.label,
                    subtitle: o.detail,
                    showChevron: false,
                    onTap: () => Navigator.pop(ctx, o.value),
                    trailing: o.value == selected
                        ? Icon(CupertinoIcons.check_mark,
                            size: 18, color: c.accent)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Apple-styled confirmation. Destructive choices are red and never the default.
///
/// [cancelLabel] defaults to the localized "Cancel" resolved from [context];
/// it cannot be a `const` default because it depends on the active locale, so
/// the parameter is nullable and the fallback is applied in the body instead.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final resolvedCancelLabel =
      cancelLabel ?? AppLocalizations.of(context)!.commonCancel;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.of(context).scrim,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      final t = Theme.of(ctx).textTheme;
      return CupertinoTheme(
        data: CupertinoThemeData(
          brightness: c.brightness,
          primaryColor: c.accent,
        ),
        child: CupertinoAlertDialog(
          title: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(title, style: t.titleMedium),
          ),
          content: Text(message,
              style: t.bodyMedium?.copyWith(color: c.labelSecondary)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(resolvedCancelLabel, style: TextStyle(color: c.accent)),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel,
                  style: TextStyle(color: destructive ? c.red : c.accent)),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

/// One-line toast. Errors are red-tinted; everything else is neutral.
void showToast(BuildContext context, String message, {bool isError = false}) {
  final c = AppColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? CupertinoIcons.exclamationmark_circle
                : CupertinoIcons.check_mark_circled,
            size: 18,
            color: isError ? c.red : c.green,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
    ));
}

/// Bottom action bar pinned above the home indicator. Used for the primary
/// action on form screens, where a button at the end of a long scroll would
/// be easy to miss.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bgBase,
        border: Border(
            top: BorderSide(color: c.separator, width: AppMetrics.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
              AppSpacing.gutter, AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}
