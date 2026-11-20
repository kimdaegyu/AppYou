import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_fonts.dart';

/// 재배포하는 글꼴의 저작권 고지와 OFL 원문.
abstract final class FontLicenseNotice {
  static Future<String> load() async {
    final buffer = StringBuffer()
      ..writeln('SIL Open Font License 1.1')
      ..writeln(
        'The font files shipped with this app are unmodified upstream binaries.',
      )
      ..writeln(
        'Reserved Font Names are unchanged. The fonts are not sold separately.',
      )
      ..writeln();
    for (final file in AppFonts.files) {
      buffer
        ..writeln(file.family)
        ..writeln(file.asset)
        ..writeln(file.sourceUrl)
        ..writeln(file.revision)
        ..writeln(file.sha256)
        ..writeln('Reserved Font Name: ${file.reservedFontName}')
        ..writeln();
      try {
        buffer.writeln(await rootBundle.loadString(file.licenseAsset));
      } catch (_) {
        buffer.writeln(
          'The license file could not be read: ${file.licenseAsset}',
        );
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

Future<void> showFontLicenses(BuildContext context) async {
  final notice = await FontLicenseNotice.load();
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Open source fonts'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: SelectableText(notice)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
