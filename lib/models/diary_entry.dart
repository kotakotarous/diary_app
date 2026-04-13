class DiaryLink {
  final String label;
  final String url;

  DiaryLink({required this.label, required this.url});

  factory DiaryLink.fromJson(Map<String, dynamic> json) => DiaryLink(
        label: json['label'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
}

/// 気分: 5=最高 4=良い 3=普通 2=悪い 1=最悪
class DiaryEntry {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final List<String> tags;
  final List<DiaryLink> links;
  final int? mood; // 1〜5, null=未設定
  final DateTime updatedAt; // 同期用：最終更新日時

  DiaryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    this.tags = const [],
    this.links = const [],
    this.mood,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? date;

  int get wordCount => content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    return DiaryEntry(
      id: json['id'] as String,
      date: date,
      title: json['title'] as String? ?? '',
      content: json['content'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      links: (json['links'] as List<dynamic>?)
              ?.map((e) => DiaryLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mood: json['mood'] as int?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : date,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'content': content,
        'tags': tags,
        'links': links.map((l) => l.toJson()).toList(),
        if (mood != null) 'mood': mood,
        'updatedAt': updatedAt.toIso8601String(),
      };

  DiaryEntry copyWith({
    DateTime? date,
    String? title,
    String? content,
    List<String>? tags,
    List<DiaryLink>? links,
    Object? mood = _sentinel,
    DateTime? updatedAt,
  }) =>
      DiaryEntry(
        id: id,
        date: date ?? this.date,
        title: title ?? this.title,
        content: content ?? this.content,
        tags: tags ?? this.tags,
        links: links ?? this.links,
        mood: mood == _sentinel ? this.mood : mood as int?,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

const _sentinel = Object();
