import 'package:material_ui/material_ui.dart';

import 'core/fonts/app_font_loader.dart';
import 'core/locale/app_locale_bootstrap.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/locale/app_locale_store.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/font_license_notice.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.store, this.loader, this.deviceTags});

  final AppLocaleStore? store;
  final AppFontLoader? loader;
  final List<String>? deviceTags;

  @override
  Widget build(BuildContext context) {
    return AppLocaleBootstrap(
      store: store,
      loader: loader,
      deviceTags: deviceTags,
      builder: (context, controller) {
        return MaterialApp(
          title: 'Flutter Demo',
          locale: controller.locale,
          supportedLocales: AppFonts.supportedLocales,
          localizationsDelegates: AppTheme.localizationsDelegates,
          theme: AppTheme.forLanguage(controller.languageCode),
          themeAnimationDuration: Duration.zero,
          home: MyHomePage(
            title: 'Flutter Demo Home Page',
            controller: controller,
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.controller});

  final String title;
  final AppLocaleController controller;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final roles = AppTypography.rolesOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            key: const Key('language-menu'),
            onSelected: (code) {
              controller.select(code);
            },
            itemBuilder: (context) {
              return [
                for (final code in AppFonts.released)
                  PopupMenuItem<String>(value: code, child: Text(code)),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(controller.languageCode),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              FontSamples.specimen(controller.languageCode),
              key: const Key('font-specimen'),
              style: roles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'font: ${controller.readiness.name}',
              key: const Key('font-status'),
            ),
            TextButton(
              onPressed: () {
                showFontLicenses(context);
              },
              child: const Text('OFL'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
