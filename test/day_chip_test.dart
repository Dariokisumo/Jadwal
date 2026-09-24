import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/theme/relational_colors.dart';
import 'package:jadwal/theme/relational_theme.dart';
import 'package:jadwal/widgets/day_chip.dart';

void main() {
  Widget buildSubject({
    required DateTime date,
    bool isSelected = true,
    bool isToday = true,
    bool isFriday = false,
    VoidCallback? onTap,
    double width = 360,
  }) {
    return MaterialApp(
      theme: buildRelationalTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DayChip(
              dayKey: isFriday ? 'friday' : 'thursday',
              label: isFriday ? 'Fr' : 'Th',
              date: date,
              isSelected: isSelected,
              isToday: isToday,
              isFriday: isFriday,
              onTap: onTap ?? () {},
              colors: buildRelationalTheme(Brightness.light)
                  .extension<RelationalColors>()!,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows weekday abbreviation and calendar date', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      buildSubject(date: DateTime(2026, 9, 24)),
    );

    expect(find.text('Th'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'Thursday.*24.*today.*selected'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byType(DayChip)),
      isSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('keeps seven dated chips inside a narrow large-text row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRelationalTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: Row(
                children: List.generate(7, (index) {
                  return Expanded(
                    child: DayChip(
                      dayKey: 'thursday',
                      label: 'Th',
                      date: DateTime(2026, 9, 19 + index),
                      isSelected: index == 5,
                      isToday: index == 5,
                      isFriday: false,
                      onTap: () {},
                      colors: buildRelationalTheme(Brightness.light)
                          .extension<RelationalColors>()!,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('Friday remains disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildSubject(
        date: DateTime(2026, 9, 25),
        isFriday: true,
        isToday: true,
        isSelected: true,
        onTap: () => tapped = true,
      ),
    );

    expect(find.text('25'), findsOneWidget);
    expect(find.byIcon(Icons.coffee_rounded), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'today.*selected.*rest day')),
      findsOneWidget,
    );
    await tester.tap(find.byType(DayChip));
    expect(tapped, isFalse);
  });
}
