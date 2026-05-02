class FaceRecognitionSubmitResponse {
  final String jobId;
  final String status;
  final String message;

  FaceRecognitionSubmitResponse({
    required this.jobId,
    required this.status,
    required this.message,
  });

  factory FaceRecognitionSubmitResponse.fromJson(Map<String, dynamic> json) {
    return FaceRecognitionSubmitResponse(
      jobId: json['job_id'] as String,
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String? ?? '',
    );
  }
}

class FaceRecognitionStudentModel {
  final String id;
  final String? name;
  final String? avatarUrl;
  final String? belt;

  FaceRecognitionStudentModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.belt,
  });

  factory FaceRecognitionStudentModel.fromJson(Map<String, dynamic> json) {
    return FaceRecognitionStudentModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      belt: json['belt'] as String?,
    );
  }
}

class FaceRecognitionResultModel {
  final int faceIndex;
  final String faceCropBase64;
  final String status;
  final double confidence;
  final FaceRecognitionStudentModel? student;

  FaceRecognitionResultModel({
    required this.faceIndex,
    required this.faceCropBase64,
    required this.status,
    required this.confidence,
    required this.student,
  });

  factory FaceRecognitionResultModel.fromJson(Map<String, dynamic> json) {
    return FaceRecognitionResultModel(
      faceIndex: (json['face_index'] as num?)?.toInt() ?? 0,
      faceCropBase64: json['face_crop_base64'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      student: json['student'] is Map<String, dynamic>
          ? FaceRecognitionStudentModel.fromJson(
              json['student'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FaceRecognitionJobStatusModel {
  final String jobId;
  final String status;
  final String sessionId;
  final int totalFacesDetected;
  final List<FaceRecognitionResultModel> results;
  final String? errorMessage;
  /// JPEG base64 reduzido só para conferência (opcional).
  final String? referencePhotoBase64;

  FaceRecognitionJobStatusModel({
    required this.jobId,
    required this.status,
    required this.sessionId,
    required this.totalFacesDetected,
    required this.results,
    required this.errorMessage,
    required this.referencePhotoBase64,
  });

  factory FaceRecognitionJobStatusModel.fromJson(Map<String, dynamic> json) {
    final resultList = (json['results'] as List<dynamic>? ?? const []);
    return FaceRecognitionJobStatusModel(
      jobId: json['job_id'] as String,
      status: json['status'] as String? ?? 'pending',
      sessionId: json['session_id'] as String,
      totalFacesDetected: (json['total_faces_detected'] as num?)?.toInt() ?? 0,
      results: resultList
          .whereType<Map<String, dynamic>>()
          .map(FaceRecognitionResultModel.fromJson)
          .toList(),
      errorMessage: json['error_message'] as String?,
      referencePhotoBase64: json['reference_photo_base64'] as String?,
    );
  }
}

class FaceRecognitionEmbeddingStatusStudentModel {
  final String studentId;
  final String? name;
  final String email;
  final String? avatarUrl;
  final bool hasEmbedding;

  FaceRecognitionEmbeddingStatusStudentModel({
    required this.studentId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.hasEmbedding,
  });

  factory FaceRecognitionEmbeddingStatusStudentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return FaceRecognitionEmbeddingStatusStudentModel(
      studentId: json['student_id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      hasEmbedding: json['has_embedding'] as bool? ?? false,
    );
  }
}

class FaceRecognitionEmbeddingStatusModel {
  final String academyId;
  final int totalStudents;
  final int withEmbedding;
  final int withoutEmbedding;
  final List<FaceRecognitionEmbeddingStatusStudentModel> students;

  FaceRecognitionEmbeddingStatusModel({
    required this.academyId,
    required this.totalStudents,
    required this.withEmbedding,
    required this.withoutEmbedding,
    required this.students,
  });

  factory FaceRecognitionEmbeddingStatusModel.fromJson(
      Map<String, dynamic> json) {
    final rows = (json['students'] as List<dynamic>? ?? const []);
    return FaceRecognitionEmbeddingStatusModel(
      academyId: json['academy_id'] as String,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      withEmbedding: (json['with_embedding'] as num?)?.toInt() ?? 0,
      withoutEmbedding: (json['without_embedding'] as num?)?.toInt() ?? 0,
      students: rows
          .whereType<Map<String, dynamic>>()
          .map(FaceRecognitionEmbeddingStatusStudentModel.fromJson)
          .toList(),
    );
  }
}
