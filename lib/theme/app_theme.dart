// ─────────────────────────────────────────────────────────────────────────────
// Diplomacy design system.
//
// One Apple-HIG-shaped language for the whole client. Everything visual comes
// from here: no screen inlines a hex, a size, a radius or a duration.
//
// The rules this file encodes, and why:
//
//  1. One accent, ever. Patina teal is the only interactive colour — links,
//     primary CTAs, selection, focus. Red/green/orange exist for *state*
//     only, never for decoration.
//  2. Depth comes from the surface, not from chrome. Elevation is a step up
//     the background ladder (base → grouped → elevated → raised) plus a
//     hairline. There is no shadow anywhere in the app.
//  3. Weight ladder 400 / 600 / 700. 500 is never used — it muddies the
//     Apple cadence.
//  4. Capsules read as actions. A pill radius is the "this is tappable"
//     signal; cards and sheets use the continuous-corner radii below.
//  5. Concentric corners: inner radius + padding = outer radius.
//  6. 44pt minimum touch target, always.
//
// Appearance: the app ships dark-only on purpose. The HIG allows a permanently
// dark appearance for immersive, map-first experiences, and the board art is
// authored for a dark ground. The light palette is defined and wired so the
// choice stays reversible — flip `AppTheme.themeMode`.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Spacing ──────────────────────────────────────────────────────────────────
// 4pt base. Structural layout snaps to md/lg/xl.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal page gutter. Content never touches the device edge.
  static const double gutter = 20;
}

// ── Radii ────────────────────────────────────────────────────────────────────
// Grammar: `sm` inline chips · `md` controls inside a card · `lg` cards and
// grouped sections · `xl` sheets and hero surfaces · `capsule` anything that
// reads as an action. Don't invent in-between values.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 18;
  static const double xl = 24;
  static const double capsule = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brCapsule =
      BorderRadius.all(Radius.circular(capsule));
}

// ── Motion ───────────────────────────────────────────────────────────────────
// Quiet and purposeful. Nothing bounces; nothing outstays 300ms.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasised = Curves.easeInOutCubic;

  /// Press feedback used by every custom tappable surface.
  static const double pressScale = 0.97;
}

// ── Metrics ──────────────────────────────────────────────────────────────────
abstract final class AppMetrics {
  /// HIG minimum touch target.
  static const double minTap = 44;

  /// Standard height of a primary capsule CTA.
  static const double buttonHeight = 50;

  /// Standard height of a grouped-list row.
  static const double rowHeight = 52;

  /// Hairline thickness. Separators are never heavier than this.
  static const double hairline = 0.5;
}

