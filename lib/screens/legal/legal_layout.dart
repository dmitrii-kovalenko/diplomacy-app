import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared reading layout for the legal documents.
///
/// Long prose has different needs from the rest of the app: a measure capped
/// near 70 characters, a looser line height, and secondary-coloured body text
/// under primary-coloured headings so the structure is scannable.
class LegalScaffold extends StatelessWidget {
  const LegalScaffold({
    super.key,
    required this.title,
    required this.children,
    this.intro,
  });

  final String title;
  final String? intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: c.bgBase,
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0,
                      AppSpacing.gutter, AppSpacing.huge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (intro != null) ...[
                        Text(intro!,
                            style: t.bodyLarge
                                ?.copyWith(color: c.labelSecondary)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading inside a legal document.
class LegalHeading extends StatelessWidget {
  const LegalHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Body paragraph inside a legal document.
class LegalBody extends StatelessWidget {
  const LegalBody(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: c.labelSecondary, height: 1.55),
      ),
    );
  }
}

/// Label/value pair — used for the Impressum's contact block, where the
/// relationship between the two matters more than the prose around them.
class LegalFact extends StatelessWidget {
  const LegalFact({super.key, required this.label, required this.lines});

  final String label;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: t.labelSmall
                  ?.copyWith(color: c.labelTertiary, letterSpacing: 0.6)),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines)
            Text(line, style: t.bodyLarge?.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
