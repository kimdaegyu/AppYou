import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/features/catalog/content_repository.dart';
import 'package:look_at_you/features/catalog/content_text.dart';
import 'package:look_at_you/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'home opens life tactics and leaves the public catalog inactive',
    (tester) async {
      final bundle = await tester.runAsync(
        () => ContentRepository().load(
          version: pilotDataVersion,
          channel: 'preview',
        ),
      );
      final release = await tester.runAsync(
        () => ContentRepository().load(
          version: pilotDataVersion,
          channel: 'release',
        ),
      );
      expect(bundle, isNotNull);
      expect(bundle!.quiz('life_tactics')!.isActive, isFalse);
      expect(release!.quizzes, isEmpty);
      expect(release.pilots, isEmpty);

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

      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byKey(const Key('home-life-tactics')), findsOneWidget);
      expect(find.text('나의 인생 전술'), findsOneWidget);
      expect(find.byKey(const Key('pilot-start')), findsOneWidget);
      expect(find.text('어떤 테스트를 해 볼까요?'), findsNothing);
      final wealth = bundle.quiz('wealth_four');
      expect(wealth, isNotNull);
      expect(wealth!.isActive, isFalse);
      final wealthTitle = AppTextBook(bundle.locales)
          .resolve('ko', wealth.titleTextKey)
          .text;
      expect(find.text(wealthTitle), findsOneWidget);
      expect(find.text('Coming Soon...'), findsOneWidget);
    },
  );
}
