import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import 'content_models.dart';
import 'content_repository.dart';

class ContentScope extends InheritedWidget {
  const ContentScope({super.key, required this.bundle, required super.child});

  final ContentBundle bundle;

  static ContentBundle of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ContentScope>();
    assert(scope != null, 'ContentScope가 없습니다.');
    return scope!.bundle;
  }

  @override
  bool updateShouldNotify(ContentScope oldWidget) => bundle != oldWidget.bundle;
}

/// 번들을 읽기 전에는 제품 문구를 그리지 않는다.
class ContentLoader extends StatefulWidget {
  const ContentLoader({
    super.key,
    required this.builder,
    this.repository,
    this.version = contentDataVersion,
    this.channel = 'preview',
  });

  final ContentRepository? repository;
  final String version;
  final String channel;
  final Widget Function(BuildContext context, ContentLoadPhase phase) builder;

  @override
  State<ContentLoader> createState() => _ContentLoaderState();
}

class ContentLoadPhase {
  const ContentLoadPhase({this.bundle, this.error, required this.retry});

  final ContentBundle? bundle;
  final Object? error;
  final VoidCallback retry;
}

class _ContentLoaderState extends State<ContentLoader> {
  late ContentRepository _repository;
  ContentBundle? _bundle;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ContentRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final bundle = await _repository.load(
        version: widget.version,
        channel: widget.channel,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bundle = bundle;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bundle = null;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      ContentLoadPhase(
        bundle: _bundle,
        error: _error,
        retry: () {
          setState(() => _error = null);
          _load();
        },
      ),
    );
  }
}

/// 언어 복원이나 번들 로드 전에 보여주는 빈 표면.
class ContentPending extends StatelessWidget {
  const ContentPending({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: message == null
            ? const SizedBox.shrink()
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message!),
                    if (onRetry != null)
                      TextButton(onPressed: onRetry, child: const Text('retry data')),
                  ],
                ),
              ),
      ),
    );
  }
}
