import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/features/catalog/content_codec.dart';
import 'package:look_at_you/features/catalog/content_models.dart';
import 'package:look_at_you/features/catalog/content_repository.dart';
import 'package:look_at_you/features/catalog/content_text.dart';
import 'package:look_at_you/shared/widgets/app_choice_option.dart';
import 'package:look_at_you/ui_preview.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects malformed JSON and an unsupported schema version', () {
    expect(
      () => ContentCodec.parse(
        catalogJson: '{',
        quizJsonById: const {},
        localeJsonByCode: const {},
      ),
      throwsA(isA<ContentLoadException>()),
    );
    expect(
      () => ContentCodec.parse(
        catalogJson: jsonEncode({
          'schemaVersion': 99,
          'dataVersion': '0.2.0',
          'channel': 'preview',
          'quizzes': <Object>[],
        }),
        quizJsonById: const {},
        localeJsonByCode: const {},
      ),
      throwsA(isA<ContentVersionException>()),
    );
  });

  test('resolves keys, placeholders, and Korean fallback', () {
    final book = AppTextBook({
      'ko': LocaleCatalog(
        locale: 'ko',
        strings: {'common.ui.quiz.progress': '{current} / {total}문항'},
        statuses: {'common.ui.quiz.progress': 'draft'},
        origins: const {},
      ),
      'en': LocaleCatalog(
        locale: 'en',
        strings: {'common.ui.quiz.progress': '{current} / {total} questions'},
        statuses: {'common.ui.quiz.progress': 'draft'},
        origins: {'common.ui.quiz.progress': 'machine'},
      ),
    });

    final english = book.resolve(
      'en',
      'common.ui.quiz.progress',
      values: {'current': 1, 'total': 18, 'extra': null},
    );
    expect(english.text, '1 / 18 questions');
    expect(english.status, 'draft');
    expect(english.origin, 'machine');
    expect(english.usedFallback, isFalse);

    final missing = book.resolve('ja', 'common.ui.quiz.progress');
    expect(missing.text, '{current} / {total}문항');
    expect(missing.status, 'missing');
    expect(missing.usedFallback, isTrue);

    final absent = book.resolve('ko', 'common.ui.missing');
    expect(absent.status, 'absent');
    expect(absent.text, '{common.ui.missing}');
  });

  test('parses each bundle once and can retry after a failure', () async {
    var failed = true;
    var reads = 0;
    final repository = ContentRepository(
      loadString: (asset) async {
        reads += 1;
        if (failed) {
          throw Exception('offline');
        }
        return _asset(asset);
      },
    );

    await expectLater(
      repository.load(),
      throwsA(isA<ContentLoadException>()),
    );
    failed = false;
    final first = await repository.load();
    final readsAfterSuccess = reads;
    final second = await repository.load();
    expect(identical(first, second), isTrue);
    expect(reads, readsAfterSuccess);
    expect(first.quiz('life_tactics')?.questionCount, 0);
  });

  test('loads the generated preview and empty release catalog', () async {
    final preview = await ContentRepository().load();
    final book = AppTextBook(preview.locales);
    final quiz = preview.quiz('life_tactics');

    expect(preview.channel, 'preview');
    expect(preview.schemaVersion, 1);
    expect(quiz?.questions, hasLength(18));
    expect(quiz?.optionsFor('agreement5'), hasLength(5));
    expect(book.resolve('ko', 'life_tactics.title').text, '나의 인생 전술');
    expect(book.resolve('en', 'life_tactics.title').text, 'My Life Tactics');
    expect(book.resolve('ja', 'life_tactics.question.tq01').origin, 'machine');
    expect(
      book.resolve(
        'pt-BR',
        'common.ui.quiz.progress',
        values: {'current': 1, 'total': 18},
      ).text,
      '1 / 18 perguntas',
    );
    expect(book.resolve('vi', 'life_tactics.title').usedFallback, isTrue);

    final release = await ContentRepository().load(channel: 'release');
    expect(release.quizzes, isEmpty);
    expect(release.locales['ko']?.strings, isEmpty);
  });

  testWidgets('saved language is ready before catalog text and selection stays', (
    tester,
  ) async {
    final bundle = _sampleBundle();
    tester.view.physicalSize = const Size(400, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.text('나의 인생 전술'), findsNothing);
    expect(find.text('My Life Tactics'), findsNothing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.widget<Text>(find.byKey(const Key('catalog-title'))).data,
      'My Life Tactics',
    );
    expect(find.text('나의 인생 전술'), findsNothing);
    expect(find.textContaining('Unreviewed draft'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-choice-0')));
    await tester.pump();
    expect(
      tester.widget<AppChoiceOption>(find.byKey(const Key('catalog-choice-0'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('lang-ja')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('catalog-title'))).data,
      'My Life Tactics',
    );
    expect(find.text('わたしの人生戦術'), findsNothing);
    expect(
      tester.widget<AppChoiceOption>(find.byKey(const Key('catalog-choice-0'))).selected,
      isTrue,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-position'))).data,
      '1 / 2',
    );
    expect(tester.takeException(), isNull);
  });
}

ContentBundle _sampleBundle() {
  LocaleCatalog locale(String code, String title, String answer) {
    return LocaleCatalog(
      locale: code,
      strings: {
        'life_tactics.title': title,
        'life_tactics.intro': title,
        'life_tactics.question.tq01': title,
        'life_tactics.answer.a1': answer,
        'life_tactics.result.tr10.name': title,
        'common.saida.start': title,
        'common.ui.quiz.next': 'Next',
        'common.ui.quiz.progress': '{current} / {total}',
      },
      statuses: {
        for (final key in [
          'life_tactics.title',
          'life_tactics.intro',
          'life_tactics.question.tq01',
          'life_tactics.answer.a1',
          'life_tactics.result.tr10.name',
          'common.saida.start',
          'common.ui.quiz.next',
          'common.ui.quiz.progress',
        ])
          key: 'draft',
      },
      origins: {'life_tactics.title': 'machine'},
    );
  }

  return ContentBundle(
    schemaVersion: 1,
    dataVersion: '0.2.0',
    channel: 'preview',
    locales: {
      'ko': locale('ko', '나의 인생 전술', '전혀 그렇지 않다'),
      'en': locale('en', 'My Life Tactics', 'Not at all'),
      'ja': locale('ja', 'わたしの人生戦術', 'まったくそうではない'),
      'pt-BR': locale('pt-BR', 'Minhas táticas de vida', 'Nem um pouco'),
    },
    quizzes: [
      QuizContent(
        schemaVersion: 1,
        dataVersion: '0.2.0',
        quizId: 'life_tactics',
        scoreMode: 'independent_sum',
        completionPolicy: 'all_required',
        resultRuleStatus: 'pending',
        resultTemplateId: 'football_formation',
        titleTextKey: 'life_tactics.title',
        introTextKey: 'life_tactics.intro',
        questionCount: 18,
        isActive: false,
        sortOrder: 1,
        dimensions: const [],
        questions: const [
          QuestionContent(
            questionId: 'tq01',
            promptTextKey: 'life_tactics.question.tq01',
            scaleId: 'agreement5',
            dimensionId: 'happiness',
            weight: 1,
            reverse: false,
            reviewStatus: 'draft',
            sortOrder: 1,
            isActive: true,
          ),
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
      ),
    ],
  );
}

String _asset(String asset) {
  if (asset.contains('/pilots/')) {
    throw FlutterError('Unable to load asset: $asset');
  }
  if (asset.endsWith('/catalog.json')) {
    return jsonEncode({
      'schemaVersion': 1,
      'dataVersion': '0.2.0',
      'channel': 'preview',
      'quizzes': [
        {
          'quizId': 'life_tactics',
          'titleTextKey': 'life_tactics.title',
          'introTextKey': 'life_tactics.intro',
          'questionCount': 0,
          'resultTemplateId': 'football_formation',
          'sortOrder': 1,
          'isActive': false,
          'scoreMode': 'independent_sum',
          'completionPolicy': 'all_required',
          'resultRuleStatus': 'pending',
        },
      ],
    });
  }
  if (asset.endsWith('/life_tactics.json')) {
    return jsonEncode({
      'schemaVersion': 1,
      'dataVersion': '0.2.0',
      'quizId': 'life_tactics',
      'scoreMode': 'independent_sum',
      'completionPolicy': 'all_required',
      'resultRuleStatus': 'pending',
      'resultTemplateId': 'football_formation',
      'titleTextKey': 'life_tactics.title',
      'introTextKey': 'life_tactics.intro',
      'questionCount': 0,
      'isActive': false,
      'sortOrder': 1,
      'dimensions': <Object>[],
      'questions': <Object>[],
      'options': <Object>[],
      'resultTypes': <Object>[],
    });
  }
  final code = asset.split('/').last.replaceAll('.json', '');
  return jsonEncode({
    'schemaVersion': 1,
    'dataVersion': '0.2.0',
    'locale': code,
    'strings': {'life_tactics.title': code},
    'statuses': {'life_tactics.title': 'draft'},
  });
}
