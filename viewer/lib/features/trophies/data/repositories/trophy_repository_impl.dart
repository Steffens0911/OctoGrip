import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/trophies/data/datasources/trophy_local_datasource.dart';
import 'package:viewer/features/trophies/data/datasources/trophy_remote_datasource.dart';
import 'package:viewer/features/trophies/data/mappers/trophy_mapper.dart';
import 'package:viewer/features/trophies/data/models/trophy_dto.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';
import 'package:viewer/utils/error_message.dart';

class TrophyRepositoryImpl implements TrophyRepository {
  TrophyRepositoryImpl({
    required TrophyRemoteDataSource remote,
    required TrophyLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final TrophyRemoteDataSource _remote;
  final TrophyLocalDataSource _local;
  final Logger _log = Logger('TrophyRepository');

  @override
  Future<Either<TrophyFailure, List<TrophyEntity>>> getCached(
    String academyId,
  ) async {
    try {
      final cached = await _local.read(academyId);
      if (cached == null || cached.isEmpty) {
        return const Right([]);
      }
      return Right(cached.map((d) => TrophyMapper.toEntity(d)).toList());
    } on TrophyFailure catch (e) {
      return Left(e);
    } catch (e, st) {
      _log.warning('getCached', e, st);
      return Left(UnknownTrophyFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<Either<TrophyFailure, List<TrophyEntity>>> syncFromRemote(
    String academyId,
  ) async {
    try {
      final dtos = await _remote.fetchAll(academyId);
      try {
        await _local.write(academyId, dtos);
      } catch (e, st) {
        _log.warning('Hive write failed after fetch', e, st);
        await _tryClearLocal(academyId);
      }
      return Right(dtos.map((d) => TrophyMapper.toEntity(d)).toList());
    } catch (e, st) {
      _log.warning('syncFromRemote', e, st);
      return Left(NetworkTrophyFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<void> clearLocalCache(String academyId) =>
      _tryClearLocal(academyId);

  @override
  Future<Either<TrophyFailure, TrophyEntity>> create({
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
    try {
      final dto = await _remote.create(
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
      await _mergeIntoCache(academyId, dto);
      return Right(TrophyMapper.toEntity(dto));
    } catch (e, st) {
      _log.warning('create', e, st);
      return Left(NetworkTrophyFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<Either<TrophyFailure, TrophyEntity>> update({
    required String id,
    required String academyId,
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
    try {
      final dto = await _remote.update(
        id: id,
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
      await _mergeIntoCache(academyId, dto, replaceId: id);
      return Right(TrophyMapper.toEntity(dto));
    } catch (e, st) {
      _log.warning('update', e, st);
      return Left(NetworkTrophyFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<Either<TrophyFailure, Unit>> delete({
    required String academyId,
    required String id,
  }) async {
    try {
      await _remote.delete(id);
      await _removeFromCache(academyId, id);
      return const Right(unit);
    } catch (e, st) {
      _log.warning('delete', e, st);
      return Left(NetworkTrophyFailure(userFacingMessage(e)));
    }
  }

  Future<void> _mergeIntoCache(
    String academyId,
    TrophyDto dto, {
    String? replaceId,
  }) async {
    try {
      final existing = await _local.read(academyId) ?? [];
      final list = List<TrophyDto>.from(existing);
      final idx = list.indexWhere(
        (e) => e.id == (replaceId ?? dto.id) || e.id == dto.id,
      );
      if (idx >= 0) {
        list[idx] = dto;
      } else {
        list.add(dto);
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await _local.write(academyId, list);
    } catch (e, st) {
      _log.warning('Hive merge failed', e, st);
      await _tryClearLocal(academyId);
    }
  }

  Future<void> _removeFromCache(String academyId, String id) async {
    try {
      final existing = await _local.read(academyId) ?? [];
      final list = existing.where((e) => e.id != id).toList(growable: false);
      await _local.write(academyId, list);
    } catch (e, st) {
      _log.warning('Hive remove failed', e, st);
      await _tryClearLocal(academyId);
    }
  }

  Future<void> _tryClearLocal(String academyId) async {
    try {
      await _local.clear(academyId);
    } catch (e, st) {
      _log.warning('Hive clear failed', e, st);
    }
  }
}
