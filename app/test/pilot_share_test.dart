import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_bootstrap.dart';
import 'package:look_at_you/core/locale/app_locale_controller.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/core/theme/app_theme.dart';
import 'package:look_at_you/features/catalog/content_repository.dart';
import 'package:look_at_you/features/life_tactics/pilot_checkpoint.dart';
import 'package:look_at_you/features/life_tactics/pilot_host.dart';
import 'package:look_at_you/features/life_tactics/pilot_pages.dart';
import 'package:look_at_you/features/life_tactics/pilot_session_store_memory.dart';
import 'package:look_at_you/features/life_tactics/pilot_share_capture.dart';
import 'package:look_at_you/features/life_tactics/pilot_share_file.dart';
import 'package:look_at_you/features/life_tactics/pilot_share_gateway.dart';
import 'package:look_at_you/features/life_tactics/pilot_share_link.dart';
import 'package:look_at_you/shared/widgets/app_button.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final previousCanShare = pilotCanShareLink;
  final previousKakaoBrowser = pilotKakaoTalkBrowser;
  final previousShare = pilotShareLink;
  final previousKakao = pilotSendKakao;
  final previousCopy = pilotCopyText;
  final previousSave = pilotSaveFile;
  final previousCapture = pilotCaptureCard;

  tearDown(() {
    pilotCanShareLink = previousCanShare;
    pilotKakaoTalkBrowser = previousKakaoBrowser;
    pilotShareLink = previousShare;
    pilotSendKakao = previousKakao;
    pilotCopyText = previousCopy;
    pilotSaveFile = previousSave;
    pilotCaptureCard = previousCapture;
  });

  test('share filename keeps the result and language', () {
    expect(
      PilotShareFile.filenameFor(resultTypeId: 'tr01', languageCode: 'ko'),
      'look-at-you_life-tactics_tr01_ko.png',
    );
    expect(
      PilotShareFile.filenameFor(resultTypeId: 'tr10', languageCode: 'pt-BR'),
      'look-at-you_life-tactics_tr10_pt-BR.png',
    );
    expect(
      pilotImageOpensForSaving('Mozilla/5.0 (iPhone; CPU iPhone OS'),
      isTrue,
    );
    expect(
      pilotImageOpensForSaving('Mozilla/5.0 (Macintosh)', maxTouchPoints: 5),
      isTrue,
    );
    expect(pilotImageOpensForSaving('Mozilla/5.0 Chrome/120.0'), isFalse);
    expect(
      pilotImageOpensForSaving('Android; wv) Chrome/120 KAKAOTALK'),
      isTrue,
    );
    expect(pilotKakaoTalkAgent('Android Chrome KAKAOTALK'), isTrue);
    expect(pilotKakaoTalkAgent('Android Chrome/120 Mobile'), isFalse);
    expect(pilotUsesKakaoShare(systemShare: false, kakaoTalk: true), isTrue);
    expect(pilotUsesKakaoShare(systemShare: true, kakaoTalk: true), isFalse);
    expect(pilotImageOpensForSaving('Android Chrome/120 Mobile'), isFalse);
  });

  test('diagnosis link keeps only the public quiz id', () {
    final link = pilotDiagnosisLink('life_tactics');
    expect(
      link.toString(),
      'https://lookatyou.dcstudio.workers.dev/?quizId=life_tactics',
    );
    expect(link.queryParameters, {'quizId': 'life_tactics'});
  });

  testWidgets('link share opens the sheet without a file', (tester) async {
    final saved = <PilotShareFile>[];
    final shared = <PilotShareLink>[];
    var shareResult = PilotShareFileResult.opened;
    final copied = <String>[];
    pilotCanShareLink = (_) => true;
    pilotShareLink = (link) {
      shared.add(link);
      return Future.value(shareResult);
    };
    pilotCopyText = (text) async {
      copied.add(text);
      return true;
    };
    pilotSaveFile = (file) async {
      saved.add(file);
      return PilotSaveFileResult.downloaded;
    };
    final gate = Completer<void>();
    pilotCaptureCard = (context, {required card, required assets}) async {
      await gate.future;
      final share = card as LifeTacticsShareCard;
      return Uint8List.fromList(utf8.encode(share.resultTypeId));
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    await tester.pump();
    expect(_button(tester).label, '링크 공유하기');
    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(shared, hasLength(1));
    expect(shared.single.url.toString(), _publicLink);
    expect(shared.single.url.queryParameters.keys.toList(), ['quizId']);
    expect(shared.single.text, _koreanShare);
    expect(shared.single.text.contains('http'), isFalse);
    expect(copied, isEmpty);
    expect(saved, isEmpty);
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);
    expect(find.text('전송 완료'), findsNothing);

    shareResult = PilotShareFileResult.cancelled;
    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(shared, hasLength(2));
    expect(copied, isEmpty);
    expect(saved, isEmpty);
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.byKey(const Key('pilot-share-link')), findsNothing);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);
    expect(saved, isEmpty);
    gate.complete();
    await tester.pump();
  });

  testWidgets(
    'unsupported or blocked link share offers an explicit copy action',
    (tester) async {
      final saved = <PilotShareFile>[];
      final copied = <String>[];
      var canShare = false;
      var shareResult = PilotShareFileResult.unavailable;
      pilotCanShareLink = (_) => canShare;
      pilotShareLink = (_) async => shareResult;
      pilotCopyText = (text) async {
        copied.add(text);
        return true;
      };
      pilotSaveFile = (file) async {
        saved.add(file);
        return PilotSaveFileResult.downloaded;
      };
      _holdCapture();
      final host = await _host(tester);
      final controller = await _locale();
      addTearDown(controller.dispose);
      await _show(tester, host, controller, const Size(400, 900));
      await tester.pump();

      await tester.tap(find.byKey(const Key('pilot-share-action')));
      await tester.pump();
      expect(copied, isEmpty);
      expect(find.text(_publicLink), findsNothing);
      expect(
        find.text(
          '이 브라우저에서는 공유창을 열 수 없어요. 아래 진단 링크를 연 뒤 브라우저 메뉴에서 공유를 선택해 주세요.',
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(const Key('pilot-copy-link')));
      await tester.tap(find.byKey(const Key('pilot-copy-link')));
      await tester.pump();
      expect(copied, [_publicLink]);
      expect(saved, isEmpty);
      expect(find.text('진단 링크를 복사했어요. 채팅창에 붙여넣어 주세요.'), findsOneWidget);
      expect(find.byKey(const Key('pilot-share-link')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('pilot-share-action')));
      canShare = true;
      shareResult = PilotShareFileResult.failed;
      await tester.tap(find.byKey(const Key('pilot-share-action')));
      await tester.pump();
      expect(copied, [_publicLink]);
      expect(find.text(_publicLink), findsNothing);
      expect(find.byKey(const Key('pilot-copy-link')), findsOneWidget);
      expect(saved, isEmpty);
      expect(find.text('진단 링크를 복사했어요. 채팅창에 붙여넣어 주세요.'), findsNothing);
    },
  );

  testWidgets('a failed copy shows the diagnosis url for manual copy', (
    tester,
  ) async {
    final saved = <PilotShareFile>[];
    pilotCanShareLink = (_) => false;
    pilotShareLink = (_) async => PilotShareFileResult.opened;
    pilotCopyText = (_) async => false;
    pilotSaveFile = (file) async {
      saved.add(file);
      return PilotSaveFileResult.downloaded;
    };
    _holdCapture();
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    await tester.pump();

    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('pilot-copy-link')));
    await tester.tap(find.byKey(const Key('pilot-copy-link')));
    await tester.pump();
    expect(saved, isEmpty);
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.text(_publicLink), findsOneWidget);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);
  });

  testWidgets('kakao in-app share sends the result name and diagnosis link', (
    tester,
  ) async {
    final shared = <PilotShareLink>[];
    final kakao = <PilotKakaoShare>[];
    var kakaoResult = PilotShareFileResult.opened;
    pilotCanShareLink = (_) => false;
    pilotKakaoTalkBrowser = () => true;
    pilotShareLink = (link) async {
      shared.add(link);
      return PilotShareFileResult.opened;
    };
    pilotSendKakao = (message) {
      kakao.add(message);
      return Future.value(kakaoResult);
    };
    pilotCopyText = (_) async => true;
    _holdCapture();
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    await tester.pump();
    expect(_button(tester).label, '카카오톡으로 공유하기');
    expect(find.byKey(const Key('pilot-copy-link')), findsNothing);
    expect(
      find.text('이 브라우저에서는 공유창을 열 수 없어요. 아래 진단 링크를 연 뒤 브라우저 메뉴에서 공유를 선택해 주세요.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(shared, isEmpty);
    expect(kakao, hasLength(1));
    expect(kakao.single.text, '인생의 올라운더');
    expect(kakao.single.buttonTitle, '나도 진단하기');
    expect(kakao.single.webUrl.toString(), _publicLink);
    expect(kakao.single.mobileWebUrl.toString(), _publicLink);
    expect(kakao.single.webUrl.queryParameters, {'quizId': 'life_tactics'});
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.byKey(const Key('pilot-copy-link')), findsNothing);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);

    kakaoResult = PilotShareFileResult.cancelled;
    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(find.byKey(const Key('pilot-copy-link')), findsNothing);
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);

    kakaoResult = PilotShareFileResult.failed;
    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(find.byKey(const Key('pilot-copy-link')), findsOneWidget);
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.text(_publicLink), findsNothing);
  });

  testWidgets('link share still works when the image cannot be prepared', (
    tester,
  ) async {
    final saved = <PilotShareFile>[];
    final shared = <PilotShareLink>[];
    pilotCanShareLink = (_) => true;
    pilotShareLink = (link) async {
      shared.add(link);
      return PilotShareFileResult.opened;
    };
    pilotCopyText = (_) async => false;
    pilotSaveFile = (file) async {
      saved.add(file);
      return PilotSaveFileResult.downloaded;
    };
    pilotCaptureCard = (context, {required card, required assets}) async {
      throw StateError('png');
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    for (var step = 0; step < 4; step++) {
      await tester.pump();
    }
    expect(_button(tester).onPressed, isNotNull);
    expect(_saveButton(tester).onPressed, isNull);
    expect(find.text('공유 이미지를 만들지 못했어요. 미리보기를 다시 열어 주세요.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(shared.single.url.toString(), _publicLink);
    expect(shared.single.text, _koreanShare);
    expect(saved, isEmpty);
  });

  testWidgets('saving the image still downloads that png', (tester) async {
    final saved = <PilotShareFile>[];
    final shared = <PilotShareLink>[];
    pilotCanShareLink = (_) => false;
    pilotShareLink = (link) async {
      shared.add(link);
      return PilotShareFileResult.opened;
    };
    pilotCopyText = (_) async => true;
    pilotSaveFile = (file) async {
      saved.add(file);
      return PilotSaveFileResult.downloaded;
    };
    _holdCapture();
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    await _ready(tester);

    await tester.tap(find.byKey(const Key('pilot-share-save')));
    await tester.pump();
    expect(shared, isEmpty);
    expect(saved, hasLength(1));
    expect(saved.single.filename, 'look-at-you_life-tactics_tr10_ko.png');
    expect(find.byKey(const Key('pilot-share-notice')), findsNothing);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);
  });

  testWidgets('opening the image tells the person to finish saving', (
    tester,
  ) async {
    pilotCanShareLink = (_) => true;
    pilotShareLink = (_) async => PilotShareFileResult.opened;
    pilotSaveFile = (_) async => PilotSaveFileResult.opened;
    _holdCapture();
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    await _ready(tester);
    await tester.tap(find.byKey(const Key('pilot-share-save')));
    await tester.pump();
    expect(find.text('이미지가 열렸어요. 기기에서 저장을 마쳐 주세요.'), findsOneWidget);
    expect(find.byKey(const Key('pilot-share-card')), findsOneWidget);
  });

  testWidgets('a new language or result drops the previous png', (
    tester,
  ) async {
    final saved = <PilotShareFile>[];
    final shared = <PilotShareLink>[];
    var hold = false;
    Completer<void>? gate;
    pilotCanShareLink = (_) => true;
    pilotShareLink = (link) async {
      shared.add(link);
      return PilotShareFileResult.opened;
    };
    pilotCopyText = (_) async => false;
    pilotSaveFile = (file) async {
      saved.add(file);
      return PilotSaveFileResult.downloaded;
    };
    pilotCaptureCard = (context, {required card, required assets}) async {
      if (hold) {
        gate = Completer<void>();
        await gate!.future;
      }
      final share = card as LifeTacticsShareCard;
      return Uint8List.fromList(
        utf8.encode('${share.resultTypeId}|${share.name}|${share.description}'),
      );
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(400, 900));
    await _ready(tester);
    final first = _saveButton(tester).onPressed;
    expect(first, isNotNull);

    hold = true;
    await controller.select('en');
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNull);
    expect(_button(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('pilot-share-action')));
    await tester.pump();
    expect(saved, isEmpty);
    expect(shared.single.url.toString(), _publicLink);
    expect(
      shared.single.text,
      "I got 'All-rounder of Life'. What's your life tactic?",
    );
    gate!.complete();
    await _ready(tester);
    await tester.tap(find.byKey(const Key('pilot-share-save')));
    await tester.pump();
    expect(saved.single.filename, 'look-at-you_life-tactics_tr10_en.png');
    expect(utf8.decode(saved.single.bytes), contains('All-rounder of Life'));
    expect(utf8.decode(saved.single.bytes), isNot(contains('인생의 올라운더')));

    saved.clear();
    hold = true;
    gate = null;
    _answer(host, _happinessScores);
    host.finish();
    await tester.pump();
    final changed = host.outcome!.resultTypeId;
    expect(changed, isNot('tr10'));
    expect(_saveButton(tester).onPressed, isNull);
    expect(_button(tester).onPressed, isNotNull);
    gate!.complete();
    await _ready(tester);
    await tester.tap(find.byKey(const Key('pilot-share-save')));
    await tester.pump();
    expect(saved.single.filename, 'look-at-you_life-tactics_${changed}_en.png');
    expect(utf8.decode(saved.single.bytes), startsWith('$changed|'));
    expect(
      utf8.decode(saved.single.bytes),
      isNot(contains('All-rounder of Life')),
    );
  });

  testWidgets('narrow and large text stack the share actions', (tester) async {
    _holdCapture();
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _show(tester, host, controller, const Size(360, 800));
    await tester.pump();
    final narrowShare = tester.getRect(
      find.byKey(const Key('pilot-share-action')),
    );
    final narrowSave = tester.getRect(
      find.byKey(const Key('pilot-share-save')),
    );
    expect(narrowSave.top, greaterThan(narrowShare.bottom - 1));

    await _show(
      tester,
      host,
      controller,
      const Size(1280, 900),
      textScale: 1.4,
    );
    await tester.pump();
    final largeShare = tester.getRect(
      find.byKey(const Key('pilot-share-action')),
    );
    final largeSave = tester.getRect(find.byKey(const Key('pilot-share-save')));
    expect(largeSave.top, greaterThan(largeShare.bottom - 1));

    await _show(tester, host, controller, const Size(1280, 900));
    await tester.pump();
    final wideShare = tester.getRect(
      find.byKey(const Key('pilot-share-action')),
    );
    final wideSave = tester.getRect(find.byKey(const Key('pilot-share-save')));
    expect((wideShare.top - wideSave.top).abs(), lessThan(2));
    expect(wideSave.left, greaterThan(wideShare.right));
  });

  testWidgets('a long translation stays on the card and the png is 1080 wide', (
    tester,
  ) async {
    const ending = '끝까지-보이는-문장-END';
    final description = '${'긴 번역 ' * 40}$ending';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LifeTacticsShareCard(
                brand: 'Look At You',
                quizTitle: '나의 인생 전술',
                formation: '4-2-4',
                name: '불꽃 모험가',
                catchphrase: '오늘은 새로운 쪽으로.',
                description: description,
                studio: 'D.CStudio',
                resultTypeId: 'tr01',
                saidaAsset:
                    'assets/images/saida/saida_life_tactics_tr01_v002.webp',
                retryLabel: '다시 시도',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final card = tester.getRect(find.byKey(const Key('pilot-share-card')));
    expect(card.height, greaterThan(card.width));
    expect(find.textContaining(ending), findsOneWidget);
    expect(find.byKey(const Key('pilot-marker-rows-4-2-4')), findsOneWidget);
  });
}

const _happinessScores = [5, 1, 1, 1, 5, 5, 1, 5, 5, 1, 1, 5, 1, 1, 1, 1, 5, 1];

void _holdCapture() {
  pilotCaptureCard = (context, {required card, required assets}) async {
    final share = card as LifeTacticsShareCard;
    return Uint8List.fromList(
      utf8.encode('${share.resultTypeId}|${share.name}'),
    );
  };
}

const _publicLink =
    'https://lookatyou.dcstudio.workers.dev/?quizId=life_tactics';

const _koreanShare = '나는 ‘인생의 올라운더’가 나왔어. 너의 인생 전술은 뭐야?';

Future<void> _ready(WidgetTester tester) async {
  for (var step = 0; step < 12; step++) {
    await tester.pump();
    if (_saveButton(tester).onPressed != null) {
      return;
    }
  }
  fail('share image was not ready');
}

AppButton _button(WidgetTester tester) {
  return tester.widget<AppButton>(find.byKey(const Key('pilot-share-action')));
}

AppButton _saveButton(WidgetTester tester) {
  return tester.widget<AppButton>(find.byKey(const Key('pilot-share-save')));
}

Future<PilotHost> _host(WidgetTester tester) async {
  final bundle = await tester.runAsync(
    () =>
        ContentRepository().load(version: pilotDataVersion, channel: 'preview'),
  );
  final host = PilotHost()..bind(bundle!);
  final saved = _checkpoint(host);
  expect(host.restore(saved), isTrue);
  host.releaseHold();
  return host;
}

Future<AppLocaleController> _locale() async {
  final controller = AppLocaleController(
    store: MemoryLocaleStore()..value = 'ko',
    loader: AppFontLoader(
      loadBytes: (_) async => ByteData(0),
      register: (_, _) async {},
    ),
  );
  await controller.select('ko');
  return controller;
}

Future<void> _show(
  WidgetTester tester,
  PilotHost host,
  AppLocaleController controller,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.forLanguage(controller.languageCode),
      home: AppLocaleScope(
        controller: controller,
        child: PilotSharePage(host: host),
      ),
    ),
  );
  await tester.pump();
}

void _answer(PilotHost host, List<int> scores) {
  for (var index = 0; index < scores.length; index++) {
    final item = host.questionItems[index];
    final options = [...host.quiz!.optionsFor(item.scaleId)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final option = options.firstWhere(
      (item) => item.scoreValue == scores[index],
    );
    host.questions!.select(item.questionId, option.optionId);
  }
}

String _checkpoint(PilotHost host) {
  final store = MemoryPilotSessionStore();
  host.store = store;
  host.ensureQuestions();
  for (var index = 0; index < host.questionItems.length; index++) {
    final options = host.quiz!.optionsFor(host.questionItems[index].scaleId);
    host.selectQuestion(index, options[3].optionId);
  }
  host.ensureScenes();
  for (var index = 0; index < host.sceneItems.length; index++) {
    final options = [...host.sceneItems[index].options]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    host.selectScene(index, options.first.optionId);
  }
  host.finish();
  host.releaseHold();
  host.notePlace(PilotStage.result);
  return store.value!;
}
