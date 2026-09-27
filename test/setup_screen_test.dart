import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/screens/setup_screen.dart';
import 'package:jadwal/theme/relational_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.jadwal/exact_alarm');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'isAppInstalled') {
        return false;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      if (methodCall.method == 'HapticFeedback.vibrate') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget buildSubject({double textScaleFactor = 1.0}) {
    return MaterialApp(
      theme: buildRelationalTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScaleFactor),
          size: const Size(360, 800),
        ),
        child: const SetupScreen(),
      ),
    );
  }

  testWidgets('renders SetupScreen initial step 1 elements', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Jadwal'), findsOneWidget);
    expect(find.text('Offline timetable tracker'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Choose Assistant'), findsOneWidget);
    expect(find.text('Have a timetable photo?'), findsOneWidget);
    expect(find.text('Pick & Align Timetable Photo'), findsOneWidget);
    expect(find.text('Upload File'), findsOneWidget);
    expect(find.text('.jadwal or .json'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Copy prompt'), findsOneWidget);
    expect(find.text('Try Sample'), findsOneWidget);
  });

  testWidgets('zero overflow on narrow 320px viewport with large font scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: buildRelationalTheme(Brightness.light),
      home: const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.4),
        ),
        child: SetupScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify all primary elements are present without RenderFlex overflow
    expect(find.text('Choose Assistant'), findsOneWidget);
    expect(find.text('Pick & Align Timetable Photo'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Try Sample transitions to Step 2 with visual preview card without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: buildRelationalTheme(Brightness.light),
      home: const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(1.2),
        ),
        child: SetupScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final trySampleFinder = find.text('Try Sample');
    expect(trySampleFinder, findsOneWidget);
    await tester.ensureVisible(trySampleFinder);
    await tester.pumpAndSettle();
    await tester.tap(trySampleFinder);
    await tester.pumpAndSettle();

    // Verify step 2 appears
    expect(find.text('Review & Import'), findsOneWidget);
    expect(find.text('Demo Teacher'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Import This Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
