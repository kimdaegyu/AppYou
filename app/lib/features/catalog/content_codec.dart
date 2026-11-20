import 'dart:convert';

import 'content_models.dart';

/// 지원하는 JSON 번들 구조. 1은 규칙 없는 목록, 2는 진단별 rule을 포함한다.
const supportedSchemaVersions = {1, 2};

class ContentLoadException implements Exception {
  const ContentLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContentVersionException extends ContentLoadException {
  const ContentVersionException(this.schemaVersion)
    : super('지원하지 않는 schemaVersion $schemaVersion');

  final int schemaVersion;
}

/// 카탈로그, 진단 파일, 언어 파일을 한 번들로 합친다.
abstract final class ContentCodec {
  static ContentBundle parse({
    required String catalogJson,
    required Map<String, String> quizJsonById,
    required Map<String, String> localeJsonByCode,
    List<ScenarioPilot> pilots = const [],
  }) {
    final catalog = _object(_decode(catalogJson, 'catalog.json'), 'catalog.json');
    final schemaVersion = _schema(catalog, 'catalog.json');
    final dataVersion = _string(catalog, 'dataVersion', 'catalog.json');
    final channel = _string(catalog, 'channel', 'catalog.json');
    final listed = _list(catalog, 'quizzes', 'catalog.json');
    final quizzes = <QuizContent>[];
    for (var index = 0; index < listed.length; index++) {
      final summary = _asMap(listed[index], 'catalog.json.quizzes[$index]');
      final quizId = _string(summary, 'quizId', 'catalog.json.quizzes[$index]');
      final raw = quizJsonById[quizId];
      if (raw == null) {
        throw ContentLoadException('quizzes/$quizId.json 이 없습니다.');
      }
      quizzes.add(_quiz(raw, quizId, dataVersion, schemaVersion));
    }
    final locales = <String, LocaleCatalog>{};
    for (final entry in localeJsonByCode.entries) {
      locales[entry.key] = _locale(
        entry.value,
        entry.key,
        dataVersion,
        schemaVersion,
      );
    }
    return ContentBundle(
      schemaVersion: schemaVersion,
      dataVersion: dataVersion,
      channel: channel,
      quizzes: quizzes,
      locales: locales,
      pilots: pilots,
    );
  }

  static ScenarioPilot parsePilot(String raw) {
    const path = 'pilots/scenario.json';
    final json = _object(_decode(raw, path), path);
    final scenarios = <ScenarioContent>[];
    final listed = _list(json, 'scenarios', path);
    for (var index = 0; index < listed.length; index++) {
      final item = _asMap(listed[index], '$path.scenarios[$index]');
      final options = <ScenarioOptionContent>[];
      final optionList = _list(item, 'options', '$path.scenarios[$index]');
      for (var optionIndex = 0; optionIndex < optionList.length; optionIndex++) {
        final option = _asMap(optionList[optionIndex], '$path.scenarios[$index].options[$optionIndex]');
        final optionPath = '$path.scenarios[$index].options[$optionIndex]';
        options.add(
          ScenarioOptionContent(
            optionId: _string(option, 'optionId', optionPath),
            dimensionId: _string(option, 'dimensionId', optionPath),
            labelTextKey: _string(option, 'labelTextKey', optionPath),
            sortOrder: _int(option, 'sortOrder', optionPath),
            pointsByDimension: option['pointsByDimension'] == null
                ? const {}
                : _intMap(option['pointsByDimension'], '$optionPath.pointsByDimension'),
          ),
        );
      }
      options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      scenarios.add(
        ScenarioContent(
          scenarioId: _string(item, 'scenarioId', '$path.scenarios[$index]'),
          promptTextKey: _string(item, 'promptTextKey', '$path.scenarios[$index]'),
          sortOrder: _int(item, 'sortOrder', '$path.scenarios[$index]'),
          options: options,
        ),
      );
    }
    scenarios.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final locales = <String, LocaleCatalog>{};
    final localeJson = _object(json['locales'], '$path.locales');
    for (final entry in localeJson.entries) {
      final body = _asMap(entry.value, '$path.locales.${entry.key}');
      locales[entry.key] = LocaleCatalog(
        locale: entry.key,
        strings: _stringMap(body['strings'], '$path.locales.${entry.key}.strings'),
        statuses: _stringMap(body['statuses'], '$path.locales.${entry.key}.statuses'),
        origins: const {},
      );
    }
    final scoringMode = _optionalString(json, 'scoringMode', path) ?? 'axis_count';
    if (scoringMode != 'axis_count' && scoringMode != 'option_points') {
      throw ContentLoadException('$path.scoringMode 를 지원하지 않습니다.');
    }
    if (scoringMode == 'option_points') {
      for (final scenario in scenarios) {
        for (final option in scenario.options) {
          if (option.pointsByDimension.isEmpty) {
            throw ContentLoadException('$path 의 ${option.optionId} 배점이 없습니다.');
          }
        }
      }
    }
    return ScenarioPilot(
      quizId: _string(json, 'quizId', path),
      baseDataVersion: _string(json, 'baseDataVersion', path),
      pilotVersion: _string(json, 'pilotVersion', path),
      scoringMode: scoringMode,
      scenarios: scenarios,
      locales: locales,
    );
  }

