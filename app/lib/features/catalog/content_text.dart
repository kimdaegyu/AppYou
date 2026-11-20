import 'content_models.dart';

final _placeholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

/// 선택한 언어의 문구. 없거나 비어 있으면 한국어로 되돌리고 상태를 남긴다.
class AppTextBook {
  const AppTextBook(this.locales, {this.fallbackLocale = 'ko'});

  final Map<String, LocaleCatalog> locales;
  final String fallbackLocale;

  ResolvedText resolve(
    String languageCode,
    String key, {
    Map<String, Object?> values = const {},
  }) {
    final catalog = locales[languageCode];
    final direct = catalog?.strings[key];
    if (direct != null && direct.isNotEmpty) {
      return ResolvedText(
        key: key,
        text: interpolate(direct, values),
        status: catalog?.statuses[key] ?? 'reviewed',
        usedFallback: false,
        origin: catalog?.origins[key],
      );
    }
    final fallback = locales[fallbackLocale];
    final korean = fallback?.strings[key];
    if (korean != null && korean.isNotEmpty) {
      return ResolvedText(
        key: key,
        text: interpolate(korean, values),
        status: 'missing',
        usedFallback: languageCode != fallbackLocale,
        origin: fallback?.origins[key],
      );
    }
    return ResolvedText(
      key: key,
      text: '{$key}',
      status: 'absent',
      usedFallback: false,
      origin: null,
    );
  }
}

String interpolate(String template, Map<String, Object?> values) {
  return template.replaceAllMapped(_placeholder, (match) {
    final name = match.group(1)!;
    final value = values[name];
    if (!values.containsKey(name) || value == null) {
      return match.group(0)!;
    }
    return '$value';
  });
}
