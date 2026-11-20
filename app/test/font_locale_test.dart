import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_controller.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/core/theme/app_theme.dart';
import 'package:look_at_you/shared/widgets/app_choice_option.dart';
import 'package:look_at_you/ui_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nine language codes map to the requested families', () {
    expect(AppFonts.languageCodes, hasLength(9));
    expect(AppFonts.plan('ko').primary.family, 'Pretendard');
    expect(AppFonts.plan('en').primary.family, 'Pretendard Std');
    expect(AppFonts.plan('pt-BR').primary.family, 'Pretendard Std');
    expect(AppFonts.plan('es').primary.family, 'Pretendard Std');
    expect(AppFonts.plan('id').primary.family, 'Pretendard Std');
    expect(AppFonts.plan('ja').primary.family, 'Pretendard JP');
    expect(AppFonts.plan('vi').primary.family, 'Noto Sans');
    expect(AppFonts.plan('th').primary.family, 'Noto Sans Thai');
    expect(AppFonts.plan('hi').primary.family, 'Noto Sans Devanagari');

    expect(AppFonts.plan('ja').fallbackFamilies, isEmpty);
    expect(AppFonts.plan('ko').fallbackFamilies, isEmpty);
    expect(AppFonts.plan('th').fallbackFamilies, ['Pretendard Std']);
    expect(AppFonts.plan('hi').fallbackFamilies, ['Pretendard Std']);
    expect(
      AppFonts.plan('en').primary.asset,
      AppFonts.plan('pt-BR').primary.asset,
    );
    for (final code in AppFonts.languageCodes) {
      final plan = AppFonts.plan(code);
      expect(plan.fallbackFamilies, isNot(contains('Pretendard')));
      if (code != 'ja') {
        expect(plan.fallbackFamilies, isNot(contains('Pretendard JP')));
      }
      for (final weight in AppFonts.usedWeights) {
        expect(plan.primary.containsWeight(weight), isTrue, reason: code);
      }
    }
  });

  test('normalizes regional tags without mapping pt-PT to pt-BR', () {
    expect(AppFonts.normalize('pt_BR'), 'pt-BR');
    expect(AppFonts.normalize('pt-br'), 'pt-BR');
    expect(AppFonts.normalize('PT-BR'), 'pt-BR');
    expect(AppFonts.normalize('pt'), isNull);
    expect(AppFonts.normalize('pt-PT'), isNull);
    expect(AppFonts.normalize('en-US'), 'en');
    expect(AppFonts.normalize('ko-KR'), 'ko');
    expect(AppFonts.normalize('ja-JP'), 'ja');
    expect(AppFonts.normalize('es-419'), 'es');
    expect(AppFonts.normalize('zz'), isNull);
  });

  test('invalid stored values fall through to a released device language', () {
    expect(
      AppFonts.resolve(saved: 'nope', deviceTags: const ['th', 'en-GB']),
      'en',
    );
    expect(AppFonts.resolve(saved: 'pt-PT', deviceTags: const ['th']), 'ko');
    expect(AppFonts.resolve(saved: 'vi', deviceTags: const ['en']), 'vi');
    expect(AppFonts.resolve(saved: null, deviceTags: const ['ja-JP']), 'ja');
    expect(AppFonts.resolve(deviceTags: const []), 'ko');
  });

  test('theme roles inherit the locale family and four weights', () {
    final theme = AppTheme.forLanguage('ja');
    final roles = theme.extension<AppTextRoles>()!;
    expect(theme.textTheme.headlineLarge?.fontFamily, 'Pretendard JP');
    expect(theme.textTheme.headlineLarge?.fontSize, 28);
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.headlineLarge?.height, 1.3);
    expect(theme.textTheme.titleLarge?.fontSize, 20);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.titleLarge?.height, 1.5);
    expect(theme.textTheme.titleLarge?.locale, const Locale('ja'));
    expect(theme.textTheme.titleLarge?.fontFamilyFallback, isEmpty);
    expect(theme.textTheme.headlineMedium?.fontSize, 24);
    expect(theme.textTheme.headlineMedium?.height, 1.4);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyLarge?.fontWeight, FontWeight.w400);
    expect(theme.textTheme.bodyLarge?.height, 1.6);
    expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.labelLarge?.height, 1.3);
    expect(roles.button.color, isNull);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodyMedium?.height, 1.5);
    expect(roles.saida.fontSize, 16);
    expect(roles.saida.fontWeight, FontWeight.w500);
    expect(roles.saida.height, 1.5);
    expect(
      AppTypography.styleFor(AppTextRole.resultName, 'en').fontFamily,
      'Pretendard Std',
    );
    expect(AppTheme.light.textTheme.titleLarge?.fontFamily, 'Pretendard');
  });

  test('Vietnamese NFC and NFD samples are different code unit sequences', () {
    expect(FontSamples.viNfc, isNot(FontSamples.viNfd));
    expect(FontSamples.viNfc.runes, contains(0x1EBF));
    expect(FontSamples.viNfd.runes, isNot(contains(0x1EBF)));
    expect(FontSamples.viNfd.runes, contains(0x0302));
    expect(FontSamples.viNfd.runes, contains(0x0323));
  });

  test('sources.json matches the font files the theme loads', () async {
    final json = jsonDecode(
      await File('assets/fonts/sources.json').readAsString(),
    ) as Map<String, dynamic>;
    final families = (json['families'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(families, hasLength(AppFonts.files.length));
    for (final file in AppFonts.files) {
      final recorded = families.singleWhere((item) => item['id'] == file.id);
      expect(recorded['family'], file.family);
      expect(recorded['asset'], file.asset);
      expect(recorded['sha256'], file.sha256);
      expect(recorded['bytes'], file.bytes);
      expect(recorded['revision'], file.revision);
      expect(recorded['qaOnly'], file.qaOnly);
      expect(recorded['modified'], isFalse);
      final bundled = await rootBundle.load(file.asset);
      expect(bundled.lengthInBytes, file.bytes, reason: file.asset);
      final license = await rootBundle.loadString(file.licenseAsset);
      expect(license, contains('SIL Open Font License'));
    }
  });

  test('shared preferences restores only the language code', () async {
    SharedPreferences.setMockInitialValues({
      AppLocaleStore.storageKey: 'pt_BR',
    });
    final store = SharedPreferencesLocaleStore();
    expect(await store.read(), 'pt_BR');
    await store.write('ja');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AppLocaleStore.storageKey), 'ja');
    expect(preferences.getKeys(), {AppLocaleStore.storageKey});
  });

  test(
    'a bad stored value and a failing store still open on a default',
    () async {
      final loader = _immediateLoader();
      final broken = MemoryLocaleStore()..fail = true;
      final controller = AppLocaleController(store: broken, loader: loader);
      await controller.restore(const ['th']);
      expect(controller.languageCode, 'ko');
      expect(controller.readiness, AppFontReadiness.ready);

      final invalid = MemoryLocaleStore()..value = 'nope';
      final restored = AppLocaleController(
        store: invalid,
        loader: _immediateLoader(),
      );
      await restored.restore(const ['pt-PT', 'en-US']);
      expect(restored.languageCode, 'en');
    },
  );

  test('ko then ja then en keeps the latest language', () async {
    final gates = <String, Completer<void>>{};
    final loader = AppFontLoader(
      loadBytes: (asset) async {
        gates.putIfAbsent(asset, Completer<void>.new);
        await gates[asset]!.future;
        return ByteData(1);
      },
      register: (_, _) async {},
    );
    final controller = AppLocaleController(
      store: MemoryLocaleStore(),
      loader: loader,
      languageCode: 'ko',
    );

    final japanese = controller.select('ja');
    await pumpEventQueue();
    expect(controller.languageCode, 'ja');
    expect(gates[AppFonts.pretendardJp.asset], isNotNull);

    final english = controller.select('en');
    expect(controller.languageCode, 'en');
    expect(controller.locale, const Locale('en'));
    await pumpEventQueue();

    gates[AppFonts.pretendardJp.asset]!.complete();
    await japanese;
    expect(controller.languageCode, 'en');
    expect(controller.readiness, AppFontReadiness.loading);

    gates[AppFonts.pretendardStd.asset]!.complete();
    await english;
    expect(controller.languageCode, 'en');
    expect(controller.readiness, AppFontReadiness.ready);
    expect(controller.locale, const Locale('en'));
  });

  test('one Latin load is shared and a failed load can be retried', () async {
    var calls = 0;
    final gate = Completer<void>();
    final loader = AppFontLoader(
      loadBytes: (asset) async {
        calls += 1;
        await gate.future;
        return ByteData(1);
      },
      register: (_, _) async {},
    );
    final first = loader.ensure(AppFonts.plan('en'));
    final second = loader.ensure(AppFonts.plan('pt-BR'));
    final third = loader.ensure(AppFonts.plan('es'));
    expect(calls, 1);
    gate.complete();
    await Future.wait([first, second, third]);
    expect(calls, 1);

    var fail = true;
    final flaky = AppFontLoader(
      loadBytes: (asset) async {
        if (fail) {
          throw StateError('injected');
        }
        return ByteData(1);
      },
      register: (_, _) async {},
    );
    final controller = AppLocaleController(
      store: MemoryLocaleStore(),
      loader: flaky,
      languageCode: 'ko',
    );
    await controller.select('ja');
    expect(controller.languageCode, 'ja');
    expect(controller.readiness, AppFontReadiness.failed);
    expect(controller.isFontReady, isFalse);

    fail = false;
    await controller.retry();
    expect(controller.languageCode, 'ja');
    expect(controller.readiness, AppFontReadiness.ready);

    controller.failNextLoad();
    await controller.select('vi');
    expect(controller.languageCode, 'vi');
    expect(controller.readiness, AppFontReadiness.failed);
    await controller.retry();
    expect(controller.readiness, AppFontReadiness.ready);
  });

  testWidgets('preview keeps the answer and question across languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiPreviewApp(
        store: MemoryLocaleStore()..value = 'ko',
        deviceTags: const ['en-US'],
        loader: _immediateLoader(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('preview-next')), 400);
    await tester.tap(find.text('바로 정리했다'));
    await tester.pump();
    expect(
      tester
          .widget<AppChoiceOption>(
            find.widgetWithText(AppChoiceOption, '바로 정리했다'),
          )
          .selected,
      isTrue,
    );

    await tester.scrollUntilVisible(find.byKey(const Key('lang-en')), -400);
    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pumpAndSettle();
    expect(find.text('What’s your formation? 4–4–2'), findsWidgets);
    expect(
      tester
          .widget<AppChoiceOption>(find.byType(AppChoiceOption).first)
          .selected,
      isTrue,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-position'))).data,
      '1 / 2',
    );

    await tester.scrollUntilVisible(find.byKey(const Key('preview-next')), 400);
    await tester.tap(find.byKey(const Key('preview-next')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-position'))).data,
      '2 / 2',
    );
    await tester.scrollUntilVisible(find.byKey(const Key('lang-pt-BR')), -400);
    await tester.tap(find.byKey(const Key('lang-pt-BR')));
    await tester.pumpAndSettle();
    expect(find.textContaining('São Paulo'), findsWidgets);
    expect(find.text('What’s your formation? 4–4–2'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-position'))).data,
      '2 / 2',
    );
    expect(tester.takeException(), isNull);
  });
}

AppFontLoader _immediateLoader() {
  return AppFontLoader(
    loadBytes: (_) async => ByteData(0),
    register: (_, _) async {},
  );
}
