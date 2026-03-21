import 'package:dartz/dartz.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/techniques/data/datasources/technique_local_datasource.dart';
import 'package:viewer/features/techniques/data/datasources/technique_remote_datasource.dart';
import 'package:viewer/features/techniques/data/mappers/technique_mapper.dart';
import 'package:viewer/features/techniques/data/models/technique_dto.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';
import 'package:viewer/utils/error_message.dart';

class TechniqueRepositoryImpl implements TechniqueRepository {
  TechniqueRepositoryImpl({
    required TechniqueRemoteDataSource remote,
    required TechniqueLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final TechniqueRemoteDataSource _remote;
  final TechniqueLocalDataSource _local;
  final Logger _log = Logger('TechniqueRepository');

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> getCached(
    String academyId,
  ) async {
    try {
      final cached = await _local.read(academyId);
      if (cached == null || cached.isEmpty) {
        return const Right([]);
      }
      final entities =
          cached.map((d) => TechniqueMapper.toEntity(d)).toList();
      return Right(entities);
    } on TechniqueFailure catch (e) {
      return Left(e);
    } catch (e, st) {
      _log.warning('getCached', e, st);
      return Left(UnknownTechniqueFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> syncFromRemote(
    String academyId,
  ) async {
    try {
      final dtos = await _remote.fetchAll(academyId);
      try {
        await _local.write(academyId, dtos);
      } catch (e, st) {
        _log.warning(
          'Hive write failed after successful fetch for academy $academyId',
          e,
          st,
        );
        await _tryClearLocal(academyId, context: 'after failed write');
      }
      final entities = dtos.map((d) => TechniqueMapper.toEntity(d)).toList();
      return Right(entities);
    } catch (e, st) {
      _log.warning('syncFromRemote', e, st);
      return Left(NetworkTechniqueFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<void> clearLocalCache(String academyId) async {
    await _tryClearLocal(academyId, context: 'explicit clear');
  }

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    try {
      final dto = await _remote.create(
        academyId: academyId,
        name: name,
        slug: slug,
        description: description,
        videoUrl: videoUrl,
      );
      await _mergeIntoCache(academyId, dto);
      return Right(TechniqueMapper.toEntity(dto));
    } catch (e, st) {
      _log.warning('create', e, st);
      return Left(NetworkTechniqueFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    try {
      final dto = await _remote.update(
        academyId: academyId,
        id: id,
        name: name,
        slug: slug,
        description: description,
        videoUrl: videoUrl,
      );
      await _mergeIntoCache(academyId, dto, replaceId: id);
      return Right(TechniqueMapper.toEntity(dto));
    } catch (e, st) {
      _log.warning('update', e, st);
      return Left(NetworkTechniqueFailure(userFacingMessage(e)));
    }
  }

  @override
  Future<Either<TechniqueFailure, Unit>> delete({
    required String academyId,
    required String id,
  }) async {
    try {
      await _remote.delete(academyId: academyId, id: id);
      await _removeFromCache(academyId, id);
      return const Right(unit);
    } catch (e, st) {
      _log.warning('delete', e, st);
      return Left(NetworkTechniqueFailure(userFacingMessage(e)));
    }
  }

  Future<void> _mergeIntoCache(
    String academyId,
    TechniqueDto dto, {
    String? replaceId,
  }) async {
    try {
      final existing = await _local.read(academyId) ?? [];
      final list = List<TechniqueDto>.from(existing);
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
      _log.warning(
        'Hive merge failed for academy $academyId after remote success',
        e,
        st,
      );
      await _tryClearLocal(academyId, context: 'after failed merge');
    }
  }

  Future<void> _removeFromCache(String academyId, String id) async {
    try {
      final existing = await _local.read(academyId) ?? [];
      final list =
          existing.where((e) => e.id != id).toList(growable: false);
      await _local.write(academyId, list);
    } catch (e, st) {
      _log.warning(
        'Hive remove failed for academy $academyId (id=$id) after remote delete',
        e,
        st,
      );
      await _tryClearLocal(academyId, context: 'after failed remove');
    }
  }

  Future<void> _tryClearLocal(String academyId, {required String context}) async {
    try {
      await _local.clear(academyId);
      _log.fine('Hive cleared for academy $academyId ($context)');
    } catch (e, st) {
      _log.warning('Hive clear failed for academy $academyId ($context)', e, st);
    }
  }
}
