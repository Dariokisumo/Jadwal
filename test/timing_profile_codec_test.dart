import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/models/timing_profile.dart';
import 'package:jadwal/services/timing_profile_codec.dart';

void main() {
  group('TimingProfileCodec', () {
    test('encodes and decodes standard profile using compact binary format', () {
      final original = TimingProfile(
        id: 'test_profile',
        name: 'Winter Timings',
        slots: {
          1: ['8:30 AM', '9:15 AM'],
          2: ['9:20 AM', '10:05 AM'],
          3: ['10:20 AM', '11:05 AM'],
        },
      );

      final encoded = TimingProfileCodec.encode(original);
      expect(encoded.isNotEmpty, isTrue);

      final decoded = TimingProfileCodec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, 'Winter Timings');
      expect(decoded.slots.length, 3);
      expect(decoded.slots[1], ['8:30 AM', '9:15 AM']);
      expect(decoded.slots[2], ['9:20 AM', '10:05 AM']);
      expect(decoded.slots[3], ['10:20 AM', '11:05 AM']);
    });

    test('extracts and decodes from deep link URLs and share formats', () {
      final original = TimingProfile(
        id: 'exam_sched',
        name: 'Exam Schedule',
        slots: {
          1: ['9:00 AM', '12:00 PM'],
        },
      );
      final payload = TimingProfileCodec.encode(original);

      // 1. jadwal:// scheme
      final fromJadwalUri =
          TimingProfileCodec.decode('jadwal://profile?data=$payload');
      expect(fromJadwalUri, isNotNull);
      expect(fromJadwalUri!.name, 'Exam Schedule');
      expect(fromJadwalUri.slots[1], ['9:00 AM', '12:00 PM']);

      // 2. Web URL fragment
      final fromWebUrl = TimingProfileCodec.decode(
          'https://dariokisumo.github.io/p#$payload');
      expect(fromWebUrl, isNotNull);
      expect(fromWebUrl!.name, 'Exam Schedule');

      // 3. JADWAL_PROFILE: code
      final fromCode =
          TimingProfileCodec.decode('JADWAL_PROFILE:$payload');
      expect(fromCode, isNotNull);
      expect(fromCode!.name, 'Exam Schedule');
    });

    test('gracefully returns null on malformed or invalid inputs', () {
      expect(TimingProfileCodec.decode(''), isNull);
      expect(TimingProfileCodec.decode('invalid_data_here'), isNull);
      expect(TimingProfileCodec.decode('{}'), isNull);
      expect(TimingProfileCodec.decode('jadwal://profile?data='), isNull);
    });
  });
}
