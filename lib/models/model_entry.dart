class MoodEntry {
  final int? id;
  final String mood;
  final String date;

  MoodEntry({this.id, required this.mood, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mood': mood,
      'date': date,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'],
      mood: map['mood'],
      date: map['date'],
    );
  }
}