// ── Colour ───────────────────────────────────────────────────────────────────
/// Semantic palette. Screens read these through [AppColors.of]; the raw hexes
/// live only in [dark] and [light].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bgBase,
    required this.bgGrouped,
    required this.bgElevated,
    required this.bgRaised,
    required this.fill,
    required this.fillStrong,
    required this.separator,
    required this.separatorOpaque,
    required this.labelPrimary,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.labelQuaternary,
    required this.accent,
    required this.accentPressed,
    required this.accentMuted,
    required this.onAccent,
    required this.red,
    required this.green,
    required this.orange,
    required this.scrim,
  });

  final Brightness brightness;

  /// Background ladder — the only elevation mechanism in the app.
  final Color bgBase; // scaffold
  final Color bgGrouped; // page behind grouped sections
  final Color bgElevated; // cards, sections, sheets
  final Color bgRaised; // a control resting inside a card

  final Color fill; // tinted field / chip fill
  final Color fillStrong; // pressed state of the above

  final Color separator; // hairline between rows
  final Color separatorOpaque; // hairline on a photographic ground

  final Color labelPrimary;
  final Color labelSecondary;
  final Color labelTertiary;
  final Color labelQuaternary;

  /// The single accent. Nothing else is ever used to mean "interactive".
  final Color accent;
  final Color accentPressed;
  final Color accentMuted; // 12–16% accent, for tinted buttons and badges
  final Color onAccent; // label resting on [accent]

  /// State only — never decoration.
  final Color red;
  final Color green;
  final Color orange;

  final Color scrim;

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF0B0D12),
    bgGrouped: Color(0xFF0B0D12),
    bgElevated: Color(0xFF171A21),
    bgRaised: Color(0xFF20242D),
    fill: Color(0x1FEBEBF5),
    fillStrong: Color(0x2EEBEBF5),
    separator: Color(0x24EBEBF5),
    separatorOpaque: Color(0xFF2A2E37),
    labelPrimary: Color(0xFFFFFFFF),
    labelSecondary: Color(0x9EEBEBF5),
    labelTertiary: Color(0x52EBEBF5),
    labelQuaternary: Color(0x2EEBEBF5),
    accent: Color(0xFF7CDED8),
    accentPressed: Color(0xFF4BD2C9),
    accentMuted: Color(0x247CDED8),
    onAccent: Color(0xFF0C1616),
    red: Color(0xFFFF453A),
    green: Color(0xFF30D158),
    orange: Color(0xFFFF9F0A),
    scrim: Color(0x8C000000),
  );

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFFFFFFF),
    bgGrouped: Color(0xFFF2F2F7),
    bgElevated: Color(0xFFFFFFFF),
    bgRaised: Color(0xFFF2F2F7),
    fill: Color(0x14787880),
    fillStrong: Color(0x1F787880),
    separator: Color(0x4A3C3C43),
    separatorOpaque: Color(0xFFC6C6C8),
    labelPrimary: Color(0xFF1D1D1F),
    labelSecondary: Color(0x993C3C43),
    labelTertiary: Color(0x4D3C3C43),
    labelQuaternary: Color(0x2E3C3C43),
    accent: Color(0xFF1C5F5A),
    accentPressed: Color(0xFF154744),
    accentMuted: Color(0x1F1C5F5A),
    onAccent: Color(0xFFFFFFFF),
    red: Color(0xFFFF3B30),
    green: Color(0xFF34C759),
    orange: Color(0xFFFF9500),
    scrim: Color(0x73000000),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? bgBase,
    Color? bgGrouped,
    Color? bgElevated,
    Color? bgRaised,
    Color? fill,
    Color? fillStrong,
    Color? separator,
    Color? separatorOpaque,
    Color? labelPrimary,
    Color? labelSecondary,
    Color? labelTertiary,
    Color? labelQuaternary,
    Color? accent,
    Color? accentPressed,
    Color? accentMuted,
    Color? onAccent,
    Color? red,
    Color? green,
    Color? orange,
    Color? scrim,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      bgBase: bgBase ?? this.bgBase,
      bgGrouped: bgGrouped ?? this.bgGrouped,
      bgElevated: bgElevated ?? this.bgElevated,
      bgRaised: bgRaised ?? this.bgRaised,
      fill: fill ?? this.fill,
      fillStrong: fillStrong ?? this.fillStrong,
      separator: separator ?? this.separator,
      separatorOpaque: separatorOpaque ?? this.separatorOpaque,
      labelPrimary: labelPrimary ?? this.labelPrimary,
      labelSecondary: labelSecondary ?? this.labelSecondary,
      labelTertiary: labelTertiary ?? this.labelTertiary,
      labelQuaternary: labelQuaternary ?? this.labelQuaternary,
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccent: onAccent ?? this.onAccent,
      red: red ?? this.red,
      green: green ?? this.green,
      orange: orange ?? this.orange,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bgBase: c(bgBase, other.bgBase),
      bgGrouped: c(bgGrouped, other.bgGrouped),
      bgElevated: c(bgElevated, other.bgElevated),
      bgRaised: c(bgRaised, other.bgRaised),
      fill: c(fill, other.fill),
      fillStrong: c(fillStrong, other.fillStrong),
      separator: c(separator, other.separator),
      separatorOpaque: c(separatorOpaque, other.separatorOpaque),
      labelPrimary: c(labelPrimary, other.labelPrimary),
      labelSecondary: c(labelSecondary, other.labelSecondary),
      labelTertiary: c(labelTertiary, other.labelTertiary),
      labelQuaternary: c(labelQuaternary, other.labelQuaternary),
      accent: c(accent, other.accent),
      accentPressed: c(accentPressed, other.accentPressed),
      accentMuted: c(accentMuted, other.accentMuted),
      onAccent: c(onAccent, other.onAccent),
      red: c(red, other.red),
      green: c(green, other.green),
      orange: c(orange, other.orange),
      scrim: c(scrim, other.scrim),
    );
  }
}

