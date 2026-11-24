import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_bootstrap.dart';
import 'package:look_at_you/core/locale/app_locale_controller.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/core/theme/app_theme.dart';
import 'package:look_at_you/features/catalog/content_models.dart';
import 'package:look_at_you/features/catalog/content_repository.dart';
import 'package:look_at_you/features/life_tactics/life_tactics_art.dart';
import 'package:look_at_you/features/life_tactics/pilot_checkpoint.dart';
import 'package:look_at_you/features/life_tactics/pilot_feedback.dart';
import 'package:look_at_you/features/life_tactics/pilot_home_order.dart';
import 'package:look_at_you/features/life_tactics/pilot_host.dart';
import 'package:look_at_you/features/quiz/quiz_engine.dart';
import 'package:look_at_you/features/life_tactics/pilot_pages.dart';
import 'package:look_at_you/features/life_tactics/pilot_share_capture.dart';
import 'package:look_at_you/features/life_tactics/pilot_session_store_memory.dart';
import 'package:look_at_you/main.dart';
import 'package:look_at_you/shared/widgets/app_button.dart';
import 'package:look_at_you/shared/widgets/app_choice_option.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ten result images and formation rows follow the approved mapping', () {
    expect(
      LifeTacticsArt.saidaAsset('tr06'),
      'assets/images/saida/saida_life_tactics_tr06_v003.webp',
    );
    expect(
      LifeTacticsArt.saidaAsset('tr10'),
      'assets/images/saida/saida_life_tactics_tr10_v003.webp',
    );
    for (final id in [
      'tr01',
      'tr02',
      'tr03',
      'tr04',
      'tr05',
      'tr07',
      'tr08',
      'tr09',
    ]) {
      expect(
        LifeTacticsArt.saidaAsset(id),
        'assets/images/saida/saida_life_tactics_${id}_v002.webp',
      );
    }
    expect(LifeTacticsArt.saidaAsset('tr99'), isEmpty);
    expect(
      LifeTacticsArt.baseSmile,
      'assets/images/saida/saida_base_smile_v001.webp',
    );
    expect(LifeTacticsArt.wink, 'assets/images/saida/saida_wink_v001.png');
    expect(LifeTacticsArt.markerRows('4-2-4'), [4, 2, 4]);
    expect(LifeTacticsArt.markerRows('4-3-3'), [3, 3, 4]);
    expect(LifeTacticsArt.markerRows('6-3-1'), [1, 3, 6]);
    expect(LifeTacticsArt.markerRows('4-4-2'), [2, 4, 4]);
    expect(LifeTacticsArt.markerRows('nope'), isEmpty);
    expect(LifeTacticsArt.markerWidthFactor, 0.135);
    expect(
      LifeTacticsArt.tacticsBoard,
      'assets/images/life_tactics/tactics_board_v002.webp',
    );
  });

  test('ten current formations place ten markers from attack to defense', () async {
    final bundle = await ContentRepository().load(
      version: pilotDataVersion,
      channel: 'preview',
    );
    final types = bundle.quiz('life_tactics')!.resultTypes;
    expect(types.map((item) => item.resultTypeId), [
      'tr01',
      'tr02',
      'tr03',
      'tr04',
      'tr05',
      'tr06',
      'tr07',
      'tr08',
      'tr09',
      'tr10',
    ]);
    for (final type in types) {
      final parts = type.formation.split('-').map(int.parse).toList();
      expect(parts, hasLength(3), reason: type.resultTypeId);
      expect(parts.fold<int>(0, (sum, count) => sum + count), 10);
      expect(LifeTacticsArt.markerRows(type.formation), [
        parts[2],
        parts[1],
        parts[0],
      ]);
      final version = LifeTacticsArt.v003Results.contains(type.resultTypeId)
          ? 'v003'
          : 'v002';
      expect(
        LifeTacticsArt.saidaAsset(type.resultTypeId),
        'assets/images/saida/saida_life_tactics_${type.resultTypeId}_$version.webp',
      );
    }
    expect(
      types.singleWhere((item) => item.resultTypeId == 'tr01').formation,
      '4-2-4',
    );
    expect(
      types.singleWhere((item) => item.resultTypeId == 'tr07').formation,
      '6-3-1',
    );
    expect(LifeTacticsArt.lineCounts('5-4-1'), [5, 4, 1]);
    expect(LifeTacticsArt.lineCounts('6-3-1'), [6, 3, 1]);
    expect(LifeTacticsArt.lineCounts('4-4-2'), [4, 4, 2]);
    expect(LifeTacticsArt.lineCounts('3-5-2'), [3, 5, 2]);
    expect(LifeTacticsArt.lineCounts('nope'), isNull);
    for (final type in types) {
      final rows = LifeTacticsArt.markerRows(type.formation);
      final counts = LifeTacticsArt.lineCounts(type.formation)!;
      expect(rows.fold<int>(0, (sum, value) => sum + value), 10);
      expect(counts.fold<int>(0, (sum, value) => sum + value), 10);
      expect(rows, [counts[2], counts[1], counts[0]]);
    }
    expect(LifeTacticsArt.shareSaidaBox.left, closeTo(60 / 1080, 1e-9));
    expect(LifeTacticsArt.shareSaidaBox.top, closeTo(215 / 1080, 1e-9));
    expect(LifeTacticsArt.shareSaidaBox.size, closeTo(440 / 1080, 1e-9));
    expect(LifeTacticsArt.shareBoardLeft, closeTo(680 / 1080, 1e-9));
    final blurBottom =
        LifeTacticsArt.shareBlurTop + LifeTacticsArt.shareBlurHeight;
    final boardBottom =
        LifeTacticsArt.shareBoardTop + LifeTacticsArt.shareBoardHeight;
    const frameInnerLeft = 34 / 1080;
    const frameInnerRight = 1046 / 1080;
    final blurRight =
        LifeTacticsArt.shareBlurLeft + LifeTacticsArt.shareBlurWidth;
    expect(
      LifeTacticsArt.shareBlurLeft - frameInnerLeft,
      closeTo(frameInnerRight - blurRight, 1 / 1080),
    );
    expect(LifeTacticsArt.shareBlurTop, lessThan(LifeTacticsArt.shareBoardTop));
    expect(
      LifeTacticsArt.shareBlurLeft,
      lessThan(LifeTacticsArt.shareSaidaBox.left),
    );
    expect(
      (LifeTacticsArt.shareBlurLeft + LifeTacticsArt.shareBlurWidth) -
          (LifeTacticsArt.shareBoardLeft + LifeTacticsArt.shareBoardWidth),
      greaterThanOrEqualTo(-1e-9),
    );
    expect(blurBottom, greaterThan(boardBottom));
    expect(blurBottom - boardBottom, lessThan(40 / 1080));
    expect(LifeTacticsArt.shareBoardTop, closeTo(220 / 1080, 1e-9));
    expect(LifeTacticsArt.shareBoardWidth, closeTo(344 / 1080, 1e-9));
    expect(LifeTacticsArt.shareBoardHeight, closeTo(430 / 1080, 1e-9));
  });

  test(
    'home order follows sort order and lifts only a known quiz id',
    () async {
      final bundle = await ContentRepository().load(
        version: pilotDataVersion,
        channel: 'preview',
      );
      final before = bundle.quizzes.map((item) => item.quizId).toList();
      expect(bundle.quiz('life_tactics')!.isActive, isFalse);
      expect(bundle.quiz('wealth_four')!.isActive, isFalse);
      expect(
        orderedHomeQuizzes(bundle.quizzes, null).map((item) => item.quizId),
        ['life_tactics', 'wealth_four'],
      );
      expect(
        orderedHomeQuizzes(bundle.quizzes, '').map((item) => item.quizId),
        ['life_tactics', 'wealth_four'],
      );
      expect(
        orderedHomeQuizzes(
          bundle.quizzes,
          'missing',
        ).map((item) => item.quizId),
        ['life_tactics', 'wealth_four'],
      );
      expect(
        orderedHomeQuizzes(
          bundle.quizzes,
          'wealth_four',
        ).map((item) => item.quizId),
        ['wealth_four', 'life_tactics'],
      );
      expect(
        orderedHomeQuizzes(
          bundle.quizzes,
          'wealth_four',
        ).map((item) => item.sortOrder),
        [2, 1],
      );
      expect(bundle.quizzes.map((item) => item.quizId).toList(), before);
    },
  );

  test('retry drops both answer maps and the cached result', () async {
    final bundle = await ContentRepository().load(
      version: pilotDataVersion,
      channel: 'preview',
    );
    final host = PilotHost()..bind(bundle);
    expect(host.quiz!.isActive, isFalse);
    expect(host.ensureQuestions(), isTrue);
    for (var index = 0; index < host.questionItems.length; index++) {
      final options = host.quiz!.optionsFor(host.questionItems[index].scaleId);
      host.selectQuestion(index, options[3].optionId);
      if (index + 1 < host.questionItems.length) {
        host.focusQuestion(index + 1, notify: false);
      }
    }
    host.ensureScenes();
    for (var index = 0; index < host.sceneItems.length; index++) {
      final options = [...host.sceneItems[index].options]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      host.selectScene(index, options.first.optionId);
      if (index + 1 < host.sceneItems.length) {
        host.focusScene(index + 1, notify: false);
      }
    }
    host.finish();
    expect(host.outcome!.resultTypeId, 'tr10');
    expect(host.outcome!.displayScores['happiness'], '66.7');
    expect(host.tally!.counts['happiness'], 6);
    final keptQuestions = host.questions!.answers.length;
    final keptScenes = host.scenes!.answers.length;
    expect(keptQuestions, 18);
    expect(keptScenes, 6);

    host.reset();
    expect(host.questions, isNull);
    expect(host.scenes, isNull);
    expect(host.outcome, isNull);
    expect(host.tally, isNull);
    expect(host.ensureQuestions(), isTrue);
    expect(host.questions!.answers, isEmpty);
  });

  testWidgets(
    'phone and desktop widths keep the question on screen when text grows',
    (tester) async {
      final bundle = await _load(tester);
      await _pump(tester, bundle, const Size(360, 640), textScale: 2);
      await _tap(tester, const Key('pilot-start'));
      tester.view.physicalSize = const Size(360, 560);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        expect(
          find.byKey(Key('pilot-choice-$i')).hitTestable(),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const Key('pilot-choice-4')));
      await tester.pump();
      expect(find.byKey(const Key('pilot-next')).hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('pilot-prompt')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pump();
      expect(find.byKey(const Key('pilot-next')).hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('pilot-prompt')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pilot keeps answers through back, language, scene return, share, and retry',
    (tester) async {
      final previousCapture = pilotCaptureCard;
      addTearDown(() => pilotCaptureCard = previousCapture);
      pilotCaptureCard = (context, {required card, required assets}) async {
        return Uint8List(8);
      };
      final bundle = await _load(tester);
      await _pump(tester, bundle, const Size(420, 2400));

      expect(find.text('카카오톡으로 공유'), findsNothing);
      await _tap(tester, const Key('home-life-tactics'));
      expect(find.text('기본 18문항 + 장면 선택 6개'), findsOneWidget);
      await _tap(tester, const Key('pilot-start'));

      expect(_button(tester, const Key('pilot-next')).onPressed, isNull);
      await _tap(tester, const Key('pilot-choice-3'));
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
      expect(_button(tester, const Key('pilot-next')).onPressed, isNotNull);
      await _tap(tester, const Key('pilot-next'));
      expect(find.text('2 / 18문항'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('1 / 18문항'), findsOneWidget);
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);

      await _chooseLanguage(tester, 'en');
      expect(find.text('1 / 18 questions'), findsOneWidget);
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
      await _chooseLanguage(tester, 'ko');
      expect(find.text('1 / 18문항'), findsOneWidget);

      await _tap(tester, const Key('pilot-next'));
      for (var step = 0; step < 17; step++) {
        await _tap(tester, const Key('pilot-choice-3'));
        await _tap(tester, const Key('pilot-next'));
      }
      expect(find.text('상황 선택 1 / 6'), findsOneWidget);
      expect(_button(tester, const Key('pilot-scene-next')).onPressed, isNull);

      await _tap(tester, const Key('pilot-scene-choice-1'));
      await _tap(tester, const Key('pilot-scene-back'));
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
      await _tap(tester, const Key('pilot-choice-0'));
      await _tap(tester, const Key('pilot-next'));
      expect(
        _choice(tester, const Key('pilot-scene-choice-1')).selected,
        isTrue,
      );

      await _tap(tester, const Key('pilot-scene-back'));
      await _tap(tester, const Key('pilot-choice-3'));
      await _tap(tester, const Key('pilot-next'));
      expect(
        _choice(tester, const Key('pilot-scene-choice-1')).selected,
        isTrue,
      );

      await _chooseLanguage(tester, 'en');
      expect(
        _choice(tester, const Key('pilot-scene-choice-1')).selected,
        isTrue,
      );
      expect(find.textContaining('1 / 6'), findsWidgets);
      await _chooseLanguage(tester, 'ko');

      for (var scene = 0; scene < 6; scene++) {
        await _tap(tester, const Key('pilot-scene-choice-0'));
        await _tap(
          tester,
          Key(scene == 5 ? 'pilot-scene-finish' : 'pilot-scene-next'),
        );
      }

      expect(find.text('인생의 올라운더'), findsOneWidget);
      expect(find.text('4-4-2 포메이션'), findsOneWidget);
      expect(find.textContaining('66.7'), findsNWidgets(3));
      expect(find.byKey(const Key('pilot-separate')), findsOneWidget);
      expect(find.byKey(const Key('pilot-scene-summary')), findsOneWidget);
      expect(
        find.byKey(
          const Key(
            'pilot-saida-asset:assets/images/saida/saida_life_tactics_tr10_v003.webp',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pilot-marker-rows-2-4-4')), findsOneWidget);
      expect(find.text('카카오톡으로 공유'), findsNothing);
      expect(find.text('이미지 저장'), findsNothing);
      expect(find.text('결과 링크 복사'), findsNothing);

      await _tap(tester, const Key('pilot-share'));
      expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);
      expect(find.byKey(const Key('pilot-share-action')), findsOneWidget);
      expect(find.byKey(const Key('pilot-share-save')), findsOneWidget);
      expect(find.text('결과 링크 복사'), findsNothing);
      expect(find.text('카카오톡으로 공유'), findsNothing);
      expect(find.text('Look At You'), findsWidgets);
      expect(find.byKey(const Key('pilot-share-name')), findsOneWidget);
      expect(find.text('D.CStudio'), findsOneWidget);
      expect(
        find.byKey(
          const Key(
            'pilot-share-saida:assets/images/saida/saida_life_tactics_tr10_v003.webp',
          ),
        ),
        findsOneWidget,
      );
      await _tap(tester, const Key('pilot-share-close'));
      expect(find.byKey(const Key('pilot-result')), findsOneWidget);
      expect(find.byKey(const Key('pilot-share-card')), findsNothing);

      await _tap(tester, const Key('pilot-retry'));
      expect(find.byKey(const Key('pilot-length')), findsOneWidget);
      await _tap(tester, const Key('pilot-start'));
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isFalse);
      expect(find.text('1 / 18문항'), findsOneWidget);
    },
  );

  test('share card boxes match the approved v002 stadium layout', () {
    final saida = LifeTacticsArt.shareSaidaBox;
    expect(saida.left, closeTo(60 / 1080, 1e-9));
    expect(saida.top, closeTo(215 / 1080, 1e-9));
    expect(saida.size, closeTo(440 / 1080, 1e-9));
    expect(
      LifeTacticsArt.shareLabelLeft,
      greaterThan(saida.left + saida.size * 0.93),
    );
    expect(
      LifeTacticsArt.shareBoardLeft,
      greaterThan(
        LifeTacticsArt.shareLabelLeft + LifeTacticsArt.shareLabelWidth,
      ),
    );
    expect(LifeTacticsArt.markerWidthFactor, closeTo(0.09 * 1.5, 1e-12));
  });

  test(
    'a scene record keeps earlier answers and a bad record is dropped',
    () async {
      final bundle = await ContentRepository().load(
        version: pilotDataVersion,
        channel: 'preview',
      );
      final saved = _checkpoint(bundle, stage: PilotStage.scene, sceneIndex: 2);
      final host = PilotHost()..bind(bundle);
      expect(host.restore(saved), isTrue);
      expect(host.stage, PilotStage.scene);
      expect(host.sceneIndex, 2);
      expect(host.questions!.missingIds, isEmpty);
      expect(host.scenes!.answers, hasLength(3));
      expect(host.questionSelection(0), isNotNull);

      final broken = PilotHost()..bind(bundle);
      expect(broken.restore('{'), isFalse);
      expect(broken.stage, PilotStage.home);
      expect(broken.questions, isNull);

      final mismatch = saved.replaceFirst(
        '"dataVersion":"0.9.0"',
        '"dataVersion":"0.8.0"',
      );
      final other = PilotHost()..bind(bundle);
      expect(other.restore(mismatch), isFalse);
      expect(other.stage, PilotStage.home);
    },
  );

  testWidgets(
    'refresh restores the choice before next and the previous question',
    (tester) async {
      final bundle = await _load(tester);
      final store = MemoryPilotSessionStore();
      await _pump(tester, bundle, const Size(400, 900), session: store);
      await _tap(tester, const Key('home-life-tactics'));
      await _tap(tester, const Key('pilot-start'));
      await _tap(tester, const Key('pilot-choice-3'));
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
      expect(store.value, contains('"stage":"question"'));

      await _reload(tester, bundle, store, const Size(400, 900));
      expect(find.text('1 / 18문항'), findsOneWidget);
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);

      await _tap(tester, const Key('pilot-next'));
      await _tap(tester, const Key('pilot-choice-1'));
      await _tap(tester, const Key('pilot-back'));
      await _reload(tester, bundle, store, const Size(400, 900));
      expect(find.text('1 / 18문항'), findsOneWidget);
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
      await _tap(tester, const Key('pilot-next'));
      expect(find.text('2 / 18문항'), findsOneWidget);
      expect(_choice(tester, const Key('pilot-choice-1')).selected, isTrue);
    },
  );

  testWidgets('refresh restores scene 3, the result, and home after leaving', (
    tester,
  ) async {
    final bundle = await _load(tester);
    final scene = MemoryPilotSessionStore()
      ..value = _checkpoint(bundle, stage: PilotStage.scene, sceneIndex: 2);
    await _pump(tester, bundle, const Size(360, 800), session: scene);
    expect(find.text('상황 선택 3 / 6'), findsOneWidget);
    expect(_choice(tester, const Key('pilot-scene-choice-0')).selected, isTrue);
    await _tap(tester, const Key('pilot-scene-back'));
    expect(find.text('상황 선택 2 / 6'), findsOneWidget);
    expect(_choice(tester, const Key('pilot-scene-choice-0')).selected, isTrue);

    final result = MemoryPilotSessionStore()
      ..value = _checkpoint(bundle, stage: PilotStage.result, sceneIndex: 5);
    await _reload(tester, bundle, result, const Size(360, 800));
    expect(find.byKey(const Key('pilot-result')), findsOneWidget);
    expect(find.text('4-4-2 포메이션'), findsWidgets);
    expect(
      find.byKey(
        const Key(
          'pilot-saida-asset:assets/images/saida/saida_life_tactics_tr10_v003.webp',
        ),
      ),
      findsOneWidget,
    );
    _expectResultRow(tester);
    expect(find.textContaining('66.7'), findsWidgets);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pump();
    _expectResultRow(tester);

    await _tap(tester, const Key('pilot-retry'));
    expect(find.byKey(const Key('pilot-length')), findsOneWidget);
    expect(result.value, contains('"stage":"home"'));
    expect(result.value, contains('"questions":{}'));
    await _reload(tester, bundle, result, const Size(360, 800));
    expect(find.byKey(const Key('pilot-length')), findsOneWidget);
    await _tap(tester, const Key('pilot-start'));
    expect(_choice(tester, const Key('pilot-choice-3')).selected, isFalse);

    final home = MemoryPilotSessionStore()
      ..value = _checkpoint(bundle, stage: PilotStage.result, sceneIndex: 5);
    await _reload(tester, bundle, home, const Size(1280, 900));
    await _tap(tester, const Key('pilot-home'));
    expect(find.byKey(const Key('home-life-tactics')), findsOneWidget);
    expect(home.value, contains('"stage":"home"'));
    await _reload(tester, bundle, home, const Size(1280, 900));
    expect(find.byKey(const Key('home-life-tactics')), findsOneWidget);
    expect(find.byKey(const Key('pilot-result')), findsNothing);

    final corrupt = MemoryPilotSessionStore()..value = '{';
    await _reload(tester, bundle, corrupt, const Size(400, 900));
    expect(find.byKey(const Key('home-life-tactics')), findsOneWidget);
    expect(corrupt.value, isNot('{'));

    final mismatch = MemoryPilotSessionStore()
      ..value = _checkpoint(
        bundle,
        stage: PilotStage.scene,
        sceneIndex: 2,
      ).replaceFirst('"dataVersion":"0.9.0"', '"dataVersion":"0.8.0"');
    await _reload(tester, bundle, mismatch, const Size(400, 900));
    expect(find.byKey(const Key('home-life-tactics')), findsOneWidget);
    expect(mismatch.value, isNot(contains('0.8.0')));
  });

  testWidgets(
    'the home list scrolls to a coming soon card and start opens question one',
    (tester) async {
      final bundle = await _load(tester);
      await _pump(tester, bundle, const Size(360, 560));
      expect(find.text('어떤 테스트를 해 볼까요?'), findsNothing);
      expect(find.text('부의 성향'), findsOneWidget);
      expect(find.text('Coming Soon...'), findsOneWidget);
      final life = tester.getRect(find.byKey(const Key('home-life-tactics')));
      final wealth = tester.getRect(
        find.byKey(const Key('home-quiz-wealth_four')),
      );
      expect(wealth.top, greaterThan(life.bottom));
      expect(wealth.top, greaterThan(560));
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-quiz-wealth_four')),
        240,
      );
      await tester.pump();
      await _tap(tester, const Key('home-quiz-wealth_four'));
      expect(find.byKey(const Key('pilot-prompt')), findsNothing);
      expect(
        find.byKey(const Key('home-coming-soon-wealth_four')),
        findsOneWidget,
      );
      await _tap(tester, const Key('pilot-start'));
      expect(find.text('1 / 18문항'), findsOneWidget);
      expect(find.byKey(const Key('pilot-prompt')), findsOneWidget);
      await _tap(tester, const Key('pilot-back'));
      expect(find.byKey(const Key('pilot-start')), findsOneWidget);
      expect(find.byKey(const Key('pilot-prompt')), findsNothing);
    },
  );

  testWidgets(
    'a quiz link reorders cards and refresh keeps the open question',
    (tester) async {
      final previous = pilotHomeQuizId;
      addTearDown(() => pilotHomeQuizId = previous);
      pilotHomeQuizId = () => 'wealth_four';
      final bundle = await _load(tester);
      await _pump(tester, bundle, const Size(360, 900));
      final wealth = tester.getRect(
        find.byKey(const Key('home-quiz-wealth_four')),
      );
      final life = tester.getRect(find.byKey(const Key('home-life-tactics')));
      expect(wealth.top, lessThan(life.top));
      expect(find.byKey(const Key('pilot-prompt')), findsNothing);
      expect(find.text('Coming Soon...'), findsOneWidget);

      pilotHomeQuizId = () => 'not-a-quiz';
      await _reload(
        tester,
        bundle,
        MemoryPilotSessionStore(),
        const Size(360, 900),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('home-life-tactics'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('home-quiz-wealth_four'))).dy,
        ),
      );

      pilotHomeQuizId = () => 'wealth_four';
      final store = MemoryPilotSessionStore()
        ..value = _questionCheckpoint(bundle);
      await _reload(tester, bundle, store, const Size(360, 900));
      expect(find.text('1 / 18문항'), findsOneWidget);
      expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
    },
  );

  testWidgets('a blocked store still accepts the selected answer', (
    tester,
  ) async {
    final bundle = await _load(tester);
    final store = MemoryPilotSessionStore()..failWrites = true;
    await _pump(tester, bundle, const Size(400, 900), session: store);
    await _tap(tester, const Key('home-life-tactics'));
    await _tap(tester, const Key('pilot-start'));
    await _tap(tester, const Key('pilot-choice-3'));
    expect(_choice(tester, const Key('pilot-choice-3')).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'share card puts Saida left of the marked board without a number badge',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: LifeTacticsShareCard(
                  brand: 'Look At You',
                  quizTitle: '나의 인생 전술',
                  formation: '4-4-2',
                  name: '인생의 올라운더',
                  catchphrase: '오늘은 세 포지션 모두 제 자리예요!',
                  description: '이번 응답에서는 세 성향의 간격이 작았어요.',
                  studio: 'D.CStudio',

                  resultTypeId: 'tr10',
                  saidaAsset:
                      'assets/images/saida/saida_life_tactics_tr10_v003.webp',
                  retryLabel: '다시 시도',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final semantics = tester.ensureSemantics();
      try {
        expect(find.text('4-4-2'), findsNothing);
        expect(
          tester
              .getSemantics(find.byKey(const Key('pilot-share-formation')))
              .label,
          '4-4-2',
        );
        final card = tester.getRect(find.byKey(const Key('pilot-share-card')));
        expect(card.width, closeTo(360, 1));
        expect(card.height, closeTo(card.width, 1));
        final saida = tester.getRect(
          find.byKey(
            const Key(
              'pilot-share-saida:assets/images/saida/saida_life_tactics_tr10_v003.webp',
            ),
          ),
        );
        final board = tester.getRect(
          find.byKey(const Key('pilot-share-board')),
        );
        final box = LifeTacticsArt.shareSaidaBox;
        expect(saida.width, closeTo(card.width * box.size, 1));
        expect(saida.height, closeTo(card.height * box.size, 1));
        expect(saida.left, closeTo(card.left + card.width * box.left, 1));
        expect(saida.top, closeTo(card.top + card.height * box.top, 1));
        expect(
          board.left,
          closeTo(card.left + card.width * LifeTacticsArt.shareBoardLeft, 1),
        );
        expect(
          board.top,
          closeTo(card.top + card.height * LifeTacticsArt.shareBoardTop, 1),
        );
        expect(
          board.width,
          closeTo(card.width * LifeTacticsArt.shareBoardWidth, 1),
        );
        expect(
          board.height,
          closeTo(card.height * LifeTacticsArt.shareBoardHeight, 1),
        );
        expect(saida.right, lessThan(board.left));
        expect(
          find.byKey(const Key('pilot-marker-rows-2-4-4')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: LifeTacticsShareCard(
                    brand: 'Look At You',
                    quizTitle: '나의 인생 전술',
                    formation: '3-5-2',
                    name: '다른 타입',
                    catchphrase: '문장',
                    description: '설명',
                    studio: 'D.CStudio',

                    resultTypeId: 'tr03',
                    saidaAsset:
                        'assets/images/saida/saida_life_tactics_tr03_v002.webp',
                    retryLabel: '다시 시도',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final otherCard = tester.getRect(
          find.byKey(const Key('pilot-share-card')),
        );
        final other = tester.getRect(
          find.byKey(
            const Key(
              'pilot-share-saida:assets/images/saida/saida_life_tactics_tr03_v002.webp',
            ),
          ),
        );
        expect(
          other.width,
          closeTo(otherCard.width * LifeTacticsArt.shareSaidaBox.size, 1),
        );
        expect(
          other.top,
          closeTo(
            otherCard.top + otherCard.height * LifeTacticsArt.shareSaidaBox.top,
            1,
          ),
        );
        expect(find.text('3-5-2'), findsNothing);
        expect(
          tester
              .getSemantics(find.byKey(const Key('pilot-share-formation')))
              .label,
          '3-5-2',
        );
        expect(other.right, lessThan(otherCard.center.dx));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: LifeTacticsShareCard(
                    brand: 'Look At You',
                    quizTitle: '나의 인생 전술',
                    formation: '6-3-1',
                    name: '여섯 수비',
                    catchphrase: '문장',
                    description: '설명',
                    studio: 'D.CStudio',

                    resultTypeId: 'tr07',
                    saidaAsset:
                        'assets/images/saida/saida_life_tactics_tr07_v002.webp',
                    retryLabel: '다시 시도',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const Key('pilot-marker-rows-1-3-6')),
          findsOneWidget,
        );
        expect(find.text('6-3-1'), findsNothing);
        expect(tester.takeException(), isNull);
        _expectSixMarkersInside(tester, const Key('pilot-marker-rows-1-3-6'));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'formation labels stay beside every line on a narrow result and the saved card',
    (tester) async {
      final bundle = await _load(tester);
      final result = MemoryPilotSessionStore()
        ..value = _checkpoint(bundle, stage: PilotStage.result, sceneIndex: 5);
      await _pump(
        tester,
        bundle,
        const Size(320, 700),
        textScale: 1.6,
        session: result,
      );
      expect(find.text('4-4-2 포메이션'), findsOneWidget);
      expect(find.text('행복 4 · 의미 4 · 심리적 풍요로움 2'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('pilot-line-label-0'))).data,
        '심리적 풍요로움',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('pilot-line-label-2'))).data,
        '행복',
      );
      expect(
        find.text(
          '당신이 중요하게 생각하는 삶의 가치가 축구 포메이션으로 표현되었어요. 수비는 행복, 미드필더는 의미, 공격은 심리적 풍요로움을 나타내요.',
        ),
        findsNothing,
      );
      final frame = tester.getRect(
        find.byKey(const Key('pilot-formation-frame')),
      );
      expect(
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const Key('pilot-formation-frame')),
                    )
                    .decoration
                as BoxDecoration)
            .borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(
        tester.getRect(find.byKey(const Key('pilot-formation'))).top,
        greaterThan(frame.top),
      );
      _expectResultRow(tester);
      expect(tester.takeException(), isNull);

      const note =
          '당신이 중요하게 생각하는 삶의 가치가 축구 포메이션으로 표현되었어요. 수비는 행복, 미드필더는 의미, 공격은 심리적 풍요로움을 나타내요.';
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: LifeTacticsShareCard(
                  brand: 'Look At You',
                  quizTitle: '나의 인생 전술',
                  formation: '5-4-1',
                  formationTitle: '5-4-1 포메이션',
                  formationCounts: '행복 5 · 의미 4 · 심리적 풍요로움 1',
                  lineLabels: ['심리적 풍요로움', '의미', '행복'],
                  name: '다정한 지킴이',
                  catchphrase: '문장',
                  description: '설명',
                  studio: 'D.CStudio',
                  resultTypeId: 'tr08',
                  saidaAsset:
                      'assets/images/saida/saida_life_tactics_tr08_v002.webp',
                  retryLabel: '다시 시도',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('5-4-1 포메이션'), findsOneWidget);
      expect(find.text('행복 5 · 의미 4 · 심리적 풍요로움 1'), findsNothing);
      expect(find.text('심리적 풍요로움'), findsOneWidget);
      expect(find.text('의미'), findsOneWidget);
      expect(find.text('행복'), findsOneWidget);
      expect(find.text('심리적 풍요로움 1'), findsNothing);
      expect(find.text('의미 4'), findsNothing);
      expect(find.text('행복 5'), findsNothing);
      expect(find.text('너의 인생 전술은 뭘까?'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('pilot-share-line-label-0')))
            .maxLines,
        1,
      );
      expect(find.text('다정한 지킴이'), findsOneWidget);
      expect(find.text(note), findsNothing);
      final card = tester.getRect(find.byKey(const Key('pilot-share-card')));
      expect(card.width, closeTo(320, 1));
      expect(card.height, closeTo(card.width, 24));
      final saida = tester.getRect(
        find.byKey(
          const Key(
            'pilot-share-saida:assets/images/saida/saida_life_tactics_tr08_v002.webp',
          ),
        ),
      );
      final board = tester.getRect(find.byKey(const Key('pilot-share-board')));
      final centers = LifeTacticsArt.lineCenters(board.height);
      expect(saida.right, lessThanOrEqualTo(board.left));
      final formationTitle = tester.getRect(find.text('5-4-1 포메이션'));
      expect(formationTitle.bottom, lessThan(saida.top));
      expect(find.text('D.CStudio'), findsOneWidget);
      expect(board.bottom, lessThan(card.bottom));
      for (var index = 0; index < centers.length; index++) {
        final label = tester.getRect(
          find.byKey(Key('pilot-share-line-label-$index')),
        );
        expect(label.right, lessThanOrEqualTo(board.left + 1));
        expect(
          label.left,
          greaterThanOrEqualTo(saida.right - card.width * 28 / 1080),
        );
        expect(
          (label.center.dy - (board.top + centers[index])).abs(),
          lessThan(8),
        );
        expect(label.bottom, lessThanOrEqualTo(card.bottom));
      }
      expect(find.byKey(const Key('pilot-marker-rows-1-4-5')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('six markers in one row stay inside the board', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 170,
              height: 213,
              child: TacticsBoard(rows: [1, 3, 6], retryLabel: '다시 시도'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    _expectSixMarkersInside(tester, const Key('pilot-marker-rows-1-3-6'));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 170,
              height: 213,
              child: TacticsBoard(rows: [4, 2, 4], retryLabel: '다시 시도'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    _expectMarkerBands(tester, const Key('pilot-marker-rows-4-2-4'), const [
      4,
      2,
      4,
    ]);
  });

  test('feedback link keeps only the quiz, version, and result type', () {
    final allRounder = _feedbackUri('0.9.0', 'tr10');
    expect(
      allRounder.toString(),
      'https://tally.so/r/kbN9YR?quiz_id=life_tactics&data_version=0.9.0&result_type_id=tr10',
    );
    expect(allRounder.host, 'tally.so');
    expect(allRounder.path, '/r/kbN9YR');
    expect(allRounder.queryParameters.keys, [
      'quiz_id',
      'data_version',
      'result_type_id',
    ]);
    expect(allRounder.queryParameters.containsValue('66.7'), isFalse);

    final other = _feedbackUri('0.8.0', 'tr03');
    expect(other.queryParameters['quiz_id'], 'life_tactics');
    expect(other.queryParameters['data_version'], '0.8.0');
    expect(other.queryParameters['result_type_id'], 'tr03');
    expect(other.queryParameters.length, 3);
  });

  testWidgets('feedback opens beside the result and can be tried again', (
    tester,
  ) async {
    final opened = <Uri>[];
    final previous = pilotOpenExternalLink;
    addTearDown(() => pilotOpenExternalLink = previous);
    pilotOpenExternalLink = (uri) {
      opened.add(uri);
      return opened.length == 1 ? false : true;
    };
    final bundle = await _load(tester);
    final store = MemoryPilotSessionStore()
      ..value = _checkpoint(bundle, stage: PilotStage.result, sceneIndex: 5);
    await _pump(tester, bundle, const Size(360, 800), session: store);
    expect(opened, isEmpty);
    expect(find.text('결과에 의견 보내기'), findsOneWidget);
    expect(find.text('한국어 설문이 새 탭에서 열려요.'), findsOneWidget);
    expect(find.byKey(const Key('pilot-feedback')), findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(const Key('pilot-feedback')));
    await tester.pump();
    final offset = scrollable.position.pixels;
    await tester.tap(find.byKey(const Key('pilot-feedback')).hitTestable());
    await tester.pump();
    expect(opened, hasLength(1));
    expect(
      opened.single.toString(),
      'https://tally.so/r/kbN9YR?quiz_id=life_tactics&data_version=0.9.0&result_type_id=tr10',
    );
    expect(scrollable.position.pixels, offset);
    expect(find.byKey(const Key('pilot-result')), findsOneWidget);
    expect(find.text('4-4-2 포메이션'), findsWidgets);

    await tester.tap(find.byKey(const Key('pilot-feedback')).hitTestable());
    await tester.pump();
    expect(opened, hasLength(2));
    expect(find.byKey(const Key('pilot-result')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    final note = tester.getSize(find.byKey(const Key('pilot-feedback-note')));
    final button = tester.getSize(find.byKey(const Key('pilot-feedback')));
    expect(note.width, lessThanOrEqualTo(320));
    expect(button.width, lessThanOrEqualTo(320));
    expect(note.height, greaterThan(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saida closes every result the same way and stays off the share card',
    (tester) async {
      final previousCapture = pilotCaptureCard;
      addTearDown(() => pilotCaptureCard = previousCapture);
      LifeTacticsShareCard? painted;
      pilotCaptureCard = (context, {required card, required assets}) {
        painted = card as LifeTacticsShareCard;
        return Future.value(Uint8List.fromList(const [1]));
      };
      final bundle = await _load(tester);
      final host = PilotHost()..bind(bundle);
      expect(
        host.restore(
          _checkpoint(bundle, stage: PilotStage.result, sceneIndex: 5),
        ),
        isTrue,
      );
      host.releaseHold();
      final controller = AppLocaleController(
        store: MemoryLocaleStore()..value = 'ko',
        loader: AppFontLoader(
          loadBytes: (_) async => ByteData(0),
          register: (_, _) async {},
        ),
      );
      addTearDown(controller.dispose);
      await controller.select('ko');
      await _showResult(tester, host, controller);

      expect(host.outcome!.resultTypeId, 'tr10');
      final balanced = tester
          .widget<Text>(find.byKey(const Key('pilot-description')))
          .data;
      expect(balanced, contains('세 성향의 간격'));
      expect(find.text('미리보기 판정입니다. 출시 결과와 공유 이력에는 들어가지 않습니다.'), findsNothing);
      expect(find.text('공유 카드 보기'), findsOneWidget);
      expect(find.byKey(const Key('pilot-closing')), findsOneWidget);
      expect(
        tester
            .widget<PilotImage>(
              find.descendant(
                of: find.byKey(const Key('pilot-closing-portrait')),
                matching: find.byType(PilotImage),
              ),
            )
            .asset,
        LifeTacticsArt.wink,
      );
      expect(find.text('축구에 여러 전술이 있듯, 삶에도 여러 길이 있어요.'), findsOneWidget);
      expect(find.text('누구나 좋은 삶을 살 수 있어요.'), findsOneWidget);
      final line = tester.widget<Text>(
        find.byKey(const Key('pilot-closing-line')),
      );
      final emphasis = tester.widget<Text>(
        find.byKey(const Key('pilot-closing-emphasis')),
      );
      expect(line.style!.fontWeight, FontWeight.w500);
      expect(emphasis.style!.fontWeight, FontWeight.w600);
      expect(line.maxLines, isNull);
      expect(
        tester.getSize(find.byKey(const Key('pilot-closing-line'))).height,
        greaterThan(24),
      );
      final portrait = tester.getSize(
        find.byKey(const Key('pilot-closing-portrait')),
      );
      final hero = tester.getSize(
        find.byKey(
          Key('pilot-saida-asset:${LifeTacticsArt.saidaAsset('tr10')}'),
        ),
      );
      expect(portrait.width, 64);
      expect(portrait.width, lessThan(hero.width));
      final bubble = tester.widget<DecoratedBox>(
        find.byKey(const Key('pilot-closing-bubble')),
      );
      expect(
        (bubble.decoration as BoxDecoration).color,
        AppColors.surfaceVariant,
      );
      final restingHeight = tester
          .getSize(find.byKey(const Key('pilot-closing-bubble')))
          .height;
      _expectClosingAboveShare(tester);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('pilot-closing-bubble'))).height,
        greaterThan(restingHeight),
      );
      expect(
        tester.getSize(find.byKey(const Key('pilot-closing-portrait'))).width,
        lessThan(
          tester
              .getSize(
                find.byKey(
                  Key('pilot-saida-asset:${LifeTacticsArt.saidaAsset('tr10')}'),
                ),
              )
              .width,
        ),
      );
      _expectClosingAboveShare(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pump();

      _answerForClosing(host, _keeperScores);
      host.finish();
      await tester.pump();
      expect(host.outcome!.resultTypeId, isNot('tr10'));
      final other = tester
          .widget<Text>(find.byKey(const Key('pilot-description')))
          .data;
      expect(other, isNot(balanced));
      expect(find.byKey(const Key('pilot-closing')), findsOneWidget);
      expect(find.text('축구에 여러 전술이 있듯, 삶에도 여러 길이 있어요.'), findsOneWidget);
      expect(find.text('누구나 좋은 삶을 살 수 있어요.'), findsOneWidget);

      await controller.select('en');
      await tester.pump();
      expect(
        find.text('Soccer has many tactics, and life has many paths.'),
        findsOneWidget,
      );
      expect(find.text('Anyone can live a good life.'), findsOneWidget);
      expect(find.text('축구에 여러 전술이 있듯, 삶에도 여러 길이 있어요.'), findsNothing);
      expect(find.text('누구나 좋은 삶을 살 수 있어요.'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('pilot-description'))).data,
        isNot(other),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forLanguage('en'),
          home: AppLocaleScope(
            controller: controller,
            child: PilotSharePage(host: host),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('pilot-closing')), findsNothing);
      expect(
        find.text('Soccer has many tactics, and life has many paths.'),
        findsNothing,
      );
      expect(find.text('Anyone can live a good life.'), findsNothing);
      expect(find.text('축구에 여러 전술이 있듯, 삶에도 여러 길이 있어요.'), findsNothing);
      final preview = tester.widget<LifeTacticsShareCard>(
        find.byType(LifeTacticsShareCard),
      );
      expect(preview.catchphrase, isNotEmpty);
      expect(preview.description, isNotEmpty);
      expect(preview.description, isNot(contains('Anyone can live')));
      expect(preview.description, isNot(contains('누구나 좋은 삶')));
      expect(painted, isNotNull);
      expect(painted!.catchphrase, preview.catchphrase);
      expect(painted!.description, preview.description);
      expect(painted!.description, isNot(contains('Anyone can live')));
    },
  );
}

void _expectClosingAboveShare(WidgetTester tester) {
  final bubble = tester.getRect(find.byKey(const Key('pilot-closing-bubble')));
  final emphasis = tester.getRect(
    find.byKey(const Key('pilot-closing-emphasis')),
  );
  final tail = tester.getRect(find.byKey(const Key('pilot-closing-tail')));
  final portrait = tester.getRect(
    find.byKey(const Key('pilot-closing-portrait')),
  );
  expect(tail.right, closeTo(bubble.left, 1));
  expect(tail.left, greaterThan(portrait.right));
  expect(tail.center.dy, greaterThan(portrait.top));
  expect(tail.center.dy, lessThan(portrait.bottom));
  final share = tester.getRect(find.byKey(const Key('pilot-share')));
  expect(emphasis.top, greaterThanOrEqualTo(bubble.top));
  expect(emphasis.bottom, lessThanOrEqualTo(bubble.bottom + 0.1));
  expect(share.top, greaterThan(bubble.bottom));
  expect(share.top, greaterThan(emphasis.bottom));
}

const _keeperScores = [5, 1, 1, 1, 5, 5, 1, 5, 5, 1, 1, 5, 1, 1, 1, 1, 5, 1];

void _answerForClosing(PilotHost host, List<int> scores) {
  for (var index = 0; index < scores.length; index++) {
    final item = host.questionItems[index];
    final options = [...host.quiz!.optionsFor(item.scaleId)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final option = options.firstWhere(
      (item) => item.scoreValue == scores[index],
    );
    host.selectQuestion(index, option.optionId);
  }
}

Future<void> _showResult(
  WidgetTester tester,
  PilotHost host,
  AppLocaleController controller,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.forLanguage(controller.languageCode),
      home: AppLocaleScope(
        controller: controller,
        child: PilotResultPage(host: host),
      ),
    ),
  );
  await tester.pump();
}

Uri _feedbackUri(String dataVersion, String resultTypeId) {
  return PilotFeedback.uriFor(
    QuizOutcome(
      quizId: 'life_tactics',
      dataVersion: dataVersion,
      ruleVersion: 'life_rank_v1_preview',
      resultTypeId: resultTypeId,
      dimensionScores: const {},
      displayScores: const {'happiness': '66.7'},
      rawTotals: const {},
      path: 'balance',
      tiedDimensionIds: const ['happiness', 'meaning', 'richness'],
      rank: const ['tr10'],
      preview: true,
      adjacentChanges: false,
    ),
  );
}

Future<ContentBundle> _load(WidgetTester tester) async {
  final bundle = await tester.runAsync(
    () =>
        ContentRepository().load(version: pilotDataVersion, channel: 'preview'),
  );
  return bundle!;
}

Future<void> _pump(
  WidgetTester tester,
  ContentBundle bundle,
  Size size, {
  double textScale = 1,
  MemoryPilotSessionStore? session,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MyApp(
      preview: bundle,
      sessionStore: session,
      store: MemoryLocaleStore()..value = 'ko',
      deviceTags: const ['ko'],
      loader: AppFontLoader(
        loadBytes: (_) async => ByteData(0),
        register: (_, _) async {},
      ),
    ),
  );
  await tester.pump();
}

Future<void> _reload(
  WidgetTester tester,
  ContentBundle bundle,
  MemoryPilotSessionStore store,
  Size size,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await _pump(tester, bundle, size, session: store);
}

void _expectMarkerBands(WidgetTester tester, Key boardKey, List<int> counts) {
  final board = tester.getRect(find.byKey(boardKey));
  final markerSize = board.width * LifeTacticsArt.markerWidthFactor;
  final markers = <Rect>[];
  final images = find.byType(Image);
  final total = tester.widgetList(images).length;
  for (var index = 0; index < total; index++) {
    final width = tester.widget<Image>(images.at(index)).width;
    if (width != null && (width - markerSize).abs() < 0.6) {
      markers.add(tester.getRect(images.at(index)));
    }
  }
  expect(markers, hasLength(counts.fold<int>(0, (sum, count) => sum + count)));
  markers.sort((a, b) => a.center.dy.compareTo(b.center.dy));
  var start = 0;
  for (final count in counts) {
    final row = markers.sublist(start, start + count)
      ..sort((a, b) => a.left.compareTo(b.left));
    start += count;
    expect(row.last.top - row.first.top, lessThan(2));
    expect(row.first.left, greaterThanOrEqualTo(board.left - 0.5));
    expect(row.last.right, lessThanOrEqualTo(board.right + 0.5));
    expect(row.first.top, greaterThanOrEqualTo(board.top - 0.5));
    expect(row.last.bottom, lessThanOrEqualTo(board.bottom + 0.5));
    for (var index = 0; index < row.length - 1; index++) {
      expect(row[index + 1].left, greaterThan(row[index].right));
    }
  }
}

void _expectSixMarkersInside(WidgetTester tester, Key boardKey) {
  _expectMarkerBands(tester, boardKey, const [1, 3, 6]);
}

void _expectResultRow(WidgetTester tester) {
  final line = tester.getRect(find.byKey(const Key('pilot-result-line')));
  final board = tester.getRect(
    find.byKey(const Key('pilot-marker-rows-2-4-4')),
  );
  final saida = tester.getRect(
    find.byKey(
      const Key(
        'pilot-saida-asset:assets/images/saida/saida_life_tactics_tr10_v003.webp',
      ),
    ),
  );
  expect(saida.left, closeTo(line.left, 1));
  expect(board.right, closeTo(line.right, 1));
  final labels = tester.getRect(find.byKey(const Key('pilot-line-labels')));
  expect(saida.right, lessThanOrEqualTo(labels.left + 1));
  expect(labels.right, lessThanOrEqualTo(board.left + 1));
  expect(board.height / board.width, closeTo(1.25, 0.02));
  expect(saida.width, lessThan(board.height));
  final centers = LifeTacticsArt.lineCenters(board.height);
  for (var index = 0; index < centers.length; index++) {
    final label = tester.getRect(find.byKey(Key('pilot-line-label-$index')));
    expect(
      (label.center.dy - (board.top + centers[index])).abs(),
      lessThan(10),
    );
    expect(label.right, lessThanOrEqualTo(board.left + 1));
  }
}

String _questionCheckpoint(ContentBundle bundle) {
  final store = MemoryPilotSessionStore();
  final host = PilotHost()
    ..bind(bundle)
    ..store = store;
  host.ensureQuestions();
  final options = host.quiz!.optionsFor(host.questionItems.first.scaleId);
  host.selectQuestion(0, options[3].optionId);
  host.releaseHold();
  host.notePlace(PilotStage.question, questionIndex: 0);
  return store.value!;
}

String _checkpoint(
  ContentBundle bundle, {
  required String stage,
  required int sceneIndex,
}) {
  final store = MemoryPilotSessionStore();
  final host = PilotHost()
    ..bind(bundle)
    ..store = store;
  host.ensureQuestions();
  for (var index = 0; index < host.questionItems.length; index++) {
    final options = host.quiz!.optionsFor(host.questionItems[index].scaleId);
    host.selectQuestion(index, options[3].optionId);
  }
  host.ensureScenes();
  final answered = stage == PilotStage.scene
      ? sceneIndex + 1
      : host.sceneItems.length;
  for (var index = 0; index < answered; index++) {
    final options = [...host.sceneItems[index].options]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    host.selectScene(index, options.first.optionId);
  }
  if (stage == PilotStage.result || stage == PilotStage.share) {
    host.finish();
  }
  host.releaseHold();
  host.notePlace(
    stage,
    questionIndex: stage == PilotStage.question ? host.questionIndex : null,
    sceneIndex: stage == PilotStage.scene ? sceneIndex : null,
  );
  return store.value!;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder.last);
  await tester.pump();
  await tester.tap(finder.hitTestable());
  await tester.pump();
}

Future<void> _chooseLanguage(WidgetTester tester, String code) async {
  await _tap(tester, const Key('language-menu'));
  await tester.pump(const Duration(milliseconds: 300));
  await _tap(tester, Key('language-$code'));
  await tester.pump();
}

AppButton _button(WidgetTester tester, Key key) {
  return tester.widget<AppButton>(find.byKey(key).hitTestable());
}

AppChoiceOption _choice(WidgetTester tester, Key key) {
  return tester.widget<AppChoiceOption>(find.byKey(key).hitTestable());
}
