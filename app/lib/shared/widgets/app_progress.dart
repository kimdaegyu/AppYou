import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 현재 문항과 전체 문항 수로 그리는 진행 막대.
///
/// [label]과 [semanticLabel]은 호출하는 화면의 번역 문구를 그대로 쓴다.
/// [total]이 0 이하거나 [current]가 0 이하면 막대는 0이고 예외를 내지 않는다.
class AppProgress extends StatelessWidget {
  const AppProgress({
    super.key,
    required this.current,
    required this.total,
    required this.label,
    this.semanticLabel,
  });

  final int current;
  final int total;
  final String label;
  final String? semanticLabel;

  /// 0 이상 1 이하의 진행 비율. 전체가 0이어도 NaN이 아니다.
  static double fraction(int current, int total) {
    if (total <= 0 || current <= 0) {
      return 0;
    }
    if (current >= total) {
      return 1;
    }
    return current / total;
  }

  @override
  Widget build(BuildContext context) {
    final value = fraction(current, total);

    return Semantics(
      container: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTypography.rolesOf(context).secondary),
          const SizedBox(height: AppSpacing.inlineGap),
          SizedBox(
            height: AppSpacing.progressHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.progress),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.highlight),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: const ColoredBox(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
