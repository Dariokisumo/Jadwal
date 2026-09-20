import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/models/saved_timetable.dart';
import 'package:jadwal/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedTimetable model tests', () {
    test('serializes and deserializes correctly', () {
      final sampleData = {
        'teacher': 'Dr. Dario',
        'timetable': {
          'saturday': [
            {
              'period': 1,
              'subject': 'ENG',
              'classroom': 'CL 6',
              'start': '8:00 AM',
              'end': '8:40 AM'
            }
          ],
          'sunday': [],
          'monday': [],
          'tuesday': [],
          'wednesday': [],
          'thursday': []
        }
      };

      final timetable = SavedTimetable(
        id: '12345',
        name: 'Fall Semester',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        data: sampleData,
      );

      expect(timetable.teacher, equals('Dr. Dario'));
      expect(timetable.totalClasses, equals(1));
      expect(timetable.activeDays, equals(['Sat']));
      expect(timetable.timeSpan, equals('8:00 AM – 8:40 AM'));

      final json = timetable.toJson();
      final restored = SavedTimetable.fromJson(json);

      expect(restored.id, equals('12345'));
      expect(restored.name, equals('Fall Semester'));
      expect(restored.teacher, equals('Dr. Dario'));
      expect(restored.totalClasses, equals(1));
    });

    test('generates valid .jadwal file content with metadata', () {
      final sampleData = {
        'teacher': 'Prof. Alan',
        'timetable': {
          'saturday': [],
          'sunday': [],
          'monday': [],
          'tuesday': [],
          'wednesday': [],
          'thursday': []
        }
      };

      final timetable = SavedTimetable(
        id: 'test_id',
        name: 'Spring Schedule',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        data: sampleData,
      );

      final fileContent = timetable.toFileContent();
      expect(fileContent, contains('"app": "jadwal"'));
      expect(fileContent, contains('"format_version": 1'));
      expect(fileContent, contains('"teacher": "Prof. Alan"'));
      expect(fileContent, contains('"name": "Spring Schedule"'));
    });

    test('StorageService saved timetables library operations', () async {
      SharedPreferences.setMockInitialValues({
        'timetable_json': '{"teacher":"Test Teacher","timetable":{"saturday":[],"sunday":[],"monday":[],"tuesday":[],"wednesday":[],"thursday":[]}}',
      });

      // Loading when empty auto-seeds current live timetable
      final list = await StorageService.loadSavedTimetables();
      expect(list.isNotEmpty, isTrue);
      expect(list.first.teacher, equals('Test Teacher'));

      // Save a new timetable snapshot
      final newEntry = await StorageService.saveCurrentLiveTimetableAs('My New Schedule');
      expect(newEntry, isNotNull);
      expect(newEntry!.name, equals('My New Schedule'));

      final updatedList = await StorageService.loadSavedTimetables();
      expect(updatedList.length, equals(2));
      expect(updatedList.first.name, equals('My New Schedule'));

      // Activate timetable
      await StorageService.activateTimetable(list.last);
      final activeId = await StorageService.loadActiveTimetableId();
      expect(activeId, equals(list.last.id));
    });
  });
}
