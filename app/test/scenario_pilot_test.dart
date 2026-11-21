import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/features/catalog/content_models.dart';
import 'package:look_at_you/features/catalog/content_repository.dart';
import 'package:look_at_you/features/quiz/quiz_engine.dart';
import 'package:look_at_you/features/quiz/quiz_scenario.dart';
import 'package:look_at_you/shared/widgets/app_choice_option.dart';
import 'package:look_at_you/ui_preview.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all fours stay 4-4-2 when six scenarios choose richness', () async {
    final preview = await ContentRepository().load(version: '0.4.0');
    final pilot = preview.pilot('life_tactics');
    expect(pilot, isNotNull);
    expect(pilot!.scenarios, hasLength(6));
    final quiz = preview.quiz('life_tactics')!;
    final outcome = scoreIntegerValues(
      quiz,
      List<int>.filled(18, 4),
      allowPending: true,
    );
    expect(outcome.resultTypeId, 'tr10');
    expect(outcome.displayScores, {
      'happiness': '75.0',
      'meaning': '75.0',
      'richness': '75.0',
    });

    final tally = tallyScenarioAnswers(
      pilot,
      _choices(pilot, 'richness'),
      dimensionOrder: const ['happiness', 'meaning', 'richness'],
    );
    expect(tally.counts, {'happiness': 0, 'meaning': 0, 'richness': 6});
    expect(tally.total, 6);
    expect(tally.kind, 'lead');
    expect(outcome.resultTypeId, 'tr10');

    expect(
      tallyScenarioAnswers(
        pilot,
        _pattern(pilot, {'happiness': 2, 'meaning': 2, 'richness': 2}),
      ).kind,
      'balanced',
    );
    final tie = tallyScenarioAnswers(
      pilot,
      _pattern(pilot, {'happiness': 0, 'meaning': 3, 'richness': 3}),
    );
    expect(tie.kind, 'tie');
    expect(tie.leaders, ['meaning', 'richness']);
    expect(
      tallyScenarioAnswers(
        pilot,
        _pattern(pilot, {'happiness': 3, 'meaning': 2, 'richness': 1}),
      ).kind,
      'lead',
    );

    final moved = Map<String, String>.of(_choices(pilot, 'richness'));
    final first = pilot.scenarios.first;
    moved[first.scenarioId] = first.options
        .firstWhere((option) => option.dimensionId == 'happiness')
        .optionId;
    final after = tallyScenarioAnswers(
      pilot,
      moved,
      dimensionOrder: const ['happiness', 'meaning', 'richness'],
    );
    expect(after.counts['happiness'], 1);
    expect(after.counts['richness'], 5);
    expect(after.total, 6);

    expect(
      () => loadScenarioRows([
        {
          'scenarioId': first.scenarioId,
          'optionId': first.options.first.optionId,
        },
        {
          'scenarioId': first.scenarioId,
          'optionId': first.options.last.optionId,
        },
      ]),
      throwsA(
        isA<QuizFailure>().having(
          (error) => error.code,
          'code',
          'invalidAnswer',
        ),
      ),
    );
    final foreign = Map<String, String>.of(_choices(pilot, 'happiness'));
    foreign[first.scenarioId] = pilot.scenarios[1].options.first.optionId;
    expect(
      () => tallyScenarioAnswers(pilot, foreign),
      throwsA(
        isA<QuizFailure>().having(
          (error) => error.code,
          'code',
          'invalidAnswer',
        ),
      ),
    );

    final release = await ContentRepository().load(
      version: pilotDataVersion,
      channel: 'release',
    );
    expect(release.pilots, isEmpty);
    final legacy = await ContentRepository().load();
    expect(legacy.pilots, isEmpty);
    expect(legacy.quiz('life_tactics')?.rule, isNull);
  });

  test('729 scenario responses match the python fixture', () async {
    final pilot = (await ContentRepository().load(version: '0.5.0'))
        .pilot('life_tactics')!;
    expect(pilot.scoringMode, 'option_points');
    const order = ['happiness', 'meaning', 'richness'];
    for (var index = 0; index < 3; index++) {
      final tally = tallyScenarioAnswers(
        pilot,
        _slot(pilot, index),
        dimensionOrder: order,
      );
      expect(tally.counts, {'happiness': 6, 'meaning': 6, 'richness': 6});
      expect(tally.total, 18);
      expect(tally.kind, 'balanced');
    }
    final happiness = tallyScenarioAnswers(
      pilot,
      _choices(pilot, 'happiness'),
      dimensionOrder: order,
    );
    expect(happiness.counts, {'happiness': 12, 'meaning': 3, 'richness': 3});
    expect(happiness.kind, 'lead');
    expect(happiness.leaders, ['happiness']);

    final replaced = Map<String, String>.of(_slot(pilot, 0));
    replaced[pilot.scenarios.first.scenarioId] =
        pilot.scenarios.first.options[1].optionId;
    expect(
      tallyScenarioAnswers(pilot, replaced, dimensionOrder: order).counts,
      isNot(
        tallyScenarioAnswers(
          pilot,
          _slot(pilot, 0),
          dimensionOrder: order,
        ).counts,
      ),
    );
    expect(
      () => tallyScenarioAnswers(pilot, {
        pilot.scenarios.first.scenarioId:
            pilot.scenarios.first.options.first.optionId,
      }),
      throwsA(
        isA<QuizFailure>().having((error) => error.code, 'code', 'incomplete'),
      ),
    );
    final broken = ScenarioPilot(
      quizId: pilot.quizId,
      baseDataVersion: pilot.baseDataVersion,
      pilotVersion: pilot.pilotVersion,
      scenarios: pilot.scenarios,
      locales: pilot.locales,
      scoringMode: 'unknown',
    );
    expect(
      () =>
          tallyScenarioAnswers(broken, _slot(pilot, 0), dimensionOrder: order),
      throwsA(
        isA<QuizFailure>().having(
          (error) => error.code,
          'code',
          'invalidDefinition',
        ),
      ),
    );

    final lines = File('test/fixtures/scenario_v2_729.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty)
        .toList();
    expect(lines, hasLength(729));
    final choices = [
      for (final scenario in pilot.scenarios)
        [for (final option in scenario.options) option.optionId],
    ];
    var row = 0;
    void walk(int depth, List<String> picked) {
      if (depth == choices.length) {
        final answers = {
          for (var index = 0; index < pilot.scenarios.length; index++)
            pilot.scenarios[index].scenarioId: picked[index],
        };
        final tally = tallyScenarioAnswers(
          pilot,
          answers,
          dimensionOrder: order,
        );
        final line =
            '${picked.join(',')}|${tally.counts['happiness']},${tally.counts['meaning']},${tally.counts['richness']}|${tally.total}|${tally.leaders.join(',')}|${tally.kind}';
        expect(line, lines[row], reason: 'row $row');
        row += 1;
        return;
      }
      for (final optionId in choices[depth]) {
        picked.add(optionId);
        walk(depth + 1, picked);
        picked.removeLast();
      }
    }

    walk(0, []);
    expect(row, 729);
  });

  testWidgets('preview walks 18 questions and 6 scenarios before one card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bundle = await tester.runAsync(
      () => ContentRepository().load(version: pilotDataVersion),
    );
    await tester.pumpWidget(
      UiPreviewApp(
        bundle: bundle,
        store: MemoryLocaleStore()..value = 'en',
        deviceTags: const ['ko'],
        loader: AppFontLoader(
          loadBytes: (_) async => ByteData(0),
          register: (_, _) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    Future<void> tap(Key key) async {
      final finder = find.byKey(key);
      await tester.scrollUntilVisible(finder, 400);
      await tester.tap(finder);
      await tester.pump();
    }

    await tap(const Key('pilot-start'));
    for (var question = 0; question < 18; question++) {
      await tap(const Key('pilot-choice-3'));
      await tap(const Key('pilot-next'));
    }
    expect(find.byKey(const Key('pilot-result')), findsNothing);
    expect(find.text('상황 선택 1 / 6'), findsOneWidget);

    await tap(const Key('pilot-scenario-back'));
    expect(find.byKey(const Key('pilot-question')), findsOneWidget);
    expect(
      tester
          .widget<AppChoiceOption>(find.byKey(const Key('pilot-choice-3')))
          .selected,
      isTrue,
    );
    await tap(const Key('lang-ja'));
    expect(
      tester
          .widget<AppChoiceOption>(find.byKey(const Key('pilot-choice-3')))
          .selected,
      isTrue,
    );
    await tap(const Key('lang-en'));
    await tap(const Key('pilot-next'));

    for (var index = 0; index < 6; index++) {
      await tap(const Key('pilot-scenario-choice-0'));
      final last = index == 5;
      await tap(Key(last ? 'pilot-scenario-finish' : 'pilot-scenario-next'));
    }

    expect(find.byKey(const Key('catalog-result')), findsNothing);
    expect(find.byKey(const Key('catalog-saida')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('pilot-score-happiness'))).data,
      contains('66.7'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('pilot-score-meaning'))).data,
      contains('66.7'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('pilot-score-richness'))).data,
      contains('66.7'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('pilot-formation'))).data,
      '4-4-2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('pilot-scenario-count-happiness')))
          .data,
      contains('6점'),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('pilot-scenario-count-meaning')))
          .data,
      contains('6점'),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('pilot-scenario-count-richness')))
          .data,
      contains('6점'),
    );
    final record = tester
        .widget<Text>(find.byKey(const Key('pilot-record')))
        .data!;
    expect(record, contains('"baseDataVersion":"0.9.0"'));
    expect(record, contains('"scoringMode":"option_points"'));
    expect(record, contains('"baseResultTypeId":"tr10"'));
    expect(record, contains('"lt_q9_06":"a4"'));
    expect(record, contains('"lt_q9_15":"a4"'));
    expect(record, contains('"happiness":"66.7"'));
    expect(record, contains('"richness":6'));

    await tap(const Key('pilot-retry'));
    expect(find.byKey(const Key('pilot-start')), findsOneWidget);
    expect(find.byKey(const Key('pilot-result')), findsNothing);
  });
}

Map<String, String> _slot(ScenarioPilot pilot, int index) {
  return {
    for (final scenario in pilot.scenarios)
      scenario.scenarioId: scenario.options[index].optionId,
  };
}

Map<String, String> _choices(ScenarioPilot pilot, String dimensionId) {
  return {
    for (final scenario in pilot.scenarios)
      scenario.scenarioId: scenario.options
          .firstWhere((option) => option.dimensionId == dimensionId)
          .optionId,
  };
}

Map<String, String> _pattern(ScenarioPilot pilot, Map<String, int> counts) {
  final remaining = Map<String, int>.of(counts);
  final answers = <String, String>{};
  for (final scenario in pilot.scenarios) {
    final dimensionId = remaining.entries
        .firstWhere((entry) => entry.value > 0)
        .key;
    remaining[dimensionId] = remaining[dimensionId]! - 1;
    answers[scenario.scenarioId] = scenario.options
        .firstWhere((option) => option.dimensionId == dimensionId)
        .optionId;
  }
  return answers;
}
