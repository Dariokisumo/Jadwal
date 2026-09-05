import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/widget_data_service.dart';
import 'theme/primitives.dart';
import 'theme/relational_theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<String> accentNotifier = ValueNotifier('default');

const Map<String, Color> accentSeeds = {
  'default': Primitives.actionGold,
  'navy': Primitives.actionNavy,
  'copper': Primitives.actionCopper,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    StorageService.isTimetableLoaded(),
    StorageService.loadThemeMode(),
    StorageService.loadTimetable(),
    StorageService.loadAccent(),
  ]);

  final alreadySetUp = results[0] as bool;
  final savedTheme = results[1] as String;
  final savedAccent = results[3] as String;

  // Re-register recurring alarms at startup so they survive reboots
  // even if HomeScreen hasn't loaded yet.
  if (alreadySetUp) {
    final data = results[2] as Map<String, dynamic>?;
    if (data != null) {
      try {
        await NotificationService.scheduleAll(
          data['timetable'] as Map<String, dynamic>,
        );
      } catch (e, stack) {
        debugPrint('main: NotificationService.scheduleAll failed: $e');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  switch (savedTheme) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
      break;
    case 'dark':
      themeNotifier.value = ThemeMode.dark;
      break;
    default:
      themeNotifier.value = ThemeMode.system;
  }

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: accentNotifier,
          builder: (context, accentName, _) {
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
      },
    );
  }
}
