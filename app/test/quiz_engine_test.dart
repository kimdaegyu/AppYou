import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/features/catalog/content_models.dart';
import 'package:look_at_you/features/catalog/content_repository.dart';
import 'package:look_at_you/features/quiz/quiz_engine.dart';
import 'package:look_at_you/features/quiz/quiz_ratio.dart';
import 'package:look_at_you/features/quiz/quiz_session.dart';
import 'package:look_at_you/shared/widgets/app_choice_option.dart';
import 'package:look_at_you/ui_preview.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pilot bundle scores the review cases and blocks release judgment', () async {
    // 31개 사례는 lt_vp 문항 ID와 종전 표시 순서에 묶여 있다.
    const reviewDataVersion = '0.3.0';
    final baselineBundle = await ContentRepository().load(version: reviewDataVersion);
    final baseline = baselineBundle.quiz('life_tactics')!;
    expect(baseline.questions.map((item) => item.questionId).toList(), [
      for (var number = 1; number <= 18; number++) 'lt_vp${number.toString().padLeft(2, '0')}',
    ]);

    final edited = (await ContentRepository().load(version: '0.4.0')).quiz('life_tactics')!;
    expect(edited.questions.map((item) => item.questionId).toList(), const [
      'lt_ed01',
      'lt_ed05',
      'lt_ed09',
      'lt_ed12',
      'lt_ed07',
      'lt_ed02',
      'lt_ed11',
      'lt_ed04',
      'lt_ed18',
      'lt_ed14',
      'lt_ed03',
      'lt_vp10',
      'lt_ed08',
      'lt_ed15',
      'lt_ed16',
      'lt_vp06',
      'lt_ed13',
      'lt_ed17',
    ]);
    final editedFours = scoreIntegerValues(edited, List<int>.filled(18, 4), allowPending: true);
    expect(editedFours.resultTypeId, 'tr10');
    expect(editedFours.displayScores, {'happiness': '75.0', 'meaning': '75.0', 'richness': '75.0'});

    final scoredBundle = await ContentRepository().load(version: '0.5.0');
    final scored = scoredBundle.quiz('life_tactics')!;
    expect(scored.dataVersion, '0.5.0');
    expect(scored.questions.map((item) => item.questionId).toList(), const [
      'lt_ed01',
      'lt_ed05',
      'lt_ed09',
      'lt_ed12',
      'lt_ed07',
      'lt_ed02',
      'lt_ed11',
      'lt_ed04',
      'lt_rev_r01',
      'lt_rev_m01',
      'lt_ed03',
      'lt_vp10',
      'lt_ed08',
      'lt_ed15',
      'lt_rev_h01',
      'lt_vp06',
      'lt_ed13',
      'lt_ed17',
    ]);
    final scoredFours = scoreIntegerValues(scored, List<int>.filled(18, 4), allowPending: true);
    expect(scoredFours.displayScores, {'happiness': '66.7', 'meaning': '66.7', 'richness': '66.7'});
    expect(scoredBundle.pilot('life_tactics')!.scenarios.first.options.first.optionId, 'sv2_01_1');

    final revisedBundle = await ContentRepository().load(version: '0.6.0');
    final revised = revisedBundle.quiz('life_tactics')!;
    expect(revised.dataVersion, '0.6.0');
    expect(revised.questions.map((item) => item.questionId).toList(), const [
      'lt_ed01',
      'lt_ed05',
      'lt_r6_try',
      'lt_r6_routine',
      'lt_ed07',
      'lt_ed02',
      'lt_ed11',
      'lt_ed04',
      'lt_r6_depth',
      'lt_rev_m01',
      'lt_r6_prepare',
      'lt_vp10',
      'lt_ed08',
      'lt_r6_revise',
      'lt_rev_h01',
      'lt_r6_perspective',
      'lt_ed13',
      'lt_ed17',
    ]);
    expect(revised.questions[8].reverse, isTrue);
    expect(revisedBundle.pilot('life_tactics')!.scenarios.first.options.first.optionId, 'lt_s6_01_1');
    expect(
      scoreIntegerValues(revised, List<int>.filled(18, 4), allowPending: true).displayScores,
      {'happiness': '66.7', 'meaning': '66.7', 'richness': '66.7'},
    );

    final plainBundle = await ContentRepository().load(version: '0.7.0');
    final plain = plainBundle.quiz('life_tactics')!;
    expect(plain.dataVersion, '0.7.0');
    expect(plain.questions[12].questionId, 'lt_q7_13');
    expect(
      plainBundle.locales['ko']!.strings['life_tactics.question.lt_q7_13'],
      '여럿이 만든 안내판을 누가 썼다면, 길을 찾는 데 도움이 됐는지 먼저 듣고 싶다.',
    );

    final wordingBundle = await ContentRepository().load(version: '0.7.1');
    final wording = wordingBundle.quiz('life_tactics')!;
    expect(wording.dataVersion, '0.7.1');
    expect(wording.questions.map((item) => item.questionId).toList(), const [
      'lt_q7_01',
      'lt_q7_02',
      'lt_q7_03',
      'lt_q7_04',
      'lt_q7_05',
      'lt_q7_06',
      'lt_q7_07',
      'lt_q7_08',
      'lt_q7_09',
      'lt_q7_10',
      'lt_q7_11',
      'lt_q7_12',
      'lt_q7_13',
      'lt_q7_14',
      'lt_q7_15',
      'lt_q7_16',
      'lt_q7_17',
      'lt_q7_18',
    ]);
    expect(wording.questions.where((item) => item.reverse).map((item) => item.questionId).toList(), [
      'lt_q7_09',
      'lt_q7_10',
      'lt_q7_15',
    ]);
    expect(
      wordingBundle.locales['ko']!.strings['life_tactics.question.lt_q7_13'],
      '우리가 만든 안내판을 본 사람에게 길을 쉽게 찾았는지 먼저 물어보고 싶다.',
    );
    expect(
      scoreIntegerValues(wording, List<int>.filled(18, 4), allowPending: true).displayScores,
      {'happiness': '66.7', 'meaning': '66.7', 'richness': '66.7'},
    );

    final preview = await ContentRepository().load(version: '0.8.0');
    final quiz = preview.quiz('life_tactics')!;
    expect(preview.schemaVersion, 2);
    expect(quiz.dataVersion, '0.8.0');
    expect(quiz.questions, hasLength(18));
    expect(quiz.rule?.ruleVersion, 'life_rank_v1_preview');
    expect(quiz.questions.map((item) => item.questionId).toList(), const [
      'lt_q7_01',
      'lt_q7_02',
      'lt_q7_03',
      'lt_q7_04',
      'lt_q7_05',
      'lt_q8_06',
      'lt_q7_07',
      'lt_q7_08',
      'lt_q7_09',
      'lt_q7_10',
      'lt_q7_11',
      'lt_q7_12',
      'lt_q8_13',
      'lt_q8_14',
      'lt_q7_15',
      'lt_q7_16',
      'lt_q8_17',
      'lt_q7_18',
    ]);
    expect(quiz.questions[5].reverse, isTrue);
    expect(quiz.questions[13].reverse, isTrue);
    expect(quiz.questions[16].reverse, isTrue);
    expect(quiz.questions.where((item) => item.reverse).map((item) => item.questionId).toList(), [
      'lt_q8_06',
      'lt_q7_09',
      'lt_q7_10',
      'lt_q8_14',
      'lt_q7_15',
      'lt_q8_17',
    ]);
    for (final axis in const ['happiness', 'meaning', 'richness']) {
      final items = quiz.questions.where((item) => item.dimensionId == axis);
      expect(items.where((item) => !item.reverse), hasLength(4), reason: axis);
      expect(items.where((item) => item.reverse), hasLength(2), reason: axis);
    }
    expect(
      preview.locales['ko']!.strings['life_tactics.question.lt_q8_13'],
      '우리가 만든 안내판을 본 사람에게 한 가지만 물을 수 있다. 나는 글씨가 잘 보였는지보다 길을 쉽게 찾았는지 묻고 싶다.',
    );
    expect(
      preview.locales['ko']!.strings['life_tactics.question.lt_q8_17'],
      '바쁜 하루가 끝나면 잠깐 쉬기보다 내일 할 일을 미리 정리하고 싶다.',
    );
    final ninthHigh = [for (var index = 0; index < 18; index++) index == 8 ? 5 : 3];
    final ninthLow = [for (var index = 0; index < 18; index++) index == 8 ? 1 : 3];
    final ninthFive = scoreIntegerValues(quiz, ninthHigh, allowPending: true);
    final ninthOne = scoreIntegerValues(quiz, ninthLow, allowPending: true);
    expect(ninthOne.dimensionScores['richness']!.compareTo(ninthFive.dimensionScores['richness']!) > 0, isTrue);
    expect(ninthFive.displayScores['happiness'], ninthOne.displayScores['happiness']);
    final pilot = preview.pilot('life_tactics')!;
    expect(pilot.scoringMode, 'option_points');
    expect(pilot.scenarios, hasLength(6));
    expect(pilot.scenarios.first.options.first.optionId, 'lt_s7_01_1');
    expect(pilot.scenarios.fold<int>(0, (sum, scene) => sum + scene.options.length), 18);
    expect(
      pilot.locales['ko']!.strings['life_tactics.scenario.lt_s8_02'],
      '친구와 함께한 날을 떠올려요. 서로 질문 하나씩 하기로 했어요. 무엇을 물을까요?',
    );
    expect(
      pilot.locales['ko']!.strings['life_tactics.scenario.lt_s8_03'],
      '여럿이 모일 방에 의자를 놓아요. 의자를 하나 옮긴다면 어디에 놓을까요?',
    );
    expect(
      pilot.locales['ko']!.strings['life_tactics.scenario.lt_s8_05'],
      '모임이 끝났어요. 다음에 올 사람에게 한 줄을 남긴다면 무엇을 적을까요?',
    );
    List<int> happinessFloor(int item17) {
      return [
        for (final question in quiz.questions)
          question.questionId == 'lt_q8_17'
              ? item17
              : question.dimensionId == 'happiness'
              ? (question.reverse ? 5 : 1)
              : 3,
      ];
    }
    final chosenOne = scoreIntegerValues(quiz, happinessFloor(1), allowPending: true);
    final chosenFive = scoreIntegerValues(quiz, happinessFloor(5), allowPending: true);
    expect(chosenOne.dimensionScores['happiness']! * QuizRatio.integer(6), QuizRatio.integer(100));
    expect(chosenFive.dimensionScores['happiness']! * QuizRatio.integer(6), QuizRatio.integer(0));
    expect(chosenOne.displayScores['meaning'], chosenFive.displayScores['meaning']);
    final forwardHigh = [
      for (final question in quiz.questions) question.reverse ? 1 : 5,
    ];
    final forwardLow = [
      for (final question in quiz.questions) question.reverse ? 5 : 1,
    ];
    expect(
      scoreIntegerValues(quiz, forwardHigh, allowPending: true).displayScores.values.toSet(),
      {'100.0'},
    );
    expect(
      scoreIntegerValues(quiz, forwardLow, allowPending: true).displayScores.values.toSet(),
      {'0.0'},
    );
    final allFours = scoreIntegerValues(quiz, List<int>.filled(18, 4), allowPending: true);
    expect(allFours.resultTypeId, 'tr10');
    expect(allFours.displayScores, {'happiness': '58.3', 'meaning': '58.3', 'richness': '58.3'});
    expect(
      allFours.dimensionScores['happiness'],
      QuizRatio.integer(175) / QuizRatio.integer(3),
    );

    final balancedBundle = await ContentRepository().load(version: pilotDataVersion);
    final balanced = balancedBundle.quiz('life_tactics')!;
    expect(balanced.dataVersion, '0.9.0');
    expect(balanced.questions.map((item) => item.questionId).toList(), const [
      'lt_q7_01',
      'lt_q7_02',
      'lt_q7_03',
      'lt_q7_04',
      'lt_q7_05',
      'lt_q9_06',
      'lt_q7_07',
      'lt_q7_08',
      'lt_q9_09',
      'lt_q9_10',
      'lt_q7_11',
      'lt_q7_12',
      'lt_q9_13',
      'lt_q9_14',
      'lt_q9_15',
      'lt_q7_16',
      'lt_q9_17',
      'lt_q7_18',
    ]);
    expect(balanced.questions.where((item) => item.reverse).map((item) => item.questionId).toList(), [
      'lt_q9_06',
      'lt_q9_09',
      'lt_q9_15',
    ]);
    for (final axis in const ['happiness', 'meaning', 'richness']) {
      final items = balanced.questions.where((item) => item.dimensionId == axis);
      expect(items.where((item) => item.reverse), hasLength(1), reason: axis);
    }
    expect(
      balancedBundle.locales['ko']!.strings['life_tactics.question.lt_q9_13']!,
      startsWith('한 시간 동안 하고 싶은 일을 고를 수 있다.'),
    );
    final balancedPilot = balancedBundle.pilot('life_tactics')!;
    expect(balancedPilot.scoringMode, 'option_points');
    expect(
      balancedPilot.locales['ko']!.strings['life_tactics.scenario.lt_s9_02'],
      '친구와 함께 보낸 하루를 떠올려요. 어떤 이야기를 나누고 싶나요?',
    );
    expect(
      balancedPilot.locales['ko']!.strings['life_tactics.scenario.lt_s9_03'],
      '오늘 모임을 사진 한 장으로 남겨요. 어떤 순간을 담고 싶나요?',
    );
    expect(
      balancedPilot.locales['ko']!.strings['life_tactics.scenario.lt_s9_06'],
      '오늘 일기에는 한 장면만 담을 자리가 있어요. 무엇을 남길까요?',
    );
    List<int> restFloor(int item15) {
      return [
        for (final question in balanced.questions)
          question.questionId == 'lt_q9_15'
              ? item15
              : question.dimensionId == 'happiness'
              ? 1
              : 3,
      ];
    }
    final restOne = scoreIntegerValues(balanced, restFloor(1), allowPending: true);
    final restFive = scoreIntegerValues(balanced, restFloor(5), allowPending: true);
    expect(restOne.dimensionScores['happiness']! * QuizRatio.integer(6), QuizRatio.integer(100));
    expect(restFive.dimensionScores['happiness']! * QuizRatio.integer(6), QuizRatio.integer(0));
    expect(
      scoreIntegerValues(balanced, List<int>.filled(18, 4), allowPending: true).displayScores,
      {'happiness': '66.7', 'meaning': '66.7', 'richness': '66.7'},
    );
    final current = QuizSession.start(quiz, allowPending: true);
    expect(
      () => current.importRows('0.4.0', [
        for (final question in edited.questions) {'questionId': question.questionId, 'optionId': 'a4'},
      ]),
      throwsA(isA<QuizFailure>().having((error) => error.code, 'code', 'versionMismatch')),
    );
    expect(current.answers, isEmpty);

    final release = await ContentRepository().load(version: pilotDataVersion, channel: 'release');
    expect(release.quizzes, isEmpty);
    final legacy = await ContentRepository().load();
    expect(legacy.schemaVersion, 1);
    expect(legacy.quiz('life_tactics')?.rule, isNull);
    expect(
      () => scoreIntegerValues(legacy.quiz('life_tactics')!, List<Object?>.filled(18, 3)),
      throwsA(isA<QuizFailure>().having((error) => error.code, 'code', 'ruleUnavailable')),
    );

    final cases = jsonDecode(File('test/fixtures/review_cases.json').readAsStringSync()) as List;
    expect(cases, hasLength(31));
    for (final raw in cases) {
      final item = raw as Map<String, Object?>;
      final answers = item['answers'] as List;
      try {
        final outcome = scoreIntegerValues(baseline, answers, allowPending: true);
        expect(outcome.resultTypeId, item['code'], reason: item['id'] as String);
        expect(outcome.preview, isTrue);
      } on QuizFailure catch (error) {
        expect(error.code, item['code'], reason: item['id'] as String);
      }
    }

    expect(scoreIntegerValues(quiz, List.filled(18, 1), allowPending: true).resultTypeId, 'tr10');
    expect(scoreIntegerValues(quiz, List.filled(18, 5), allowPending: true).resultTypeId, 'tr10');
    expect(
      judgeScores(quiz, const {'happiness': '75', 'meaning': '75', 'richness': '25'}, allowPending: true).resultTypeId,
      'tr08',
    );
    expect(
      judgeScores(quiz, const {'happiness': '25', 'meaning': '75', 'richness': '75'}, allowPending: true).resultTypeId,
      'tr05',
    );
    expect(
      judgeScores(quiz, const {'happiness': '75', 'meaning': '25', 'richness': '25'}, allowPending: true).resultTypeId,
      'tr07',
    );
    expect(
      judgeScores(quiz, const {'happiness': '62', 'meaning': '56', 'richness': '50'}, allowPending: true).resultTypeId,
      'tr10',
    );
    expect(
      judgeScores(quiz, const {'happiness': '62.01', 'meaning': '56', 'richness': '50'}, allowPending: true).resultTypeId,
      'tr08',
    );
    expect(
      judgeScores(quiz, const {'happiness': '70', 'meaning': '50', 'richness': '45'}, allowPending: true).resultTypeId,
      'tr07',
    );
    expect(
      judgeScores(quiz, const {'happiness': '69.99', 'meaning': '50', 'richness': '45'}, allowPending: true).resultTypeId,
      'tr08',
    );

    final weighted = scoreIntegerValues(_mini(quiz.rule!), const [2, 2, 3, 3], allowPending: true);
    expect(weighted.displayScores['happiness'], '62.5');
    expect(QuizRatio.decimal('62.5').tenths, '62.5');

    final session = QuizSession.start(quiz, allowPending: true);
    expect(
      () => session.importRows('0.2.0', const [
        {'questionId': 'lt_vp01', 'optionId': 'a3'},
      ]),
      throwsA(isA<QuizFailure>().having((error) => error.code, 'code', 'versionMismatch')),
    );
    expect(session.answers, isEmpty);
    expect(
      () => loadAnswerRows(const [
        {'questionId': 'lt_vp01', 'optionId': 'a1'},
        {'questionId': 'lt_vp01', 'optionId': 'a2'},
      ]),
      throwsA(isA<QuizFailure>().having((error) => error.code, 'code', 'invalidAnswer')),
    );
  });

  test('every equal-weight lattice cell has one type and 4824 edges change', () async {
    final quiz = (await ContentRepository().load(version: pilotDataVersion)).quiz('life_tactics')!;
    final seen = <String>{};
    var edges = 0;
    var changed = 0;
    for (var happiness = 6; happiness <= 30; happiness++) {
      for (var meaning = 6; meaning <= 30; meaning++) {
        for (var richness = 6; richness <= 30; richness++) {
          final current = _raw(quiz, happiness, meaning, richness);
          seen.add(current);
          for (final axis in const ['happiness', 'meaning', 'richness']) {
            final value = axis == 'happiness'
                ? happiness
                : axis == 'meaning'
                ? meaning
                : richness;
            if (value == 30) {
              continue;
            }
            edges += 1;
            final moved = _raw(
              quiz,
              axis == 'happiness' ? value + 1 : happiness,
              axis == 'meaning' ? value + 1 : meaning,
              axis == 'richness' ? value + 1 : richness,
            );
            if (moved != current) {
              changed += 1;
            }
          }
        }
      }
    }
    expect(edges, 45000);
    expect(changed, 4824);
    expect(seen, {'tr01', 'tr02', 'tr03', 'tr04', 'tr05', 'tr06', 'tr07', 'tr08', 'tr09', 'tr10'});
  });

  testWidgets('pilot answer stays selected across languages and back navigation', (tester) async {
    tester.view.physicalSize = const Size(400, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiPreviewApp(
        bundle: _pilotBundle(),
        store: MemoryLocaleStore()..value = 'en',
        deviceTags: const ['ko'],
        loader: AppFontLoader(loadBytes: (_) async => ByteData(0), register: (_, _) async {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(find.byKey(const Key('pilot-start')), 400);

    await tester.tap(find.byKey(const Key('pilot-start')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('pilot-question'))).data, 'English prompt');
    await tester.tap(find.byKey(const Key('pilot-choice-0')));
    await tester.pump();
    expect(
      tester.widget<AppChoiceOption>(find.byKey(const Key('pilot-choice-0'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('lang-ja')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('pilot-question'))).data, '日本語の設問');
    expect(find.text('English prompt'), findsNothing);
    expect(
      tester.widget<AppChoiceOption>(find.byKey(const Key('pilot-choice-0'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('pilot-next')));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pilot-back')));
    await tester.pump();
    expect(
      tester.widget<AppChoiceOption>(find.byKey(const Key('pilot-choice-0'))).selected,
      isTrue,
    );
    expect(tester.widget<Text>(find.byKey(const Key('preview-position'))).data, '1 / 2');
  });
}

String _raw(QuizContent quiz, int happiness, int meaning, int richness) {
  String score(int raw) => '${100 * (raw - 6)}/24';

  return judgeScores(quiz, {
    'happiness': score(happiness),
    'meaning': score(meaning),
    'richness': score(richness),
  }, allowPending: true).resultTypeId;
}

QuizContent _mini(QuizRule rule) {
  QuestionContent question(String id, String axis, int weight, bool reverse, int order) {
    return QuestionContent(
      questionId: id,
      promptTextKey: id,
      scaleId: 'agreement5',
      dimensionId: axis,
      weight: weight,
      reverse: reverse,
      reviewStatus: 'draft',
      sortOrder: order,
      isActive: true,
    );
  }

  return QuizContent(
    schemaVersion: 2,
    dataVersion: '9.9.9',
    quizId: 'mini',
    scoreMode: 'independent_sum',
    completionPolicy: 'all_required',
    resultRuleStatus: 'pending',
    resultTemplateId: 'football_formation',
    titleTextKey: 'title',
    introTextKey: 'intro',
    questionCount: 4,
    isActive: false,
    sortOrder: 1,
    dimensions: const [],
    questions: [
      question('h1', 'happiness', 1, false, 1),
      question('h2', 'happiness', 3, true, 2),
      question('m1', 'meaning', 1, false, 3),
      question('r1', 'richness', 1, false, 4),
    ],
    options: [
      for (var score = 1; score <= 5; score++)
        OptionContent(
          optionId: 'a$score',
          scaleId: 'agreement5',
          labelTextKey: 'label',
          scoreValue: score,
          sortOrder: score,
          isActive: true,
        ),
    ],
    resultTypes: const [],
    rule: rule,
  );
}

ContentBundle _pilotBundle() {
  LocaleCatalog locale(String code, String prompt) {
    return LocaleCatalog(
      locale: code,
      strings: {
        'life_tactics.title': prompt,
        'life_tactics.intro': prompt,
        'life_tactics.question.one': prompt,
        'life_tactics.question.two': 'Second',
        'life_tactics.answer.a1': 'A',
        'life_tactics.answer.a2': 'B',
        'common.ui.quiz.start': 'Start',
        'common.ui.quiz.next': 'Next',
        'common.ui.quiz.back': 'Back',
        'common.ui.quiz.progress': '{current} / {total}',
        'life_tactics.result.tr10.name': prompt,
        'common.saida.start': prompt,
      },
      statuses: const {},
      origins: const {},
    );
  }

  QuestionContent question(String id, String key, int order) {
    return QuestionContent(
      questionId: id,
      promptTextKey: key,
      scaleId: 'agreement5',
      dimensionId: 'happiness',
      weight: 1,
      reverse: false,
      reviewStatus: 'draft',
      sortOrder: order,
      isActive: true,
    );
  }

  return ContentBundle(
    schemaVersion: 2,
    dataVersion: '0.3.0',
    channel: 'preview',
    locales: {
      'ko': locale('ko', '한국어 문항'),
      'en': locale('en', 'English prompt'),
      'ja': locale('ja', '日本語の設問'),
      'pt-BR': locale('pt-BR', 'Pergunta'),
    },
    quizzes: [
      QuizContent(
        schemaVersion: 2,
        dataVersion: '0.3.0',
        quizId: 'life_tactics',
        scoreMode: 'independent_sum',
        completionPolicy: 'all_required',
        resultRuleStatus: 'pending',
        resultTemplateId: 'football_formation',
        titleTextKey: 'life_tactics.title',
        introTextKey: 'life_tactics.intro',
        questionCount: 2,
        isActive: false,
        sortOrder: 1,
        dimensions: const [],
        questions: [
          question('q1', 'life_tactics.question.one', 1),
          question('q2', 'life_tactics.question.two', 2),
        ],
        options: const [
          OptionContent(
            optionId: 'a1',
            scaleId: 'agreement5',
            labelTextKey: 'life_tactics.answer.a1',
            scoreValue: 1,
            sortOrder: 1,
            isActive: true,
          ),
          OptionContent(
            optionId: 'a2',
            scaleId: 'agreement5',
            labelTextKey: 'life_tactics.answer.a2',
            scoreValue: 2,
            sortOrder: 2,
            isActive: true,
          ),
        ],
        resultTypes: const [
          ResultTypeContent(
            resultTypeId: 'tr10',
            nameTextKey: 'life_tactics.result.tr10.name',
            formation: '4-4-2',
            shareTextKey: 'life_tactics.result.tr10.share',
            descriptionKey: 'life_tactics.result.tr10.description',
            catchphraseKey: 'life_tactics.result.tr10.catchphrase',
            designStatus: 'candidate',
            resultTemplateId: 'football_formation',
            sortOrder: 10,
            isActive: false,
          ),
        ],
        rule: const QuizRule(
          ruleVersion: 'life_rank_v1_preview',
          strategy: 'range_gap_rank',
          balanceMaxRange: '12',
          dominanceMinGap: '20',
          tiePriority: ['happiness', 'meaning', 'richness'],
          mappings: [],
        ),
      ),
    ],
  );
}
