/// Excel에서 생성한 번들. 점수 계산은 features/quiz가 담당한다.
class ContentBundle {
  const ContentBundle({
    required this.schemaVersion,
    required this.dataVersion,
    required this.channel,
    required this.quizzes,
    required this.locales,
    this.pilots = const [],
  });

  final int schemaVersion;
  final String dataVersion;
  final String channel;
  final List<QuizContent> quizzes;
  final Map<String, LocaleCatalog> locales;
  final List<ScenarioPilot> pilots;

  /// pilotVersion을 비우면 이 번들 버전의 파일럿을 고른다.
  ScenarioPilot? pilot(String quizId, {String? pilotVersion}) {
    final matches = [for (final item in pilots) if (item.quizId == quizId) item];
    if (pilotVersion != null) {
      for (final item in matches) {
        if (item.pilotVersion == pilotVersion) {
          return item;
        }
      }
      return null;
    }
    for (final item in matches) {
      if (item.baseDataVersion == dataVersion) {
        return item;
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  QuizContent? quiz(String quizId) {
    for (final item in quizzes) {
      if (item.quizId == quizId) {
        return item;
      }
    }
    return null;
  }
}

class LocaleCatalog {
  const LocaleCatalog({
    required this.locale,
    required this.strings,
    required this.statuses,
    required this.origins,
  });

  final String locale;
  final Map<String, String> strings;
  final Map<String, String> statuses;
  final Map<String, String> origins;
}

class QuizContent {
  const QuizContent({
    required this.schemaVersion,
    required this.dataVersion,
    required this.quizId,
    required this.scoreMode,
    required this.completionPolicy,
    required this.resultRuleStatus,
    required this.resultTemplateId,
    required this.titleTextKey,
    required this.introTextKey,
    required this.questionCount,
    required this.isActive,
    required this.sortOrder,
    required this.dimensions,
    required this.questions,
    required this.options,
    required this.resultTypes,
    this.rule,
  });

  final int schemaVersion;
  final String dataVersion;
  final String quizId;
  final String scoreMode;
  final String completionPolicy;
  final String resultRuleStatus;
  final String resultTemplateId;
  final String titleTextKey;
  final String introTextKey;
  final int questionCount;
  final bool isActive;
  final int sortOrder;
  final List<DimensionContent> dimensions;
  final List<QuestionContent> questions;
  final List<OptionContent> options;
  final List<ResultTypeContent> resultTypes;
  final QuizRule? rule;

  List<OptionContent> optionsFor(String scaleId) {
    final items = [
      for (final option in options)
        if (option.scaleId == scaleId && option.isActive) option,
    ];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
}

class DimensionContent {
  const DimensionContent({
    required this.dimensionId,
    required this.nameTextKey,
    required this.roleTextKey,
    required this.sortOrder,
    required this.isActive,
  });

  final String dimensionId;
  final String nameTextKey;
  final String? roleTextKey;
  final int sortOrder;
  final bool isActive;
}

class QuestionContent {
  const QuestionContent({
    required this.questionId,
    required this.promptTextKey,
    required this.scaleId,
    required this.dimensionId,
    required this.weight,
    required this.reverse,
    required this.reviewStatus,
    required this.sortOrder,
    required this.isActive,
  });

  final String questionId;
  final String promptTextKey;
  final String scaleId;
  final String dimensionId;
  final num weight;
  final bool reverse;
  final String reviewStatus;
  final int sortOrder;
  final bool isActive;
}

class OptionContent {
  const OptionContent({
    required this.optionId,
    required this.scaleId,
    required this.labelTextKey,
    required this.scoreValue,
    required this.sortOrder,
    required this.isActive,
  });

  final String optionId;
  final String scaleId;
  final String labelTextKey;
  final num scoreValue;
  final int sortOrder;
  final bool isActive;
}

class ResultTypeContent {
  const ResultTypeContent({
    required this.resultTypeId,
    required this.nameTextKey,
    required this.formation,
    required this.shareTextKey,
    required this.descriptionKey,
    required this.catchphraseKey,
    required this.designStatus,
    required this.resultTemplateId,
    required this.sortOrder,
    required this.isActive,
  });

  final String resultTypeId;
  final String nameTextKey;
  final String formation;
  final String shareTextKey;
  final String descriptionKey;
  final String catchphraseKey;
  final String designStatus;
  final String resultTemplateId;
  final int sortOrder;
  final bool isActive;
}

class QuizRule {
  const QuizRule({
    required this.ruleVersion,
    required this.strategy,
    required this.balanceMaxRange,
    required this.dominanceMinGap,
    required this.tiePriority,
    required this.mappings,
  });

  final String ruleVersion;
  final String strategy;
  final String balanceMaxRange;
  final String dominanceMinGap;
  final List<String> tiePriority;
  final List<RuleMapping> mappings;
}

class RuleMapping {
  const RuleMapping({
    required this.kind,
    required this.firstDimensionId,
    required this.secondDimensionId,
    required this.resultTypeId,
  });

  final String kind;
  final String? firstDimensionId;
  final String? secondDimensionId;
  final String resultTypeId;
}

class ScenarioPilot {
  const ScenarioPilot({
    required this.quizId,
    required this.baseDataVersion,
    required this.pilotVersion,
    required this.scenarios,
    required this.locales,
    this.scoringMode = 'axis_count',
  });

  final String quizId;
  final String baseDataVersion;
  final String pilotVersion;

  /// axis_count는 선택 횟수, option_points는 축 점수 합이다.
  final String scoringMode;
  final List<ScenarioContent> scenarios;
  final Map<String, LocaleCatalog> locales;
}

class ScenarioContent {
  const ScenarioContent({
    required this.scenarioId,
    required this.promptTextKey,
    required this.sortOrder,
    required this.options,
  });

  final String scenarioId;
  final String promptTextKey;
  final int sortOrder;
  final List<ScenarioOptionContent> options;
}

class ScenarioOptionContent {
  const ScenarioOptionContent({
    required this.optionId,
    required this.dimensionId,
    required this.labelTextKey,
    required this.sortOrder,
    this.pointsByDimension = const {},
  });

  final String optionId;
  final String dimensionId;
  final String labelTextKey;
  final int sortOrder;
  final Map<String, int> pointsByDimension;
}

class ResolvedText {
  const ResolvedText({
    required this.key,
    required this.text,
    required this.status,
    required this.usedFallback,
    required this.origin,
  });

  final String key;
  final String text;

  /// reviewed, draft, missing, absent 중 하나.
  final String status;
  final bool usedFallback;
  final String? origin;
}
