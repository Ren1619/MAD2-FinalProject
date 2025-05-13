class Log {
  final String id;
  final String description;
  final String timestamp;
  final String type;
  final String user;
  final String? ip;
  final String? companyId;

  Log({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.type,
    required this.user,
    this.ip,
    this.companyId,
  });

  // Convert a Log object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'timestamp': timestamp,
      'type': type,
      'user': user,
      'ip': ip,
      'companyId': companyId,
    };
  }

  // Create a Log object from a Map
  factory Log.fromMap(Map<String, dynamic> map) {
    return Log(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      timestamp: map['timestamp'] ?? '',
      type: map['type'] ?? '',
      user: map['user'] ?? '',
      ip: map['ip'],
      companyId: map['companyId'],
    );
  }

  // Format timestamp for display
  String getFormattedTimestamp() {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}