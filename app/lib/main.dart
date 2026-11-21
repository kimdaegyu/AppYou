import 'package:material_ui/material_ui.dart';

import 'core/fonts/app_font_loader.dart';
import 'core/locale/app_locale_bootstrap.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/locale/app_locale_store.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/content_models.dart';
import 'features/catalog/content_repository.dart';
import 'features/catalog/content_scope.dart';
import 'features/life_tactics/pilot_checkpoint.dart';
import 'features/life_tactics/pilot_host.dart';
import 'features/life_tactics/pilot_pages.dart';
import 'features/life_tactics/pilot_session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.store,
    this.loader,
    this.deviceTags,
    this.preview,
    this.sessionStore,
  });

  final AppLocaleStore? store;
  final AppFontLoader? loader;
  final List<String>? deviceTags;

  /// 테스트가 이미 읽은 0.9.0 미리보기 번들. 비어 있으면 앱이 직접 읽는다.
  final ContentBundle? preview;

  /// 같은 탭 기록. 비어 있으면 웹은 sessionStorage, 그 외에는 빈 메모리를 쓴다.
  final PilotSessionStore? sessionStore;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _host = PilotHost();
  var _queued = false;

  @override
  void initState() {
    super.initState();
    _host.store = widget.sessionStore ?? createPilotSessionStore();
    final preview = widget.preview;
    if (preview != null) {
      _host.bind(preview);
      _queueRestore();
    }
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleBootstrap(
      store: widget.store,
      loader: widget.loader,
      deviceTags: widget.deviceTags,
      builder: (context, controller) {
        final preview = widget.preview;
        if (preview != null) {
          return _material(controller);
        }
        return ContentLoader(
          version: pilotDataVersion,
          channel: 'preview',
          builder: (context, phase) {
            final bundle = phase.bundle;
            if (bundle == null) {
              return ContentPending(
                message: phase.error?.toString(),
                onRetry: phase.error == null ? null : phase.retry,
              );
            }
            _host.bind(bundle);
            _queueRestore();
            return _material(controller);
          },
        );
      },
    );
  }

  void _queueRestore() {
    if (_queued) {
      return;
    }
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final raw = _readStore();
      final restored = _host.restore(raw);
      if (raw != null && raw.isNotEmpty && !restored) {
        _clearStore();
      }
      _openRestored();
    });
  }

  void _openRestored() {
    final navigator = _navigatorKey.currentState;
    if (_host.stage == PilotStage.intro) {
      _host.stage = PilotStage.home;
      _host.questions = null;
      _host.scenes = null;
      _host.outcome = null;
      _host.tally = null;
    }
    final stage = _host.stage;
    if (navigator == null || stage == PilotStage.home) {
      _host.releaseHold();
      return;
    }
    final questionCount = stage == PilotStage.question
        ? _host.questionIndex + 1
        : _host.questionItems.length;
    for (var index = 0; index < questionCount; index++) {
      final page = index;
      navigator.push(
        PilotRoute<void>(
          builder: (_) => PilotQuestionPage(host: _host, index: page),
        ),
      );
    }
    if (stage == PilotStage.question) {
      _finishRestore(PilotStage.question, questionIndex: _host.questionIndex);
      return;
    }
    final sceneCount = stage == PilotStage.scene
        ? _host.sceneIndex + 1
        : _host.sceneItems.length;
    for (var index = 0; index < sceneCount; index++) {
      final page = index;
      navigator.push(
        PilotRoute<void>(
          builder: (_) => PilotScenePage(host: _host, index: page),
        ),
      );
    }
    if (stage == PilotStage.scene) {
      _finishRestore(PilotStage.scene, sceneIndex: _host.sceneIndex);
      return;
    }
    navigator.push(
      PilotRoute<void>(builder: (_) => PilotResultPage(host: _host)),
    );
    if (stage == PilotStage.share) {
      navigator.push(
        PilotRoute<void>(builder: (_) => PilotSharePage(host: _host)),
      );
    }
    _finishRestore(stage);
  }

  void _finishRestore(String stage, {int? questionIndex, int? sceneIndex}) {
    _host.releaseHold();
    _host.notePlace(
      stage,
      questionIndex: questionIndex,
      sceneIndex: sceneIndex,
    );
  }

  String? _readStore() {
    try {
      return _host.store.read();
    } catch (_) {
      return null;
    }
  }

  void _clearStore() {
    try {
      _host.store.clear();
    } catch (_) {}
  }

  Widget _material(AppLocaleController controller) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [pilotRouteObserver],
      title: 'Look At You',
      debugShowCheckedModeBanner: false,
      locale: controller.locale,
      supportedLocales: AppFonts.supportedLocales,
      localizationsDelegates: AppTheme.localizationsDelegates,
      theme: AppTheme.forLanguage(controller.languageCode),
      themeAnimationDuration: Duration.zero,
      home: PilotHomePage(host: _host),
    );
  }
}
