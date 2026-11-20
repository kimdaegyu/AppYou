import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_fonts.dart';
export 'app_radius.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// Look At You 라이트 테마. 앱과 미리보기가 같은 진입점을 쓴다.
abstract final class AppTheme {
  static const localizationsDelegates = GlobalMaterialLocalizations.delegates;

  /// 한국어 테마. 기존 호출부를 유지한다.
  static ThemeData get light => forLanguage('ko');

  static ThemeData forLanguage(String languageCode) {
    final plan = AppFonts.plan(languageCode);
    final roles = AppTypography.rolesFor(plan);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.highlight,
      onSecondary: AppColors.textPrimary,
      tertiary: AppColors.pinkAccent,
      onTertiary: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      surfaceTint: AppColors.surface,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceVariant,
      surfaceContainerHighest: AppColors.surfaceVariant,
      inversePrimary: AppColors.primaryPressed,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: NoSplash.splashFactory,
      extensions: [roles],
      textTheme: TextTheme(
        headlineLarge: roles.display,
        headlineMedium: roles.resultName,
        titleLarge: roles.question,
        bodyLarge: roles.body,
        bodyMedium: roles.secondary,
        labelLarge: roles.button,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.highlight,
        linearMinHeight: 8,
      ),
    );
  }
}
