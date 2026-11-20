import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'content_codec.dart';
import 'content_models.dart';

const contentDataVersion = '0.2.0';
const pilotDataVersion = '0.9.0';
const scenarioPointVersions = {'0.5.0', '0.6.0', '0.7.0', '0.7.1', '0.8.0', '0.9.0'};
const releaseLanguageCodes = ['ko', 'en', 'ja', 'pt-BR'];

/// 생성 JSON을 한 번만 파싱한다. 실패한 요청은 캐시에 남기지 않는다.
class ContentRepository {
  ContentRepository({Future<String> Function(String asset)? loadString})
    : _loadString = loadString ?? rootBundle.loadString;

  final Future<String> Function(String asset) _loadString;
  final Map<String, Future<ContentBundle>> _pending = {};

  Future<ContentBundle> load({
    String version = contentDataVersion,
    String channel = 'preview',
  }) {
    final key = '$channel/$version';
    return _pending.putIfAbsent(key, () {
      return _read(version, channel).catchError((Object error, StackTrace stack) {
        _pending.remove(key);
        Error.throwWithStackTrace(error, stack);
      });
    });
  }

  Future<ContentBundle> _read(String version, String channel) async {
    final root = 'assets/data/$version/$channel';
    try {
      final catalogJson = await _loadString('$root/catalog.json');
      final quizJson = <String, String>{};
      for (final quizId in _quizIds(catalogJson)) {
        quizJson[quizId] = await _loadString('$root/quizzes/$quizId.json');
      }
      final locales = <String, String>{};
      for (final code in releaseLanguageCodes) {
        locales[code] = await _loadString('$root/locales/$code.json');
      }
      final pilots = <ScenarioPilot>[];
      if (channel == 'preview') {
        final pilotFile = scenarioPointVersions.contains(version) ? 'scenario_v2.json' : 'scenario_v1.json';
        final pilotJson = await _optionalString('$root/pilots/life_tactics/$pilotFile');
        if (pilotJson != null) {
          pilots.add(ContentCodec.parsePilot(pilotJson));
        }
      }
      return ContentCodec.parse(
        catalogJson: catalogJson,
        quizJsonById: quizJson,
        localeJsonByCode: locales,
        pilots: pilots,
      );
    } on ContentLoadException {
      rethrow;
    } catch (error) {
      throw ContentLoadException('콘텐츠를 읽지 못했습니다. $error');
    }
  }

  Future<String?> _optionalString(String asset) async {
    try {
      return await _loadString(asset);
    } on FlutterError catch (error) {
      if (error.message.contains('Unable to load asset')) {
        return null;
      }
      rethrow;
    }
  }

  static List<String> _quizIds(String catalogJson) {
    final decoded = jsonDecode(catalogJson);
    if (decoded is! Map || decoded['quizzes'] is! List) {
      throw const ContentLoadException('catalog.json quizzes 배열이 없습니다.');
    }
    return [
      for (final item in decoded['quizzes'] as List)
        if (item is Map && item['quizId'] is String) item['quizId'] as String,
    ];
  }
}
