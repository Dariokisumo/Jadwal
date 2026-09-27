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

  Widget buildSubject({double textScaleFactor = 1.0, bool initialShowWelcomeGuide = true}) {
    return MaterialApp(
      theme: buildRelationalTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScaleFactor),
          size: const Size(360, 800),
        ),
        child: SetupScreen(initialShowWelcomeGuide: initialShowWelcomeGuide),
      ),
    );
  }

  testWidgets('renders SetupScreen initial welcome guide elements', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Jadwal'), findsOneWidget);
    expect(find.text('Offline timetable tracker'), findsOneWidget);
    expect(find.text('How Jadwal Works'), findsOneWidget);
    expect(find.text('Snap your paper schedule'), findsOneWidget);
    expect(find.text('Your AI helper reads it'), findsOneWidget);
    expect(find.text('Get offline bell alerts'), findsOneWidget);
    expect(find.text('Start with Schedule Photo'), findsOneWidget);
    expect(find.text('Try Demo Schedule'), findsOneWidget);
    expect(find.text('100% Offline'), findsOneWidget);
  });

  testWidgets('navigating to Step 1 renders all assistant and photo elements', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final stepByStepFinder = find.text('Step-by-step setup or manual import →');
    expect(stepByStepFinder, findsOneWidget);
    await tester.tap(stepByStepFinder);
    await tester.pumpAndSettle();

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

    // Tapping Guide button returns to the welcome guide
    final guideButton = find.text('Guide');
    expect(guideButton, findsOneWidget);
    await tester.tap(guideButton);
    await tester.pumpAndSettle();
    expect(find.text('How Jadwal Works'), findsOneWidget);
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

    // Verify Welcome Guide renders with zero overflow on narrow viewport
    expect(find.text('How Jadwal Works'), findsOneWidget);
    expect(find.text('Start with Schedule Photo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Navigate to Step 1 and verify zero overflow as well
    final manualStepFinder = find.text('Step-by-step setup or manual import →');
    await tester.ensureVisible(manualStepFinder);
    await tester.tap(manualStepFinder);
    await tester.pumpAndSettle();

    expect(find.text('Choose Assistant'), findsOneWidget);
    expect(find.text('Pick & Align Timetable Photo'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Try Demo Schedule on welcome guide transitions to Step 2 with visual preview card without overflow', (tester) async {
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

    final tryDemoFinder = find.text('Try Demo Schedule');
    expect(tryDemoFinder, findsOneWidget);
    await tester.ensureVisible(tryDemoFinder);
    await tester.pumpAndSettle();
    await tester.tap(tryDemoFinder);
    await tester.pumpAndSettle();

    // Verify step 2 appears
    expect(find.text('Review & Import'), findsOneWidget);
    expect(find.text('Demo Teacher'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Import This Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct Step 1 initial mode works with Try Sample', (tester) async {
    await tester.pumpWidget(buildSubject(initialShowWelcomeGuide: false));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 3'), findsOneWidget);
    final trySampleFinder = find.text('Try Sample');
    expect(trySampleFinder, findsOneWidget);
    await tester.tap(trySampleFinder);
    await tester.pumpAndSettle();

    expect(find.text('Review & Import'), findsOneWidget);
    expect(find.text('Demo Teacher'), findsOneWidget);
  });
}