// ── Typography ───────────────────────────────────────────────────────────────
// Apple's iOS ramp. Body runs at 17 — the reading pace the whole system is
// tuned around — and large titles carry negative tracking, which is most of
// what makes type read as "Apple".
abstract final class AppTypography {
  static const double largeTitle = 34;
  static const double title1 = 28;
  static const double title2 = 22;
  static const double title3 = 20;
  static const double headline = 17;
  static const double body = 17;
  static const double callout = 16;
  static const double subhead = 15;
  static const double footnote = 13;
  static const double caption1 = 12;
  static const double caption2 = 11;

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextTheme build(AppColors c, TargetPlatform platform) {
    final primary = c.labelPrimary;
    final secondary = c.labelSecondary;

    final theme = TextTheme(
      // Large title → title2. Bold with tightened tracking.
      displayLarge: TextStyle(
          fontSize: largeTitle,
          fontWeight: bold,
          letterSpacing: -0.7,
          height: 1.15,
          color: primary),
      displayMedium: TextStyle(
          fontSize: title1,
          fontWeight: bold,
          letterSpacing: -0.5,
          height: 1.18,
          color: primary),
      displaySmall: TextStyle(
          fontSize: title2,
          fontWeight: bold,
          letterSpacing: -0.3,
          height: 1.2,
          color: primary),

      headlineLarge: TextStyle(
          fontSize: title1,
          fontWeight: bold,
          letterSpacing: -0.5,
          height: 1.18,
          color: primary),
      // Material's SliverAppBar.large draws its EXPANDED title from this slot
      // (appBarTheme.titleTextStyle only styles the collapsed one), so this is
      // where the HIG large title actually lands. Left at title2 it rendered
      // at 22 — barely above the 20pt section headers underneath it, which is
      // exactly the hierarchy a large title exists to establish.
      headlineMedium: TextStyle(
          fontSize: largeTitle,
          fontWeight: bold,
          letterSpacing: -0.7,
          height: 1.15,
          color: primary),
      headlineSmall: TextStyle(
          fontSize: title3,
          fontWeight: semibold,
          letterSpacing: -0.2,
          height: 1.25,
          color: primary),

      // Section and row titles.
      titleLarge: TextStyle(
          fontSize: title3,
          fontWeight: semibold,
          letterSpacing: -0.2,
          height: 1.25,
          color: primary),
      titleMedium: TextStyle(
          fontSize: headline,
          fontWeight: semibold,
          letterSpacing: -0.1,
          height: 1.3,
          color: primary),
      titleSmall: TextStyle(
          fontSize: subhead,
          fontWeight: semibold,
          letterSpacing: -0.1,
          height: 1.3,
          color: primary),

      bodyLarge: TextStyle(
          fontSize: body, fontWeight: regular, height: 1.4, color: primary),
      bodyMedium: TextStyle(
          fontSize: subhead, fontWeight: regular, height: 1.4, color: primary),
      bodySmall: TextStyle(
          fontSize: footnote,
          fontWeight: regular,
          height: 1.35,
          color: secondary),

      labelLarge: const TextStyle(
          fontSize: body, fontWeight: semibold, letterSpacing: -0.1, height: 1.2),
      labelMedium: TextStyle(
          fontSize: footnote, fontWeight: semibold, height: 1.2, color: secondary),
      labelSmall: TextStyle(
          fontSize: caption2,
          fontWeight: semibold,
          letterSpacing: 0.1,
          height: 1.2,
          color: secondary),
    );

    // SF Pro is the system face on Apple platforms and comes for free. Off
    // Apple, Inter is the canonical substitute — same ladder, same tracking.
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return isApple ? theme : GoogleFonts.interTextTheme(theme);
  }
}

// ── Theme ────────────────────────────────────────────────────────────────────
abstract final class AppTheme {
  /// Dark-only for now; see the note at the top of this file.
  static const ThemeMode themeMode = ThemeMode.dark;

