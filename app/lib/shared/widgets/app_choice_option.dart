import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 문항의 답변 한 개.
///
/// 선택 여부와 문구는 호출하는 화면이 넘긴다. 선택되면 primary 테두리,
/// surfaceVariant 배경, 선택 아이콘을 함께 보여주고 스크린 리더에도 전달한다.
class AppChoiceOption extends StatelessWidget {
  const AppChoiceOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final iconSize = scaler.scale(AppSpacing.iconSlot);
    final gap = scaler.scale(AppSpacing.inlineGap);

    return MergeSemantics(
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: FilledButton(
          onPressed: onPressed,
          style: ButtonStyle(
            elevation: const WidgetStatePropertyAll(0),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            animationDuration: Duration.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
            alignment: Alignment.centerLeft,
            minimumSize: const WidgetStatePropertyAll(
              Size(double.infinity, AppSpacing.choiceMinHeight),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppRadius.button),
                ),
              ),
            ),
            backgroundColor: WidgetStatePropertyAll(
              selected ? AppColors.surfaceVariant : AppColors.surface,
            ),
            foregroundColor: const WidgetStatePropertyAll(
              AppColors.textPrimary,
            ),
            side: WidgetStateProperty.resolveWith((states) {
              final focused = states.contains(WidgetState.focused);
              return BorderSide(
                color: focused
                    ? AppColors.info
                    : selected
                    ? AppColors.primary
                    : AppColors.border,
                width: 2,
              );
            }),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.rolesOf(context).body,
                  semanticsLabel: semanticLabel,
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: selected
                    ? Icon(
                        Icons.check_circle,
                        size: iconSize,
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
