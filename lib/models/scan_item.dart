class ScanItem {
  final String url;
  final DateTime timestamp;
  final String? title;

  ScanItem({
    required this.url,
    required this.timestamp,
    this.title,
  });

  ScanItem copyWith({
    String? url,
    DateTime? timestamp,
    String? title,
  }) {
    return ScanItem(
      url: url ?? this.url,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
    );
  }

  /// Factory constructor to create a ScanItem from JSON map.
  factory ScanItem.fromJson(Map<String, dynamic> json) {
    return ScanItem(
      url: json['url'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String?,
    );
  }

  /// Converts the ScanItem to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'timestamp': timestamp.toIso8601String(),
      if (title != null) 'title': title,
    };
  }
}

