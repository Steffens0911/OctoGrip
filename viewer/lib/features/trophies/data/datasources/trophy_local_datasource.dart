import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/trophies/data/models/trophy_dto.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';

List<dynamic> _decodeTrophyListInIsolate(String raw) =>
    jsonDecode(raw) as List<dynamic>;

String _encodeTrophyListInIsolate(List<Map<String, dynamic>> payload) =>
    jsonEncode(payload);

abstract class TrophyLocalDataSource {
  Future<List<TrophyDto>?> read(String academyId);
  Future<void> write(String academyId, List<TrophyDto> items);
  Future<void> clear(String academyId);
}

class TrophyLocalDataSourceImpl implements TrophyLocalDataSource {
  TrophyLocalDataSourceImpl({Box<String>? boxOverride}) : _boxOverride = boxOverride;

  static const String _boxName = 'trophies_module_v1';
  final Logger _log = Logger('TrophyLocalDataSource');
  final Box<String>? _boxOverride;

  Future<Box<String>> get _box async {
    if (_boxOverride != null) return _boxOverride!;
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  String _key(String academyId) => 'academy_$academyId';

  @override
  Future<List<TrophyDto>?> read(String academyId) async {
    try {
      final box = await _box;
      final raw = box.get(_key(academyId));
      if (raw == null || raw.isEmpty) return null;
      final decoded =
          raw.length < 8000 ? jsonDecode(raw) as List<dynamic> : await compute(_decodeTrophyListInIsolate, raw);
      return decoded
          .map((e) => TrophyDto.fromHiveMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e, st) {
      _log.warning('read cache failed', e, st);
      throw const CacheTrophyFailure('Não foi possível ler o cache local.');
    }
  }

  @override
  Future<void> write(String academyId, List<TrophyDto> items) async {
    try {
      final box = await _box;
      final payload = items.map((e) => e.toHiveMap()).toList();
      final encoded = payload.length < 80
          ? jsonEncode(payload)
          : await compute(_encodeTrophyListInIsolate, payload);
      await box.put(_key(academyId), encoded);
    } catch (e, st) {
      _log.warning('write cache failed', e, st);
      throw const CacheTrophyFailure('Não foi possível gravar o cache local.');
    }
  }

  @override
  Future<void> clear(String academyId) async {
    final box = await _box;
    await box.delete(_key(academyId));
  }
}
