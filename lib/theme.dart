import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CampusLoop design tokens.
/// Direction: a campus "departures board" — precise, legible, time-first.
class AppColors {
  static const background = Color(0xFF0E0E10);
  static const surface = Color(0xFF1A1A1D);
  static const surfaceHigh = Color(0xFF232326);
  static const accent = Color(0xFFE0483E); // brand red
  static const textPrimary = Color(0xFFF2F0EC);
  static const textSecondary = Color(0xFF8A8A8E);
  static const divider = Color(0xFF2A2A2D);

  // Recommendation semantics — used consistently as left-edge bars on cards.
  static const recHostel = Color(0xFF4CAF7D); // green
  static const recCanteen = Color(0xFFE8A33D); // amber
  static const recStay = Color(0xFF6B6B70); // neutral grey
  static const recInfo = Color(0xFF5B8DEF); // blue, "at hostel" info state
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final bodyFont = GoogleFonts.interTextTheme(base.textTheme);
    final monoFont = GoogleFonts.spaceMono();

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: bodyFont.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: monoFont.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: bodyFont.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.accent.withValues(alpha: 0.4) : AppColors.divider),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceHigh,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.divider),
      ),
    );
  }

  /// Monospace style for time, slot codes, and other "data" text —
  /// the departures-board signature. Use for anything precise/numeric.
  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.spaceMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// A card with a colored left-edge bar — the app's signature visual element,
/// used to mark what kind of information a card is showing at a glance.
class AccentBarCard extends StatelessWidget {
  final Color barColor;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AccentBarCard({
    super.key,
    required this.barColor,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: barColor),
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );
  }
}