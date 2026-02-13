class Lesson {
  final String id;
  final String title;
  final String slug;
  final String? videoUrl;
  final String? content;
  final int orderIndex;
  final String techniqueId;

  Lesson({
    required this.id,
    required this.title,
    required this.slug,
    this.videoUrl,
    this.content,
    required this.orderIndex,
    required this.techniqueId,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      videoUrl: json['video_url'] as String?,
      content: json['content'] as String?,
      orderIndex: (json['order_index'] as num).toInt(),
      techniqueId: json['technique_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'video_url': videoUrl,
        'content': content,
        'order_index': orderIndex,
        'technique_id': techniqueId,
      };
}
