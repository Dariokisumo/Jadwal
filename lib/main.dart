import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/widget_data_service.dart';
import 'theme/relational_theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<String> accentNotifier = ValueNotifier('default');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize deep link handling early
  DeepLinkService.init();

  try {
    await NotificationService.init();
  } catch (e, stack) {
    debugPrint('main: NotificationService.init failed: $e');
    debugPrintStack(stackTrace: stack);
  }

  // Update home screen widget on startup
  try {
    await WidgetDataService.updateWidget();
  } catch (e, stack) {
    debugPrint('main: WidgetDataService.updateWidget failed: $e');
    debugPrintStack(stackTrace: stack);
  }

  final results = await Future.wait([
    StorageService.loadThemeMode(),
    StorageService.loadTimetable(),
    StorageService.loadAccent(),
  ]);

  final savedTheme = results[0] as String;
  final timetableData = results[1] as Map<String, dynamic>?;
  final savedAccent = results[2] as String;
  final alreadySetUp = timetableData != null;

  // Re-register recurring alarms at startup so they survive reboots
  // even if HomeScreen hasn't loaded yet.
  if (alreadySetUp) {
    try {
      final tt = timetableData['timetable'];
      if (tt is Map) {
        await NotificationService.scheduleAll(
          tt.cast<String, dynamic>(),
        );
      }
    } catch (e, stack) {
      debugPrint('main: NotificationService.scheduleAll failed: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  const themeModes = {
    'light': ThemeMode.light,
    'dark': ThemeMode.dark,
  };
  themeNotifier.value = themeModes[savedTheme] ?? ThemeMode.system;

  accentNotifier.value = savedAccent;

  runApp(JadwalApp(
    startOnHome: alreadySetUp,
  ));
}

class JadwalApp extends StatelessWidget {
  final bool startOnHome;

  const JadwalApp({
    super.key,
    required this.startOnHome,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, accentNotifier]),
      builder: (context, _) {
        final mode = themeNotifier.value;
        final accentName = accentNotifier.value;
        return MaterialApp(
          title: 'Jadwal',
          debugShowCheckedModeBanner: false,
          theme: buildRelationalTheme(
            Brightness.light,
            accent: accentName,
          ),
          darkTheme: buildRelationalTheme(
            Brightness.dark,
            accent: accentName,
          ),
          themeMode: mode,
          home: startOnHome ? const HomeScreen() : const SetupScreen(),
        );
      },
    );
  }
}
