import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_spacing.dart';

/// 모바일 좌우 여백과 PC 최대 너비 520, 중앙 정렬을 공통 적용한다.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.contentMaxWidth,
    this.horizontalPadding = AppSpacing.mobileHorizontal,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}
