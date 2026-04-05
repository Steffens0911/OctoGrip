import 'package:viewer/utils/form_utils.dart';

class WeeklyPanelLoginUserItem {
  final String userId;
  final String? name;
  final String email;
  final String role;
  final String? academyId;
  final int distinctLoginDaysInWeek;
  final List<DateTime> loginDays;

  WeeklyPanelLoginUserItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.academyId,
    required this.distinctLoginDaysInWeek,
    required this.loginDays,
  });

  factory WeeklyPanelLoginUserItem.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['login_days'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList();
    final parsedDays = rawDays
        .map(parseApiDate)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return WeeklyPanelLoginUserItem(
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      academyId: json['academy_id'] as String?,
      distinctLoginDaysInWeek:
          (json['distinct_login_days_in_week'] as num?)?.toInt() ?? 0,
      loginDays: parsedDays,
    );
  }
}

class WeeklyPanelLoginsReport {
  final String? academyId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int eligibleUsersCount;
  final int usersLoggedAtLeastOnce;
  final List<WeeklyPanelLoginUserItem> users;

  WeeklyPanelLoginsReport({
    required this.academyId,
    required this.weekStart,
    required this.weekEnd,
    required this.eligibleUsersCount,
    required this.usersLoggedAtLeastOnce,
    required this.users,
  });

  factory WeeklyPanelLoginsReport.fromJson(Map<String, dynamic> json) {
    final weekStart =
        parseApiDate(json['week_start'] as String?) ?? DateTime.now();
    final weekEnd = parseApiDate(json['week_end'] as String?) ?? DateTime.now();
    final users = (json['users'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(WeeklyPanelLoginUserItem.fromJson)
        .toList();
    return WeeklyPanelLoginsReport(
      academyId: json['academy_id'] as String?,
      weekStart: weekStart,
      weekEnd: weekEnd,
      eligibleUsersCount: (json['eligible_users_count'] as num?)?.toInt() ?? 0,
      usersLoggedAtLeastOnce:
          (json['users_logged_at_least_once'] as num?)?.toInt() ?? 0,
      users: users,
    );
  }
}
