import 'package:material_ui/material_ui.dart';

import 'core/fonts/app_font_loader.dart';
import 'core/locale/app_locale_bootstrap.dart';
import 'core/locale/app_locale_store.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/content_models.dart';
import 'features/catalog/content_repository.dart';
import 'features/catalog/content_scope.dart';
import 'features/catalog/content_text.dart';
import 'features/quiz/quiz_engine.dart';
import 'features/quiz/quiz_session.dart';
import 'shared/widgets/app_button.dart';
import 'shared/widgets/app_card.dart';
import 'shared/widgets/app_choice_option.dart';
import 'shared/widgets/app_content_frame.dart';
import 'shared/widgets/app_progress.dart';
import 'shared/widgets/font_license_notice.dart';

/// 개발용 공통 UI 미리보기. 제품 진입점은 `lib/main.dart`다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UiPreviewApp());
}

class UiPreviewApp extends StatelessWidget {
  const UiPreviewApp({
    super.key,
    this.store,
    this.loader,
    this.deviceTags,
    this.repository,
    this.bundle,
  });

  final AppLocaleStore? store;
  final AppFontLoader? loader;
  final List<String>? deviceTags;
  final ContentRepository? repository;
  final ContentBundle? bundle;

  @override
  Widget build(BuildContext context) {
    if (bundle != null) {
      return _ready(bundle!);
    }
    return ContentLoader(
      repository: repository,
      version: pilotDataVersion,
      builder: (context, phase) {
        final loaded = phase.bundle;
        if (loaded == null) {
          return ContentPending(
            message: phase.error?.toString(),
            onRetry: phase.error == null ? null : phase.retry,
          );
        }
        return _ready(loaded);
      },
    );
  }

  Widget _ready(ContentBundle loaded) {
    return ContentScope(
      bundle: loaded,
      child: AppLocaleBootstrap(
        store: store,
        loader: loader,
        deviceTags: deviceTags,
        builder: (context, controller) {
          if (!controller.settled) {
            return const ContentPending();
          }
          return MaterialApp(
            title: 'Look At You UI Preview',
            debugShowCheckedModeBanner: false,
            locale: controller.locale,
            supportedLocales: AppFonts.supportedLocales,
            localizationsDelegates: AppTheme.localizationsDelegates,
            theme: AppTheme.forLanguage(controller.languageCode),
            themeAnimationDuration: Duration.zero,
            home: const UiPreviewPage(),
          );
        },
      ),
    );
  }
}

class _PreviewQuestion {
  const _PreviewQuestion(this.prompt, this.answers);

  final String prompt;
  final List<String> answers;
}

