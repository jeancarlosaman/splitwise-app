import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand palette ─────────────────────────────────────────────────────────
  static const green         = Color(0xFF00E676);
  static const greenDark     = Color(0xFF00C853);
  static const greenSubtle   = Color(0xFF0D2618);
  static const black         = Color(0xFF000000);
  static const surface       = Color(0xFF0D0D0D);
  static const surface2      = Color(0xFF161616);
  static const border        = Color(0xFF222222);
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const positive      = Color(0xFF00E676);
  static const negative      = Color(0xFFFF5252);
  static const amber         = Color(0xFFFFD600);

  // Legacy aliases so existing code compiles without changes
  static const primary  = green;
  static const cardDark = surface;

  static const _radius      = Radius.circular(20);
  static const _inputRadius = Radius.circular(14);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: black,
        colorScheme: const ColorScheme.dark(
          primary: green,
          secondary: greenDark,
          surface: surface,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: textPrimary,
          outline: border,
          error: negative,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: black,
          foregroundColor: textPrimary,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_radius),
            side: const BorderSide(color: border, width: 0.5),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 0.5),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: border, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: border, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(_inputRadius),
            borderSide: const BorderSide(color: negative, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
          prefixIconColor: textSecondary,
          suffixIconColor: textSecondary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(_inputRadius),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: green),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: green,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface2,
          selectedColor: greenSubtle,
          side: const BorderSide(color: border, width: 0.5),
          labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          checkmarkColor: green,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: green,
          unselectedLabelColor: textSecondary,
          indicatorColor: green,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: border,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: textSecondary,
          textColor: textPrimary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surface2,
          contentTextStyle: const TextStyle(color: textPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          modalBackgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            backgroundColor: surface,
            selectedBackgroundColor: greenSubtle,
            foregroundColor: textSecondary,
            selectedForegroundColor: green,
            side: const BorderSide(color: border, width: 0.5),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
          contentTextStyle:
              const TextStyle(color: textSecondary, fontSize: 14),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1),
          headlineMedium: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineSmall:
              TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          titleLarge:
              TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          titleMedium:
              TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13),
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
          labelLarge:
              TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          labelSmall: TextStyle(color: textSecondary, fontSize: 11),
        ),
      );

  // App is dark-only — light just returns dark
  static ThemeData get light => dark;

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const greenGradient = LinearGradient(
    colors: [green, greenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy alias
  static const primaryGradient = greenGradient;

  static const redGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFD50000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Green gradient button ────────────────────────────────────────────────────
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
    this.gradient = AppTheme.greenGradient,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled ? AppTheme.surface2 : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppTheme.green.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color:
                              disabled ? AppTheme.textSecondary : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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
