import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium dark fintech palette + typography. Inspired by Revolut / N26 /
/// Apple Wallet — tonal blacks with a refined mint accent, generous spacing,
/// Inter font with tabular figures so amounts line up cleanly across rows.
class AppTheme {
  // ── Base palette ──────────────────────────────────────────────────────────
  // Warmer than pure black so the eye can perceive tonal depth.
  static const bg = Color(0xFF09090B);
  static const black = bg; // legacy alias

  /// Tonal surface scale — lighter as you go up in elevation.
  /// Use ink (the "deepest" tone) for cards on bg, ink2 for cards on ink, etc.
  static const ink = Color(0xFF111114);
  static const ink2 = Color(0xFF18181B);
  static const ink3 = Color(0xFF26262C);
  static const surface = ink; // legacy alias
  static const surface2 = ink2; // legacy alias

  /// Hairline borders. Subtle so cards feel sculpted by tone, not boxed in.
  static const border = Color(0xFF26262C);
  static const borderStrong = Color(0xFF3F3F46);

  // ── Brand: refined mint ───────────────────────────────────────────────────
  // Slightly desaturated vs the loud Material Design green, with better
  // contrast on dark backgrounds.
  static const mint = Color(0xFF34D399);
  static const mintBright = Color(0xFF6EE7B7);
  static const mintDeep = Color(0xFF059669);
  static const mintGlow = Color(0x4034D399); // semi-transparent for glow halos
  static const mintTint = Color(0xFF0A1F18); // subtle bg behind mint elements

  static const green = mint; // legacy alias
  static const greenDark = mintDeep; // legacy alias
  static const greenSubtle = mintTint; // legacy alias

  // ── Semantic colors ───────────────────────────────────────────────────────
  static const positive = mint;
  static const negative = Color(0xFFF87171);
  static const negativeTint = Color(0xFF1F0A0A);
  static const amber = Color(0xFFFBBF24);
  static const violet = Color(0xFFA78BFA);
  static const blue = Color(0xFF60A5FA);
  static const pink = Color(0xFFF472B6);
  static const orange = Color(0xFFFB923C);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textTertiary = Color(0xFF71717A);

  // ── Legacy compatibility ─────────────────────────────────────────────────
  static const primary = mint;
  static const cardDark = surface;

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const radiusSm = Radius.circular(10);
  static const radiusMd = Radius.circular(16);
  static const radiusLg = Radius.circular(22);
  static const radiusXl = Radius.circular(28);
  static const _radius = radiusLg;
  static const _inputRadius = radiusMd;

  // ── Typography ────────────────────────────────────────────────────────────
  /// Inter — the de-facto fintech font (used by Revolut, N26, Stripe, Linear).
  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.interTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge:
          base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium:
          base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(
        color: textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.2,
      ),
      labelLarge:
          base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium:
          base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(
        color: textTertiary,
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
      bodySmall: base.bodySmall?.copyWith(
          color: textSecondary, fontSize: 12, height: 1.4),
    );
  }

  /// Tabular-figures Inter — use for any amount displayed in a list so the
  /// digits line up across rows (column-aligned numerics).
  static TextStyle moneyStyle({
    double fontSize = 16,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double letterSpacing = -0.3,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? textPrimary,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Big hero balance — the single number at the top of summary cards.
  static TextStyle moneyHero({Color? color}) => GoogleFonts.inter(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        color: color ?? textPrimary,
        letterSpacing: -1.5,
        height: 1.05,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        canvasColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: mint,
          secondary: mintDeep,
          surface: ink,
          surfaceContainerHighest: ink2,
          onPrimary: Color(0xFF052E1F),
          onSecondary: Colors.white,
          onSurface: textPrimary,
          outline: border,
          outlineVariant: borderStrong,
          error: negative,
        ),
        textTheme: _buildTextTheme(),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: textPrimary,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
          iconTheme: const IconThemeData(color: textPrimary, size: 22),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: ink,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(_radius),
            side: const BorderSide(color: border, width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        dividerTheme: const DividerThemeData(
            color: border, thickness: 1, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ink,
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: mint, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: negative, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: GoogleFonts.inter(color: textSecondary),
          hintStyle: GoogleFonts.inter(color: textTertiary),
          prefixIconColor: textSecondary,
          suffixIconColor: textSecondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mint,
            foregroundColor: const Color(0xFF052E1F),
            minimumSize: const Size(double.infinity, 52),
            elevation: 0,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(radiusMd)),
            textStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: mint,
            foregroundColor: const Color(0xFF052E1F),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(radiusMd)),
            textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: mint,
            textStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: mint,
          foregroundColor: Color(0xFF052E1F),
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radiusXl)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: ink2,
          selectedColor: mintTint,
          side: const BorderSide(color: border, width: 1),
          labelStyle: GoogleFonts.inter(
              color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radiusSm)),
          checkmarkColor: mint,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: textPrimary,
          unselectedLabelColor: textTertiary,
          indicatorColor: mint,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: border,
          labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: textSecondary,
          textColor: textPrimary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: ink3,
          contentTextStyle:
              GoogleFonts.inter(color: textPrimary, fontSize: 13),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radiusMd)),
          behavior: SnackBarBehavior.floating,
          actionTextColor: mint,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: ink,
          modalBackgroundColor: ink,
          surfaceTintColor: Colors.transparent,
          showDragHandle: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: ink,
            selectedBackgroundColor: mintTint,
            foregroundColor: textSecondary,
            selectedForegroundColor: mint,
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: ink,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(radiusLg)),
          titleTextStyle: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          contentTextStyle: GoogleFonts.inter(
              color: textSecondary, fontSize: 14, height: 1.4),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: textSecondary,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(radiusSm)),
          ),
        ),
      );

  // App is dark-only — light just returns dark
  static ThemeData get light => dark;

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Subtle mint glow — use for hero balance cards and primary CTAs.
  static const mintGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium card backdrop — barely-there gradient that adds tonal depth
  /// without screaming "I'm a gradient".
  static const cardGradient = LinearGradient(
    colors: [Color(0xFF18181B), Color(0xFF111114)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Tinted variant for positive/hero cards (mint glow at top fading out).
  static const mintTintGradient = LinearGradient(
    colors: [Color(0xFF143228), Color(0xFF111114)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Tinted variant for warning/owing cards.
  static const negativeTintGradient = LinearGradient(
    colors: [Color(0xFF2A1212), Color(0xFF111114)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Legacy aliases
  static const greenGradient = mintGradient;
  static const primaryGradient = mintGradient;
  static const redGradient = LinearGradient(
    colors: [Color(0xFFF87171), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Mint-gradient primary CTA with a soft glow shadow. Used as the headline
/// action on auth screens, add-expense, settle-up, etc.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final LinearGradient gradient;
  final bool isLoading;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.gradient = AppTheme.mintGradient,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled ? AppTheme.ink2 : null,
        borderRadius: const BorderRadius.all(AppTheme.radiusMd),
        boxShadow: disabled
            ? null
            : const [
                BoxShadow(
                  color: AppTheme.mintGlow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: const BorderRadius.all(AppTheme.radiusMd),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Color(0xFF052E1F)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon,
                            color: disabled
                                ? AppTheme.textSecondary
                                : const Color(0xFF052E1F),
                            size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: disabled
                              ? AppTheme.textSecondary
                              : const Color(0xFF052E1F),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
