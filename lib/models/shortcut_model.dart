class ShortcutModel {
  final int? id;
  final String title;
  final String url;
  final String? favicon;

  ShortcutModel({
    this.id,
    required this.title,
    required this.url,
    this.favicon,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'favicon': favicon,
    };
  }

  factory ShortcutModel.fromMap(Map<String, dynamic> map) {
    return ShortcutModel(
      id: map['id'],
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      favicon: map['favicon'],
    );
  }
}
