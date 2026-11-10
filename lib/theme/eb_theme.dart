// Tema de EASYBUS: Material 3 con la identidad propia (marino, río, Poppins).
// Las pantallas usan Theme.of(context) y los tokens de eb_tokens.dart.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'eb_tokens.dart';

abstract final class EbTheme {
  static const fontFamily = 'Poppins';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: EbColors.navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: EbColors.navy,
      onPrimary: EbColors.white,
      secondary: EbColors.river,
      onSecondary: EbColors.white,
      tertiary: EbColors.bank,
      onTertiary: EbColors.white,
      surface: EbColors.white,
      onSurface: EbColors.textPrimary,
      onSurfaceVariant: EbColors.textMuted,
      surfaceContainerLowest: EbColors.white,
      surfaceContainerLow: EbColors.surface,
      surfaceContainer: EbColors.surface,
      outline: EbColors.textMuted,
      outlineVariant: EbColors.divider,
      error: EbColors.alertSuspended,
      onError: EbColors.white,
    );

    final textTheme = _textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: EbColors.textPrimary,
      displayColor: EbColors.textPrimary,
    );

    const pill = StadiumBorder();
    const buttonSize = Size(EbSizes.minTouch, EbSizes.minTouch);
    const buttonPadding = EdgeInsets.symmetric(horizontal: EbSpacing.l, vertical: EbSpacing.m - 4);
    final buttonText = textTheme.labelLarge;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: EbColors.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: EbColors.surface,
        foregroundColor: EbColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        // Barras del sistema transparentes con íconos oscuros sobre el fondo claro.
        // Con navegación por botones, Android añade su propio velo para que se lean.
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: EbColors.navy),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EbColors.navy,
          foregroundColor: EbColors.white,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EbColors.navy,
          foregroundColor: EbColors.white,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EbColors.navy,
          side: const BorderSide(color: EbColors.navy, width: 1.5),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EbColors.riverInk,
          minimumSize: buttonSize,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: buttonSize),
      ),

      cardTheme: CardThemeData(
        color: EbColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EbRadius.card)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: EbColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: EbColors.skeleton,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(EbRadius.sheet)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: EbColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EbRadius.sheet)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: EbColors.surface,
        selectedColor: EbColors.riverTint,
        side: BorderSide.none,
        shape: pill,
        labelStyle: textTheme.labelMedium?.copyWith(color: EbColors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EbColors.white,
        hintStyle: textTheme.bodyLarge?.copyWith(color: EbColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: EbSpacing.l, vertical: EbSpacing.m),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EbRadius.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EbRadius.pill),
          borderSide: const BorderSide(color: EbColors.river, width: 2),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: EbColors.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: EbColors.white),
        actionTextColor: EbColors.riverTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EbRadius.card)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EbColors.river,
        linearTrackColor: EbColors.riverTint,
      ),

      dividerTheme: const DividerThemeData(color: EbColors.divider, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: EbSpacing.s,
        iconColor: EbColors.navy,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: EbColors.textMuted),
      ),

      // Transiciones de página suaves (detalle en la skill easybus-motion)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Escala tipográfica. displayMedium se reserva para la hora del próximo zarpe
  // ("07:20"), que es el dato más importante de la app.
  static const _textTheme = TextTheme(
    displayMedium: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.5),
    displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.25),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.45),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.3),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.3),
  );
}
