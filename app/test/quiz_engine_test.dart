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
    final preview = await ContentRepository().load(version: pilotDataVersion);
    final quiz = preview.quiz('life_tactics')!;
    expect(preview.schemaVersion, 2);
    expect(quiz.questions, hasLength(18));
    expect(quiz.rule?.ruleVersion, 'life_rank_v1_preview');
    expect(quiz.questions.map((item) => item.questionId).toList(), [
      for (var number = 1; number <= 18; number++) 'lt_vp${number.toString().padLeft(2, '0')}',
    ]);

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
        final outcome = scoreIntegerValues(quiz, answers, allowPending: true);
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
