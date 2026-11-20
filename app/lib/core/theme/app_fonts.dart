import 'package:material_ui/material_ui.dart';

/// 배포 파일 한 개. 웹에서는 `flutter/fonts`가 아니라 런타임에 이 에셋만 읽는다.
class AppFontFile {
  const AppFontFile({
    required this.id,
    required this.family,
    required this.asset,
    required this.licenseAsset,
    required this.sourceUrl,
    required this.revision,
    required this.sha256,
    required this.bytes,
    required this.weightMin,
    required this.weightMax,
    required this.reservedFontName,
    required this.qaOnly,
  });

  final String id;
  final String family;
  final String asset;
  final String licenseAsset;
  final String sourceUrl;
  final String revision;
  final String sha256;
  final int bytes;
  final int weightMin;
  final int weightMax;
  final String reservedFontName;

  /// 번역 출시 전 미리보기 검수 전용. 기본 4언어의 첫 방문에서는 요청하지 않는다.
  final bool qaOnly;

  bool containsWeight(int weight) => weight >= weightMin && weight <= weightMax;
}

/// 한 언어의 기본 패밀리, 그 다음으로 시도할 패밀리, 로드할 에셋.
class AppFontPlan {
  const AppFontPlan({
    required this.languageCode,
    required this.locale,
    required this.primary,
    this.fallbacks = const [],
  });

  final String languageCode;
  final Locale locale;
  final AppFontFile primary;
  final List<AppFontFile> fallbacks;

  List<AppFontFile> get files => [primary, ...fallbacks];

  List<String> get fallbackFamilies => [
    for (final file in fallbacks) file.family,
  ];
}

/// 언어 코드와 폰트 파일을 대응시킨다.
///
/// 한국어 Pretendard와 Pretendard JP는 다른 언어의 공통 폴백이 아니다.
/// 이미 글리프가 있으면 엔진이 다음 패밀리로 넘어가지 않기 때문이다.
abstract final class AppFonts {
  static const usedWeights = <int>[400, 500, 600, 700];

  static const pretendard = AppFontFile(
    id: 'pretendard',
    family: 'Pretendard',
    asset: 'assets/fonts/pretendard/PretendardVariable.ttf',
    licenseAsset: 'assets/fonts/pretendard/LICENSE.txt',
    sourceUrl: 'https://github.com/orioncactus/pretendard/raw/v1.3.9/packages/pretendard/dist/public/variable/PretendardVariable.ttf',
    revision: 'v1.3.9',
    sha256: '3090ccde0442bb347aa7685d9ba8b17436a60682df6e8f92a9a670de14056e22',
    bytes: 6739336,
    weightMin: 45,
    weightMax: 930,
    reservedFontName: 'Pretendard',
    qaOnly: false,
  );

  static const pretendardStd = AppFontFile(
    id: 'pretendard-std',
    family: 'Pretendard Std',
    asset: 'assets/fonts/pretendard_std/PretendardStdVariable.ttf',
    licenseAsset: 'assets/fonts/pretendard_std/LICENSE.txt',
    sourceUrl: 'https://github.com/orioncactus/pretendard/raw/v1.3.9/packages/pretendard-std/dist/public/variable/PretendardStdVariable.ttf',
    revision: 'v1.3.9',
    sha256: '499ff7e76f905bd909b4640fe333022fb0f241e292b84e1b6986c7b46eb57a80',
    bytes: 881216,
    weightMin: 45,
    weightMax: 930,
    reservedFontName: 'Pretendard Std',
    qaOnly: false,
  );

  static const pretendardJp = AppFontFile(
    id: 'pretendard-jp',
    family: 'Pretendard JP',
    asset: 'assets/fonts/pretendard_jp/PretendardJPVariable.ttf',
    licenseAsset: 'assets/fonts/pretendard_jp/LICENSE.txt',
    sourceUrl: 'https://github.com/orioncactus/pretendard/raw/v1.3.9/packages/pretendard-jp/dist/public/variable/PretendardJPVariable.ttf',
    revision: 'v1.3.9',
    sha256: 'bc1d77db0f3cb9c20986b8939aa8a28d5216552d777d082955da22f420535cbb',
    bytes: 13087888,
    weightMin: 45,
    weightMax: 930,
    reservedFontName: 'Pretendard JP',
    qaOnly: false,
  );

  static const notoSans = AppFontFile(
    id: 'noto-sans',
    family: 'Noto Sans',
    asset: 'assets/fonts/noto_sans/NotoSans[wdth,wght].ttf',
    licenseAsset: 'assets/fonts/noto_sans/OFL.txt',
    sourceUrl: 'https://github.com/google/fonts/raw/2984c575fdce412ee02b2baaba67672b9a9434d8/ofl/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf',
    revision: '2984c575fdce412ee02b2baaba67672b9a9434d8',
    sha256: 'bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d',
    bytes: 2049096,
    weightMin: 100,
    weightMax: 900,
    reservedFontName: 'Noto Sans',
    qaOnly: true,
  );

  static const notoSansThai = AppFontFile(
    id: 'noto-sans-thai',
    family: 'Noto Sans Thai',
    asset: 'assets/fonts/noto_sans_thai/NotoSansThai[wdth,wght].ttf',
    licenseAsset: 'assets/fonts/noto_sans_thai/OFL.txt',
    sourceUrl: 'https://github.com/google/fonts/raw/64fcce14ed3e59cb68c3d225c016c738923ff0dc/ofl/notosansthai/NotoSansThai%5Bwdth%2Cwght%5D.ttf',
    revision: '64fcce14ed3e59cb68c3d225c016c738923ff0dc',
    sha256: '5a1c559bb539583c8a1fd99d1c5b9491e5e14478c9cd2bd0970d5c3096cc9ef8',
    bytes: 218652,
    weightMin: 100,
    weightMax: 900,
    reservedFontName: 'Noto Sans Thai',
    qaOnly: true,
  );