  static ThemeData dark(TargetPlatform platform) =>
      _build(AppColors.dark, platform);

  static ThemeData light(TargetPlatform platform) =>
      _build(AppColors.light, platform);

  static ThemeData _build(AppColors c, TargetPlatform platform) {
    final text = AppTypography.build(c, platform);
    final isDark = c.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.bgBase,
      canvasColor: c.bgBase,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: text,

      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        primaryContainer: c.accentMuted,
        onPrimaryContainer: c.accent,
        secondary: c.accent,
        onSecondary: c.onAccent,
        surface: c.bgElevated,
        onSurface: c.labelPrimary,
        surfaceContainerHighest: c.bgRaised,
        onSurfaceVariant: c.labelSecondary,
        error: c.red,
        onError: isDark ? const Color(0xFF17120A) : Colors.white,
        outline: c.separatorOpaque,
        outlineVariant: c.separator,
        shadow: Colors.transparent,
        scrim: c.scrim,
      ),

      // Nav bars are chrome: transparent, hairline-free, large title by default.
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.labelPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        // Deliberately NOT set. Material resolves the collapsed AND the
        // expanded title of SliverAppBar.large from this one slot
        // (app_bar.dart: titleTextStyle ?? appBarTheme.titleTextStyle ??
        // config.expandedTextStyle), so pinning it here silently flattens
        // every large title to the inline size — no hierarchy at all.
        // Left null, the collapsed title falls back to titleLarge and the
        // expanded one to headlineMedium, which is the HIG behaviour.
        iconTheme: IconThemeData(color: c.accent, size: 22),
        actionsIconTheme: IconThemeData(color: c.accent, size: 22),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // No shadows anywhere: a card is a surface step plus a hairline.
      cardTheme: CardTheme(
        color: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: c.separator, width: AppMetrics.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.separator,
        thickness: AppMetrics.hairline,
        space: AppMetrics.hairline,
      ),

      // Capsule CTA — the pill radius *is* the "this is an action" signal.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.fill,
          disabledForegroundColor: c.labelTertiary,
          minimumSize: const Size(0, AppMetrics.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.brCapsule),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accentMuted,
          foregroundColor: c.accent,
          minimumSize: const Size(0, AppMetrics.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          elevation: 0,
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.brCapsule),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.labelPrimary,
          minimumSize: const Size(0, AppMetrics.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          side: BorderSide(color: c.separatorOpaque, width: 1),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.brCapsule),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(0, AppMetrics.minTap),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.brCapsule),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(AppMetrics.minTap, AppMetrics.minTap),
        ),
      ),

      // Fields are a tinted well, not a boxed border. Focus is a 2px accent ring.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fill,
        hintStyle: text.bodyLarge?.copyWith(color: c.labelTertiary),
        labelStyle: text.bodyLarge?.copyWith(color: c.labelSecondary),
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.accent),
        errorStyle: text.bodySmall?.copyWith(color: c.red),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: const OutlineInputBorder(
            borderRadius: AppRadius.brMd, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadius.brMd, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: c.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: c.red, width: 2),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? c.green : c.fillStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.labelSecondary,
        textColor: c.labelPrimary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: AppSpacing.md,
        horizontalTitleGap: AppSpacing.md,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),

      // Sheets: elevated surface, xl corners, grabber drawn by the sheet itself.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: c.scrim,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: c.bgRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.labelSecondary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgRaised,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.labelPrimary),
        actionTextColor: c.accent,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.fill,
        selectedColor: c.accentMuted,
        side: BorderSide.none,
        labelStyle: text.titleSmall!,
        secondaryLabelStyle: text.titleSmall!.copyWith(color: c.accent),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.brCapsule),
        showCheckmark: false,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.fill,
        circularTrackColor: Colors.transparent,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.bgRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: text.bodyLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: c.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.horizontal(left: Radius.circular(AppRadius.xl)),
        ),
      ),

      tabBarTheme: TabBarTheme(
        labelColor: c.accent,
        unselectedLabelColor: c.labelSecondary,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        indicatorColor: c.accent,
        dividerColor: c.separator,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.brCapsule),
      ),

      // Native page transitions per platform; no custom choreography.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
