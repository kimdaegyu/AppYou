import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, text }

/// 주요 동작, 보조 동작, 글자 버튼을 한 위젯으로 그린다.
///
/// [onPressed]가 null이면 비활성 색과 함께 포인터·키보드 입력을 막는다.
/// 높이는 기본 치수에서 시작하고, 긴 문구와 글꼴 확대에 맞춰 늘어난다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.semanticLabel,
    this.expand,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final String? semanticLabel;

  /// null이면 Primary·Secondary는 가로로 늘리고 Text는 내용 너비를 유지한다.
  final bool? expand;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: _style(context),
      child: Text(
        label,
        textAlign: TextAlign.center,
        semanticsLabel: semanticLabel,
      ),
    );
  }

  ButtonStyle _style(BuildContext context) {
    final expandWidth = expand ?? variant != AppButtonVariant.text;
    final minHeight = switch (variant) {
      AppButtonVariant.primary => AppSpacing.buttonPrimaryHeight,
      AppButtonVariant.secondary => AppSpacing.buttonSecondaryHeight,
      AppButtonVariant.text => AppSpacing.buttonTextMin,
    };
    final minWidth = expandWidth ? double.infinity : AppSpacing.buttonTextMin;
    final padding = variant == AppButtonVariant.text
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: Duration.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      minimumSize: WidgetStatePropertyAll(Size(minWidth, minHeight)),
      padding: WidgetStatePropertyAll(padding),
      alignment: Alignment.center,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
        ),
      ),
      textStyle: WidgetStatePropertyAll(AppTypography.rolesOf(context).button),
      backgroundColor: WidgetStateProperty.resolveWith(_background),
      foregroundColor: WidgetStateProperty.resolveWith(_foreground),
      side: WidgetStateProperty.resolveWith(_side),
    );
  }

  Color _background(Set<WidgetState> states) {
    final disabled = states.contains(WidgetState.disabled);
    final pressed = states.contains(WidgetState.pressed);
    return switch (variant) {
      AppButtonVariant.primary when disabled => AppColors.surfaceVariant,
      AppButtonVariant.primary when pressed => AppColors.primaryPressed,
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.secondary when disabled => AppColors.surface,
      AppButtonVariant.secondary when pressed => AppColors.furGold,
      AppButtonVariant.secondary => AppColors.highlight,
      AppButtonVariant.text => Colors.transparent,
    };
  }

  Color _foreground(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return AppColors.textSecondary;
    }
    return switch (variant) {
      AppButtonVariant.primary => AppColors.onPrimary,
      AppButtonVariant.secondary => AppColors.textPrimary,
      AppButtonVariant.text => AppColors.primary,
    };
  }

  BorderSide _side(Set<WidgetState> states) {
    final focused = states.contains(WidgetState.focused);
    final disabled = states.contains(WidgetState.disabled);
    if (focused && !disabled) {
      final color = variant == AppButtonVariant.primary
          ? AppColors.onPrimary
          : AppColors.primary;
      return BorderSide(color: color, width: 2);
    }
    return switch (variant) {
      AppButtonVariant.primary when disabled => const BorderSide(
        color: AppColors.border,
      ),
      AppButtonVariant.secondary => const BorderSide(color: AppColors.border),
      _ => BorderSide.none,
    };
  }
}
