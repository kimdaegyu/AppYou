import 'dart:async';

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
import 'package:look_at_you/features/life_tactics/pilot_host.dart';
import 'package:look_at_you/features/life_tactics/pilot_pages.dart';
import 'package:look_at_you/features/life_tactics/pilot_session_store_memory.dart';
import 'package:look_at_you/features/life_tactics/pilot_visual.dart';
import 'package:look_at_you/main.dart';
import 'package:look_at_you/shared/widgets/app_button.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final previousLoad = pilotLoadAsset;

  tearDown(() {
    pilotLoadAsset = previousLoad;
  });

  testWidgets('home can start while its images are still empty slots', (
    tester,
  ) async {
    final bundle = await tester.runAsync(
      () => ContentRepository().load(
        version: pilotDataVersion,
        channel: 'preview',
      ),
    );
    await tester.pumpWidget(
      MyApp(
        preview: bundle,
        store: MemoryLocaleStore()..value = 'ko',
        deviceTags: const ['ko'],
        loader: AppFontLoader(
          loadBytes: (_) async => ByteData(0),
          register: (_, _) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('나의 인생 전술'), findsWidgets);
    expect(find.byKey(const Key('pilot-start')), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byKey(const Key('pilot-start'))).onPressed,
      isNotNull,
    );
    expect(tester.getSize(find.byKey(const Key('pilot-home-art'))).height, 220);
    expect(
      tester.getSize(find.byKey(const Key('pilot-home-saida'))),
      const Size(150, 150),
    );
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    expect(find.text('공유 카드를 만드는 중…'), findsNothing);
    final start = tester.getTopLeft(find.byKey(const Key('pilot-start'))).dy;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(find.byKey(const Key('pilot-start'))).dy, start);
    await tester.tap(find.byKey(const Key('pilot-start')));
    await tester.pump();
    expect(find.byKey(const Key('pilot-next')), findsOneWidget);
  });

  testWidgets('result images wait 400ms before one loading notice', (
    tester,
  ) async {
    final gates = <Completer<void>>[];
    pilotLoadAsset = (context, asset) {
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _showResult(tester, host, controller);
    expect(find.text('인생의 올라운더'), findsOneWidget);
    expect(find.byKey(const Key('pilot-description')), findsOneWidget);
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    expect(find.byKey(const Key('pilot-result-image-cover')), findsOneWidget);
    final description = tester
        .getTopLeft(find.byKey(const Key('pilot-description')))
        .dy;
    final share = tester.getTopLeft(find.text('공유 카드 보기')).dy;

    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('결과 이미지를 불러오는 중…'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('pilot-description'))).dy,
      description,
    );
    expect(tester.getTopLeft(find.text('공유 카드 보기')).dy, share);

    expect(gates, hasLength(3));
    for (final gate in gates) {
      gate.complete();
    }
    await tester.pump();
    await tester.pump();
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    expect(find.byKey(const Key('pilot-result-image-cover')), findsNothing);
    expect(find.byKey(const Key('pilot-marker-rows-2-4-4')), findsOneWidget);
    expect(find.text('인생의 올라운더'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('pilot-description'))).dy,
      description,
    );
    expect(tester.getTopLeft(find.text('공유 카드 보기')).dy, share);
  });

  testWidgets('result images that finish within 400ms skip the notice', (
    tester,
  ) async {
    pilotLoadAsset = (context, asset) =>
        Future<void>.delayed(const Duration(milliseconds: 200));
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _showResult(tester, host, controller);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    expect(find.byKey(const Key('pilot-result-image-cover')), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
  });

  testWidgets('a failed result image retries the same result', (tester) async {
    var fail = true;
    final gates = <Completer<void>>[];
    pilotLoadAsset = (context, asset) {
      if (fail) {
        return Future<void>.error(StateError('image'));
      }
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _showResult(tester, host, controller);
    await tester.pump();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('인생의 올라운더'), findsOneWidget);
    expect(host.outcome!.resultTypeId, 'tr10');

    fail = false;
    await tester.tap(find.byKey(const Key('pilot-result-image-retry')));
    await tester.pump();
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    for (final gate in gates) {
      gate.complete();
    }
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('pilot-result-image-cover')), findsNothing);
    expect(find.text('인생의 올라운더'), findsOneWidget);
    expect(host.outcome!.resultTypeId, 'tr10');
  });

  testWidgets('a late image load cannot reveal the previous result', (
    tester,
  ) async {
    final gates = <Completer<void>>[];
    pilotLoadAsset = (context, asset) {
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _showResult(tester, host, controller);
    final first = gates.length;
    expect(first, 3);
    _score(host, const {'happiness': 17, 'meaning': 21, 'richness': 26});
    await tester.pump();
    expect(host.outcome!.resultTypeId, 'tr01');
    expect(find.text('불꽃 모험가'), findsOneWidget);
    for (var index = 0; index < first; index++) {
      gates[index].complete();
    }
    await tester.pump();
    expect(find.byKey(const Key('pilot-result-image-cover')), findsOneWidget);
    expect(
      find.byKey(Key('pilot-saida-asset:${LifeTacticsArt.saidaAsset('tr01')}')),
      findsOneWidget,
    );
    for (final gate in gates.skip(first)) {
      gate.complete();
    }
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('pilot-result-image-cover')), findsNothing);
    expect(find.text('불꽃 모험가'), findsOneWidget);
  });

  testWidgets('changing language replaces the result loading notice', (
    tester,
  ) async {
    final gates = <Completer<void>>[];
    pilotLoadAsset = (context, asset) {
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _showResult(tester, host, controller);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('결과 이미지를 불러오는 중…'), findsOneWidget);
    await controller.select('en');
    await tester.pump();
    expect(find.text('Loading the result images…'), findsOneWidget);
    expect(find.text('결과 이미지를 불러오는 중…'), findsNothing);
    expect(find.text('All-rounder of Life'), findsOneWidget);
    for (final gate in gates) {
      gate.complete();
    }
    await tester.pump();
    expect(find.text('Loading the result images…'), findsNothing);
  });

  testWidgets('leaving the result ignores a late image load', (tester) async {
    final gates = <Completer<void>>[];
    pilotLoadAsset = (context, asset) {
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    };
    final host = await _host(tester);
    final controller = await _locale();
    addTearDown(controller.dispose);
    await _showResult(tester, host, controller);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final gate in gates) {
      gate.complete();
    }
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

Future<PilotHost> _host(WidgetTester tester) async {
  final bundle = await tester.runAsync(
    () =>
        ContentRepository().load(version: pilotDataVersion, channel: 'preview'),
  );
  final host = PilotHost()..bind(bundle!);
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

Future<void> _showResult(
  WidgetTester tester,
  PilotHost host,
  AppLocaleController controller,
) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

void _score(PilotHost host, Map<String, int> rawTotals) {
  final grouped = <String, List<QuestionContent>>{};
  for (final question in host.questionItems) {
    grouped.putIfAbsent(question.dimensionId, () => []).add(question);
  }
  for (final entry in rawTotals.entries) {
    final questions = grouped[entry.key]!;
    final parts = _parts(entry.value, questions.length);
    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      final wanted = question.reverse ? 6 - parts[index] : parts[index];
      final option = host.quiz!
          .optionsFor(question.scaleId)
          .firstWhere((item) => item.scoreValue == wanted);
      host.questions!.select(question.questionId, option.optionId);
    }
  }
  host.finish();
}

List<int> _parts(int total, int count) {
  final values = List<int>.filled(count, 1);
  var left = total - count;
  var index = 0;
  while (left > 0) {
    final room = 5 - values[index];
    final take = left < room ? left : room;
    values[index] += take;
    left -= take;
    index = (index + 1) % count;
  }
  return values;
}