  static QuizContent _quiz(
    String raw,
    String quizId,
    String dataVersion,
    int catalogSchema,
  ) {
    final path = 'quizzes/$quizId.json';
    final json = _object(_decode(raw, path), path);
    final schemaVersion = _schema(json, path);
    if (schemaVersion != catalogSchema) {
      throw ContentLoadException('$path 의 schemaVersion이 카탈로그와 다릅니다.');
    }
    if (_string(json, 'dataVersion', path) != dataVersion) {
      throw ContentLoadException('$path 의 dataVersion이 카탈로그와 다릅니다.');
    }
    if (_string(json, 'quizId', path) != quizId) {
      throw ContentLoadException('$path 의 quizId가 카탈로그와 다릅니다.');
    }
    return QuizContent(
      schemaVersion: schemaVersion,
      dataVersion: dataVersion,
      quizId: quizId,
      scoreMode: _string(json, 'scoreMode', path),
      completionPolicy: _string(json, 'completionPolicy', path),
      resultRuleStatus: _string(json, 'resultRuleStatus', path),
      resultTemplateId: _string(json, 'resultTemplateId', path),
      titleTextKey: _string(json, 'titleTextKey', path),
      introTextKey: _string(json, 'introTextKey', path),
      questionCount: _int(json, 'questionCount', path),
      isActive: _bool(json, 'isActive', path),
      sortOrder: _int(json, 'sortOrder', path),
      dimensions: _mapList(json, 'dimensions', path, _dimension),
      questions: _mapList(json, 'questions', path, _question),
      options: _mapList(json, 'options', path, _option),
      resultTypes: _mapList(json, 'resultTypes', path, _result),
      rule: _rule(json, path, schemaVersion),
    );
  }

  static QuizRule? _rule(Map<String, Object?> json, String path, int schema) {
    if (schema < 2) {
      if (json.containsKey('rule')) {
        throw ContentLoadException('$path 는 schema 1인데 rule이 있습니다.');
      }
      return null;
    }
    if (!json.containsKey('rule')) {
      throw ContentLoadException('$path 에 rule이 없습니다.');
    }
    final value = json['rule'];
    if (value == null) {
      return null;
    }
    final rule = _asMap(value, '$path.rule');
    return QuizRule(
      ruleVersion: _string(rule, 'ruleVersion', '$path.rule'),
      strategy: _string(rule, 'strategy', '$path.rule'),
      balanceMaxRange: _decimal(rule, 'balanceMaxRange', '$path.rule'),
      dominanceMinGap: _decimal(rule, 'dominanceMinGap', '$path.rule'),
      tiePriority: [
        for (final item in _list(rule, 'tiePriority', '$path.rule'))
          if (item is String) item else throw ContentLoadException('$path.rule.tiePriority 항목이 문자열이 아닙니다.'),
      ],
      mappings: _mapList(rule, 'mappings', '$path.rule', _mapping),
    );
  }

  static RuleMapping _mapping(Map<String, Object?> json, String path) {
    return RuleMapping(
      kind: _string(json, 'kind', path),
      firstDimensionId: _optionalString(json, 'firstDimensionId', path),
      secondDimensionId: _optionalString(json, 'secondDimensionId', path),
      resultTypeId: _string(json, 'resultTypeId', path),
    );
  }

  static DimensionContent _dimension(Map<String, Object?> json, String path) {
    return DimensionContent(
      dimensionId: _string(json, 'dimensionId', path),
      nameTextKey: _string(json, 'nameTextKey', path),
      roleTextKey: _optionalString(json, 'roleTextKey', path),
      sortOrder: _int(json, 'sortOrder', path),
      isActive: _bool(json, 'isActive', path),
    );
  }

  static QuestionContent _question(Map<String, Object?> json, String path) {
    return QuestionContent(
      questionId: _string(json, 'questionId', path),
      promptTextKey: _string(json, 'promptTextKey', path),
      scaleId: _string(json, 'scaleId', path),
      dimensionId: _string(json, 'dimensionId', path),
      weight: _num(json, 'weight', path),
      reverse: _bool(json, 'reverse', path),
      reviewStatus: _string(json, 'reviewStatus', path),
      sortOrder: _int(json, 'sortOrder', path),
      isActive: _bool(json, 'isActive', path),
    );
  }

  static OptionContent _option(Map<String, Object?> json, String path) {
    return OptionContent(
      optionId: _string(json, 'optionId', path),
      scaleId: _string(json, 'scaleId', path),
      labelTextKey: _string(json, 'labelTextKey', path),
      scoreValue: _num(json, 'scoreValue', path),
      sortOrder: _int(json, 'sortOrder', path),
      isActive: _bool(json, 'isActive', path),
    );
  }

