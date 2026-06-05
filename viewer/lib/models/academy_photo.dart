class PhotoAuthor {
  final String id;
  final String? name;
  final String? avatarUrl;

  const PhotoAuthor({required this.id, this.name, this.avatarUrl});

  factory PhotoAuthor.fromJson(Map<String, dynamic> json) {
    return PhotoAuthor(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class PhotoComment {
  final String id;
  final String photoId;
  final PhotoAuthor author;
  final String body;
  final DateTime createdAt;

  const PhotoComment({
    required this.id,
    required this.photoId,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    return PhotoComment(
      id: json['id'] as String,
      photoId: json['photo_id'] as String,
      author: PhotoAuthor.fromJson(json['author'] as Map<String, dynamic>),
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AcademyPhoto {
  final String id;
  final String academyId;
  final PhotoAuthor author;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String status;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool isSystemPost;
  final String? systemPostType;
  final String? systemPostRefId;
  final DateTime createdAt;

  const AcademyPhoto({
    required this.id,
    required this.academyId,
    required this.author,
    this.imageUrl,
    this.thumbnailUrl,
    this.caption,
    required this.status,
    required this.likesCount,
    this.commentsCount = 0,
    required this.likedByMe,
    required this.isSystemPost,
    this.systemPostType,
    this.systemPostRefId,
    required this.createdAt,
  });

  bool get isReady => status == 'ready';

  factory AcademyPhoto.fromJson(Map<String, dynamic> json) {
    return AcademyPhoto(
      id: json['id'] as String,
      academyId: json['academy_id'] as String,
      author: PhotoAuthor.fromJson(json['author'] as Map<String, dynamic>),
      imageUrl: json['image_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      status: json['status'] as String? ?? 'processing',
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      isSystemPost: json['is_system_post'] as bool? ?? false,
      systemPostType: json['system_post_type'] as String?,
      systemPostRefId: json['system_post_ref_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AcademyPhoto copyWith({
    String? id,
    String? academyId,
    PhotoAuthor? author,
    String? imageUrl,
    String? thumbnailUrl,
    String? caption,
    String? status,
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
    bool? isSystemPost,
    String? systemPostType,
    String? systemPostRefId,
    DateTime? createdAt,
  }) {
    return AcademyPhoto(
      id: id ?? this.id,
      academyId: academyId ?? this.academyId,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      status: status ?? this.status,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      isSystemPost: isSystemPost ?? this.isSystemPost,
      systemPostType: systemPostType ?? this.systemPostType,
      systemPostRefId: systemPostRefId ?? this.systemPostRefId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PhotoFeedPage {
  final List<AcademyPhoto> items;
  final String? nextCursor;

  const PhotoFeedPage({required this.items, this.nextCursor});

  factory PhotoFeedPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PhotoFeedPage(
      items: rawItems
          .map((e) => AcademyPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

class PhotoRestriction {
  final String id;
  final String academyId;
  final String userId;
  final String? userName;
  final String? reason;
  final DateTime? expiresAt;
  final bool active;
  final DateTime createdAt;

  const PhotoRestriction({
    required this.id,
    required this.academyId,
    required this.userId,
    this.userName,
    this.reason,
    this.expiresAt,
    required this.active,
    required this.createdAt,
  });

  factory PhotoRestriction.fromJson(Map<String, dynamic> json) {
    return PhotoRestriction(
      id: json['id'] as String,
      academyId: json['academy_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      reason: json['reason'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
