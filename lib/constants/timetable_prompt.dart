/// The exact prompt the user copies and pastes into any AI
/// (Claude, ChatGPT, Gemini, etc.) along with their timetable image.
///
/// IMPORTANT: If you change this prompt, the JSON shape it produces must
/// still match the schema expected by `JsonValidator` and `Period.fromJson`.
/// Keep both in sync.
const String kTimetablePrompt = '''
Analyze the attached image of a teacher's weekly timetable and extract the schedule into a structured JSON format.

### 1. Orientation & Grid Reading
- The image may be rotated (portrait or landscape). Locate the days header row and the period/time column to correctly orient your reading of the grid, regardless of the camera angle.
- Read the exact start and end times for each of the 9 periods directly from the image headers. Do not guess or assume times.

### 2. Data Extraction Rules
- **Days:** Map abbreviations to full lowercase keys: Sa (saturday), Su (sunday), Mo (monday), Tu (tuesday), We (wednesday), Th (thursday).
- **Cells:** Each occupied cell contains a subject code (e.g., ENG, HAD, TMN) and a classroom (e.g., CL 6). 
- **Empty Cells:** Ignore them completely. Only output objects for cells that contain a subject.
- **Time Format:** Format all extracted times into standard 12-hour AM/PM format (e.g., "2:00 PM").

### 3. Output Rules
- Output **ONLY** the JSON inside a standard markdown code block. 
- Absolutely no greetings, explanations, formatting notes, or conversational text before or after the JSON block.

### Expected JSON Schema
Return exactly this structure, populated with the real data from the image:

```json
{
  "teacher": "TEACHER NAME",
  "timetable": {
    "saturday": [
      {
        "period": 7,
        "subject": "HAD",
        "classroom": "CL 6",
        "start": "2:00 PM",
        "end": "2:40 PM"
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
''';

/// Valid day keys, in week order starting Saturday (matches the source
/// timetable layout). Used for iteration and validation.
const List<String> kDayKeys = [
  'saturday',
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
];

/// Human-friendly labels for display.
const Map<String, String> kDayLabels = {
  'saturday': 'Saturday',
  'sunday': 'Sunday',
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
};

/// Two-letter abbreviations used by the day selector chips and the
/// edit grid headers.
const Map<String, String> kDayAbbreviations = {
  'saturday': 'Sa',
  'sunday': 'Su',
  'monday': 'Mo',
  'tuesday': 'Tu',
  'wednesday': 'We',
  'thursday': 'Th',
  'friday': 'Fr',
};
