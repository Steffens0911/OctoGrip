// Gerado a partir dos `fromJson` de lib/models; inclua aqui todo modelo novo.
//
// Contrato com a API: um app já instalado precisa sobreviver a campos que a API
// deixa de mandar (ou manda null) e a campos novos que ele não conhece.
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/models/academy_student_list_item.dart';
import 'package:viewer/models/active_students_report.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/models/attendance_qr.dart';
import 'package:viewer/models/attendance_ranking.dart';
import 'package:viewer/models/audit_history.dart';
import 'package:viewer/models/engagement_report.dart';
import 'package:viewer/models/face_checkin.dart';
import 'package:viewer/models/face_recognition.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/mission_completion_report.dart';
import 'package:viewer/models/mission_history_item.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/notification_model.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/models/pre_checkin.dart';
import 'package:viewer/models/professor.dart';
import 'package:viewer/models/professor_impact.dart';
import 'package:viewer/models/punctuality_report.dart';
import 'package:viewer/models/students_attention_report.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/technique_execution_summary.dart';
import 'package:viewer/models/training_session.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/models/user_academy_stats.dart';
import 'package:viewer/models/weekly_kit.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';

void main() {
  final parsers = <String, Object Function()>{
    'Academy': () => Academy.fromJson(<String, dynamic>{}),
    'AcademyDifficultyEntry': () => AcademyDifficultyEntry.fromJson(<String, dynamic>{}),
    'AcademyRankingEntry': () => AcademyRankingEntry.fromJson(<String, dynamic>{}),
    'AcademyWeeklyReport': () => AcademyWeeklyReport.fromJson(<String, dynamic>{}),
    'AcademyPhoto': () => AcademyPhoto.fromJson(<String, dynamic>{}),
    'PhotoAuthor': () => PhotoAuthor.fromJson(<String, dynamic>{}),
    'PhotoComment': () => PhotoComment.fromJson(<String, dynamic>{}),
    'PhotoFeedPage': () => PhotoFeedPage.fromJson(<String, dynamic>{}),
    'PhotoRestriction': () => PhotoRestriction.fromJson(<String, dynamic>{}),
    'AcademyStudentListItem': () => AcademyStudentListItem.fromJson(<String, dynamic>{}),
    'ActiveStudent': () => ActiveStudent.fromJson(<String, dynamic>{}),
    'ActiveStudentsReport': () => ActiveStudentsReport.fromJson(<String, dynamic>{}),
    'AttendanceMyStatsModel': () => AttendanceMyStatsModel.fromJson(<String, dynamic>{}),
    'AttendancePeriodBucketModel': () => AttendancePeriodBucketModel.fromJson(<String, dynamic>{}),
    'AttendanceRecordModel': () => AttendanceRecordModel.fromJson(<String, dynamic>{}),
    'AttendanceRecordWithSessionModel': () => AttendanceRecordWithSessionModel.fromJson(<String, dynamic>{}),
    'AttendanceSessionModel': () => AttendanceSessionModel.fromJson(<String, dynamic>{}),
    'AttendanceSessionStatModel': () => AttendanceSessionStatModel.fromJson(<String, dynamic>{}),
    'AttendanceStudentDetailModel': () => AttendanceStudentDetailModel.fromJson(<String, dynamic>{}),
    'AttendanceStudentStatModel': () => AttendanceStudentStatModel.fromJson(<String, dynamic>{}),
    'AttendanceUserSummaryModel': () => AttendanceUserSummaryModel.fromJson(<String, dynamic>{}),
    'QrTokenModel': () => QrTokenModel.fromJson(<String, dynamic>{}),
    'AttendanceMyPositionModel': () => AttendanceMyPositionModel.fromJson(<String, dynamic>{}),
    'AttendanceRankingEntryModel': () => AttendanceRankingEntryModel.fromJson(<String, dynamic>{}),
    'AttendanceRankingModel': () => AttendanceRankingModel.fromJson(<String, dynamic>{}),
    'AuditHistoryResult': () => AuditHistoryResult.fromJson(<String, dynamic>{}),
    'AuditLogItem': () => AuditLogItem.fromJson(<String, dynamic>{}),
    'RestoreResult': () => RestoreResult.fromJson(<String, dynamic>{}),
    'EngagementPeriodMetrics': () => EngagementPeriodMetrics.fromJson(<String, dynamic>{}),
    'EngagementReport': () => EngagementReport.fromJson(<String, dynamic>{}),
    'FaceArriveResponse': () => FaceArriveResponse.fromJson(<String, dynamic>{}),
    'FaceRecognitionJobStatusModel': () => FaceRecognitionJobStatusModel.fromJson(<String, dynamic>{}),
    'FaceRecognitionResultModel': () => FaceRecognitionResultModel.fromJson(<String, dynamic>{}),
    'FaceRecognitionStudentModel': () => FaceRecognitionStudentModel.fromJson(<String, dynamic>{}),
    'FaceRecognitionSubmitResponse': () => FaceRecognitionSubmitResponse.fromJson(<String, dynamic>{}),
    'GlobalPartner': () => GlobalPartner.fromJson(<String, dynamic>{}),
    'Lesson': () => Lesson.fromJson(<String, dynamic>{}),
    'ChampionshipEvent': () => ChampionshipEvent.fromJson(<String, dynamic>{}),
    'TrophyAward': () => TrophyAward.fromJson(<String, dynamic>{}),
    'TrophyTemplate': () => TrophyTemplate.fromJson(<String, dynamic>{}),
    'UserTrophyAwardsResponse': () => UserTrophyAwardsResponse.fromJson(<String, dynamic>{}),
    'Mission': () => Mission.fromJson(<String, dynamic>{}),
    'MissionCompletionReport': () => MissionCompletionReport.fromJson(<String, dynamic>{}),
    'MissionHistoryItem': () => MissionHistoryItem.fromJson(<String, dynamic>{}),
    'MissionToday': () => MissionToday.fromJson(<String, dynamic>{}),
    'MissionWeek': () => MissionWeek.fromJson(<String, dynamic>{}),
    'MissionWeekSlot': () => MissionWeekSlot.fromJson(<String, dynamic>{}),
    'WeeklyKitOption': () => WeeklyKitOption.fromJson(<String, dynamic>{}),
    'NotificationModel': () => NotificationModel.fromJson(<String, dynamic>{}),
    'Partner': () => Partner.fromJson(<String, dynamic>{}),
    'Confirmant': () => Confirmant.fromJson(<String, dynamic>{}),
    'PreCheckinStatus': () => PreCheckinStatus.fromJson(<String, dynamic>{}),
    'Professor': () => Professor.fromJson(<String, dynamic>{}),
    'AtRiskStudent': () => AtRiskStudent.fromJson(<String, dynamic>{}),
    'DailyVideoView': () => DailyVideoView.fromJson(<String, dynamic>{}),
    'ExecutionDetail': () => ExecutionDetail.fromJson(<String, dynamic>{}),
    'ProfessorImpact': () => ProfessorImpact.fromJson(<String, dynamic>{}),
    'TechniqueImpact': () => TechniqueImpact.fromJson(<String, dynamic>{}),
    'PunctualityReport': () => PunctualityReport.fromJson(<String, dynamic>{}),
    'PunctualityStudentEntry': () => PunctualityStudentEntry.fromJson(<String, dynamic>{}),
    'StudentAttentionItem': () => StudentAttentionItem.fromJson(<String, dynamic>{}),
    'StudentsAttentionReport': () => StudentsAttentionReport.fromJson(<String, dynamic>{}),
    'Technique': () => Technique.fromJson(<String, dynamic>{}),
    'TechniqueExecutionSummary': () => TechniqueExecutionSummary.fromJson(<String, dynamic>{}),
    'TrainingSession': () => TrainingSession.fromJson(<String, dynamic>{}),
    'TrainingTemplate': () => TrainingTemplate.fromJson(<String, dynamic>{}),
    'TrainingStats': () => TrainingStats.fromJson(<String, dynamic>{}),
    'TrainingVideo': () => TrainingVideo.fromJson(<String, dynamic>{}),
    'TrainingVideoCompletionResult': () => TrainingVideoCompletionResult.fromJson(<String, dynamic>{}),
    'AcademyRecentItem': () => AcademyRecentItem.fromJson(<String, dynamic>{}),
    'AcademyUserEarned': () => AcademyUserEarned.fromJson(<String, dynamic>{}),
    'AcademyUserEarnedItem': () => AcademyUserEarnedItem.fromJson(<String, dynamic>{}),
    'TrophyHomeSummary': () => TrophyHomeSummary.fromJson(<String, dynamic>{}),
    'TrophyHomeSummaryItem': () => TrophyHomeSummaryItem.fromJson(<String, dynamic>{}),
    'TrophyWithEarned': () => TrophyWithEarned.fromJson(<String, dynamic>{}),
    'UsageMetrics': () => UsageMetrics.fromJson(<String, dynamic>{}),
    'UserModel': () => UserModel.fromJson(<String, dynamic>{}),
    'UserAcademyStats': () => UserAcademyStats.fromJson(<String, dynamic>{}),
    'WeeklyKitItemRead': () => WeeklyKitItemRead.fromJson(<String, dynamic>{}),
    'WeeklyKitRead': () => WeeklyKitRead.fromJson(<String, dynamic>{}),
    'WeeklyPanelLoginUserItem': () => WeeklyPanelLoginUserItem.fromJson(<String, dynamic>{}),
    'WeeklyPanelLoginsReport': () => WeeklyPanelLoginsReport.fromJson(<String, dynamic>{}),
  };

  group('fromJson com JSON vazio não lança exceção', () {
    for (final entry in parsers.entries) {
      test(entry.key, () => expect(entry.value, returnsNormally));
    }
  });

  test('campo desconhecido é ignorado', () {
    expect(
      () => UserModel.fromJson(<String, dynamic>{
        'id': 'u1',
        'email': 'a@b.com',
        'campo_que_ainda_nao_existe': {'qualquer': [1, 2, 3]},
      }),
      returnsNormally,
    );
  });
}
