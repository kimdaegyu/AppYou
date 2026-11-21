import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/locale/app_locale_bootstrap.dart';
import '../../core/locale/app_locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../catalog/content_models.dart';
import '../catalog/content_text.dart';
import '../quiz/quiz_engine.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_choice_option.dart';
import '../../shared/widgets/app_content_frame.dart';
import '../../shared/widgets/app_progress.dart';
import 'life_tactics_art.dart';
import 'pilot_checkpoint.dart';
import 'pilot_feedback.dart';
import 'pilot_home_order.dart';
import 'pilot_host.dart';
import 'pilot_share_capture.dart';
import 'pilot_share_file.dart';
import 'pilot_share_gateway.dart';
import 'pilot_share_link.dart';

/// 화면 전환 시간을 없애 뒤로 가기가 문항 위치에 바로 닿게 한다.
class PilotRoute<T> extends MaterialPageRoute<T> {
  PilotRoute({required super.builder, this.marker});

  /// 예전 시작 경로를 구분하던 표식. 다시 하기는 첫 화면까지 돌아간다.
  final String? marker;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

class PilotHomePage extends StatelessWidget {
  const PilotHomePage({super.key, required this.host});

  final PilotHost host;

  @override
  Widget build(BuildContext context) {
    return PilotPlace(
      host: host,
      stage: PilotStage.home,
      child: ListenableBuilder(
        listenable: host,
        builder: (context, _) {
          final bundle = host.bundle!;
          final code = AppLocaleScope.of(context).languageCode;
          final title = _bundleText(bundle, code, 'common.ui.home.title');
          final quizzes = orderedHomeQuizzes(bundle.quizzes, pilotHomeQuizId());
          final playable = host.quiz;
          return _scaffold(
            context: context,
            title: title,
            children: [
              if (playable == null)
                Text(
                  _bundleText(bundle, code, 'life_tactics.pilot.unavailable'),
                  key: const Key('pilot-error'),
                )
              else
                for (var index = 0; index < quizzes.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.sectionGap),
                  if (quizzes[index].quizId == playable.quizId)
                    _LifeTacticsHomeCard(host: host)
                  else
                    _ComingSoonCard(host: host, quiz: quizzes[index]),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _LifeTacticsHomeCard extends StatelessWidget {
  const _LifeTacticsHomeCard({required this.host});

  final PilotHost host;

  @override
  Widget build(BuildContext context) {
    final bundle = host.bundle!;
    final code = AppLocaleScope.of(context).languageCode;
    final quiz = host.quiz;
    final pilot = host.pilot;
    final retry = _bundleText(bundle, code, 'life_tactics.pilot.imageRetry');
    final Widget details;
    if (quiz != null && pilot != null && host.canPlay) {
      details = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _bundleText(bundle, code, quiz.titleTextKey),
            style: AppTypography.rolesOf(context).resultName,
          ),
          const SizedBox(height: AppSpacing.stackGap),
          Text(
            _bundleText(bundle, code, quiz.introTextKey),
            style: AppTypography.rolesOf(context).body,
          ),
          const SizedBox(height: AppSpacing.stackGap),
          Text(
            _bundleText(bundle, code, 'life_tactics.pilot.length', {
              'questions': host.questionItems.length,
              'scenes': host.sceneItems.length,
            }),
            key: const Key('pilot-length'),
            style: AppTypography.rolesOf(context).secondary,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppButton(
            key: const Key('pilot-start'),
            label: _bundleText(bundle, code, 'common.ui.quiz.start'),
            onPressed: () => _startLifeTactics(context, host),
          ),
        ],
      );
    } else {
      details = Text(
        _bundleText(bundle, code, 'life_tactics.pilot.unavailable'),
        key: const Key('pilot-error'),
      );
    }
    return AppCard(
      key: const Key('home-life-tactics'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PilotImage(
                    asset: LifeTacticsArt.stadium,
                    fit: BoxFit.cover,
                    retryLabel: retry,
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(
                      height: 150,
                      child: PilotImage(
                        asset: LifeTacticsArt.coach,
                        fit: BoxFit.contain,
                        retryLabel: retry,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: details,
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.host, required this.quiz});

  final PilotHost host;
  final QuizContent quiz;

  @override
  Widget build(BuildContext context) {
    final bundle = host.bundle!;
    final code = AppLocaleScope.of(context).languageCode;
    return AppCard(
      key: Key('home-quiz-${quiz.quizId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bundleText(bundle, code, quiz.titleTextKey),
            style: AppTypography.rolesOf(context).resultName,
          ),
          const SizedBox(height: AppSpacing.stackGap),
          Text(
            _bundleText(bundle, code, 'common.ui.home.comingSoon'),
            key: Key('home-coming-soon-${quiz.quizId}'),
            style: AppTypography.rolesOf(context).secondary,
          ),
        ],
      ),
    );
  }
}

void _startLifeTactics(BuildContext context, PilotHost host) {
  if (!host.ensureQuestions()) {
    return;
  }
  final index = host.questionIndex;
  Navigator.of(context)
      .push(
        PilotRoute<void>(
          builder: (_) => PilotQuestionPage(host: host, index: index),
        ),
      )
      .then((_) => host.focusQuestion(index));
}

class PilotQuestionPage extends StatelessWidget {
  const PilotQuestionPage({super.key, required this.host, required this.index});

  final PilotHost host;
  final int index;

  @override
  Widget build(BuildContext context) {
    return PilotPlace(
      host: host,
      stage: PilotStage.question,
      questionIndex: index,
      child: ListenableBuilder(
        listenable: host,
        builder: (context, _) {
          final bundle = host.bundle!;
          final code = AppLocaleScope.of(context).languageCode;
          final quiz = host.quiz!;
          final items = host.questionItems;
          final question = items[index];
          final options = quiz.optionsFor(question.scaleId);
          final last = index == items.length - 1;
          final selected = host.questionSelection(index);
          final pilot = host.pilot!;
          final nextLabel = last
              ? _sceneText(pilot, code, 'life_tactics.scenario.ui.open')
              : _bundleText(bundle, code, 'common.ui.quiz.next');
          return _scaffold(
            context: context,
            title: _bundleText(bundle, code, quiz.titleTextKey),
            onBack: () => Navigator.of(context).pop(),
            children: [
              AppProgress(
                key: const Key('pilot-progress'),
                current: index + 1,
                total: items.length,
                label: _bundleText(bundle, code, 'common.ui.quiz.progress', {
                  'current': index + 1,
                  'total': items.length,
                }),
              ),
              const SizedBox(height: 12),
              Text(
                _bundleText(bundle, code, question.promptTextKey),
                key: const Key('pilot-prompt'),
                style: AppTypography.rolesOf(context).question,
              ),
              const SizedBox(height: AppSpacing.stackGap),
              for (
                var optionIndex = 0;
                optionIndex < options.length;
                optionIndex++
              ) ...[
                AppChoiceOption(
                  key: Key('pilot-choice-$optionIndex'),
                  label: _bundleText(
                    bundle,
                    code,
                    options[optionIndex].labelTextKey,
                  ),
                  selected: selected == options[optionIndex].optionId,
                  onPressed: () =>
                      host.selectQuestion(index, options[optionIndex].optionId),
                ),
                if (optionIndex != options.length - 1)
                  const SizedBox(height: 8),
              ],
            ],
            footer: Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('pilot-back'),
                    label: _bundleText(bundle, code, 'common.ui.quiz.back'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.inlineGap),
                Expanded(
                  child: AppButton(
                    key: const Key('pilot-next'),
                    label: nextLabel,
                    onPressed: selected == null
                        ? null
                        : () {
                            final navigator = Navigator.of(context);
                            if (last) {
                              host.ensureScenes();
                              host.focusScene(0, notify: false);
                              navigator
                                  .push(
                                    PilotRoute<void>(
                                      builder: (_) =>
                                          PilotScenePage(host: host, index: 0),
                                    ),
                                  )
                                  .then((_) => host.focusQuestion(index));
                              return;
                            }
                            final next = index + 1;
                            host.focusQuestion(next, notify: false);
                            navigator
                                .push(
                                  PilotRoute<void>(
                                    builder: (_) => PilotQuestionPage(
                                      host: host,
                                      index: next,
                                    ),
                                  ),
                                )
                                .then((_) => host.focusQuestion(index));
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PilotScenePage extends StatelessWidget {
  const PilotScenePage({super.key, required this.host, required this.index});

  final PilotHost host;
  final int index;

  @override
  Widget build(BuildContext context) {
    return PilotPlace(
      host: host,
      stage: PilotStage.scene,
      sceneIndex: index,
      child: ListenableBuilder(
        listenable: host,
        builder: (context, _) {
          final bundle = host.bundle!;
          final pilot = host.pilot!;
          final code = AppLocaleScope.of(context).languageCode;
          final scenes = host.sceneItems;
          final scene = scenes[index];
          final options = [...scene.options]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final last = index == scenes.length - 1;
          final selected = host.sceneSelection(index);
          return _scaffold(
            context: context,
            title: _sceneText(pilot, code, 'life_tactics.scenario.ui.title'),
            onBack: () => Navigator.of(context).pop(),
            children: [
              Text(
                _sceneText(pilot, code, 'life_tactics.scenario.ui.intro'),
                style: AppTypography.rolesOf(context).secondary,
              ),
              const SizedBox(height: AppSpacing.stackGap),
              AppProgress(
                key: const Key('pilot-scene-progress'),
                current: index + 1,
                total: scenes.length,
                label: _sceneText(
                  pilot,
                  code,
                  'life_tactics.scenario.ui.progress',
                  {'current': index + 1, 'total': scenes.length},
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _sceneText(pilot, code, scene.promptTextKey),
                key: const Key('pilot-scene-prompt'),
                style: AppTypography.rolesOf(context).question,
              ),
              const SizedBox(height: AppSpacing.stackGap),
              for (
                var optionIndex = 0;
                optionIndex < options.length;
                optionIndex++
              ) ...[
                AppChoiceOption(
                  key: Key('pilot-scene-choice-$optionIndex'),
                  label: _sceneText(
                    pilot,
                    code,
                    options[optionIndex].labelTextKey,
                  ),
                  selected: selected == options[optionIndex].optionId,
                  onPressed: () =>
                      host.selectScene(index, options[optionIndex].optionId),
                ),
                if (optionIndex != options.length - 1)
                  const SizedBox(height: 8),
              ],
              if (host.failure != null) ...[
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  host.failure!,
                  key: const Key('pilot-error'),
                  style: AppTypography.rolesOf(context).body,
                ),
              ],
            ],
            footer: Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('pilot-scene-back'),
                    label: _bundleText(bundle, code, 'common.ui.quiz.back'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.inlineGap),
                Expanded(
                  child: AppButton(
                    key: Key(last ? 'pilot-scene-finish' : 'pilot-scene-next'),
                    label: last
                        ? _sceneText(
                            pilot,
                            code,
                            'life_tactics.scenario.ui.finish',
                          )
                        : _bundleText(bundle, code, 'common.ui.quiz.next'),
                    onPressed: selected == null
                        ? null
                        : () {
                            final navigator = Navigator.of(context);
                            if (!last) {
                              final next = index + 1;
                              host.focusScene(next, notify: false);
                              navigator
                                  .push(
                                    PilotRoute<void>(
                                      builder: (_) => PilotScenePage(
                                        host: host,
                                        index: next,
                                      ),
                                    ),
                                  )
                                  .then((_) => host.focusScene(index));
                              return;
                            }
                            try {
                              host.finish();
                            } on QuizFailure catch (error) {
                              host.reportFailure(error.message);
                              return;
                            }
                            navigator
                                .push(
                                  PilotRoute<void>(
                                    builder: (_) => PilotResultPage(host: host),
                                  ),
                                )
                                .then((_) => host.focusScene(index));
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PilotResultPage extends StatelessWidget {
  const PilotResultPage({super.key, required this.host});

  final PilotHost host;

  @override
  Widget build(BuildContext context) {
    return PilotPlace(
      host: host,
      stage: PilotStage.result,
      child: ListenableBuilder(
        listenable: host,
        builder: (context, _) {
          final bundle = host.bundle!;
          final quiz = host.quiz!;
          final pilot = host.pilot!;
          final code = AppLocaleScope.of(context).languageCode;
          final outcome = host.outcome;
          final tally = host.tally;
          if (outcome == null || tally == null) {
            return _scaffold(
              context: context,
              title: _bundleText(bundle, code, quiz.titleTextKey),
              onBack: () => Navigator.of(context).pop(),
              children: [
                Text(
                  _bundleText(bundle, code, 'life_tactics.pilot.unavailable'),
                  key: const Key('pilot-error'),
                ),
              ],
            );
          }
          final result = quiz.resultTypes.firstWhere(
            (item) => item.resultTypeId == outcome.resultTypeId,
          );
          final name = _bundleText(bundle, code, result.nameTextKey);
          final asset = LifeTacticsArt.saidaAsset(result.resultTypeId);
          final rows = LifeTacticsArt.markerRows(result.formation);
          final roles = AppTypography.rolesOf(context);
          final retry = _bundleText(
            bundle,
            code,
            'life_tactics.pilot.imageRetry',
          );
          String axisName(String id) {
            return _bundleText(
              bundle,
              code,
              quiz.dimensions
                  .firstWhere((item) => item.dimensionId == id)
                  .nameTextKey,
            );
          }

          final leaders = tally.leaders.map(axisName).join(' · ');
          return _scaffold(
            context: context,
            title: _bundleText(bundle, code, quiz.titleTextKey),
            onBack: () => Navigator.of(context).pop(),
            children: [
              Text(
                name,
                key: const Key('pilot-result'),
                style: roles.resultName,
              ),
              const SizedBox(height: AppSpacing.stackGap),
              DecoratedBox(
                key: const Key('pilot-formation-frame'),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.button),
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bundleText(
                          bundle,
                          code,
                          'life_tactics.result.formationTitle',
                          {'formation': result.formation},
                        ),
                        key: const Key('pilot-formation'),
                        style: roles.body,
                      ),
                      const SizedBox(height: AppSpacing.stackGap),
                      _ResultLine(
                        asset: asset,
                        name: name,
                        rows: rows,
                        labels: _lineLabels(bundle, code, quiz),
                        retryLabel: retry,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Text(
                _bundleText(bundle, code, result.catchphraseKey),
                key: const Key('pilot-catchphrase'),
                style: roles.saida,
              ),
              const SizedBox(height: AppSpacing.stackGap),
              Text(
                _bundleText(bundle, code, result.descriptionKey),
                key: const Key('pilot-description'),
                style: roles.body,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Text(
                _bundleText(bundle, code, 'common.ui.result.axes'),
                style: roles.secondary,
              ),
              const SizedBox(height: AppSpacing.inlineGap),
              for (final axis in host.axisOrder)
                Text(
                  '${axisName(axis)} ${outcome.displayScores[axis]}',
                  key: Key('pilot-score-$axis'),
                  style: roles.body,
                ),
              if (outcome.tiedDimensionIds.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  _bundleText(bundle, code, 'life_tactics.result.tie.note'),
                  style: roles.secondary,
                ),
              ],
              if (outcome.path == 'balance') ...[
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  _bundleText(bundle, code, 'life_tactics.result.balance.note'),
                  key: const Key('pilot-reason'),
                  style: roles.body,
                ),
              ],
              if (outcome.adjacentChanges) ...[
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  _bundleText(
                    bundle,
                    code,
                    'life_tactics.result.boundary.note',
                  ),
                  key: const Key('pilot-boundary'),
                  style: roles.secondary,
                ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              Text(
                _bundleText(bundle, code, 'life_tactics.pilot.separate'),
                key: const Key('pilot-separate'),
                style: roles.secondary,
              ),
              const SizedBox(height: AppSpacing.stackGap),
              Text(
                _sceneText(pilot, code, 'life_tactics.scenario.ui.summary'),
                key: const Key('pilot-scene-summary'),
                style: roles.secondary,
              ),
              const SizedBox(height: AppSpacing.inlineGap),
              for (final axis in host.axisOrder)
                Text(
                  _sceneText(pilot, code, 'life_tactics.scenario.ui.count', {
                    'axis': axisName(axis),
                    'count': tally.counts[axis] ?? 0,
                  }),
                  key: Key('pilot-scene-count-$axis'),
                  style: roles.body,
                ),
              const SizedBox(height: AppSpacing.stackGap),
              Text(
                _sceneText(
                  pilot,
                  code,
                  tally.kind == 'balanced'
                      ? 'life_tactics.scenario.ui.balanced'
                      : tally.kind == 'tie'
                      ? 'life_tactics.scenario.ui.tie'
                      : 'life_tactics.scenario.ui.lead',
                  {
                    'axis': tally.leaders.isEmpty
                        ? ''
                        : axisName(tally.leaders.first),
                    'axes': leaders,
                  },
                ),
                key: const Key('pilot-scene-kind'),
                style: roles.body,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _SaidaClosing(
                line: _bundleText(
                  bundle,
                  code,
                  'life_tactics.result.closing.line',
                ),
                emphasis: _bundleText(
                  bundle,
                  code,
                  'life_tactics.result.closing.emphasis',
                ),
                retryLabel: retry,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              AppButton(
                key: const Key('pilot-share'),
                label: _bundleText(bundle, code, 'life_tactics.pilot.share'),
                onPressed: () {
                  Navigator.of(context).push(
                    PilotRoute<void>(
                      builder: (_) => PilotSharePage(host: host),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.optionGap),
              AppButton(
                key: const Key('pilot-feedback'),
                label: _bundleText(bundle, code, 'life_tactics.pilot.feedback'),
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  pilotOpenExternalLink(PilotFeedback.uriFor(outcome));
                },
              ),
              const SizedBox(height: AppSpacing.inlineGap),
              Text(
                _bundleText(bundle, code, 'life_tactics.pilot.feedbackNote'),
                key: const Key('pilot-feedback-note'),
                style: roles.secondary,
              ),
              const SizedBox(height: AppSpacing.optionGap),
              AppButton(
                key: const Key('pilot-retry'),
                label: _bundleText(bundle, code, 'common.ui.result.retry'),
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  host.reset();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: AppSpacing.optionGap),
              AppButton(
                key: const Key('pilot-home'),
                label: _bundleText(bundle, code, 'life_tactics.pilot.home'),
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  host.goHome();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class PilotSharePage extends StatefulWidget {
  const PilotSharePage({super.key, required this.host});

  final PilotHost host;

  @override
  State<PilotSharePage> createState() => _PilotSharePageState();
}

class _PilotSharePageState extends State<PilotSharePage> {
  Uint8List? _png;
  String? _signature;
  String? _noticeKey;
  String? _manualUrl;
  var _offerCopy = false;
  var _preparing = false;
  var _acting = false;
  var _captureSerial = 0;

  PilotHost get host => widget.host;

  @override
  void initState() {
    super.initState();
    host.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _captureSerial += 1;
    host.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    final locale = AppLocaleScope.of(context);
    final card = _cardFor(locale.languageCode, export: false);
    final fontsReady =
        locale.isFontReady || locale.readiness == AppFontReadiness.failed;
    final signature = card == null || !fontsReady
        ? null
        : _signatureFor(locale.languageCode, card);
    if (signature == _signature && (_png != null || _preparing)) {
      return;
    }
    setState(() {
      _signature = signature;
      _png = null;
      _noticeKey = null;
      _manualUrl = null;
      _offerCopy = false;
      _preparing = signature != null;
    });
    if (signature != null) {
      _schedule(signature);
    }
  }

  void _schedule(String signature) {
    final serial = ++_captureSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _captureSerial) {
        return;
      }
      _capture(serial, signature);
    });
  }

  Future<void> _capture(int serial, String signature) async {
    final card = _cardFor(
      AppLocaleScope.of(context).languageCode,
      export: true,
    );
    if (card == null) {
      return;
    }
    try {
      final bytes = await pilotCaptureCard(
        context,
        card: card,
        assets: [
          LifeTacticsArt.shareTemplate,
          LifeTacticsArt.tacticsBoard,
          LifeTacticsArt.marker,
          card.saidaAsset,
        ],
      );
      if (!mounted || serial != _captureSerial || signature != _signature) {
        return;
      }
      setState(() {
        _png = bytes;
        _preparing = false;
      });
    } catch (_) {
      if (!mounted || serial != _captureSerial) {
        return;
      }
      setState(() {
        _png = null;
        _preparing = false;
        _noticeKey = 'life_tactics.pilot.sharePrepareFailed';
      });
    }
  }

  void _share() {
    final link = _link();
    if (link == null || _acting) {
      return;
    }
    if (pilotCanShareLink(link)) {
      _shareWithSystem(link);
      return;
    }
    if (pilotUsesKakaoShare(
      systemShare: false,
      kakaoTalk: pilotKakaoTalkBrowser(),
    )) {
      _shareWithKakao(link);
      return;
    }
    _showCopyOnly();
  }

  void _shareWithSystem(PilotShareLink link) {
    final serial = _captureSerial;
    final pending = pilotShareLink(link);
    setState(() {
      _acting = true;
      _manualUrl = null;
      _offerCopy = false;
      _clearShareNotice();
    });
    pending.then((result) {
      if (!mounted) {
        return;
      }
      if (serial != _captureSerial) {
        setState(() => _acting = false);
        return;
      }
      if (result == PilotShareFileResult.cancelled ||
          result == PilotShareFileResult.opened) {
        setState(() {
          _acting = false;
          _manualUrl = null;
          _offerCopy = false;
          _clearShareNotice();
        });
        return;
      }
      _showCopyOnly();
    });
  }

  void _shareWithKakao(PilotShareLink link) {
    final card = _visibleCard();
    if (card == null) {
      _showCopyOnly();
      return;
    }
    final code = AppLocaleScope.of(context).languageCode;
    final serial = _captureSerial;
    final pending = pilotSendKakao(
      PilotKakaoShare(
        text: card.name,
        buttonTitle: _bundleText(
          host.bundle!,
          code,
          'life_tactics.pilot.kakaoDiagnose',
        ),
        webUrl: link.url,
        mobileWebUrl: link.url,
      ),
    );
    setState(() {
      _acting = true;
      _manualUrl = null;
      _offerCopy = false;
      _clearShareNotice();
    });
    pending.then((result) {
      if (!mounted) {
        return;
      }
      if (serial != _captureSerial) {
        setState(() => _acting = false);
        return;
      }
      if (result == PilotShareFileResult.cancelled ||
          result == PilotShareFileResult.opened) {
        setState(() {
          _acting = false;
          _manualUrl = null;
          _offerCopy = false;
          _clearShareNotice();
        });
        return;
      }
      _showCopyOnly();
    });
  }

  void _showCopyOnly() {
    setState(() {
      _acting = false;
      _manualUrl = null;
      _offerCopy = true;
      _clearShareNotice();
    });
  }

  void _clearShareNotice() {
    if (_noticeKey == 'life_tactics.pilot.linkCopied' ||
        _noticeKey == 'life_tactics.pilot.browserShareHint') {
      _noticeKey = null;
    }
  }

  void _copyLink(PilotShareLink link, int serial) {
    final pending = pilotCopyText(link.url.toString());
    setState(() => _acting = true);
    pending.then((copied) {
      if (!mounted) {
        return;
      }
      if (serial != _captureSerial) {
        setState(() => _acting = false);
        return;
      }
      setState(() {
        _acting = false;
        if (copied) {
          _noticeKey = 'life_tactics.pilot.linkCopied';
          _manualUrl = null;
          _offerCopy = false;
        } else {
          _noticeKey = null;
          _manualUrl = link.url.toString();
          _offerCopy = true;
        }
      });
    });
  }

  void _save(PilotShareFile file) {
    final pending = pilotSaveFile(file);
    setState(() {
      _acting = true;
      _noticeKey = null;
    });
    pending.then((result) {
      if (!mounted || !identical(file.bytes, _png)) {
        return;
      }
      setState(() {
        _acting = false;
        _manualUrl = null;
        _noticeKey = switch (result) {
          PilotSaveFileResult.failed => 'life_tactics.pilot.saveFailed',
          PilotSaveFileResult.opened => 'life_tactics.pilot.saveOpened',
          PilotSaveFileResult.downloaded => null,
        };
      });
    });
  }

  PilotShareLink? _link() {
    final card = _visibleCard();
    final bundle = host.bundle;
    final quiz = host.quiz;
    if (card == null || bundle == null || quiz == null) {
      return null;
    }
    final code = AppLocaleScope.of(context).languageCode;
    return PilotShareLink(
      url: pilotDiagnosisLink(quiz.quizId),
      text: _bundleText(bundle, code, 'life_tactics.pilot.shareLinkText', {
        'name': card.name,
        'quiz': card.quizTitle,
      }),
    );
  }

  PilotShareFile? _file() {
    final bytes = _png;
    final card = _visibleCard();
    if (bytes == null || card == null) {
      return null;
    }
    return PilotShareFile(
      bytes: bytes,
      saveHint: _bundleText(
        host.bundle!,
        AppLocaleScope.of(context).languageCode,
        'life_tactics.pilot.holdImage',
      ),
      closeLabel: _bundleText(
        host.bundle!,
        AppLocaleScope.of(context).languageCode,
        'life_tactics.pilot.close',
      ),
      filename: PilotShareFile.filenameFor(
        resultTypeId: card.resultTypeId,
        languageCode: AppLocaleScope.of(context).languageCode,
      ),
    );
  }

  LifeTacticsShareCard? _visibleCard() {
    return _cardFor(AppLocaleScope.of(context).languageCode, export: false);
  }

  String _signatureFor(String languageCode, LifeTacticsShareCard card) {
    return [
      languageCode,
      card.resultTypeId,
      card.saidaAsset,
      card.formation,
      card.formationTitle,
      card.formationCounts,
      card.lineLabels.join('\u0001'),
      card.name,
      card.catchphrase,
      card.description,
      card.brand,
      card.quizTitle,
      card.studio,
    ].join('\u0001');
  }

  LifeTacticsShareCard? _cardFor(String languageCode, {required bool export}) {
    final bundle = host.bundle;
    final quiz = host.quiz;
    final outcome = host.outcome;
    if (bundle == null || quiz == null || outcome == null) {
      return null;
    }
    final result = quiz.resultTypes
        .where((item) => item.resultTypeId == outcome.resultTypeId)
        .firstOrNull;
    if (result == null) {
      return null;
    }
    return LifeTacticsShareCard(
      brand: _bundleText(bundle, languageCode, 'life_tactics.pilot.cardBrand'),
      quizTitle: _bundleText(bundle, languageCode, quiz.titleTextKey),
      formation: result.formation,
      formationTitle: LifeTacticsArt.lineCounts(result.formation) == null
          ? ''
          : _bundleText(
              bundle,
              languageCode,
              'life_tactics.result.formationTitle',
              {'formation': result.formation},
            ),
      formationCounts:
          _formationCounts(bundle, languageCode, quiz, result.formation) ?? '',
      lineLabels: _lineLabels(bundle, languageCode, quiz),
      name: _bundleText(bundle, languageCode, result.nameTextKey),
      catchphrase: _bundleText(bundle, languageCode, result.catchphraseKey),
      description: _bundleText(bundle, languageCode, result.descriptionKey),
      studio: _bundleText(
        bundle,
        languageCode,
        'life_tactics.pilot.cardStudio',
      ),
      resultTypeId: result.resultTypeId,
      saidaAsset: LifeTacticsArt.saidaAsset(result.resultTypeId),
      retryLabel: _bundleText(
        bundle,
        languageCode,
        'life_tactics.pilot.imageRetry',
      ),
      export: export,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = host.bundle!;
    final code = AppLocaleScope.of(context).languageCode;
    final card = _visibleCard();
    final fileReady = _png != null && !_acting;
    final link = _link();
    final shareKey =
        pilotUsesKakaoShare(
          systemShare: link != null && pilotCanShareLink(link),
          kakaoTalk: pilotKakaoTalkBrowser(),
        )
        ? 'life_tactics.pilot.kakaoShare'
        : 'life_tactics.pilot.shareAction';
    final notice = _noticeKey == null
        ? null
        : _bundleText(bundle, code, _noticeKey!);
    return PilotPlace(
      host: host,
      stage: PilotStage.share,
      child: _scaffold(
        context: context,
        title: _bundleText(bundle, code, 'life_tactics.pilot.share'),
        onBack: () => Navigator.of(context).pop(),
        children: [
          if (card == null)
            Text(
              _bundleText(bundle, code, 'life_tactics.pilot.unavailable'),
              key: const Key('pilot-error'),
            )
          else
            card,
          const SizedBox(height: AppSpacing.sectionGap),
          _ShareActionButtons(
            shareLabel: _bundleText(bundle, code, shareKey),
            saveLabel: _bundleText(
              bundle,
              code,
              'life_tactics.pilot.saveImage',
            ),
            onShare: card != null && !_acting ? _share : null,
            onSave: fileReady ? () => _save(_file()!) : null,
          ),
          if (notice != null) ...[
            const SizedBox(height: AppSpacing.inlineGap),
            Text(
              notice,
              key: const Key('pilot-share-notice'),
              style: AppTypography.rolesOf(context).secondary,
            ),
          ],
          if (_offerCopy)
            TextButton(
              key: const Key('pilot-copy-link'),
              onPressed: _acting || _link() == null
                  ? null
                  : () => _copyLink(_link()!, _captureSerial),
              child: Text(
                _bundleText(bundle, code, 'life_tactics.pilot.copyLink'),
              ),
            ),
          if (_manualUrl != null) ...[
            const SizedBox(height: AppSpacing.inlineGap),
            SelectableText(
              _manualUrl!,
              key: const Key('pilot-share-link'),
              style: AppTypography.rolesOf(context).secondary,
            ),
          ],
          const SizedBox(height: AppSpacing.optionGap),
          AppButton(
            key: const Key('pilot-share-close'),
            label: _bundleText(bundle, code, 'life_tactics.pilot.close'),
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ShareActionButtons extends StatelessWidget {
  const _ShareActionButtons({
    required this.shareLabel,
    required this.saveLabel,
    required this.onShare,
    required this.onSave,
  });

  final String shareLabel;
  final String saveLabel;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 480 || scale > 1.15;
        AppButton shareButton({required bool expand}) {
          return AppButton(
            key: const Key('pilot-share-action'),
            label: shareLabel,
            expand: expand,
            onPressed: onShare,
          );
        }

        AppButton saveButton({required bool expand}) {
          return AppButton(
            key: const Key('pilot-share-save'),
            label: saveLabel,
            variant: AppButtonVariant.secondary,
            expand: expand,
            onPressed: onSave,
          );
        }

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              shareButton(expand: true),
              const SizedBox(height: AppSpacing.optionGap),
              saveButton(expand: true),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: shareButton(expand: false),
              ),
            ),
            const SizedBox(width: AppSpacing.optionGap),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: saveButton(expand: false),
              ),
            ),
          ],
        );
      },
    );
  }
}

class TacticsBoard extends StatelessWidget {
  const TacticsBoard({
    super.key,
    required this.rows,
    required this.retryLabel,
    this.semanticsLabel,
    this.keyed = true,
  });

  final List<int> rows;
  final String retryLabel;

  /// 포메이션을 한 번만 읽게 한다. 결과 화면은 보이는 글자가 그 역할을 한다.
  final String? semanticsLabel;

  /// 저장용 복제 카드는 화면의 마커 키와 겹치지 않는다.
  final bool keyed;

  @override
  Widget build(BuildContext context) {
    final label = rows.isEmpty ? 'empty' : rows.join('-');
    return Semantics(
      key: semanticsLabel == null ? null : const Key('pilot-share-formation'),
      label: semanticsLabel,
      container: semanticsLabel != null,
      excludeSemantics: semanticsLabel != null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final marker = width * LifeTacticsArt.markerWidthFactor;
          return Stack(
            key: keyed ? Key('pilot-marker-rows-$label') : null,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: PilotImage(
                  asset: LifeTacticsArt.tacticsBoard,
                  fit: BoxFit.fill,
                  retryLabel: retryLabel,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    width * 0.075,
                    height * LifeTacticsArt.boardInsetTop,
                    width * 0.075,
                    height * LifeTacticsArt.boardInsetBottom,
                  ),
                  child: Column(
                    children: [
                      for (final count in rows)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (var index = 0; index < count; index++)
                                Image.asset(
                                  LifeTacticsArt.marker,
                                  width: marker,
                                  height: marker,
                                  excludeFromSemantics: true,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LifeTacticsShareCard extends StatelessWidget {
  const LifeTacticsShareCard({
    super.key,
    required this.brand,
    required this.quizTitle,
    required this.formation,
    this.formationTitle = '',
    this.formationCounts = '',
    this.lineLabels = const [],
    required this.name,
    required this.catchphrase,
    required this.description,
    required this.studio,
    required this.resultTypeId,
    required this.saidaAsset,
    required this.retryLabel,
    this.export = false,
  });

  final String brand;
  final String quizTitle;
  final String formation;
  final String formationTitle;
  final String formationCounts;
  final List<String> lineLabels;
  final String name;
  final String catchphrase;
  final String description;
  final String studio;
  final String resultTypeId;
  final String saidaAsset;
  final String retryLabel;

  /// 저장용 복제. 화면의 키와 낭독 레이블을 다시 만들지 않는다.
  final bool export;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scaler = MediaQuery.textScalerOf(context);
        double px(double size) => size * width / 360;
        final family = AppTypography.rolesOf(context).body.fontFamily;
        TextStyle style(double size, FontWeight weight, Color color) {
          return TextStyle(
            fontFamily: family,
            fontSize: px(size),
            fontWeight: weight,
            height: 1.25,
            color: color,
            // CanvasKit replays an unset decoration as a yellow line in toImage.
            decoration: TextDecoration.none,
            decorationColor: color,
          );
        }

        final textWidth = width * 0.86;
        final gap = px(6);
        final block =
            _shareTextHeight(
              name,
              style(24, FontWeight.w800, AppColors.textPrimary),
              textWidth,
              scaler,
            ) +
            gap +
            _shareTextHeight(
              catchphrase,
              style(14, FontWeight.w700, AppColors.primary),
              textWidth,
              scaler,
            ) +
            gap +
            _shareTextHeight(
              description,
              style(12, FontWeight.w500, AppColors.textPrimary),
              textWidth,
              scaler,
            );
        final extra = block > width * 0.29 ? block - width * 0.29 : 0.0;
        final height = width + extra;
        final saida = LifeTacticsArt.shareSaidaBox;
        final rows = LifeTacticsArt.markerRows(formation);
        final showFullText = extra > 0;
        return SizedBox(
          key: Key(export ? 'pilot-share-export' : 'pilot-share-card'),
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: width,
                height: width,
                child: PilotImage(
                  asset: LifeTacticsArt.shareTemplate,
                  fit: BoxFit.fill,
                  retryLabel: retryLabel,
                ),
              ),
              Positioned(
                left: width * LifeTacticsArt.shareStadiumMaskLeft,
                top: width * LifeTacticsArt.shareStadiumMaskTop,
                width: width * LifeTacticsArt.shareStadiumMaskWidth,
                height: width * LifeTacticsArt.shareStadiumMaskHeight,
                child: const ColoredBox(color: AppColors.background),
              ),
              Positioned(
                left: width * LifeTacticsArt.shareBlurLeft,
                top: width * LifeTacticsArt.shareBlurTop,
                width: width * LifeTacticsArt.shareBlurWidth,
                height: width * LifeTacticsArt.shareBlurHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(px(10)),
                  child: PilotImage(
                    asset: LifeTacticsArt.stadium,
                    fit: BoxFit.cover,
                    retryLabel: retryLabel,
                  ),
                ),
              ),
              Positioned(
                left: width * LifeTacticsArt.shareBlurLeft,
                top: width * LifeTacticsArt.shareBlurTop,
                width: width * LifeTacticsArt.shareBlurWidth,
                height: width * LifeTacticsArt.shareBlurHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(px(10)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: px(3), sigmaY: px(3)),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              if (showFullText)
                Positioned(
                  left: 0,
                  right: 0,
                  top: width * 0.96,
                  bottom: 0,
                  child: const ColoredBox(color: AppColors.background),
                ),
              Positioned(
                left: width * 0.07,
                top: width * 0.045,
                width: width * 0.46,
                child: Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(18, FontWeight.w800, AppColors.textPrimary),
                ),
              ),
              Positioned(
                right: width * 0.07,
                top: width * 0.052,
                width: width * 0.38,
                child: Text(
                  quizTitle,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style(12, FontWeight.w600, AppColors.textSecondary),
                ),
              ),
              if (formationTitle.isNotEmpty || formationCounts.isNotEmpty)
                Positioned(
                  right: width * 0.07,
                  top: width * 0.108,
                  width: width * 0.78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (formationTitle.isNotEmpty)
                        Text(
                          formationTitle,
                          textAlign: TextAlign.right,
                          style: style(
                            12,
                            FontWeight.w700,
                            AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              Positioned(
                left: width * saida.left,
                top: width * saida.top,
                width: width * saida.size,
                height: width * saida.size,
                child: KeyedSubtree(
                  key: export ? null : Key('pilot-share-saida:$saidaAsset'),
                  child: PilotImage(
                    asset: saidaAsset,
                    fit: BoxFit.contain,
                    retryLabel: retryLabel,
                    semanticLabel: name,
                  ),
                ),
              ),
              if (lineLabels.length == 3)
                Positioned(
                  left: width * LifeTacticsArt.shareLabelLeft,
                  top: width * LifeTacticsArt.shareBoardTop,
                  width: width * LifeTacticsArt.shareLabelWidth,
                  height: width * LifeTacticsArt.shareBoardHeight,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.noScaling),
                    child: _FormationLabels(
                      labels: lineLabels,
                      style: TextStyle(
                        fontFamily: family,
                        fontSize: width * 0.03,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.none,
                        decorationColor: AppColors.textPrimary,
                      ),
                      idPrefix: export ? null : 'pilot-share-line-label',
                      singleLine: true,
                    ),
                  ),
                ),
              Positioned(
                key: export ? null : const Key('pilot-share-board'),
                left: width * LifeTacticsArt.shareBoardLeft,
                top: width * LifeTacticsArt.shareBoardTop,
                width: width * LifeTacticsArt.shareBoardWidth,
                height: width * LifeTacticsArt.shareBoardHeight,
                child: TacticsBoard(
                  rows: rows,
                  retryLabel: retryLabel,
                  semanticsLabel: export ? null : formation,
                  keyed: !export,
                ),
              ),
              Positioned(
                left: width * 0.07,
                right: width * 0.07,
                top: width * 0.62,
                bottom: showFullText ? null : width * 0.09,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: export ? null : const Key('pilot-share-name'),
                      maxLines: showFullText ? null : 2,
                      overflow: showFullText
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: style(24, FontWeight.w800, AppColors.textPrimary),
                    ),
                    SizedBox(height: px(6)),
                    Text(
                      catchphrase,
                      maxLines: showFullText ? null : 2,
                      overflow: showFullText
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: style(14, FontWeight.w700, AppColors.primary),
                    ),
                    SizedBox(height: px(6)),
                    Text(
                      description,
                      maxLines: showFullText ? null : 3,
                      overflow: showFullText
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: style(12, FontWeight.w500, AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: width * 0.07,
                bottom: width * 0.032,
                width: width * 0.34,
                child: Text(
                  studio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(11, FontWeight.w600, AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

double _shareTextHeight(
  String text,
  TextStyle style,
  double maxWidth,
  TextScaler scaler, {
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: maxLines,
  )..layout(maxWidth: maxWidth);
  return painter.size.height;
}

class PilotImage extends StatefulWidget {
  const PilotImage({
    super.key,
    required this.asset,
    required this.retryLabel,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String asset;
  final String retryLabel;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  State<PilotImage> createState() => _PilotImageState();
}

class _PilotImageState extends State<PilotImage> {
  var _attempt = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.asset.isEmpty) {
      return _retry();
    }
    return Image.asset(
      widget.asset,
      key: ValueKey('${widget.asset}-$_attempt'),
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      errorBuilder: (context, error, stackTrace) => _retry(),
    );
  }

  Widget _retry() {
    return AppButton(
      key: const Key('pilot-image-retry'),
      label: widget.retryLabel,
      variant: AppButtonVariant.secondary,
      expand: false,
      onPressed: () => setState(() => _attempt += 1),
    );
  }
}

Widget _scaffold({
  required BuildContext context,
  required String title,
  required List<Widget> children,
  VoidCallback? onBack,
  Widget? footer,
}) {
  final controller = AppLocaleScope.of(context);
  return Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: onBack == null
          ? null
          : IconButton(
              tooltip: title,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.rolesOf(context).body,
      ),
      actions: [
        PopupMenuButton<String>(
          key: const Key('language-menu'),
          onSelected: controller.select,
          itemBuilder: (context) {
            return [
              for (final code in AppFonts.released)
                PopupMenuItem<String>(
                  key: Key('language-$code'),
                  value: code,
                  child: Text(code),
                ),
            ];
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(controller.languageCode),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: AppContentFrame(
        child: footer != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: bounds.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: footer,
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
      ),
    ),
  );
}

List<String> _lineLabels(
  ContentBundle bundle,
  String language,
  QuizContent quiz,
) {
  String name(String id) {
    final dimension = quiz.dimensions
        .where((item) => item.dimensionId == id)
        .firstOrNull;
    if (dimension == null) {
      return '';
    }
    return _bundleText(bundle, language, dimension.nameTextKey);
  }

  return [name('richness'), name('meaning'), name('happiness')];
}

String? _formationCounts(
  ContentBundle bundle,
  String language,
  QuizContent quiz,
  String formation,
) {
  final counts = LifeTacticsArt.lineCounts(formation);
  if (counts == null) {
    return null;
  }
  String name(String id) {
    final dimension = quiz.dimensions
        .where((item) => item.dimensionId == id)
        .firstOrNull;
    if (dimension == null) {
      return id;
    }
    return _bundleText(bundle, language, dimension.nameTextKey);
  }

  return _bundleText(bundle, language, 'life_tactics.result.formationCounts', {
    'happiness': name('happiness'),
    'defense': counts[0],
    'meaning': name('meaning'),
    'midfield': counts[1],
    'richness': name('richness'),
    'attack': counts[2],
  });
}

String _bundleText(
  ContentBundle bundle,
  String language,
  String key, [
  Map<String, Object?> values = const {},
]) {
  return AppTextBook(bundle.locales)
      .resolve(language, key, values: values)
      .text;
}

String _sceneText(
  ScenarioPilot pilot,
  String language,
  String key, [
  Map<String, Object?> values = const {},
]) {
  return AppTextBook(pilot.locales).resolve(language, key, values: values).text;
}

/// 결과 본문 마지막의 윙크 초상과 말풍선. 공유 카드에는 넣지 않는다.
class _SaidaClosing extends StatelessWidget {
  const _SaidaClosing({
    required this.line,
    required this.emphasis,
    required this.retryLabel,
  });

  final String line;
  final String emphasis;
  final String retryLabel;

  /// 문항 안내 말풍선의 초상 크기. 결과 상단 사이다보다 작게 둔다.
  static const portraitSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final roles = AppTypography.rolesOf(context);
    return Row(
      key: const Key('pilot-closing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            key: const Key('pilot-closing-portrait'),
            width: portraitSize,
            height: portraitSize,
            child: PilotImage(
              asset: LifeTacticsArt.wink,
              fit: BoxFit.contain,
              retryLabel: retryLabel,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: CustomPaint(
            key: const Key('pilot-closing-tail'),
            size: const Size(10, 14),
            painter: const _LeftBubbleTail(AppColors.surfaceVariant),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            key: const Key('pilot-closing-bubble'),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line,
                    key: const Key('pilot-closing-line'),
                    style: roles.saida,
                  ),
                  Text(
                    emphasis,
                    key: const Key('pilot-closing-emphasis'),
                    style: roles.saida.copyWith(
                      fontWeight: roles.button.fontWeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 말풍선 왼쪽에서 사이다를 가리키는 꼬리.
class _LeftBubbleTail extends CustomPainter {
  const _LeftBubbleTail(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LeftBubbleTail oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 사이다 45, 전술판 55. 간격 10을 뺀 콘텐츠 폭을 한 줄로 채운다.
class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.asset,
    required this.name,
    required this.rows,
    required this.labels,
    required this.retryLabel,
  });

  final String asset;
  final String name;
  final List<int> rows;
  final List<String> labels;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final style = AppTypography.rolesOf(context).secondary;
        final previousLabel = constraints.maxWidth * 0.34;
        final boardWidth = constraints.maxWidth * 0.40;
        final previousSaida =
            (constraints.maxWidth - previousLabel - boardWidth - gap * 2).clamp(
              0.0,
              constraints.maxWidth,
            );
        final saidaWidth = previousSaida * 1.7;
        final labelWidth =
            (constraints.maxWidth - saidaWidth - boardWidth - gap * 2).clamp(
              0.0,
              constraints.maxWidth,
            );
        final boardHeight = boardWidth / 0.8;
        return SizedBox(
          key: const Key('pilot-result-line'),
          width: constraints.maxWidth,
          height: boardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: saidaWidth,
                height: boardHeight,
                child: Center(
                  child: SizedBox(
                    key: Key('pilot-saida-asset:$asset'),
                    width: saidaWidth,
                    height: saidaWidth,
                    child: PilotImage(
                      asset: asset,
                      fit: BoxFit.contain,
                      retryLabel: retryLabel,
                      semanticLabel: name,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: gap),
              SizedBox(
                width: labelWidth,
                height: boardHeight,
                child: _FormationLabels(
                  labels: labels,
                  style: style,
                  singleLine: true,
                ),
              ),
              const SizedBox(width: gap),
              SizedBox(
                width: boardWidth,
                height: boardHeight,
                child: TacticsBoard(rows: rows, retryLabel: retryLabel),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormationLabels extends StatelessWidget {
  const _FormationLabels({
    required this.labels,
    required this.style,
    this.idPrefix = 'pilot-line-label',
    this.singleLine = false,
  });

  final List<String> labels;
  final TextStyle style;
  final String? idPrefix;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final centers = LifeTacticsArt.lineCenters(height);
        final pitch = centers.length > 1 ? centers[1] - centers[0] : height;
        return Stack(
          key: idPrefix == null ? null : Key('${idPrefix}s'),
          children: [
            for (var index = 0; index < labels.length && index < 3; index++)
              Positioned(
                left: 0,
                right: 0,
                top: centers[index] - pitch / 2,
                height: pitch,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: singleLine
                        ? Text(
                            labels[index],
                            key: idPrefix == null
                                ? null
                                : Key('$idPrefix-$index'),
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.right,
                            style: style,
                          )
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Text(
                              labels[index],
                              key: idPrefix == null
                                  ? null
                                  : Key('$idPrefix-$index'),
                              textAlign: TextAlign.right,
                              style: style,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final RouteObserver<PageRoute<void>> pilotRouteObserver =
    RouteObserver<PageRoute<void>>();

/// 맨 앞 화면의 단계만 기록한다. 아래에 깔린 경로가 새로고침 위치를 덮지 않는다.
class PilotPlace extends StatefulWidget {
  const PilotPlace({
    super.key,
    required this.host,
    required this.stage,
    required this.child,
    this.questionIndex,
    this.sceneIndex,
  });

  final PilotHost host;
  final String stage;
  final int? questionIndex;
  final int? sceneIndex;
  final Widget child;

  @override
  State<PilotPlace> createState() => _PilotPlaceState();
}

class _PilotPlaceState extends State<PilotPlace> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      pilotRouteObserver.unsubscribe(this);
      pilotRouteObserver.subscribe(this, route);
      _remember();
    }
  }

  @override
  void dispose() {
    pilotRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => _remember();

  @override
  void didPopNext() => _remember();

  void _remember() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) {
        return;
      }
      widget.host.notePlace(
        widget.stage,
        questionIndex: widget.questionIndex,
        sceneIndex: widget.sceneIndex,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
