import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/controllers/edit_timetable_controller.dart';

void main() {
  group('EditTimetableController', () {
    late Map<String, dynamic> initialTimetable;

    setUp(() {
      initialTimetable = {
        'saturday': [
          {
            'period': 1,
            'subject': 'ENG',
            'classroom': 'Room 101',
            'start': '8:30 AM',
            'end': '9:15 AM',
          },
          {
            'period': 2,
            'subject': 'MATH',
            'classroom': 'Room 102',
            'start': '9:20 AM',
            'end': '10:05 AM',
          },
        ],
        'sunday': [],
        'monday': [],
        'tuesday': [],
        'wednesday': [],
        'thursday': [],
      };
    });

    test('reads existing periods accurately', () {
      final controller = EditTimetableController(initialTimetable, periodCount: 9);
      final p1 = controller.getPeriod('saturday', 1);
      expect(p1, isNotNull);
      expect(p1!['subject'], 'ENG');
      expect(p1['classroom'], 'Room 101');

      final p3 = controller.getPeriod('saturday', 3);
      expect(p3, isNull);
    });

    test('creates and edits periods with undo and redo history', () {
      final controller = EditTimetableController(initialTimetable, periodCount: 9);

      // Create period 3
      controller.createPeriod('saturday', 3, {
        'subject': 'SCI',
        'classroom': 'Lab 1',
        'start': '10:20 AM',
        'end': '11:05 AM',
      });

      expect(controller.hasChanges, isTrue);
      expect(controller.canUndo, isTrue);
      expect(controller.getPeriod('saturday', 3)?['subject'], 'SCI');

      // Undo create
      controller.undo();
      expect(controller.getPeriod('saturday', 3), isNull);
      expect(controller.canRedo, isTrue);

      // Redo create
      controller.redo();
      expect(controller.getPeriod('saturday', 3)?['subject'], 'SCI');

      // Edit period 3
      controller.editPeriod('saturday', 3, {
        'subject': 'PHYS',
        'classroom': 'Lab 2',
        'start': '10:20 AM',
        'end': '11:05 AM',
      });
      expect(controller.getPeriod('saturday', 3)?['subject'], 'PHYS');

      // Undo edit
      controller.undo();
      expect(controller.getPeriod('saturday', 3)?['subject'], 'SCI');
    });

    test('deletes periods with undo support', () {
      final controller = EditTimetableController(initialTimetable, periodCount: 9);

      controller.deletePeriod('saturday', 1);
      expect(controller.getPeriod('saturday', 1), isNull);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.getPeriod('saturday', 1)?['subject'], 'ENG');
    });

    test('adds and removes period columns adjusting higher period indices', () {
      final controller = EditTimetableController(initialTimetable, periodCount: 9);
      expect(controller.periodCount, 9);

      controller.addPeriodColumn();
      expect(controller.periodCount, 10);

      // Removing period 1 shifts period 2 to period 1
      controller.removePeriodColumn(1);
      expect(controller.periodCount, 9);
      final shifted = controller.getPeriod('saturday', 1);
      expect(shifted?['subject'], 'MATH');
    });
  });
}