  static const notoSansDevanagari = AppFontFile(
    id: 'noto-sans-devanagari',
    family: 'Noto Sans Devanagari',
    asset:
        'assets/fonts/noto_sans_devanagari/NotoSansDevanagari[wdth,wght].ttf',
    licenseAsset: 'assets/fonts/noto_sans_devanagari/OFL.txt',
    sourceUrl: 'https://github.com/google/fonts/raw/2bc5d431b584d89e646214bf6cfa75494e76ceea/ofl/notosansdevanagari/NotoSansDevanagari%5Bwdth%2Cwght%5D.ttf',
    revision: '2bc5d431b584d89e646214bf6cfa75494e76ceea',
    sha256: '14ec4af41f27482216d1c2229f417ff9b1425e1babb014e57d1d40d03229853e',
    bytes: 641944,
    weightMin: 100,
    weightMax: 900,
    reservedFontName: 'Noto Sans Devanagari',
    qaOnly: true,
  );

  static const files = <AppFontFile>[
    pretendard,
    pretendardStd,
    pretendardJp,
    notoSans,
    notoSansThai,
    notoSansDevanagari,
  ];

  /// 번역이 출시된 언어. 제품 메뉴와 기기 선호 해석은 이 목록만 본다.
  static const released = <String>['ko', 'en', 'ja', 'pt-BR'];

  /// 미리보기에서만 고를 수 있는 검수 언어.
  static const previewOnly = <String>['es', 'id', 'vi', 'th', 'hi'];

  static const languageCodes = <String>[
    'ko',
    'en',
    'ja',
    'pt-BR',
    'es',
    'id',
    'vi',
    'th',
    'hi',
  ];

  static const supportedLocales = <Locale>[
    Locale('ko'),
    Locale('en'),
    Locale('ja'),
    Locale('pt', 'BR'),
    Locale('es'),
    Locale('id'),
    Locale('vi'),
    Locale('th'),
    Locale('hi'),
  ];

  static const _plans = <String, AppFontPlan>{
    'ko': AppFontPlan(
      languageCode: 'ko',
      locale: Locale('ko'),
      primary: pretendard,
    ),
    'en': AppFontPlan(
      languageCode: 'en',
      locale: Locale('en'),
      primary: pretendardStd,
    ),
    'ja': AppFontPlan(
      languageCode: 'ja',
      locale: Locale('ja'),
      primary: pretendardJp,
    ),
    'pt-BR': AppFontPlan(
      languageCode: 'pt-BR',
      locale: Locale('pt', 'BR'),
      primary: pretendardStd,
    ),
    'es': AppFontPlan(
      languageCode: 'es',
      locale: Locale('es'),
      primary: pretendardStd,
    ),
    'id': AppFontPlan(
      languageCode: 'id',
      locale: Locale('id'),
      primary: pretendardStd,
    ),
    'vi': AppFontPlan(
      languageCode: 'vi',
      locale: Locale('vi'),
      primary: notoSans,
    ),
    'th': AppFontPlan(
      languageCode: 'th',
      locale: Locale('th'),
      primary: notoSansThai,
      fallbacks: [pretendardStd],
    ),
    'hi': AppFontPlan(
      languageCode: 'hi',
      locale: Locale('hi'),
      primary: notoSansDevanagari,
      fallbacks: [pretendardStd],
    ),
  };

  static AppFontPlan plan(String code) {
    final normalized = normalize(code);
    final resolved = normalized == null ? null : _plans[normalized];
    if (resolved == null) {
      throw ArgumentError.value(code, 'code', '지원하지 않는 언어 코드');
    }
    return resolved;
  }

  static Locale localeOf(String code) => plan(code).locale;

  /// `pt_BR`은 `pt-BR`이 된다. `pt-PT`는 브라질 포르투갈어로 바꾸지 않는다.
  static String? normalize(String raw) {
    final parts = raw
        .trim()
        .replaceAll('_', '-')
        .split('-')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    final language = parts.first.toLowerCase();
    final region = _regionOf(parts);
    if (language == 'pt') {
      return region == 'BR' ? 'pt-BR' : null;
    }
    if (_plans.containsKey(language)) {
      return language;
    }
    return null;
  }

  /// 저장된 유효 코드, 출시 언어 안의 기기 선호, 마지막으로 한국어.
  static String resolve({String? saved, List<String> deviceTags = const []}) {
    if (saved != null) {
      final stored = normalize(saved);
      if (stored != null) {
        return stored;
      }
    }
    for (final tag in deviceTags) {
      final code = normalize(tag);
      if (code != null && released.contains(code)) {
        return code;
      }
    }
    return 'ko';
  }

  static String? _regionOf(List<String> parts) {
    if (parts.length < 2) {
      return null;
    }
    final candidate = parts[1];
    final isAlphaRegion =
        candidate.length == 2 &&
        candidate.toLowerCase().codeUnits.every(
          (unit) =>
              unit >= 0x61 && unit <= 0x7a || unit >= 0x41 && unit <= 0x5a,
        );
    if (isAlphaRegion || RegExp(r'^\d{3}$').hasMatch(candidate)) {
      return candidate.toUpperCase();
    }
    return null;
  }
}
