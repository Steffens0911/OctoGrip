import 'package:viewer/features/trophies/data/models/trophy_dto.dart';
import 'package:viewer/services/api_service.dart';

abstract class TrophyRemoteDataSource {
  Future<List<TrophyDto>> fetchAll(String academyId);
  Future<TrophyDto> create({
    required String academyId,
    required String techniqueId,
    required String name,
    required String startDate,
    required String endDate,
    required int targetCount,
    required String awardKind,
    int? minDurationDays,
    int minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
  });
  Future<TrophyDto> update({
    required String id,
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
    bool setMaxCountPerOpponent = false,
  });
  Future<void> delete(String id);
}

class TrophyRemoteDataSourceImpl implements TrophyRemoteDataSource {
  TrophyRemoteDataSourceImpl(this._api);

  final ApiService _api;

  @override
  Future<List<TrophyDto>> fetchAll(String academyId) async {
    final list = await _api.getTrophies(academyId, cacheBust: true);
    return list.map((e) => TrophyDto.fromJson(e, academyId: academyId)).toList();
  }

  @override
  Future<TrophyDto> create({
    required String academyId,
    required String techniqueId,
    required String name,
    required String startDate,
    required String endDate,
    required int targetCount,
    required String awardKind,
    int? minDurationDays,
    int minRewardLevelToUnlock = 0,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
  }) async {
    final map = await _api.createTrophy(
      academyId: academyId,
      techniqueId: techniqueId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      targetCount: targetCount,
      awardKind: awardKind,
      minDurationDays: minDurationDays,
      minRewardLevelToUnlock: minRewardLevelToUnlock,
      minGraduationToUnlock: minGraduationToUnlock,
      maxCountPerOpponent: maxCountPerOpponent,
    );
    return TrophyDto.fromJson(map, academyId: academyId);
  }

  @override
  Future<TrophyDto> update({
    required String id,
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
    bool setMaxCountPerOpponent = false,
  }) async {
    final map = await _api.updateTrophy(
      id,
      techniqueId: techniqueId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      targetCount: targetCount,
      awardKind: awardKind,
      minDurationDays: minDurationDays,
      minRewardLevelToUnlock: minRewardLevelToUnlock,
      minGraduationToUnlock: minGraduationToUnlock,
      maxCountPerOpponent: maxCountPerOpponent,
      setMaxCountPerOpponent: setMaxCountPerOpponent,
    );
    return TrophyDto.fromJson(map, academyId: map['academy_id'] as String);
  }

  @override
  Future<void> delete(String id) => _api.deleteTrophy(id);
}
