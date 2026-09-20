import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/services/json_validator.dart';

void main() {
  group('JsonValidator sanitize & normalization tests', () {
    test('sanitizes markdown fences and chat preamble', () {
      const rawWithFences = '''
Here is your timetable JSON:
```json
{
  "teacher": "Mr. Dario",
  "timetable": {
    "saturday": [
      {
        "period": 1,
        "subject": "ENG",
        "classroom": "CL 6",
        "start": "8:00 AM",
        "end": "8:40 AM"
      }
    ],
    "sunday": [],
    "monday": [],
    "tuesday": [],
    "wednesday": [],
    "thursday": []
  }
}
```
Hope this helps!
''';

      final result = JsonValidator.tryParseAndNormalize(rawWithFences);
      expect(result, isNotNull);
      expect(result!['teacher'], equals('Mr. Dario'));
      expect((result['timetable']['saturday'] as List).length, equals(1));
    });

    test('auto-heals missing day keys with empty lists', () {
      final input = {
        "teacher": "Dr. Sarah",
        "timetable": {
          "saturday": [
            {
              "period": 1,
              "subject": "MATH",
              "classroom": "Room 101",
              "start": "9:00 AM",
              "end": "9:45 AM"
            }
          ]
          // sunday, monday, tuesday, wednesday, thursday are omitted
        }
      };

      final result = JsonValidator.validate(input);
      expect(result.isValid, isTrue);
      final data = result.data!;
      expect(data['teacher'], equals('Dr. Sarah'));
      expect(data['timetable']['sunday'], isEmpty);
      expect(data['timetable']['monday'], isEmpty);
      expect(data['timetable']['thursday'], isEmpty);
    });

    test('normalizes 24-hour time format to 12-hour AM/PM', () {
      expect(JsonValidator.normalizeTime('14:00'), equals('2:00 PM'));
      expect(JsonValidator.normalizeTime('08:30'), equals('8:30 AM'));
      expect(JsonValidator.normalizeTime('0:00'), equals('12:00 AM'));
      expect(JsonValidator.normalizeTime('12:00'), equals('12:00 PM'));
      expect(JsonValidator.normalizeTime('23:59'), equals('11:59 PM'));
    });

    test('normalizes 12-hour time format without space or leading zero', () {
      expect(JsonValidator.normalizeTime('2:00PM'), equals('2:00 PM'));
      expect(JsonValidator.normalizeTime('02:00pm'), equals('2:00 PM'));
      expect(JsonValidator.normalizeTime('8:30am'), equals('8:30 AM'));
      expect(JsonValidator.normalizeTime('08:00 AM'), equals('8:00 AM'));
      expect(JsonValidator.normalizeTime('2:00 PM'), equals('2:00 PM'));
    });

    test('normalizes teacher_name alias and string period numbers', () {
      final input = {
        "teacher_name": "Prof. Smith",
        "timetable": {
          "saturday": [
            {
              "period": "3",
              "subject": "PHY",
              "classroom": "Lab 2",
              "start": "10:00am",
              "end": "10:45am"
            }
          ]
        }
      };

      final result = JsonValidator.validate(input);
      expect(result.isValid, isTrue);
      final data = result.data!;
      expect(data['teacher'], equals('Prof. Smith'));
      final period = (data['timetable']['saturday'] as List).first as Map<String, dynamic>;
      expect(period['period'], equals(3));
      expect(period['start'], equals('10:00 AM'));
      expect(period['end'], equals('10:45 AM'));
    });
  });
}
