class ScanItem {
  final String url;
  final DateTime timestamp;

  ScanItem({
    required this.url,
    required this.timestamp,
  });

  /// Factory constructor to create a ScanItem from JSON map.
  factory ScanItem.fromJson(Map<String, dynamic> json) {
    return ScanItem(
      url: json['url'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Converts the ScanItem to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
