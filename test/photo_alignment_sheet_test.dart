import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/constants/timetable_prompt.dart';
import 'package:jadwal/theme/relational_theme.dart';
import 'package:jadwal/widgets/photo_alignment_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Minimal 1x1 valid PNG bytes
  final kMinimalPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  const channel = MethodChannel('com.jadwal/exact_alarm');

  String? mockClipboardText;

  setUp(() {
    mockClipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'shareFile') {
        return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        mockClipboardText = (methodCall.arguments as Map)['text'] as String?;
        return null;
      }
      if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': mockClipboardText};
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

  Widget buildSubject({
    required void Function(String assistantName) onShared,
    String? originalPath,
  }) {
    return MaterialApp(
      theme: buildRelationalTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              PhotoAlignmentSheet.show(
                context,
                imageBytes: kMinimalPng,
                originalPath: originalPath,
                geminiInstalled: true,
                chatGptInstalled: false,
                claudeInstalled: true,
                onShared: onShared,
              );
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  testWidgets('renders photo alignment sheet elements', (tester) async {
    await tester.pumpWidget(buildSubject(onShared: (_) {}));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Align Timetable Photo'), findsOneWidget);
    expect(find.text('Ensure columns are upright and readable'), findsOneWidget);
    expect(find.text('0°'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    // Guidance chips
    expect(find.text('Level & straight'), findsOneWidget);
    expect(find.text('All days visible'), findsOneWidget);
    expect(find.text('Clear lighting'), findsOneWidget);

    // AI share targets
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('rotates image and updates rotation label', (tester) async {
    await tester.pumpWidget(buildSubject(onShared: (_) {}));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('0°'), findsOneWidget);

    // Tap rotate button once -> 90°
    await tester.tap(find.text('0°'));
    await tester.pumpAndSettle();
    expect(find.text('90°'), findsOneWidget);

    // Tap rotate button again -> 180°
    await tester.tap(find.text('90°'));
    await tester.pumpAndSettle();
    expect(find.text('180°'), findsOneWidget);

    // Tap reset button -> 0°
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('0°'), findsOneWidget);
  });

  testWidgets('toggles grid on and off', (tester) async {
    await tester.pumpWidget(buildSubject(onShared: (_) {}));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    final gridButton = find.text('Grid');
    expect(gridButton, findsOneWidget);

    // Tap grid button
    await tester.tap(gridButton);
    await tester.pumpAndSettle();

    // Tap again
    await tester.tap(gridButton);
    await tester.pumpAndSettle();
  });

  testWidgets('sharing copies prompt and fires onShared callback', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final tempFile = File('${Directory.systemTemp.path}/test_shared_img.png');
    tempFile.writeAsBytesSync(kMinimalPng);
    addTearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    String? sharedWith;
    await tester.pumpWidget(buildSubject(
      originalPath: tempFile.path,
      onShared: (name) {
        sharedWith = name;
      },
    ));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    final chatGptFinder = find.text('ChatGPT');
    expect(chatGptFinder, findsOneWidget);

    await tester.ensureVisible(chatGptFinder);
    await tester.pumpAndSettle();

    // Tap ChatGPT tile to dispatch gesture
    await tester.tap(chatGptFinder);
    await tester.pumpAndSettle();

    // Verify onShared was called with ChatGPT
    expect(sharedWith, equals('ChatGPT'));

    // Verify clipboard content has the prompt
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData?.text, equals(kTimetablePrompt));
  });
}
