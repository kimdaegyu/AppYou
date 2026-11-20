import 'package:material_ui/material_ui.dart';

import '../fonts/app_font_loader.dart';
import 'app_locale_controller.dart';
import 'app_locale_store.dart';

/// 첫 프레임은 저장소를 기다리지 않고 그리고, 이어서 언어와 폰트를 맞춘다.
class AppLocaleBootstrap extends StatefulWidget {
  const AppLocaleBootstrap({
    super.key,
    required this.builder,
    this.store,
    this.loader,
    this.deviceTags,
  });

  final Widget Function(BuildContext context, AppLocaleController controller)
  builder;
  final AppLocaleStore? store;
  final AppFontLoader? loader;
  final List<String>? deviceTags;

  @override
  State<AppLocaleBootstrap> createState() => _AppLocaleBootstrapState();
}

class _AppLocaleBootstrapState extends State<AppLocaleBootstrap> {
  late final AppLocaleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppLocaleController(
      store: widget.store ?? const SharedPreferencesLocaleStore(),
      loader: widget.loader ?? AppFontLoader(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final tags =
          widget.deviceTags ??
          WidgetsBinding.instance.platformDispatcher.locales
              .map((locale) => locale.toLanguageTag())
              .toList();
      _controller.restore(tags);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return AppLocaleScope(
          controller: _controller,
          child: widget.builder(context, _controller),
        );
      },
    );
  }
}

class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope가 앱 루트에 없습니다.');
    return scope!.notifier!;
  }
}