/// 미리보기 문구. 진단 원본이나 Excel 검수 상태를 바꾸지 않는다.
const _questions = <String, List<_PreviewQuestion>>{
  'ko': [
    _PreviewQuestion('최근에 일이 예상보다 길어지고 주변의 기대도 커졌을 때, 나는 어떤 쪽에 더 가까웠나요?', [
      '바로 정리했다',
      '하루 정도 생각을 정리한 뒤 움직였다',
      '여러 사람의 이야기를 들으면서 내가 놓치고 있던 부분까지 확인한 다음에, 서두르지 않고 다음 행동을 골랐다',
    ]),
    _PreviewQuestion('오늘 경기에서 내가 맡은 역할은 어디에 더 가까웠나요?', [
      '앞에서 흐름을 열었다',
      '간격을 맞추며 이었다',
      '마지막 선택을 정리했다',
    ]),
  ],
  'en': [
    _PreviewQuestion('What’s your formation? 4–4–2', [
      'Set the shape early',
      'Wait and then move',
      'Listen first, then choose the next action',
    ]),
    _PreviewQuestion('Where did you play today?', [
      'Opened the line',
      'Held the gap',
      'Closed the last choice',
    ]),
  ],
  'ja': [
    _PreviewQuestion('骨・直・令・返、きょうの作戦。カタカナ', [
      '先に形を決めた',
      '一日置いて動いた',
      '話を聞いてから次を選んだ',
    ]),
    _PreviewQuestion('きょうの役割はどこに近かったですか。', ['流れを開いた', '間隔を保った', '最後の選択を閉じた']),
  ],
  'pt-BR': [
    _PreviewQuestion('São Paulo, ação, você, bênção', [
      'Defini logo',
      'Esperei um dia',
      'Ouvi e depois escolhi',
    ]),
    _PreviewQuestion('Qual papel ficou mais perto hoje?', [
      'Abri o caminho',
      'Mantive o espaço',
      'Fechei a escolha',
    ]),
  ],
  'es': [
    _PreviewQuestion('¿Cuál es tu táctica? ¡Mañana!', [
      'Lo ordené enseguida',
      'Esperé un día',
      'Escuché y luego elegí',
    ]),
    _PreviewQuestion('¿Qué papel se pareció más al tuyo?', [
      'Abrí el paso',
      'Cuidé el espacio',
      'Cerré la elección',
    ]),
  ],
  'id': [
    _PreviewQuestion('Bagaimana caramu mengambil keputusan?', [
      'Langsung merapikan',
      'Menunggu sehari',
      'Mendengar dulu, lalu memilih',
    ]),
    _PreviewQuestion('Peran mana yang paling dekat hari ini?', [
      'Membuka jalan',
      'Menjaga jarak',
      'Menutup pilihan',
    ]),
  ],
  'vi': [
    _PreviewQuestion('Tiếng Việt, Nguyễn, tưởng tượng, Ắ ẵ ộ ự Đ đ', [
      'Sắp xếp ngay',
      'Nghĩ một ngày',
      'Nghe rồi mới chọn',
    ]),
    _PreviewQuestion('Hôm nay vai của bạn gần với điều nào?', [
      'Mở đường',
      'Giữ khoảng cách',
      'Chốt lựa chọn',
    ]),
  ],
  'th': [
    _PreviewQuestion('ผู้เล่น น้ำ หนึ่ง กำลังใจ', [
      'จัดทันที',
      'รอหนึ่งวัน',
      'ฟังก่อนแล้วค่อยเลือก',
    ]),
    _PreviewQuestion('วันนี้บทบาทใกล้ข้อใด', [
      'เปิดทาง',
      'รักษาจังหวะ',
      'ปิดทางเลือก',
    ]),
  ],
  'hi': [
    _PreviewQuestion('हिंदी खिलाड़ी दृष्टि क्ष त्र ज्ञ कि की', [
      'तुरंत समेटा',
      'एक दिन सोचा',
      'सुनकर चुना',
    ]),
    _PreviewQuestion('आज की भूमिका किसके करीब थी?', [
      'रास्ता खोला',
      'दूरी रखी',
      'चुनाव पूरा किया',
    ]),
  ],
};

class UiPreviewPage extends StatefulWidget {
  const UiPreviewPage({super.key});

  @override
  State<UiPreviewPage> createState() => _UiPreviewPageState();
}

class _UiPreviewPageState extends State<UiPreviewPage> {
  static const _progressSamples = <({int current, int total, String label})>[
    (current: 1, total: 18, label: '1 / 18'),
    (current: 9, total: 18, label: '9 / 18'),
    (current: 18, total: 18, label: '18 / 18'),
  ];

  static const _weights = <(int, FontWeight)>[
    (400, FontWeight.w400),
    (500, FontWeight.w500),
    (600, FontWeight.w600),
    (700, FontWeight.w700),
  ];

