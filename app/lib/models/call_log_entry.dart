class CallLogEntry {
  final String number;
  final String direction; // 'outgoing', 'incoming', 'missed'
  final DateTime timestamp;
  final int durationSeconds;

  CallLogEntry({
    required this.number,
    required this.direction,
    required this.timestamp,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'direction': direction,
    'timestamp': timestamp.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory CallLogEntry.fromJson(Map<String, dynamic> j) => CallLogEntry(
    number: j['number'] as String,
    direction: j['direction'] as String,
    timestamp: DateTime.parse(j['timestamp'] as String),
    durationSeconds: j['durationSeconds'] as int,
  );
}
