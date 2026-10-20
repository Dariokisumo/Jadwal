import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/models/period_model.dart';

void main() {
  group('Notification text formatting tests', () {
    test('formats period title and body properly with room', () {
      final period = Period(
        periodNumber: 1,
        subject: 'MAT',
        classroom: 'Room 4',
        start: '8:00 AM',
        end: '8:40 AM',
      );

      final title = period.subject.isNotEmpty
          ? 'Period ${period.periodNumber} · ${period.subject}'
          : 'Period ${period.periodNumber}';
      final room = period.classroom.trim();
      final body = room.isNotEmpty
          ? 'Starts at ${period.start} in $room'
          : 'Starts at ${period.start}';

      expect(title, 'Period 1 · MAT');
      expect(body, 'Starts at 8:00 AM in Room 4');
    });

    test('formats period title and body properly without room (no awkward spacing)', () {
      final period = Period(
        periodNumber: 3,
        subject: 'ENG',
        classroom: '   ',
        start: '10:00 AM',
        end: '10:40 AM',
      );

      final title = period.subject.isNotEmpty
          ? 'Period ${period.periodNumber} · ${period.subject}'
          : 'Period ${period.periodNumber}';
      final room = period.classroom.trim();
      final body = room.isNotEmpty
          ? 'Starts at ${period.start} in $room'
          : 'Starts at ${period.start}';

      expect(title, 'Period 3 · ENG');
      expect(body, 'Starts at 10:00 AM');
    });
  });
}
