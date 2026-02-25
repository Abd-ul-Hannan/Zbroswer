class HistoryItem {
  final int? id;
  final String title;
  final String url;
  final String timestamp;

  HistoryItem({
    this.id,
    required this.title,
    required this.url,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'url': url, 'timestamp': timestamp};
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      timestamp: map['timestamp'],
    );
  }
}
