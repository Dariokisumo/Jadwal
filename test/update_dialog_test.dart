import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/services/update_service.dart';
import 'package:jadwal/theme/relational_theme.dart';
import 'package:jadwal/widgets/update_dialog.dart';

void main() {
  group('UpdateService logic tests', () {
    test('isVersionNewer correctly compares semantic versions', () {
      expect(UpdateService.isVersionNewer('v2.10.5', '2.10.4'), isTrue);
      expect(UpdateService.isVersionNewer('v2.11.0', '2.10.4'), isTrue);
      expect(UpdateService.isVersionNewer('v3.0.0', '2.10.4'), isTrue);
      expect(UpdateService.isVersionNewer('v2.10.4', '2.10.4'), isFalse);
      expect(UpdateService.isVersionNewer('v2.10.3', '2.10.4'), isFalse);
      expect(UpdateService.isVersionNewer('v2.9.5', '2.10.4'), isFalse);
    });

    test('parseChangelogToSimpleEnglish cleans markdown bullets', () {
      const markdown = '''
# Release v2.10.4
### Features
- **Auto-Clear Reminders**: Classes automatically dismissed after 5 min.
- *Performance*: Fast widget update `build_check`.
| Table | Column |
```code
ignored
```
- Stability fixes across all devices.
''';
      final bullets = UpdateService.parseChangelogToSimpleEnglish(markdown);
      expect(bullets.length, 3);
      expect(bullets[0],
          'Auto-Clear Reminders: Classes automatically dismissed after 5 min.');
      expect(bullets[1], 'Performance: Fast widget update build_check.');
      expect(bullets[2], 'Stability fixes across all devices.');
    });

    test('AppReleaseInfo resolves download URL for arch', () {
      const release = AppReleaseInfo(
        tagName: 'v2.10.4',
        releaseName: 'v2.10.4 Release',
        changelogBullets: ['Update notes'],
        htmlUrl: 'https://github.com/test/release',
        arm64Url: 'https://github.com/test/arm64.apk',
        arm32Url: 'https://github.com/test/arm32.apk',
        isNewer: true,
        currentVersion: '2.10.3',
      );

      expect(release.getDownloadUrlForArch('arm64'),
          'https://github.com/test/arm64.apk');
      expect(release.getDownloadUrlForArch('arm32'),
          'https://github.com/test/arm32.apk');
    });
  });

  group('UpdateDialog widget rendering tests', () {
    testWidgets('renders UpdateDialog with changelog bullets and trust notice',
        (tester) async {
      const release = AppReleaseInfo(
        tagName: 'v2.10.5',
        releaseName: 'v2.10.5 Release',
        changelogBullets: [
          'Automatic notification clear',
          'Fast widget loading',
        ],
        htmlUrl: 'https://github.com/Dariokisumo/Jadwal/releases',
        arm64Url: 'https://github.com/test/arm64.apk',
        arm32Url: 'https://github.com/test/arm32.apk',
        isNewer: true,
        currentVersion: '2.10.4',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildRelationalTheme(Brightness.light),
          home: const Scaffold(
            body: UpdateDialog(release: release),
          ),
        ),
      );

      // Verify update title and tag
      expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
      expect(find.text('Jadwal v2.10.5'), findsOneWidget);

      // Verify changelog items
      expect(find.text('Automatic notification clear'), findsOneWidget);
      expect(find.text('Fast widget loading'), findsOneWidget);

      // Verify safe update notice
      expect(
        find.text(
          'Safe update: All saved timetables, widgets, and settings will remain untouched.',
        ),
        findsOneWidget,
      );

      // Verify primary download action button exists
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.text('Later'), findsOneWidget);
    });
  });
}
