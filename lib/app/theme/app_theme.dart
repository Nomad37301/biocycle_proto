import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forest = Color(0xFF124A2B);
  static const leaf = Color(0xFF6CB51D);
  static const warm = Color(0xFFF8F7F1);
  static const ink = Color(0xFF172019);
  static const conditionAttention = Color(0xFF9A6800);
  static const conditionCritical = Color(0xFFB3261E);
  static const dataUnavailable = ink;
  static const sensorTemperature = Color(0xFFD84315);
  static const sensorHumidity = Color(0xFF1565C0);
  static const transactionPending = Color(0xFF8A4B00);
  static const transactionAccepted = Color(0xFF1559A2);
  static const transactionCompleted = Color(0xFF256D35);
  static const transactionNeutral = Color(0xFF46524A);
  static const warning = conditionAttention;
  static const danger = conditionCritical;
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const status = 8.0;
  static const control = 12.0;
  static const card = 16.0;
}

@immutable
class BioCycleTheme extends ThemeExtension<BioCycleTheme> {
  const BioCycleTheme({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.sunken,
    required this.outline,
    required this.textSecondary,
    required this.isModeTerik,
  });

  final Color canvas;
  final Color surface;
  final Color raised;
  final Color sunken;
  final Color outline;
  final Color textSecondary;
  final bool isModeTerik;

  @override
  BioCycleTheme copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? sunken,
    Color? outline,
    Color? textSecondary,
    bool? isModeTerik,
  }) => BioCycleTheme(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    sunken: sunken ?? this.sunken,
    outline: outline ?? this.outline,
    textSecondary: textSecondary ?? this.textSecondary,
    isModeTerik: isModeTerik ?? this.isModeTerik,
  );

  @override
  BioCycleTheme lerp(covariant BioCycleTheme? other, double t) {
    if (other == null) return this;
    return BioCycleTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      isModeTerik: t < 0.5 ? isModeTerik : other.isModeTerik,
    );
  }
}

extension BioCycleThemeContext on BuildContext {
  BioCycleTheme get bioCycleTheme => Theme.of(this).extension<BioCycleTheme>()!;
}

ThemeData buildAppTheme({bool modeTerik = false}) {
  final canvas = modeTerik ? const Color(0xFFFFFFFF) : AppColors.warm;
  final surface = Colors.white;
  final sunken = modeTerik
      ? const Color(0xFFE8ECE9)
      : Color.alphaBlend(AppColors.ink.withValues(alpha: 0.04), AppColors.warm);
  const outline = Color(0xFF667069);
  final secondary = modeTerik
      ? const Color(0xFF354139)
      : Color.alphaBlend(AppColors.ink.withValues(alpha: 0.70), canvas);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    brightness: Brightness.light,
    surface: surface,
    error: AppColors.danger,
  ).copyWith(onSurface: AppColors.ink, outline: outline);
  final baseText = ThemeData.light().textTheme.apply(
    fontFamily: 'PlusJakartaSans',
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    extensions: [
      BioCycleTheme(
        canvas: canvas,
        surface: surface,
        raised: surface,
        sunken: sunken,
        outline: outline,
        textSecondary: secondary,
        isModeTerik: modeTerik,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: AppColors.ink,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.leaf.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: modeTerik ? FontWeight.w700 : FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
        side: BorderSide(
          color: modeTerik ? outline : AppColors.ink.withValues(alpha: 0.10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppRadius.control),
        ),
        borderSide: BorderSide(color: outline),
      ),
      filled: true,
      fillColor: sunken,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textTheme: baseText.copyWith(
      displaySmall: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: modeTerik ? 36 : 34,
        height: 1.1,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        height: 1.45,
        fontWeight: modeTerik ? FontWeight.w500 : FontWeight.w400,
        color: AppColors.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        height: 1.4,
        fontWeight: modeTerik ? FontWeight.w600 : FontWeight.w500,
        color: secondary,
      ),
      labelMedium: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        height: 1.3,
        fontWeight: modeTerik ? FontWeight.w700 : FontWeight.w600,
        color: secondary,
      ),
    ),
    dividerColor: outline,
    visualDensity: VisualDensity.standard,
  );
}