  final List<int?> _selected = [null, null];
  var _questionIndex = 0;
  var _largeText = false;
  int? _catalogSelected;
  QuizSession? _pilot;
  QuizOutcome? _pilotOutcome;
  String? _pilotError;
  var _pilotStarted = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppLocaleScope.of(context);
    final roles = AppTypography.rolesOf(context);
    final code = controller.languageCode;
    final questions = _questions[code] ?? _questions['ko']!;
    final index = _questionIndex.clamp(0, questions.length - 1);
    final question = questions[index];
    final korean = code == 'ko';

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(_largeText ? 2 : 1)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AppContentFrame(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                Text(
                  korean ? '공통 UI 미리보기' : 'Shared UI preview',
                  style: roles.display,
                ),
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  korean ? '샘플 문구와 선택 상태는 이 화면 안에서만 사용합니다.' : 'Sample copy and the selected answer stay on this screen.',
                  style: roles.secondary,
                ),
                const SizedBox(height: AppSpacing.stackGap),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final language in AppFonts.languageCodes)
                      AppButton(
                        key: Key('lang-$language'),
                        label: language,
                        expand: false,
                        variant: language == code
                            ? AppButtonVariant.primary
                            : AppButtonVariant.secondary,
                        onPressed: () {
                          controller.select(language);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  'font: ${controller.readiness.name}',
                  key: const Key('font-status'),
                  style: roles.secondary,
                ),
                AppButton(
                  key: const Key('font-scale'),
                  label: _largeText
                      ? (korean ? '글꼴 100%' : 'Text 100%')
                      : (korean ? '글꼴 200%' : 'Text 200%'),
                  variant: AppButtonVariant.text,
                  onPressed: () => setState(() => _largeText = !_largeText),
                ),
                AppButton(
                  key: const Key('font-fail-next'),
                  label: 'fail next font',
                  variant: AppButtonVariant.text,
                  onPressed: controller.failNextLoad,
                ),
                AppButton(
                  key: const Key('font-retry'),
                  label: 'retry font',
                  variant: AppButtonVariant.text,
                  onPressed: () {
                    controller.retry();
                  },
                ),
                AppButton(
                  key: const Key('font-licenses'),
                  label: 'OFL',
                  variant: AppButtonVariant.text,
                  onPressed: () {
                    showFontLicenses(context);
                  },
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _SectionTitle(korean ? '버튼' : 'Buttons'),
                AppButton(label: korean ? '다음으로' : 'Next', onPressed: () {}),
                const SizedBox(height: AppSpacing.stackGap),
                AppButton(
                  label: korean ? '이전' : 'Back',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.stackGap),
                AppButton(
                  label: korean ? '설명 보기' : 'Details',
                  variant: AppButtonVariant.text,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.stackGap),
                AppButton(
                  label: korean ? '지금은 누를 수 없음' : 'Unavailable',
                  onPressed: null,
                ),
                const SizedBox(height: AppSpacing.stackGap),
                AppButton(
                  label: korean
                      ? '번역이 길어져도 버튼 안의 글이 잘리지 않고 높이가 늘어납니다'
                      : 'A long label wraps and the button grows',
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _SectionTitle(korean ? '카드' : 'Cards'),
                AppCard(
                  child: Text(
                    korean ? '일반 카드는 표면 색, 1px 테두리, 반경 20을 사용합니다.' : 'A standard card uses the surface, a 1px border, and radius 20.',
                    style: roles.body,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackGap),
                AppCard(
                  variant: AppCardVariant.result,
                  child: Text(
                    korean ? '결과 카드는 같은 표면과 테두리에 반경 24를 사용합니다.' : 'A result card keeps the surface and border, with radius 24.',
                    style: roles.resultName,
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _SectionTitle(korean ? '진행률' : 'Progress'),
                for (final sample in _progressSamples) ...[
                  AppProgress(
                    current: sample.current,
                    total: sample.total,
                    label: sample.label,
                  ),
                  const SizedBox(height: AppSpacing.stackGap),
                ],
                const SizedBox(
                  height: AppSpacing.sectionGap - AppSpacing.stackGap,
                ),
                _SectionTitle(korean ? '문항' : 'Question'),
                Text(
                  '${index + 1} / ${questions.length}',
                  key: const Key('preview-position'),
                  style: roles.secondary,
                ),
                const SizedBox(height: AppSpacing.stackGap),
                Text(question.prompt, style: roles.question),
                const SizedBox(height: AppSpacing.stackGap),
                for (
                  var answer = 0;
                  answer < question.answers.length;
                  answer++
                ) ...[
                  AppChoiceOption(
                    label: question.answers[answer],
                    selected: _selected[index] == answer,
                    onPressed: () => setState(() => _selected[index] = answer),
                  ),
                  if (answer != question.answers.length - 1)
                    const SizedBox(height: AppSpacing.optionGap),
                ],
                const SizedBox(height: AppSpacing.stackGap),
                Text(
                  korean ? '답을 고르면 다음을 누를 수 있습니다. 다른 답을 고르면 선택 표시가 이동합니다.' : 'Choosing an answer enables Next. Another answer moves the marker.',
                  style: roles.secondary,
                ),
                const SizedBox(height: AppSpacing.stackGap),
                AppButton(
                  key: const Key('preview-next'),
                  label: korean ? '다음' : 'Next',
                  onPressed: _selected[index] == null
                      ? null
                      : () {
                          setState(() {
                            _questionIndex =
                                (_questionIndex + 1) % questions.length;
                          });
                        },
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                _SectionTitle(korean ? '글꼴 검수' : 'Font check'),
                SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FontSamples.specimen(code),
                        key: const Key('font-specimen'),
                        style: roles.body,
                      ),
                      const SizedBox(height: AppSpacing.stackGap),
                      Text(FontSamples.symbols, style: roles.body),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.stackGap),
                Text('saida', style: roles.secondary),
                Text(
                  korean
                      ? '오늘은 이 흐름이면 충분해요.'
                      : 'This shape is enough for today.',
                  key: const Key('saida-line'),
                  style: roles.saida,
                ),
                if (code == 'vi') ...[
                  const SizedBox(height: AppSpacing.stackGap),
                  Text('NFC ${FontSamples.viNfc}', style: roles.body),
                  Text('NFD ${FontSamples.viNfd}', style: roles.body),
                ],
                if (code == 'th') ...[
                  const SizedBox(height: AppSpacing.stackGap),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(FontSamples.thaiStacked, style: roles.body),
                  ),
                ],
                const SizedBox(height: AppSpacing.stackGap),
                for (final step in _weights)
                  Text(
                    '${step.$1} ${FontSamples.specimen(code)}',
                    style: roles.body.copyWith(fontWeight: step.$2),
                  ),
                const SizedBox(height: AppSpacing.sectionGap),
                ..._catalogSection(context, code, roles),
                ..._pilotSection(code, roles),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _catalogSection(
    BuildContext context,
    String code,
    AppTextRoles roles,
  ) {
    final bundle = ContentScope.of(context);
    final book = AppTextBook(bundle.locales);
    final quiz = bundle.quiz('life_tactics');
    if (quiz == null) {
      return const [Text('life_tactics가 번들에 없습니다.')];
    }
    final question = (quiz.questions.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        .first;
    final answers = quiz.optionsFor(question.scaleId);
    final result = quiz.resultTypes.firstWhere(
      (item) => item.resultTypeId == 'tr10',
    );
    final title = book.resolve(code, quiz.titleTextKey);
    final review = title.usedFallback
        ? (code == 'ko'
              ? '이 언어의 번역이 없어 한국어를 표시합니다.'
              : 'Korean copy is shown because this language has no translation.')
        : title.status == 'reviewed'
        ? (code == 'ko' ? '검수된 번역' : 'Reviewed translation')
        : (code == 'ko'
              ? '검수 전 초안입니다. 출시 목록에는 들어가지 않습니다.'
              : 'Unreviewed draft. Not in the release catalog.');

    return [
      _SectionTitle(code == 'ko' ? '데이터' : 'Catalog'),
      Text(review, key: const Key('catalog-review'), style: roles.secondary),
      const SizedBox(height: AppSpacing.stackGap),
      Text(title.text, key: const Key('catalog-title'), style: roles.display),
      const SizedBox(height: AppSpacing.stackGap),
      Text(book.resolve(code, quiz.introTextKey).text, style: roles.body),
      const SizedBox(height: AppSpacing.stackGap),
      AppProgress(
        current: 1,
        total: quiz.questionCount,
        label: book.resolve(
          code,
          'common.ui.quiz.progress',
          values: {'current': 1, 'total': quiz.questionCount},
        ).text,
      ),
      const SizedBox(height: AppSpacing.stackGap),
      Text(
        book.resolve(code, question.promptTextKey).text,
        key: const Key('catalog-question'),
        style: roles.question,
      ),
      const SizedBox(height: AppSpacing.stackGap),
      for (var index = 0; index < answers.length; index++) ...[
        AppChoiceOption(
          key: Key('catalog-choice-$index'),
          label: book.resolve(code, answers[index].labelTextKey).text,
          selected: _catalogSelected == index,
          onPressed: () => setState(() => _catalogSelected = index),
        ),
        if (index != answers.length - 1)
          const SizedBox(height: AppSpacing.optionGap),
      ],
      const SizedBox(height: AppSpacing.stackGap),
      AppButton(
        key: const Key('catalog-next'),
        label: book.resolve(code, 'common.ui.quiz.next').text,
        onPressed: () {},
      ),
      const SizedBox(height: AppSpacing.stackGap),
      Text(
        book.resolve(code, result.nameTextKey).text,
        key: const Key('catalog-result'),
        style: roles.resultName,
      ),
      Text(result.formation, style: roles.secondary),
      const SizedBox(height: AppSpacing.stackGap),
      Text(
        book.resolve(code, 'common.saida.start').text,
        key: const Key('catalog-saida'),
        style: roles.saida,
      ),
    ];
  }

  List<Widget> _pilotSection(String code, AppTextRoles roles) {
    final bundle = ContentScope.of(context);
    final quiz = bundle.quiz('life_tactics');
    if (quiz == null || quiz.rule == null) {
      return const [];
    }
    final session = _pilot ??= QuizSession.start(quiz, allowPending: true);
    final book = AppTextBook(bundle.locales);
    final questions = activeQuestions(quiz);
    final position = questions.indexWhere((item) => item.questionId == session.positionId);
    final question = questions[position < 0 ? 0 : position];
    final options = quiz.optionsFor(question.scaleId);

    String text(String key, {Map<String, Object?> values = const {}}) {
      return book.resolve(code, key, values: values).text;
    }

    if (_pilotOutcome != null) {
      final outcome = _pilotOutcome!;
      final result = quiz.resultTypes.firstWhere(
        (item) => item.resultTypeId == outcome.resultTypeId,
      );
      final tied = outcome.tiedDimensionIds
          .map((id) => text(quiz.dimensions.firstWhere((item) => item.dimensionId == id).nameTextKey))
          .join(' · ');
      return [
        const SizedBox(height: AppSpacing.sectionGap),
        _SectionTitle(code == 'ko' ? '파일럿 결과' : 'Pilot result'),
        Text(text('life_tactics.result.preview.banner'), key: const Key('pilot-banner'), style: roles.secondary),
        const SizedBox(height: AppSpacing.stackGap),
        Text(text('common.ui.result.axes'), style: roles.secondary),
        for (final axis in outcome.rank)
          Text(
            '${text(quiz.dimensions.firstWhere((item) => item.dimensionId == axis).nameTextKey)} ${outcome.displayScores[axis]}',
            key: Key('pilot-score-$axis'),
            style: roles.body,
          ),
        if (tied.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.stackGap),
          Text(text('life_tactics.result.tie.note'), style: roles.secondary),
          Text(tied, key: const Key('pilot-tie'), style: roles.body),
        ],
        if (outcome.path == 'balance') ...[
          const SizedBox(height: AppSpacing.stackGap),
          Text(text('life_tactics.result.balance.note'), style: roles.body),
        ],
        if (outcome.adjacentChanges) ...[
          const SizedBox(height: AppSpacing.stackGap),
          Text(text('life_tactics.result.boundary.note'), key: const Key('pilot-boundary'), style: roles.secondary),
        ],
        const SizedBox(height: AppSpacing.stackGap),
        Text(text(result.nameTextKey), key: const Key('pilot-result'), style: roles.resultName),
        Text(result.formation, key: const Key('pilot-formation'), style: roles.secondary),
        const SizedBox(height: AppSpacing.stackGap),
        AppButton(
          key: const Key('pilot-retry'),
          label: text('common.ui.result.retry'),
          onPressed: () => setState(() {
            session.answers.clear();
            session.moveTo(questions.first.questionId);
            _pilotOutcome = null;
            _pilotStarted = false;
          }),
        ),
      ];
    }

    if (!_pilotStarted) {
      return [
        const SizedBox(height: AppSpacing.sectionGap),
        _SectionTitle(code == 'ko' ? '파일럿' : 'Pilot'),
        Text(text(quiz.titleTextKey), key: const Key('pilot-title'), style: roles.display),
        const SizedBox(height: AppSpacing.stackGap),
        Text(text(quiz.introTextKey), style: roles.body),
        const SizedBox(height: AppSpacing.stackGap),
        AppButton(
          key: const Key('pilot-start'),
          label: text('common.ui.quiz.start'),
          onPressed: () => setState(() => _pilotStarted = true),
        ),
      ];
    }

    return [
      const SizedBox(height: AppSpacing.sectionGap),
      _SectionTitle(code == 'ko' ? '파일럿' : 'Pilot'),
      if (_pilotError != null) Text(_pilotError!, key: const Key('pilot-error'), style: roles.secondary),
      AppProgress(
        current: position + 1,
        total: questions.length,
        label: text(
          'common.ui.quiz.progress',
          values: {'current': position + 1, 'total': questions.length},
        ),
      ),
      const SizedBox(height: AppSpacing.stackGap),
      Text(text(question.promptTextKey), key: const Key('pilot-question'), style: roles.question),
      const SizedBox(height: AppSpacing.stackGap),
      for (var index = 0; index < options.length; index++) ...[
        AppChoiceOption(
          key: Key('pilot-choice-$index'),
          label: text(options[index].labelTextKey),
          selected: session.answers[question.questionId] == options[index].optionId,
          onPressed: () => setState(() {
            session.select(question.questionId, options[index].optionId);
            _pilotError = null;
            _pilotOutcome = null;
          }),
        ),
        if (index != options.length - 1) const SizedBox(height: AppSpacing.optionGap),
      ],
      const SizedBox(height: AppSpacing.stackGap),
      AppButton(
        key: const Key('pilot-back'),
        label: text('common.ui.quiz.back'),
        onPressed: position == 0
            ? null
            : () => setState(() => session.moveTo(questions[position - 1].questionId)),
      ),
      const SizedBox(height: AppSpacing.optionGap),
      AppButton(
        key: Key(position == questions.length - 1 ? 'pilot-finish' : 'pilot-next'),
        label: text(position == questions.length - 1 ? 'common.ui.quiz.finish' : 'common.ui.quiz.next'),
        onPressed: session.answers[question.questionId] == null
            ? null
            : () => setState(() {
                if (position < questions.length - 1) {
                  session.moveTo(questions[position + 1].questionId);
                  return;
                }
                try {
                  _pilotOutcome = session.complete();
                  _pilotError = null;
                } on QuizFailure catch (error) {
                  _pilotError = error.code;
                }
              }),
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.stackGap),
      child: Text(label, style: AppTypography.rolesOf(context).secondary),
    );
  }
}
