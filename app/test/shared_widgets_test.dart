import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:look_at_you/core/fonts/app_font_loader.dart';
import 'package:look_at_you/core/locale/app_locale_store.dart';
import 'package:look_at_you/core/theme/app_theme.dart';
import 'package:look_at_you/shared/widgets/app_button.dart';
import 'package:look_at_you/shared/widgets/app_choice_option.dart';
import 'package:look_at_you/shared/widgets/app_content_frame.dart';
import 'package:look_at_you/shared/widgets/app_progress.dart';
import 'package:look_at_you/ui_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('color tokens match the light theme v1.0', () {
    expect(AppColors.background, const Color(0xFFFFF9F2));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
    expect(AppColors.surfaceVariant, const Color(0xFFFFF1DF));
    expect(AppColors.primary, const Color(0xFFA44B12));
    expect(AppColors.primaryPressed, const Color(0xFF84370A));
    expect(AppColors.onPrimary, const Color(0xFFFFFFFF));
    expect(AppColors.textPrimary, const Color(0xFF4A2E1E));
    expect(AppColors.textSecondary, const Color(0xFF8B5B3A));
    expect(AppColors.border, const Color(0xFFE7D3BE));
    expect(AppColors.highlight, const Color(0xFFF8E5C8));
    expect(AppColors.furLight, const Color(0xFFE9C69B));
    expect(AppColors.furGold, const Color(0xFFD8A971));
    expect(AppColors.pinkAccent, const Color(0xFFE67878));
    expect(AppColors.success, const Color(0xFF2E705F));
    expect(AppColors.info, const Color(0xFF31699E));
    expect(AppColors.error, const Color(0xFFB23B47));
  });

  test(
    'progress fraction stays finite for start, complete, and zero total',
    () {
      expect(AppProgress.fraction(1, 18), closeTo(1 / 18, 0.0000001));
      expect(AppProgress.fraction(18, 18), 1);
      expect(AppProgress.fraction(0, 18), 0);
      expect(AppProgress.fraction(4, 0), 0);
      expect(AppProgress.fraction(0, 0), 0);
      expect(AppProgress.fraction(-3, 18), 0);
      expect(AppProgress.fraction(3, -1), 0);
      expect(AppProgress.fraction(0, 0).isNaN, isFalse);
      expect(AppProgress.fraction(4, 0).isNaN, isFalse);
    },
  );

  testWidgets('disabled button does not call its action', (tester) async {
    final handle = tester.ensureSemantics();

    var enabled = false;
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                AppButton(
                  label: '다음',
                  onPressed: enabled ? () => setState(() => taps++) : null,
                ),
                Text('taps=$taps'),
                AppButton(
                  label: '활성화',
                  variant: AppButtonVariant.text,
                  onPressed: () => setState(() => enabled = true),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(AppButton, '다음'));
    await tester.pump();
    expect(find.text('taps=0'), findsOneWidget);
    expect(
      tester.getSemantics(find.widgetWithText(AppButton, '다음')),
      isSemantics(
        label: '다음',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('taps=0'), findsOneWidget);

    await tester.tap(find.text('활성화'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, '다음'));
    await tester.pump();
    expect(find.text('taps=1'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('primary button uses pressed color and grows with text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AppButton(label: '다음으로', onPressed: _noop)),
    );

    final context = tester.element(find.text('다음으로'));
    final style = DefaultTextStyle.of(context).style;
    expect(style.fontSize, 16);
    expect(style.fontWeight, FontWeight.w600);
    expect(tester.getSize(find.byType(FilledButton)).height, 52);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('다음으로')),
    );
    await tester.pump();
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, AppColors.primaryPressed);
    await gesture.up();
  });

  testWidgets('secondary button keeps the shorter minimum height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppButton(
          label: '이전',
          variant: AppButtonVariant.secondary,
          onPressed: _noop,
        ),
      ),
    );

    expect(tester.getSize(find.byType(FilledButton)).height, 48);
  });

  testWidgets('choice selection is announced and can move', (tester) async {
    final handle = tester.ensureSemantics();

    var selected = 0;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                for (var index = 0; index < 2; index++)
                  AppChoiceOption(
                    label: index == 0 ? '짧은 답' : '더 긴 답변입니다',
                    selected: selected == index,
                    onPressed: () => setState(() => selected = index),
                  ),
              ],
            );
          },
        ),
      ),
    );

    expect(
      tester.getSemantics(find.widgetWithText(AppChoiceOption, '짧은 답')),
      isSemantics(
        label: '짧은 답',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('더 긴 답변입니다'));
    await tester.pump();

    expect(
      tester
          .widget<AppChoiceOption>(find.widgetWithText(AppChoiceOption, '짧은 답'))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<AppChoiceOption>(
            find.widgetWithText(AppChoiceOption, '더 긴 답변입니다'),
          )
          .selected,
      isTrue,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    handle.dispose();
  });

  testWidgets('choice activates from the keyboard', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        AppChoiceOption(label: '답변', selected: false, onPressed: () => taps++),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppChoiceOption),
        matching: find.byType(Material),
      ),
    );
    final side = (material.shape! as RoundedRectangleBorder).side;
    expect(side.color, AppColors.info);
    expect(side.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('progress bar shows start, complete, and zero total', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            AppProgress(current: 1, total: 18, label: '1 / 18'),
            AppProgress(current: 18, total: 18, label: '18 / 18'),
            AppProgress(current: 4, total: 0, label: '없음'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 18'), findsOneWidget);
    expect(find.text('18 / 18'), findsOneWidget);
    expect(find.text('없음'), findsOneWidget);

    final factors = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((box) => box.widthFactor)
        .toList();
    expect(factors, [closeTo(1 / 18, 0.0000001), 1, 0]);

    final bars = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.width == double.infinity &&
          widget.height == AppSpacing.progressHeight,
    );
    expect(bars, findsNWidgets(3));
    expect(tester.getSize(bars.first).height, 8);
  });

  testWidgets('long choice does not overlap its icon at 200 percent', (
    tester,
  ) async {
    const label = '여러 사람의 이야기를 들으면서 내가 놓치고 있던 부분까지 확인한 다음에, 서두르지 않고 다음 행동을 골랐다';
    _setView(tester, const Size(360, 800));

    await tester.pumpWidget(
      _wrap(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: AppChoiceOption(
            label: label,
            selected: true,
            onPressed: _noop,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final textRect = tester.getRect(find.text(label));
    final iconRect = tester.getRect(find.byIcon(Icons.check_circle));
    expect(textRect.overlaps(iconRect), isFalse);
    expect(textRect.left, greaterThanOrEqualTo(0));
    expect(iconRect.right, lessThanOrEqualTo(360));
    expect(
      tester.getSize(find.byType(AppChoiceOption)).height,
      greaterThan(52),
    );
  });

  testWidgets('content frame stays within 520 and centers on a wide canvas', (
    tester,
  ) async {
    _setView(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _wrap(
        const AppContentFrame(
          child: SizedBox(key: Key('fill'), width: double.infinity, height: 8),
        ),
      ),
    );

    final frame = find.descendant(
      of: find.byType(AppContentFrame),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(frame).width, 520);
    expect(tester.getTopLeft(frame).dx, closeTo((1280 - 520) / 2, 1));
    expect(tester.getSize(find.byKey(const Key('fill'))).width, 480);
  });

  testWidgets('preview selection enables next and moves the marker', (
    tester,
  ) async {
    _setView(tester, const Size(360, 800));
    await tester.pumpWidget(
      UiPreviewApp(
        store: MemoryLocaleStore()..value = 'ko',
        deviceTags: const ['en-US'],
        loader: AppFontLoader(
          loadBytes: (_) async => ByteData(0),
          register: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final nextFinder = find.byKey(const Key('preview-next'));
    await tester.scrollUntilVisible(nextFinder, 400);
    AppButton nextButton() => tester.widget<AppButton>(nextFinder);

    expect(nextButton().onPressed, isNull);

    await tester.ensureVisible(find.text('바로 정리했다'));
    await tester.tap(find.text('바로 정리했다'));
    await tester.pump();
    expect(nextButton().onPressed, isNotNull);
    expect(
      tester
          .widget<AppChoiceOption>(
            find.widgetWithText(AppChoiceOption, '바로 정리했다'),
          )
          .selected,
      isTrue,
    );

    const longAnswer =
        '여러 사람의 이야기를 들으면서 내가 놓치고 있던 부분까지 확인한 다음에, 서두르지 않고 다음 행동을 골랐다';
    await tester.ensureVisible(find.text(longAnswer));
    await tester.tap(find.text(longAnswer));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('바로 정리했다'), -400);
    expect(
      tester
          .widget<AppChoiceOption>(
            find.widgetWithText(AppChoiceOption, '바로 정리했다'),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<AppChoiceOption>(
            find.widgetWithText(AppChoiceOption, longAnswer),
          )
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('글꼴 200%'), -400);
    await tester.tap(find.text('글꼴 200%'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text(longAnswer), 400);
    expect(tester.takeException(), isNull);
    final textRect = tester.getRect(find.text(longAnswer));
    final iconRect = tester.getRect(find.byIcon(Icons.check_circle));
    expect(textRect.overlaps(iconRect), isFalse);
  });
}

void _noop() {}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}
