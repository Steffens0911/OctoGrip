/// Dados para exibir uma lição/técnica na tela de visualização (missão do dia ou biblioteca).
/// Se [missionId] estiver preenchido, Concluir chama POST /executions (com adversário) ou POST /mission_complete; senão POST /lesson_complete.
/// [alreadyCompleted] indica se já está concluída (botão desabilitado ao abrir).
/// [academyId] usado para listar colegas ao concluir missão (gamificação).
class LessonViewData {
  final String? lessonId;
  final String? missionId;
  final String title;
  final String description;
  final String videoUrl;
  final String? techniqueName;
  final String? positionName;
  final int multiplier;
  final String userId;
  final String? academyId;
  final int? estimatedDurationSeconds;
  final bool alreadyCompleted;

  LessonViewData({
    this.lessonId,
    this.missionId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.userId,
    this.academyId,
    this.techniqueName,
    this.positionName,
    this.multiplier = 1,
    this.estimatedDurationSeconds,
    this.alreadyCompleted = false,
  });
}