  static ResultTypeContent _result(Map<String, Object?> json, String path) {
    return ResultTypeContent(
      resultTypeId: _string(json, 'resultTypeId', path),
      nameTextKey: _string(json, 'nameTextKey', path),
      formation: _string(json, 'formation', path),
      shareTextKey: _string(json, 'shareTextKey', path),
      descriptionKey: _string(json, 'descriptionKey', path),
      catchphraseKey: _string(json, 'catchphraseKey', path),
      designStatus: _string(json, 'designStatus', path),
      resultTemplateId: _string(json, 'resultTemplateId', path),
      sortOrder: _int(json, 'sortOrder', path),
      isActive: _bool(json, 'isActive', path),
    );
  }

  static LocaleCatalog _locale(
    String raw,
    String code,
    String dataVersion,
    int catalogSchema,
  ) {
    final path = 'locales/$code.json';
    final json = _object(_decode(raw, path), path);
    if (_schema(json, path) != catalogSchema) {
      throw ContentLoadException('$path 의 schemaVersion이 카탈로그와 다릅니다.');
    }
    if (_string(json, 'dataVersion', path) != dataVersion) {
      throw ContentLoadException('$path 의 dataVersion이 카탈로그와 다릅니다.');
    }
    if (_string(json, 'locale', path) != code) {
      throw ContentLoadException('$path 의 locale이 파일 이름과 다릅니다.');
    }
    return LocaleCatalog(
      locale: code,
      strings: _stringMap(json['strings'], '$path.strings'),
      statuses: _stringMap(json['statuses'], '$path.statuses'),
      origins: json['origins'] == null
          ? const {}
          : _stringMap(json['origins'], '$path.origins'),
    );
  }

  static Object? _decode(String raw, String path) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      throw ContentLoadException('$path JSON을 읽을 수 없습니다. $error');
    }
  }

  static int _schema(Map<String, Object?> json, String path) {
    final value = _int(json, 'schemaVersion', path);
    if (!supportedSchemaVersions.contains(value)) {
      throw ContentVersionException(value);
    }
    return value;
  }

  static List<T> _mapList<T>(
    Map<String, Object?> json,
    String key,
    String path,
    T Function(Map<String, Object?>, String) decode,
  ) {
    final list = _list(json, key, path);
    return [
      for (var index = 0; index < list.length; index++)
        decode(_asMap(list[index], '$path.$key[$index]'), '$path.$key[$index]'),
    ];
  }

  static Map<String, String> _stringMap(Object? value, String path) {
    if (value is! Map) {
      throw ContentLoadException('$path 는 객체여야 합니다.');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw ContentLoadException('$path 의 값이 문자열이 아닙니다.');
      }
      result[entry.key as String] = entry.value as String;
    }
    return result;
  }

  static Map<String, Object?> _object(Object? value, String path) {
    if (value is! Map) {
      throw ContentLoadException('$path 는 객체여야 합니다.');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static Map<String, Object?> _asMap(Object? value, String path) {
    return _object(value, path);
  }

  static List<Object?> _list(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! List) {
      throw ContentLoadException('$path.$key 는 배열이어야 합니다.');
    }
    return value;
  }

  static String _string(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw ContentLoadException('$path.$key 문자열이 없습니다.');
    }
    return value;
  }

  static String? _optionalString(
    Map<String, Object?> json,
    String key,
    String path,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ContentLoadException('$path.$key 는 문자열이어야 합니다.');
    }
    return value.isEmpty ? null : value;
  }

  static Map<String, int> _intMap(Object? value, String path) {
    if (value is! Map) {
      throw ContentLoadException('$path 는 객체여야 합니다.');
    }
    final points = <String, int>{};
    for (final entry in value.entries) {
      if (entry.key is! String || entry.value is! int) {
        throw ContentLoadException('$path 의 배점은 0 이상의 정수여야 합니다.');
      }
      if (entry.value as int < 0) {
        throw ContentLoadException('$path 의 배점은 0 이상의 정수여야 합니다.');
      }
      points[entry.key as String] = entry.value as int;
    }
    return points;
  }

  static int _int(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! int) {
      throw ContentLoadException('$path.$key 는 정수여야 합니다.');
    }
    return value;
  }

  static String _decimal(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is int) {
      return '$value';
    }
    if (value is double && value.isFinite) {
      if (value == value.roundToDouble()) {
        return '${value.toInt()}';
      }
      return value.toString();
    }
    throw ContentLoadException('$path.$key 는 수여야 합니다.');
  }

  static num _num(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! num) {
      throw ContentLoadException('$path.$key 는 수여야 합니다.');
    }
    return value;
  }

  static bool _bool(Map<String, Object?> json, String key, String path) {
    final value = json[key];
    if (value is! bool) {
      throw ContentLoadException('$path.$key 는 불리언이어야 합니다.');
    }
    return value;
  }
}
