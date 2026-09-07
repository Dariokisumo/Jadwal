/// Default start and end times for each period (1–9).
///
/// Used to auto-fill time pickers when creating a new period.
/// Times are in strict `h:mm a` format (12-hour, space-separated).
const Map<int, List<String>> kPeriodSchedule = {
  1: ['7:20 AM', '8:05 AM'],
  2: ['8:05 AM', '8:50 AM'],
  3: ['9:45 AM', '10:30 AM'],
  4: ['10:30 AM', '11:15 AM'],
  5: ['11:30 AM', '12:10 PM'],
  6: ['12:10 PM', '12:55 PM'],
  7: ['2:00 PM', '2:40 PM'],
  8: ['2:40 PM', '3:20 PM'],
  9: ['3:30 PM', '4:10 PM'],
};

/// Returns sensible default start and end times for any period number.
/// For periods 1–9, uses [kPeriodSchedule]. For periods beyond 9,
/// generates sequential 40-minute blocks with 5-minute passing breaks.
List<String> defaultTimingForPeriod(int periodNumber) {
  if (kPeriodSchedule.containsKey(periodNumber)) {
    return List<String>.from(kPeriodSchedule[periodNumber]!);
  }
  // Base off period 9 end time: 4:10 PM (16:10 = 970 minutes from midnight)
  final offset = periodNumber - 9;
  final startMin = 970 + (offset - 1) * 45;
  final endMin = startMin + 40;

  String formatMinutes(int totalMin) {
    var h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    var hour12 = h % 12;
    if (hour12 == 0) hour12 = 12;
    final mStr = m.toString().padLeft(2, '0');
    return '$hour12:$mStr $period';
  }

  return [formatMinutes(startMin), formatMinutes(endMin)];
}

/// Classroom options for the class selector dropdown.
const List<String> kClassOptions = [
  'CL 1',
  'CL 2',
  'CL 3',
  'CL 4',
  'CL 5',
  'CL 6',
  'CL 7',
  'CL 8',
  'CL 9',
  'CL 10',
];
