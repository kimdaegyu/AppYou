import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// 공유 이미지와 화면이 함께 쓰는 글자 역할.
enum AppTextRole {
  display,
  question,
  resultName,
  body,
  button,
  saida,
  secondary,
}

/// 역할별 크기·굵기·줄 높이. 글꼴 패밀리는 [AppFonts]가 정한다.
class AppTextRoles extends ThemeExtension<AppTextRoles> {
  const AppTextRoles({
    required this.display,
    required this.question,
    required this.resultName,
    required this.body,
    required this.button,
    required this.saida,
    required this.secondary,
  });

  /// 패밀리 없이 수치만 가진 역할. 테마가 아직 없을 때의 기준값이다.
  static const fallback = AppTextRoles(
    display: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: AppColors.textPrimary,
    ),
    question: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    resultName: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    body: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: AppColors.textPrimary,
    ),
    button: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
    saida: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    secondary: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textSecondary,
    ),
  );

  final TextStyle display;
  final TextStyle question;
  final TextStyle resultName;
  final TextStyle body;

  /// 색은 버튼 종류가 정한다.
  final TextStyle button;
  final TextStyle saida;
  final TextStyle secondary;

  TextStyle operator [](AppTextRole role) {
    return switch (role) {
      AppTextRole.display => display,
      AppTextRole.question => question,
      AppTextRole.resultName => resultName,
      AppTextRole.body => body,
      AppTextRole.button => button,
      AppTextRole.saida => saida,
      AppTextRole.secondary => secondary,
    };
  }

  @override
  AppTextRoles copyWith({
    TextStyle? display,
    TextStyle? question,
    TextStyle? resultName,
    TextStyle? body,
    TextStyle? button,
    TextStyle? saida,
    TextStyle? secondary,
  }) {
    return AppTextRoles(
      display: display ?? this.display,
      question: question ?? this.question,
      resultName: resultName ?? this.resultName,
      body: body ?? this.body,
      button: button ?? this.button,
      saida: saida ?? this.saida,
      secondary: secondary ?? this.secondary,
    );
  }

  @override
  AppTextRoles lerp(AppTextRoles? other, double t) {
    if (other == null) {
      return this;
    }
    return AppTextRoles(
      display: TextStyle.lerp(display, other.display, t)!,
      question: TextStyle.lerp(question, other.question, t)!,
      resultName: TextStyle.lerp(resultName, other.resultName, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      saida: TextStyle.lerp(saida, other.saida, t)!,
      secondary: TextStyle.lerp(secondary, other.secondary, t)!,
    );
  }
}

/// 화면과 이후 공유 이미지가 같은 수치·패밀리를 요청하는 진입점.
abstract final class AppTypography {
  static AppTextRoles rolesOf(BuildContext context) {
    return Theme.of(context).extension<AppTextRoles>() ?? AppTextRoles.fallback;
  }

  static AppTextRoles rolesFor(AppFontPlan plan) {
    TextStyle paint(TextStyle base, {bool inheritColor = true}) {
      return base.copyWith(
        fontFamily: plan.primary.family,
        fontFamilyFallback: plan.fallbackFamilies,
        locale: plan.locale,
        color: inheritColor ? base.color : null,
      );
    }

    const metrics = AppTextRoles.fallback;
    return AppTextRoles(
      display: paint(metrics.display),
      question: paint(metrics.question),
      resultName: paint(metrics.resultName),
      body: paint(metrics.body),
      button: paint(metrics.button, inheritColor: false),
      saida: paint(metrics.saida),
      secondary: paint(metrics.secondary),
    );
  }

  /// 결과 타입명, 포메이션 설명, 캐치프레이즈, 안내 문구가 이 스타일을 쓴다.
  ///
  /// 캡처는 해당 언어의 폰트 로드와 레이아웃이 끝난 뒤에 한다.
  static TextStyle styleFor(AppTextRole role, String languageCode) {
    return rolesFor(AppFonts.plan(languageCode))[role];
  }
}

/// 언어별 검수 예문. 제품 카탈로그가 아니라 폰트 확인용이다.
abstract final class FontSamples {
  static const specimens = <String, String>{
    'ko': '값·읽기·괜찮아요, 18문항',
    'en': 'What’s your formation? 4–4–2',
    'ja': '骨・直・令・返、きょうの作戦。カタカナ',
    'pt-BR': 'São Paulo, ação, você, bênção',
    'es': '¿Cuál es tu táctica? ¡Mañana!',
    'id': 'Bagaimana caramu mengambil keputusan?',
    'vi': 'Tiếng Việt, Nguyễn, tưởng tượng, Ắ ẵ ộ ự Đ đ',
    'th': 'ผู้เล่น น้ำ หนึ่ง กำลังใจ',
    'hi': 'हिंदी खिलाड़ी दृष्टि क्ष त्र ज्ञ कि की',
  };

  static const symbols = '4-2-4  50%  ₩  R\$  →  ⚽  🐶';

  static const viNfc = 'Ti\u1EBFng Vi\u1EC7t';
  static const viNfd = 'Tie\u0302\u0301ng Vie\u0323\u0302t';
  static const thaiStacked = 'ผู้เล่น\nหนึ่ง';

  static String specimen(String languageCode) {
    return specimens[languageCode] ?? specimens['ko']!;
  }
}
